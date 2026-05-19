/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_PROJECT_ID: string
  readonly VITE_TOKEN_BANK_ADDRESS?: string
  readonly VITE_PERMIT2_ADDRESS?: string
  /** 已部署的 NFTMarket 合约地址（与当前连接网络一致） */
  readonly VITE_NFT_MARKET_ADDRESS?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
