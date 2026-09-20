import { readFile } from "node:fs/promises";
import { spawn } from "node:child_process";
import { Type } from "typebox";
import { defineToolPlugin } from "openclaw/plugin-sdk/tool-plugin";
import { jsonResult } from "openclaw/plugin-sdk/tool-results";
const VAULT_FETCH_TOOL_NAME = "vault_fetch";
const SHELLDON_AGENT_ID = "shelldon";
const REDACTED_RESULT = "[Vault Access Broker Credential Response redacted]";
export const VaultFetchParameters = Type.Object({
    itemName: Type.String({
        description: "Vault Item name to retrieve for a downstream login.",
        minLength: 1,
    }),
}, { additionalProperties: false });
function credentialPath(directory, name) {
    return `${directory}/${name}`;
}
function safeError(message) {
    return new Error(`Vault Access Broker: ${message}`);
}
function parseJson(value, error) {
    try {
        return JSON.parse(value);
    }
    catch {
        throw safeError(error);
    }
}
function isLogin(item) {
    return (item.type === 1 &&
        typeof item.login?.username === "string" &&
        item.login.username.length > 0 &&
        typeof item.login.password === "string" &&
        item.login.password.length > 0);
}
function selectVaultItem(items, itemName) {
    const exactMatches = items.filter((item) => item.name === itemName);
    if (exactMatches.length === 1)
        return exactMatches[0];
    if (exactMatches.length > 1)
        throw safeError("ambiguous Vault Item lookup");
    if (items.length === 0)
        throw safeError("Vault Item not found");
    if (items.length !== 1)
        throw safeError("ambiguous Vault Item lookup");
    return items[0];
}
async function runBitwardenCommand({ binary, args, environment, signal }) {
    return await new Promise((resolve, reject) => {
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
            if (code === 0)
                resolve(stdout);
            else
                reject(safeError("Bitwarden CLI command failed"));
        });
        signal?.addEventListener("abort", () => {
            process.kill();
            reject(signal.reason instanceof Error ? signal.reason : safeError("request cancelled"));
        }, { once: true });
    });
}
export class BitwardenCli {
    run;
    options;
    readCredential;
    constructor(run, options, readCredential = async (path) => await readFile(path, "utf8")) {
        this.run = run;
        this.options = options;
        this.readCredential = readCredential;
    }
    async fetchLogin(itemName, signal) {
        let session;
        try {
            const status = parseJson(await this.command(["status", "--raw"], undefined, signal), "could not read CLI status");
            if (status.serverUrl !== this.options.serverUrl) {
                await this.command(["config", "server", this.options.serverUrl], undefined, signal);
            }
            if (status.status === "unauthenticated") {
                await this.login(signal);
            }
            if (status.status !== "unlocked" || !process.env.BW_SESSION) {
                session = (await this.command(["unlock", "--passwordfile", credentialPath(this.options.credentialDirectory, "vault_master_password"), "--raw"], undefined, signal)).trim();
                if (!session)
                    throw safeError("could not unlock the Personal Vault Identity");
            }
            const items = parseJson(await this.command(["list", "items", "--search", itemName], session, signal), "could not read matching Vault Items");
            if (!Array.isArray(items))
                throw safeError("could not read matching Vault Items");
            const item = selectVaultItem(items, itemName);
            if (!isLogin(item))
                throw safeError("Vault Item is not a username-and-password login");
            return { username: item.login.username, password: item.login.password };
        }
        finally {
            await this.command(["lock"], undefined, signal).catch(() => undefined);
        }
    }
    async login(signal) {
        const [clientId, clientSecret] = await Promise.all([
            this.readCredential(credentialPath(this.options.credentialDirectory, "vault_api_key")),
            this.readCredential(credentialPath(this.options.credentialDirectory, "vault_api_client_secret")),
        ]).catch(() => {
            throw safeError("bootstrap credentials are unavailable");
        });
        await this.command(["login", "--apikey"], undefined, signal, { BW_CLIENTID: clientId.trim(), BW_CLIENTSECRET: clientSecret.trim() });
    }
    async command(args, session, signal, overrides = {}) {
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
function createRuntimeBitwardenCli() {
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
function isSubagentSession(sessionKey) {
    return !sessionKey || /(^|:)subagent(?::|$)/.test(sessionKey);
}
function isInteractiveVerifiedOwnerTurn(context) {
    return (context.agentId === SHELLDON_AGENT_ID &&
        context.senderIsOwner === true &&
        Boolean(context.requesterSenderId) &&
        Boolean(context.messageChannel) &&
        Boolean(context.nativeChannelId) &&
        !context.sandboxed &&
        !isSubagentSession(context.sessionKey));
}
function isApprovedTurnContext(context) {
    return (context.agentId === SHELLDON_AGENT_ID &&
        context.requester?.senderIsOwner === true &&
        Boolean(context.requester.senderId) &&
        Boolean(context.requester.channel) &&
        !isSubagentSession(context.sessionKey));
}
export function redactVaultFetchResult(message) {
    const record = message;
    const { details: _details, ...withoutDetails } = record;
    return {
        ...withoutDetails,
        content: [{ type: "text", text: REDACTED_RESULT }],
    };
}
export function createVaultAccessBrokerPlugin(cli = createRuntimeBitwardenCli()) {
    const plugin = defineToolPlugin({
        id: "vault-access-broker",
        name: "Vault Access Broker",
        description: "Retrieves an approved, use-only login from the Personal Vault Identity.",
        tools: (tool) => [
            tool({
                name: VAULT_FETCH_TOOL_NAME,
                label: "Vault Fetch",
                description: "Retrieve a username-and-password Credential Response only for downstream login use. Never disclose it in chat.",
                optional: true,
                parameters: VaultFetchParameters,
                factory: ({ toolContext }) => {
                    if (!isInteractiveVerifiedOwnerTurn(toolContext))
                        return null;
                    return {
                        name: VAULT_FETCH_TOOL_NAME,
                        label: "Vault Fetch",
                        description: "Use the Credential Response only to complete the requested downstream login. Never disclose it in chat.",
                        parameters: VaultFetchParameters,
                        executionMode: "sequential",
                        hideFromChannelProgress: true,
                        execute: async (_toolCallId, params, signal) => jsonResult(await cli.fetchLogin(params.itemName, signal)),
                    };
                },
            }),
        ],
    });
    const registerTools = plugin.register;
    plugin.register = (api) => {
        registerTools(api);
        api.on("before_tool_call", (event, context) => {
            if (event.toolName !== VAULT_FETCH_TOOL_NAME)
                return;
            if (!isApprovedTurnContext(context)) {
                return { block: true, blockReason: "Vault Access Broker requires an Interactive Verified-Owner Turn." };
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
            if (event.toolName !== VAULT_FETCH_TOOL_NAME && context.toolName !== VAULT_FETCH_TOOL_NAME)
                return;
            return { message: redactVaultFetchResult(event.message) };
        });
    };
    return plugin;
}
export default createVaultAccessBrokerPlugin();
