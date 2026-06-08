/// <reference types="vite/client" />

declare module '*.json' {
  const value: unknown
  export default value
}

interface ImportMetaEnv {
  readonly VITE_PROJECT_ID: string
  readonly VITE_TOKEN_BANK_ADDRESS?: string
  readonly VITE_PERMIT2_ADDRESS?: string
  /** 已部署的 NFTMarket 合约地址（与当前连接网络一致） */
  readonly VITE_NFT_MARKET_ADDRESS?: string
  /** 已部署的 AirdropMerkleNFTMarket 合约地址 */
  readonly VITE_AIRDROP_MERKLE_MARKET_ADDRESS?: string
  /** ERC2612 Token 地址（测试转账用，可选） */
  readonly VITE_ERC2612_TOKEN_ADDRESS?: string
  /** 可选：覆盖 Anvil RPC（默认 dev 用 /rpc-anvil 代理） */
  readonly VITE_ANVIL_RPC_URL?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
