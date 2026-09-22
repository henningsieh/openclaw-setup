import { Type } from "typebox";
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
export declare const VaultFetchParameters: Type.TObject<{
    itemName: Type.TString;
}>;
export declare class BitwardenCli implements BitwardenCliBoundary {
    private readonly run;
    private readonly options;
    private readonly readCredential;
    constructor(run: BitwardenCommandRunner, options: BitwardenCliOptions, readCredential?: CredentialReader);
    fetchLogin(itemName: string, signal?: AbortSignal): Promise<CredentialResponse>;
    private login;
    private command;
}
export declare function redactVaultFetchResult<T extends object>(message: T): T;
export declare function createVaultAccessBrokerPlugin(cli?: BitwardenCliBoundary): import("openclaw/plugin-sdk/tool-plugin").DefinedToolPluginEntry;
declare const _default: import("openclaw/plugin-sdk/tool-plugin").DefinedToolPluginEntry;
export default _default;
