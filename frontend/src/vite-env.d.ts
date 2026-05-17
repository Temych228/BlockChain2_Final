/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_ARBITRUM_SEPOLIA_RPC: string
  readonly VITE_WALLETCONNECT_PROJECT_ID: string
  readonly VITE_INSURANCE_POOL_ADDRESS: string
  readonly VITE_GOVERNOR_ADDRESS: string
  readonly VITE_VAULT_ADDRESS: string
  readonly VITE_COLLATERAL_MANAGER_ADDRESS: string
  readonly VITE_GOVERNANCE_TOKEN_ADDRESS: string
  readonly VITE_USDC_ADDRESS: string
  readonly VITE_SUBGRAPH_URL: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
