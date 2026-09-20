import { describe, expect, it, vi } from "vitest";
import entry, { createVaultAccessBrokerPlugin } from "./index.js";
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

function loadVaultFetchTool(plugin = entry): ToolRegistration {
  const registrations: ToolRegistration[] = [];
  plugin.register({
    registerTool: (tool: RegisteredTool, options: { optional?: boolean }) =>
      registrations.push({ tool, options }),
  } as never);

  expect(registrations).toHaveLength(1);
  return registrations[0];
}

describe("vault-access-broker", () => {
  it("declares vault_fetch as an optional tool", () => {
    expect(getToolPluginMetadata(entry)?.tools).toEqual([
      expect.objectContaining({ name: "vault_fetch", optional: true }),
    ]);
  });

  it("registers vault_fetch as optional in the loaded plugin runtime", () => {
    const registration = loadVaultFetchTool();

    expect(registration.tool.name).toBe("vault_fetch");
    expect(registration.options).toMatchObject({ optional: true });
  });

  it("invokes the public tool through a controlled Bitwarden CLI boundary", async () => {
    const cli = {
      fetchLogin: vi.fn().mockRejectedValue(new Error("fake CLI is not provisioned")),
    };
    const registration = loadVaultFetchTool(createVaultAccessBrokerPlugin(cli));

    await expect(registration.tool.execute("test-call", { itemName: "Example" })).rejects.toThrow(
      "fake CLI is not provisioned",
    );
    expect(cli.fetchLogin).toHaveBeenCalledWith("Example");
  });
});
