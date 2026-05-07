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
  const bankAddressRaw =
    import.meta.env.VITE_TOKEN_BANK_ADDRESS?.trim() || undefined
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

  const {
    data: walletBalance,
    isError: walletBalanceReadError,
    error: walletBalanceReadErr,
    isPending: walletBalancePending,
    refetch: refetchWallet,
  } = useReadContract({
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

  const walletBalanceSafe = walletBalance ?? 0n
  const walletFormatted =
    walletBalanceReadError
      ? '读取失败'
      : walletBalancePending
        ? '…'
        : formatUnits(walletBalanceSafe, Number(decimals))
  const bankFormatted = formatUnits(bankBalance, Number(decimals))

  const doDeposit = useCallback(async () => {
    if (!bankAddress || !token || !address || !publicClient || !amountWei) {
      setError('请填写有效金额并确保已连接钱包。')
      return
    }
    if (!chain) {
      setError('当前链未在 wagmi 配置中（例如需包含 Foundry 31337）。请检查 appkit 网络列表。')
      return
    }
    setError(null)
    setBusy(true)
    const account = address as `0x${string}`
    try {
      if (walletBalance !== undefined && amountWei > walletBalance) {
        setError('钱包 TOKEN 余额不足')
        return
      }
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
    walletBalance,
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
            <p
              style={{
                margin: '0.5rem 0 0',
                fontSize: '0.75rem',
                color: '#666',
                wordBreak: 'break-all',
              }}
            >
              链 ID：{chainId}
              {chain ? `（${chain.name}）` : ''}
              <br />
              当前钱包：{address}
              <br />
              代币合约：{token ?? '—'}
            </p>
          </div>

          {walletBalanceReadError && walletBalanceReadErr ? (
            <p
              style={{
                margin: 0,
                fontSize: '0.85rem',
                maxWidth: 420,
                textAlign: 'center',
                color: '#b00020',
                lineHeight: 1.5,
              }}
            >
              读取余额失败（常被误判成余额 0）。请确认钱包已切到{' '}
              <strong>本地 Anvil / Foundry（chainId 31337）</strong>
              ，且浏览器能访问你 Anvil 的 RPC（本机{' '}
              <code style={{ fontSize: '0.8em' }}>127.0.0.1:8545</code>
              ）。错误：{walletBalanceReadErr.message}
            </p>
          ) : null}

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

          {!walletBalanceReadError &&
          !walletBalancePending &&
          walletBalance === 0n &&
          chainId === 31337 ? (
            <p
              style={{
                margin: 0,
                fontSize: '0.85rem',
                maxWidth: 420,
                textAlign: 'center',
                color: '#555',
                lineHeight: 1.5,
              }}
            >
              当前钱包在该代币合约上余额为 0。ERC20 / MyToken 部署时会把初始供应量记在
              <strong>部署者地址</strong>（Anvil 默认第一把私钥对应{' '}
              <code style={{ fontSize: '0.8em' }}>0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266</code>
              ）。请确认 MetaMask 选中的是该账户；若重启过 Anvil，需重新部署合约并更新{' '}
              <code style={{ fontSize: '0.8em' }}>VITE_TOKEN_BANK_ADDRESS</code>。
            </p>
          ) : null}

          {!walletBalanceReadError &&
          !walletBalancePending &&
          walletBalance === 0n &&
          chainId !== 31337 ? (
            <p
              style={{
                margin: 0,
                fontSize: '0.85rem',
                maxWidth: 420,
                textAlign: 'center',
                color: '#b00020',
                lineHeight: 1.5,
              }}
            >
              当前链 ID 为 {chainId}，不是本地 Anvil（31337）。请把钱包网络切到 Foundry / 本地链后再看余额。
            </p>
          ) : null}

          {amountWei && amountWei > bankBalance ? (
            <p
              style={{
                margin: 0,
                fontSize: '0.85rem',
                maxWidth: 420,
                textAlign: 'center',
                color: '#b00020',
                lineHeight: 1.5,
              }}
            >
              取款金额不能大于银行内存款（当前存款：{bankFormatted} {symbol}）。
            </p>
          ) : null}

          <div style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap', justifyContent: 'center' }}>
            <button
              type="button"
              disabled={
                busy ||
                !amountWei ||
                amountWei <= 0n ||
                walletBalanceReadError ||
                walletBalancePending ||
                (walletBalance !== undefined && amountWei > walletBalance)
              }
              title={
                walletBalance === 0n && amountWei && amountWei > 0n
                  ? '钱包 TOKEN 余额为 0，无法存款'
                  : undefined
              }
              onClick={() => void doDeposit()}
              style={{
                ...btnStyle,
                opacity:
                  busy ||
                  !amountWei ||
                  amountWei <= 0n ||
                  walletBalanceReadError ||
                  walletBalancePending ||
                  (walletBalance !== undefined && amountWei > walletBalance)
                    ? 0.45
                    : 1,
              }}
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
              title={
                amountWei && amountWei > bankBalance
                  ? `取款金额不能大于银行内存款（当前 ${bankFormatted} ${symbol}）`
                  : undefined
              }
              onClick={() => void doWithdraw()}
              style={{
                ...btnStyle,
                opacity:
                  busy ||
                  !amountWei ||
                  amountWei <= 0n ||
                  amountWei > bankBalance
                    ? 0.45
                    : 1,
              }}
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
