import { useAppKit, useAppKitAccount } from '@reown/appkit/react'
import { formatUnits } from 'viem'
import { useBalance, useChainId, useChains } from 'wagmi'

export default function NftMarket() {
  const { open } = useAppKit()
  const { address, isConnected } = useAppKitAccount()
  const chainId = useChainId()
  const chains = useChains()
  const chainName =
    chains.find((c) => c.id === chainId)?.name ?? `未知链`

  const { data: balance, isLoading: balanceLoading, isError: balanceError } =
    useBalance({
      address: address as `0x${string}` | undefined,
      query: {
        enabled: Boolean(address && isConnected),
      },
    })

  return (
    <div
      style={{
        minHeight: '100vh',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: '1.25rem',
        padding: '1rem',
        boxSizing: 'border-box',
      }}
    >
      <h1 style={{ margin: 0, fontSize: '1.25rem', fontWeight: 600 }}>
        NftMarket登录demo
      </h1>
      <button
        type="button"
        onClick={() => open()}
        style={{
          padding: '0.6rem 1.25rem',
          fontSize: '1rem',
          cursor: 'pointer',
          borderRadius: '8px',
          border: '1px solid #ccc',
          background: '#111',
          color: '#fafafa',
        }}
      >
        扫码连接钱包（WalletConnect）
      </button>
      {isConnected && address ? (
        <div
          style={{
            fontSize: '0.875rem',
            lineHeight: 1.6,
            textAlign: 'center',
            maxWidth: 'min(100%, 28rem)',
            wordBreak: 'break-word',
          }}
        >
          <p style={{ margin: '0 0 0.35rem' }}>
            <strong>地址</strong>
            <br />
            {address}
          </p>
          <p style={{ margin: '0 0 0.35rem' }}>
            <strong>网络</strong>
            <br />
            {chainName}（chainId {chainId}）
          </p>
          <p style={{ margin: 0 }}>
            <strong>余额</strong>
            <br />
            {balanceLoading
              ? '读取中…'
              : balanceError
                ? '余额读取失败'
                : balance
                  ? `${formatUnits(balance.value, balance.decimals)} ${balance.symbol}`
                  : `0 ${chains.find((c) => c.id === chainId)?.nativeCurrency.symbol ?? ''}`}
          </p>
        </div>
      ) : null}
    </div>
  )
}
