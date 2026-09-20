import { Type } from "typebox";
export type BitwardenCliBoundary = {
    fetchLogin(itemName: string): Promise<void>;
};
export declare const VaultFetchParameters: Type.TObject<{
    itemName: Type.TString;
}>;
export declare function createVaultAccessBrokerPlugin(cli?: BitwardenCliBoundary): import("openclaw/plugin-sdk/tool-plugin").DefinedToolPluginEntry;
declare const _default: import("openclaw/plugin-sdk/tool-plugin").DefinedToolPluginEntry;
export default _default;
