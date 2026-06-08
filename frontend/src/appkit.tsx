import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { createAppKit } from '@reown/appkit/react'
import type { AppKitNetwork } from '@reown/appkit-common'
import { foundry, mainnet, sepolia } from '@reown/appkit/networks'
import { WagmiAdapter } from '@reown/appkit-adapter-wagmi'
import { WagmiProvider } from 'wagmi'
import type { ReactNode } from 'react'
import { getAnvilRpcUrl } from './lib/anvilRpc'

const projectId = import.meta.env.VITE_PROJECT_ID
if (!projectId) {
  throw new Error('缺少 VITE_PROJECT_ID：请在 frontend/.env 中配置 Reown Dashboard 的 Project ID')
}

const queryClient = new QueryClient()

const metadata = {
  name: 'NftMarket_demo_测试',
  description: 'NftMarket 登录 demo',
  url: window.location.origin,
  icons: ['https://avatars.githubusercontent.com/u/179229932'],
}

/** Foundry 本地链：RPC 指向 Vite 代理 /rpc-anvil → 127.0.0.1:8545 */
const localFoundry: AppKitNetwork = {
  ...foundry,
  rpcUrls: {
    ...foundry.rpcUrls,
    default: { http: [getAnvilRpcUrl()] },
  },
}

const networks: [AppKitNetwork, ...AppKitNetwork[]] = [
  localFoundry,
  mainnet,
  sepolia,
]

const wagmiAdapter = new WagmiAdapter({
  networks,
  projectId,
})

createAppKit({
  adapters: [wagmiAdapter],
  networks,
  projectId,
  metadata,
})

export function AppKitWagmiProvider({ children }: { children: ReactNode }) {
  return (
    <WagmiProvider config={wagmiAdapter.wagmiConfig}>
      <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
    </WagmiProvider>
  )
}
