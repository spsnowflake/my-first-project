/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_PROJECT_ID: string
  readonly VITE_TOKEN_BANK_ADDRESS?: string
  readonly VITE_PERMIT2_ADDRESS?: string
  /** 已部署的 NFTMarket 合约地址（与当前连接网络一致） */
  readonly VITE_NFT_MARKET_ADDRESS?: string
  /** backend REST API 根地址，例如 http://127.0.0.1:3000 */
  readonly VITE_API_BASE_URL?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
