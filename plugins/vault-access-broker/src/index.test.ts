import { describe, expect, it, vi } from "vitest";
import entry, {
  BitwardenCli,
  createVaultAccessBrokerPlugin,
  redactVaultFetchResult,
  type BitwardenCommandRunner,
} from "./index.js";
import { getToolPluginMetadata } from "openclaw/plugin-sdk/tool-plugin";

type RegisteredTool = {
  name: string;
  execute: (
    toolCallId: string,
    params: { itemName: string },
    signal?: AbortSignal,
  ) => Promise<unknown>;
};

type ToolRegistration = {
  tool: RegisteredTool;
  options: { optional?: boolean };
};

type Hook = (event: Record<string, unknown>, context: Record<string, unknown>) => unknown;

function loadVaultFetchTool(
  plugin = entry,
  toolContext: Record<string, unknown> = {
    agentId: "shelldon",
    messageChannel: "telegram",
    nativeChannelId: "owner-chat",
    requesterSenderId: "owner",
    senderIsOwner: true,
    sessionKey: "agent:shelldon:telegram:owner-chat",
  },
): ToolRegistration | undefined {
  const registrations: ToolRegistration[] = [];
  plugin.register({
    registerTool: (factory: (context: Record<string, unknown>) => RegisteredTool | null, options: { optional?: boolean }) => {
      const tool = factory(toolContext);
      if (tool) registrations.push({ tool, options });
    },
    on: vi.fn(),
  } as never);

  return registrations[0];
}

