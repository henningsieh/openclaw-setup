import { readFile } from "node:fs/promises";
import { spawn } from "node:child_process";
import { Type } from "typebox";
import { defineToolPlugin } from "openclaw/plugin-sdk/tool-plugin";
import { jsonResult } from "openclaw/plugin-sdk/tool-results";

const VAULT_FETCH_TOOL_NAME = "vault_fetch";
const SHELLDON_AGENT_ID = "shelldon";
const REDACTED_RESULT = "[Vault Access Broker Credential Response redacted]";

export type CredentialResponse = {
  username: string;
  password: string;
};

export type BitwardenCliBoundary = {
  fetchLogin(itemName: string, signal?: AbortSignal): Promise<CredentialResponse>;
};

export type BitwardenCommand = {
  binary: string;
  args: string[];
  environment?: NodeJS.ProcessEnv;
  signal?: AbortSignal;
};

export type BitwardenCommandRunner = (command: BitwardenCommand) => Promise<string>;
type CredentialReader = (path: string) => Promise<string>;

type BitwardenCliOptions = {
  bwBin: string;
  serverUrl: string;
  credentialDirectory: string;
};

type BitwardenStatus = {
  status?: string;
  serverUrl?: string;
};

type VaultItem = {
  name?: unknown;
  type?: unknown;
  login?: {
    username?: unknown;
    password?: unknown;
  };
};

export const VaultFetchParameters = Type.Object(
  {
    itemName: Type.String({
      description: "Vault Item name to retrieve for a downstream login.",
      minLength: 1,
    }),
  },
  { additionalProperties: false },
);

function credentialPath(directory: string, name: string) {
  return `${directory}/${name}`;
}

function safeError(message: string): Error {
  return new Error(`Vault Access Broker: ${message}`);
}

function parseJson<T>(value: string, error: string): T {
  try {
    return JSON.parse(value) as T;
  } catch {
    throw safeError(error);
  }
}

function isLogin(item: VaultItem): item is VaultItem & { login: { username: string; password: string } } {
  return (
    item.type === 1 &&
    typeof item.login?.username === "string" &&
    item.login.username.length > 0 &&
    typeof item.login.password === "string" &&
    item.login.password.length > 0
  );
}

function selectVaultItem(items: VaultItem[], itemName: string): VaultItem {
  const exactMatches = items.filter((item) => item.name === itemName);
  if (exactMatches.length === 1) return exactMatches[0];
  if (exactMatches.length > 1) throw safeError("ambiguous Vault Item lookup");
  if (items.length === 0) throw safeError("Vault Item not found");
  if (items.length !== 1) throw safeError("ambiguous Vault Item lookup");
  return items[0];
}

