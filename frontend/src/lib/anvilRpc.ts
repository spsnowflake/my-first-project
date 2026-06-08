/** 本地 Anvil RPC：开发环境走 Vite 代理，避免 WSL 下浏览器直连 127.0.0.1:8545 失败 */
export function getAnvilRpcUrl(): string {
  const fromEnv = import.meta.env.VITE_ANVIL_RPC_URL?.trim()
  if (fromEnv) return fromEnv
  if (import.meta.env.DEV) return '/rpc-anvil'
  return 'http://127.0.0.1:8545'
}

export const ANVIL_CHAIN_ID = 31337