describe("vault-access-broker", () => {
  it("declares vault_fetch as an optional tool", () => {
    expect(getToolPluginMetadata(entry)?.tools).toEqual([
      expect.objectContaining({ name: "vault_fetch", optional: true }),
    ]);
  });

  it("registers vault_fetch when the optional-tool catalog has no turn context", () => {
    expect(loadVaultFetchTool(entry, {})).toMatchObject({ options: { optional: true } });
  });

  it("requires one-time approval for every Shelldon vault fetch", () => {
    const hooks: Array<{ name: string; hook: Hook }> = [];
    entry.register({
      registerTool: vi.fn(),
      on: (name: string, hook: Hook) => hooks.push({ name, hook }),
    } as never);
    const beforeFetch = hooks.find(({ name }) => name === "before_tool_call")?.hook;

    expect(beforeFetch).toBeDefined();
    expect(
      beforeFetch?.(
        { toolName: "vault_fetch", params: { itemName: "Example" } },
        { agentId: "shelldon" },
      ),
    ).toMatchObject({
      requireApproval: {
        allowedDecisions: ["allow-once", "deny"],
        title: "Retrieve login credential",
      },
    });
  });

  it("requires approval regardless of Shelldon session or requester context", () => {
    const hooks: Array<{ name: string; hook: Hook }> = [];
    entry.register({ registerTool: vi.fn(), on: (name: string, hook: Hook) => hooks.push({ name, hook }) } as never);
    const beforeFetch = hooks.find(({ name }) => name === "before_tool_call")?.hook;
    const event = { toolName: "vault_fetch", params: {} };

    for (const context of [
      { agentId: "shelldon", sessionKey: "agent:shelldon:webchat:any-session" },
      { agentId: "shelldon", sessionKey: "agent:shelldon:subagent:child", sandboxed: true },
      { agentId: "shelldon", sessionKey: "cron:shelldon:job" },
      { agentId: "shelldon", sessionKey: "heartbeat:shelldon" },
      { agentId: "shelldon", sessionKey: "agent:shelldon:background:job" },
      {
        agentId: "shelldon",
        requester: { channel: "telegram", senderId: "any-user", senderIsOwner: false },
      },
    ]) {
      expect(beforeFetch?.(event, context)).toMatchObject({ requireApproval: { allowedDecisions: ["allow-once", "deny"] } });
    }
  });

  it("blocks vault fetches for agents other than Shelldon", () => {
    const hooks: Array<{ name: string; hook: Hook }> = [];
    entry.register({ registerTool: vi.fn(), on: (name: string, hook: Hook) => hooks.push({ name, hook }) } as never);
    const beforeFetch = hooks.find(({ name }) => name === "before_tool_call")?.hook;

    expect(beforeFetch?.({ toolName: "vault_fetch", params: {} }, { agentId: "another-agent" })).toMatchObject({ block: true });
  });

  it("uses exact-name lookup before a single fallback and returns only a login pair", async () => {
    const calls: string[][] = [];
    const sessions: Array<string | undefined> = [];
    const runner: BitwardenCommandRunner = async ({ args, environment }) => {
      calls.push(args);
      sessions.push(environment?.BW_SESSION);
      if (args[0] === "status") return '{"status":"locked","serverUrl":"https://vault.example"}';
      if (args[0] === "unlock") return "session-token\n";
      if (args[0] === "list") {
        return JSON.stringify([
          { name: "Other Example", type: 1, login: { username: "other", password: "other-password" } },
          { name: "Example", type: 1, login: { username: "alice", password: "correct-password", totp: "hidden" } },
        ]);
      }
      return "";
    };
    const cli = new BitwardenCli(runner, {
      bwBin: "/private/bw",
      serverUrl: "https://vault.example",
      credentialDirectory: "/credentials",
    });

    await expect(cli.fetchLogin("Example")).resolves.toEqual({
      username: "alice",
      password: "correct-password",
    });
    expect(calls).toEqual([
      ["status", "--raw"],
      ["unlock", "--passwordfile", "/credentials/vault_master_password", "--raw"],
      ["list", "items", "--search", "Example"],
      ["lock"],
    ]);
    expect(sessions.slice(2)).toEqual(["session-token", "session-token"]);
  });

  it("configures and authenticates only when the CLI status requires it", async () => {
    const calls: string[][] = [];
    const runner: BitwardenCommandRunner = async ({ args }) => {
      calls.push(args);
      if (args[0] === "status") return '{"status":"unauthenticated","serverUrl":"https://other.example"}';
      if (args[0] === "unlock") return "session-token";
      if (args[0] === "list") return JSON.stringify([{ name: "Example", type: 1, login: { username: "alice", password: "password" } }]);
      return "";
    };
    const cli = new BitwardenCli(runner, {
      bwBin: "/private/bw",
      serverUrl: "https://vault.example",
      credentialDirectory: "/credentials",
    }, async () => "bootstrap");

    await cli.fetchLogin("Example");

    expect(calls.map((args) => args[0])).toEqual(["status", "config", "login", "unlock", "list", "lock"]);
  });

  it("accepts exactly one Lookup Fallback candidate", async () => {
    const runner: BitwardenCommandRunner = async ({ args }) => {
      if (args[0] === "status") return '{"status":"locked","serverUrl":"https://vault.example"}';
      if (args[0] === "unlock") return "session-token";
      if (args[0] === "list") return JSON.stringify([
        { name: "Actual Item", type: 1, login: { username: "alice", password: "password" } },
      ]);
      return "";
    };
    const cli = new BitwardenCli(runner, {
      bwBin: "/private/bw",
      serverUrl: "https://vault.example",
      credentialDirectory: "/credentials",
    });

    await expect(cli.fetchLogin("search phrase")).resolves.toEqual({ username: "alice", password: "password" });
  });

  it("locks the fetched session and fails closed for a cancelled request", async () => {
    const sessions: Array<string | undefined> = [];
    const controller = new AbortController();
    const runner: BitwardenCommandRunner = async ({ args, environment, signal }) => {
      sessions.push(environment?.BW_SESSION);
      if (args[0] === "status") return '{"status":"locked","serverUrl":"https://vault.example"}';
      if (args[0] === "unlock") return "session-token";
      if (args[0] === "list") {
        controller.abort(new Error("cancelled"));
        signal?.throwIfAborted();
      }
      return "";
    };
    const cli = new BitwardenCli(runner, {
      bwBin: "/private/bw",
      serverUrl: "https://vault.example",
      credentialDirectory: "/credentials",
    });

    await expect(cli.fetchLogin("Example", controller.signal)).rejects.toThrow();
    expect(sessions.at(-1)).toBe("session-token");
  });

  it("rejects ambiguous or non-login results and locks the vault after failure", async () => {
    const calls: string[][] = [];
    const runner: BitwardenCommandRunner = async ({ args }) => {
      calls.push(args);
      if (args[0] === "status") return '{"status":"locked","serverUrl":"https://vault.example"}';
      if (args[0] === "unlock") return "session-token";
      if (args[0] === "list") return JSON.stringify([
        { name: "One", type: 1, login: { username: "one", password: "one" } },
        { name: "Two", type: 1, login: { username: "two", password: "two" } },
      ]);
      return "";
    };
    const cli = new BitwardenCli(runner, {
      bwBin: "/private/bw",
      serverUrl: "https://vault.example",
      credentialDirectory: "/credentials",
    });

    await expect(cli.fetchLogin("missing")).rejects.toThrow("ambiguous Vault Item lookup");
    expect(calls.at(-1)).toEqual(["lock"]);
  });

  it("redacts persisted Credential Responses", () => {
    const password = "correct-password";
    const redacted = redactVaultFetchResult({
      role: "tool",
      toolCallId: "call-1",
      content: [{ type: "text", text: `alice:${password}` }],
      details: { username: "alice", password },
    } as never);

    expect(JSON.stringify(redacted)).not.toContain(password);
    expect(redacted).toMatchObject({
      content: [{ type: "text", text: "[Vault Access Broker Credential Response redacted]" }],
    });
  });

  it("invokes the public tool through the controlled Bitwarden CLI boundary", async () => {
    const cli = { fetchLogin: vi.fn().mockResolvedValue({ username: "alice", password: "password" }) };
    const registration = loadVaultFetchTool(createVaultAccessBrokerPlugin(cli));

    await expect(registration?.tool.execute("test-call", { itemName: "Example" })).resolves.toMatchObject({
      details: { username: "alice", password: "password" },
    });
    expect(cli.fetchLogin).toHaveBeenCalledWith("Example", undefined);
  });
});