async function runBitwardenCommand({ binary, args, environment, signal }: BitwardenCommand): Promise<string> {
  return await new Promise<string>((resolve, reject) => {
    const process = spawn(binary, args, {
      env: environment,
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    process.stdout.setEncoding("utf8");
    process.stdout.on("data", (chunk) => {
      stdout += chunk;
    });
    process.on("error", () => reject(safeError("Bitwarden CLI command failed")));
    process.on("close", (code) => {
      if (code === 0) resolve(stdout);
      else reject(safeError("Bitwarden CLI command failed"));
    });
    signal?.addEventListener(
      "abort",
      () => {
        process.kill();
        reject(signal.reason instanceof Error ? signal.reason : safeError("request cancelled"));
      },
      { once: true },
    );
  });
}

export class BitwardenCli implements BitwardenCliBoundary {
  constructor(
    private readonly run: BitwardenCommandRunner,
    private readonly options: BitwardenCliOptions,
    private readonly readCredential: CredentialReader = async (path) => await readFile(path, "utf8"),
  ) {}

  async fetchLogin(itemName: string, signal?: AbortSignal): Promise<CredentialResponse> {
    let session: string | undefined;
    try {
      const status = parseJson<BitwardenStatus>(
        await this.command(["status", "--raw"], undefined, signal),
        "could not read CLI status",
      );
      if (status.serverUrl !== this.options.serverUrl) {
        await this.command(["config", "server", this.options.serverUrl], undefined, signal);
      }
      if (status.status === "unauthenticated") {
        await this.login(signal);
      }
      if (status.status !== "unlocked") {
        session = (await this.command(
          ["unlock", "--passwordfile", credentialPath(this.options.credentialDirectory, "vault_master_password"), "--raw"],
          undefined,
          signal,
        )).trim();
        if (!session) throw safeError("could not unlock the Personal Vault Identity");
      }
      const items = parseJson<VaultItem[]>(
        await this.command(["list", "items", "--search", itemName], session, signal),
        "could not read matching Vault Items",
      );
      if (!Array.isArray(items)) throw safeError("could not read matching Vault Items");
      const item = selectVaultItem(items, itemName);
      if (!isLogin(item)) throw safeError("Vault Item is not a username-and-password login");
      return { username: item.login.username, password: item.login.password };
    } finally {
      await this.command(["lock"], session, signal).catch(() => undefined);
    }
  }

  private async login(signal?: AbortSignal) {
    const [clientId, clientSecret] = await Promise.all([
      this.readCredential(credentialPath(this.options.credentialDirectory, "vault_api_key")),
      this.readCredential(credentialPath(this.options.credentialDirectory, "vault_api_client_secret")),
    ]).catch(() => {
      throw safeError("bootstrap credentials are unavailable");
    });
    await this.command(
      ["login", "--apikey"],
      undefined,
      signal,
      { BW_CLIENTID: clientId.trim(), BW_CLIENTSECRET: clientSecret.trim() },
    );
  }

  private async command(
    args: string[],
    session: string | undefined,
    signal?: AbortSignal,
    overrides: NodeJS.ProcessEnv = {},
  ) {
    return await this.run({
      binary: this.options.bwBin,
      args,
      signal,
      environment: {
        ...process.env,
        ...overrides,
        ...(session ? { BW_SESSION: session } : {}),
      },
    });
  }
}

function createRuntimeBitwardenCli(): BitwardenCliBoundary {
  const credentialDirectory = process.env.CREDENTIALS_DIRECTORY;
  const bwBin = process.env.VAULT_ACCESS_BROKER_BW_BIN;
  const serverUrl = process.env.VAULT_ACCESS_BROKER_SERVER_URL;
  if (!credentialDirectory || !bwBin || !serverUrl) {
    return {
      async fetchLogin() {
        throw safeError("is not provisioned");
      },
    };
  }
  return new BitwardenCli(runBitwardenCommand, { bwBin, serverUrl, credentialDirectory });
}

type TurnContext = {
  agentId?: string;
};

function isShelldonTurn(context: TurnContext) {
  return context.agentId === SHELLDON_AGENT_ID;
}

export function redactVaultFetchResult<T extends object>(message: T): T {
  const record = message as T & { details?: unknown };
  const { details: _details, ...withoutDetails } = record;
  return {
    ...withoutDetails,
    content: [{ type: "text", text: REDACTED_RESULT }],
  } as T;
}

export function createVaultAccessBrokerPlugin(cli: BitwardenCliBoundary = createRuntimeBitwardenCli()) {
  const plugin = defineToolPlugin({
    id: "vault-access-broker",
    name: "Vault Access Broker",
    description: "Retrieves an approved, use-only login from the Personal Vault Identity.",
    tools: (tool) => [
      tool({
        name: VAULT_FETCH_TOOL_NAME,
        label: "Vault Fetch",
        description:
          "Retrieve a username-and-password Credential Response only for downstream login use. Never disclose it in chat.",
        optional: true,
        parameters: VaultFetchParameters,
        factory: () => {
          return {
            name: VAULT_FETCH_TOOL_NAME,
            label: "Vault Fetch",
            description:
              "Use the Credential Response only to complete the requested downstream login. Never disclose it in chat.",
            parameters: VaultFetchParameters,
            executionMode: "sequential" as const,
            hideFromChannelProgress: true,
            execute: async (_toolCallId, params, signal) =>
              jsonResult(await cli.fetchLogin((params as { itemName: string }).itemName, signal)),
          };
        },
      }),
    ],
  });
  const registerTools = plugin.register;
  plugin.register = (api) => {
    registerTools(api);
    api.on("before_tool_call", (event, context) => {
      if (event.toolName !== VAULT_FETCH_TOOL_NAME) return;
      if (!isShelldonTurn(context)) {
        return { block: true, blockReason: "Vault Access Broker is available only to Shelldon." };
      }
      return {
        requireApproval: {
          title: "Retrieve login credential",
          description: "Retrieve a username-and-password login for the requested downstream use.",
          severity: "warning",
          allowedDecisions: ["allow-once", "deny"],
        },
      };
    });
    api.on("tool_result_persist", (event, context) => {
      if (event.toolName !== VAULT_FETCH_TOOL_NAME && context.toolName !== VAULT_FETCH_TOOL_NAME) return;
      return { message: redactVaultFetchResult(event.message) };
    });
  };
  return plugin;
}

export default createVaultAccessBrokerPlugin();
