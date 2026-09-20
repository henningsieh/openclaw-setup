import { Type } from "typebox";
import { defineToolPlugin } from "openclaw/plugin-sdk/tool-plugin";

export type BitwardenCliBoundary = {
  fetchLogin(itemName: string): Promise<void>;
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

const unprovisionedCli: BitwardenCliBoundary = {
  async fetchLogin() {
    throw new Error(
      "Vault Access Broker is not provisioned. Configure the pinned Vault Access Runtime before enabling this tool.",
    );
  },
};

export function createVaultAccessBrokerPlugin(cli: BitwardenCliBoundary = unprovisionedCli) {
  return defineToolPlugin({
    id: "vault-access-broker",
    name: "Vault Access Broker",
    description: "Retrieves an approved, use-only login from the Personal Vault Identity.",
    tools: (tool) => [
      tool({
        name: "vault_fetch",
        label: "Vault Fetch",
        description:
          "Retrieve an approved username-and-password login pair for downstream use. Never repeat the response in chat.",
        optional: true,
        parameters: VaultFetchParameters,
        execute: async ({ itemName }) => cli.fetchLogin(itemName),
      }),
    ],
  });
}

export default createVaultAccessBrokerPlugin();
