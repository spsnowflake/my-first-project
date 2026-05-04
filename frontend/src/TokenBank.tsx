import { useCallback, useMemo, useState, type CSSProperties } from 'react'
import { useAppKitAccount } from '@reown/appkit/react'
import { isAddress, parseUnits, formatUnits } from 'viem'
import {
  useChainId,
  useChains,
  usePublicClient,
  useReadContract,
  useWriteContract,
} from 'wagmi'
import { erc20Abi, tokenBankAbi } from './abis/tokenBank'

function isBankAddress(v: string | undefined): v is `0x${string}` {
  return Boolean(v && isAddress(v))
}

export default function TokenBank() {
  const { address, isConnected } = useAppKitAccount()
  const bankAddressRaw = import.meta.env.VITE_TOKEN_BANK_ADDRESS
  const bankAddress = isBankAddress(bankAddressRaw)
    ? bankAddressRaw
    : undefined

  const [amountStr, setAmountStr] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const { data: tokenAddress } = useReadContract({
    address: bankAddress,
    abi: tokenBankAbi,
    functionName: 'erc20_address',
    query: { enabled: Boolean(bankAddress) },
  })

  const token = tokenAddress && isAddress(tokenAddress) ? tokenAddress : undefined

  const { data: decimals = 18 } = useReadContract({
    address: token,
    abi: erc20Abi,
    functionName: 'decimals',
    query: { enabled: Boolean(token) },
  })

  const { data: symbol = 'TOKEN' } = useReadContract({
    address: token,
    abi: erc20Abi,
    functionName: 'symbol',
    query: { enabled: Boolean(token) },
  })

  const { data: walletBalance = 0n, refetch: refetchWallet } = useReadContract({
    address: token,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address as `0x${string}`] : undefined,
    query: { enabled: Boolean(token && address) },
  })

  const { data: allowance = 0n, refetch: refetchAllowance } = useReadContract({
    address: token,
    abi: erc20Abi,
    functionName: 'allowance',
    args:
      token && address && bankAddress
        ? [address as `0x${string}`, bankAddress]
        : undefined,
    query: { enabled: Boolean(token && address && bankAddress) },
  })

  const { data: bankBalance = 0n, refetch: refetchBank } = useReadContract({
    address: bankAddress,
    abi: tokenBankAbi,
    functionName: 'balances',
    args: address ? [address as `0x${string}`] : undefined,
    query: { enabled: Boolean(bankAddress && address) },
  })

  const chainId = useChainId()
  const chains = useChains()
  const chain = chains.find((c) => c.id === chainId)

  const publicClient = usePublicClient()
  const { writeContractAsync } = useWriteContract()

  const amountWei = useMemo(() => {
    try {
      if (!amountStr.trim()) return null
      return parseUnits(amountStr, Number(decimals))
    } catch {
      return null
    }
  }, [amountStr, decimals])

  const walletFormatted = formatUnits(walletBalance, Number(decimals))
  const bankFormatted = formatUnits(bankBalance, Number(decimals))

  const doDeposit = useCallback(async () => {
    if (!bankAddress || !token || !address || !publicClient || !amountWei || !chain)
      return
    setError(null)
    setBusy(true)
    const account = address as `0x${string}`
    try {
      if (allowance < amountWei) {
        const approveHash = await writeContractAsync({
          address: token,
          abi: erc20Abi,
          functionName: 'approve',
          args: [bankAddress, amountWei],
          chain,
          account,
        })
        await publicClient.waitForTransactionReceipt({ hash: approveHash })
        await refetchAllowance()
      }
      const depositHash = await writeContractAsync({
        address: bankAddress,
        abi: tokenBankAbi,
        functionName: 'deposit',
        args: [amountWei],
        chain,
        account,
      })
      await publicClient.waitForTransactionReceipt({ hash: depositHash })
      await Promise.all([refetchWallet(), refetchBank(), refetchAllowance()])
    } catch (e) {
      setError(e instanceof Error ? e.message : '存款失败')
    } finally {
      setBusy(false)
    }
  }, [
    bankAddress,
    token,
    address,
    chain,
    publicClient,
    amountWei,
    allowance,
    writeContractAsync,
    refetchAllowance,
    refetchWallet,
    refetchBank,
  ])

  const doWithdraw = useCallback(async () => {
    if (!bankAddress || !address || !publicClient || !amountWei || !chain) return
    if (amountWei > bankBalance) {
      setError('取款金额不能大于银行内余额')
      return
    }
    setError(null)
    setBusy(true)
    const account = address as `0x${string}`
    try {
      const hash = await writeContractAsync({
        address: bankAddress,
        abi: tokenBankAbi,
        functionName: 'withdraw',
        args: [amountWei],
        chain,
        account,
      })
      await publicClient.waitForTransactionReceipt({ hash })
      await Promise.all([refetchWallet(), refetchBank()])
    } catch (e) {
      setError(e instanceof Error ? e.message : '取款失败')
    } finally {
      setBusy(false)
    }
  }, [
    bankAddress,
    address,
    chain,
    publicClient,
    amountWei,
    bankBalance,
    writeContractAsync,
    refetchWallet,
    refetchBank,
  ])

  if (!bankAddress) {
    return (
      <div style={{ padding: '1.5rem', maxWidth: 480, margin: '0 auto' }}>
        <p style={{ margin: 0 }}>
          请在 <code>frontend/.env</code> 中配置{' '}
          <code>VITE_TOKEN_BANK_ADDRESS</code>（已部署的 TokenBank 合约地址）。
        </p>
      </div>
    )
  }

  return (
    <div
      style={{
        minHeight: '100vh',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: '1rem',
        padding: '1rem',
        boxSizing: 'border-box',
      }}
    >
      <h1 style={{ margin: 0, fontSize: '1.25rem', fontWeight: 600 }}>
        Token Bank
      </h1>

      {!isConnected || !address ? (
        <p style={{ margin: 0 }}>请先连接钱包。</p>
      ) : (
        <>
          <div
            style={{
              fontSize: '0.9rem',
              lineHeight: 1.6,
              textAlign: 'center',
              maxWidth: 400,
            }}
          >
            <p style={{ margin: '0 0 0.25rem' }}>
              钱包内 <strong>{symbol}</strong> 余额：{walletFormatted}
            </p>
            <p style={{ margin: 0 }}>
              银行内存款：{bankFormatted} {symbol}
            </p>
          </div>

          <label style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
            <span style={{ fontSize: '0.85rem' }}>金额（{symbol}）</span>
            <input
              type="text"
              inputMode="decimal"
              value={amountStr}
              onChange={(e) => setAmountStr(e.target.value)}
              placeholder="0.0"
              style={{
                padding: '0.5rem 0.65rem',
                borderRadius: 8,
                border: '1px solid #ccc',
                minWidth: 220,
              }}
            />
          </label>

          <div style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap', justifyContent: 'center' }}>
            <button
              type="button"
              disabled={
                busy ||
                !amountWei ||
                amountWei <= 0n ||
                amountWei > walletBalance
              }
              onClick={() => void doDeposit()}
              style={btnStyle}
            >
              {busy ? '处理中…' : '存款'}
            </button>
            <button
              type="button"
              disabled={
                busy ||
                !amountWei ||
                amountWei <= 0n ||
                amountWei > bankBalance
              }
              onClick={() => void doWithdraw()}
              style={btnStyle}
            >
              {busy ? '处理中…' : '取款'}
            </button>
          </div>

          {error ? (
            <p style={{ margin: 0, color: '#b00020', fontSize: '0.85rem', maxWidth: 400, textAlign: 'center' }}>
              {error}
            </p>
          ) : null}
        </>
      )}
    </div>
  )
}

const btnStyle: CSSProperties = {
  padding: '0.55rem 1.1rem',
  fontSize: '1rem',
  cursor: 'pointer',
  borderRadius: 8,
  border: '1px solid #ccc',
  background: '#111',
  color: '#fafafa',
}
