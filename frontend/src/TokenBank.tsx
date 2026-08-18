import { useCallback, useEffect, useMemo, useState, type CSSProperties } from 'react'
import { useAppKitAccount } from '@reown/appkit/react'
import { isAddress, maxUint256, parseUnits, formatUnits, type Hex } from 'viem'
import {
  useChainId,
  useChains,
  usePublicClient,
  useReadContract,
  useSendCalls,
  useWalletClient,
  useWriteContract,
} from 'wagmi'
import { erc20Abi, erc20PermitAbi, tokenBankAbi } from './abis/tokenBank'
import {
  buildPermitDomain,
  permitTypes,
  splitPermitSignature,
  verifyPermitSignature,
  type StoredPermitSignature,
} from './permitEip2612'
import {
  buildPermit2Domain,
  buildPermit2TransferMessage,
  permit2Deadline,
  permit2TransferTypes,
  randomPermit2Nonce,
} from './permit2Eip712'

function isBankAddress(v: string | undefined): v is `0x${string}` {
  return Boolean(v && isAddress(v))
}

/** MetaMask 官方 EIP-7702 Delegator（各支持链上地址相同） */
const MM_EIP7702_DELEGATOR =
  '0x63c0c19a282a1B52b07dD5a65b58948A07DAE32B' as const

function isMetaMask7702Delegated(code: Hex | undefined): boolean {
  if (!code || code === '0x') return false
  const expected = `0xef0100${MM_EIP7702_DELEGATOR.slice(2)}`.toLowerCase()
  return code.toLowerCase() === expected
}

export default function TokenBank() {
  const { address, isConnected } = useAppKitAccount()
  const bankAddressRaw =
    import.meta.env.VITE_TOKEN_BANK_ADDRESS?.trim() || undefined
  const bankAddress = isBankAddress(bankAddressRaw)
    ? bankAddressRaw
    : undefined

  const permit2AddressRaw =
    import.meta.env.VITE_PERMIT2_ADDRESS?.trim() || undefined
  const permit2Address = isBankAddress(permit2AddressRaw)
    ? permit2AddressRaw
    : undefined

  const [amountStr, setAmountStr] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const [permitOwnerStr, setPermitOwnerStr] = useState('')
  const [permitAmountStr, setPermitAmountStr] = useState('')
  const [permitSig, setPermitSig] = useState<StoredPermitSignature | null>(null)
  const [permitVerifyMsg, setPermitVerifyMsg] = useState<string | null>(null)
  const [permitBusy, setPermitBusy] = useState(false)

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

  const { data: tokenName } = useReadContract({
    address: token,
    abi: erc20PermitAbi,
    functionName: 'name',
    query: { enabled: Boolean(token) },
  })

  const permitOwner = isAddress(permitOwnerStr) ? (permitOwnerStr as `0x${string}`) : undefined

  const {
    data: permitNonce = 0n,
    refetch: refetchPermitNonce,
  } = useReadContract({
    address: token,
    abi: erc20PermitAbi,
    functionName: 'nonces',
    args: permitOwner ? [permitOwner] : undefined,
    query: { enabled: Boolean(token && permitOwner) },
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

  const { data: allowancePermit2 = 0n, refetch: refetchAllowancePermit2 } =
    useReadContract({
      address: token,
      abi: erc20Abi,
      functionName: 'allowance',
      args:
        token && address && permit2Address
          ? [address as `0x${string}`, permit2Address]
          : undefined,
      query: { enabled: Boolean(token && address && permit2Address) },
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
  const { data: walletClient } = useWalletClient()
  const { writeContractAsync } = useWriteContract()
  const { sendCallsAsync } = useSendCalls()
  const [eoaCode, setEoaCode] = useState<Hex | undefined>()

  const refreshEoaCode = useCallback(async () => {
    if (!publicClient || !address || !isAddress(address)) {
      setEoaCode(undefined)
      return
    }
    const code = await publicClient.getCode({ address: address as `0x${string}` })
    setEoaCode(code)
  }, [publicClient, address])

  useEffect(() => {
    void refreshEoaCode()
  }, [refreshEoaCode])

  useEffect(() => {
    if (address && !permitOwnerStr) {
      setPermitOwnerStr(address)
    }
  }, [address, permitOwnerStr])

  const amountWei = useMemo(() => {
    try {
      if (!amountStr.trim()) return null
      return parseUnits(amountStr, Number(decimals))
    } catch {
      return null
    }
  }, [amountStr, decimals])

  const permitAmountWei = useMemo(() => {
    try {
      if (!permitAmountStr.trim()) return null
      return parseUnits(permitAmountStr, Number(decimals))
    } catch {
      return null
    }
  }, [permitAmountStr, decimals])

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

  const doEip7702Deposit = useCallback(async () => {
    if (!bankAddress || !token || !address || !publicClient || !walletClient) {
      setError('请连接钱包，并确认已配置 TokenBank 与代币地址。')
      return
    }
    if (!chain) {
      setError('当前链未在 wagmi 配置中。请检查网络列表。')
      return
    }
    if (chainId === 31337) {
      setError('EIP-7702 请使用 Sepolia 等支持该能力的测试网，本地 Anvil 无法走 MetaMask 升级流程。')
      return
    }
    if (!amountWei || amountWei <= 0n) {
      setError('请在上方输入框填写有效存款金额。')
      return
    }
    if (walletBalance !== undefined && amountWei > walletBalance) {
      setError('钱包 TOKEN 余额不足')
      return
    }
    setError(null)
    setBusy(true)
    const account = address as `0x${string}`
    try {
      const { id } = await sendCallsAsync({
        account,
        forceAtomic: true,
        calls: [
          {
            to: token,
            abi: erc20Abi,
            functionName: 'approve',
            args: [bankAddress, amountWei],
          },
          {
            to: bankAddress,
            abi: tokenBankAbi,
            functionName: 'deposit',
            args: [amountWei],
          },
        ],
      })
      const status = await walletClient.waitForCallsStatus({ id })
      if (status.status === 'failure' || status.statusCode >= 400) {
        throw new Error(
          `EIP-7702 批量调用失败（status=${status.status ?? status.statusCode}）`,
        )
      }
      await Promise.all([
        refetchWallet(),
        refetchBank(),
        refetchAllowance(),
        refreshEoaCode(),
      ])
    } catch (e) {
      setError(e instanceof Error ? e.message : 'EIP-7702 授权存款失败')
    } finally {
      setBusy(false)
    }
  }, [
    bankAddress,
    token,
    address,
    publicClient,
    walletClient,
    chain,
    chainId,
    amountWei,
    walletBalance,
    sendCallsAsync,
    refetchWallet,
    refetchBank,
    refetchAllowance,
    refreshEoaCode,
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

  const doPermit2Deposit = useCallback(async () => {
    if (
      !bankAddress ||
      !token ||
      !permit2Address ||
      !address ||
      !walletClient ||
      !publicClient ||
      !amountWei ||
      !chain
    ) {
      setError('请填写金额并连接钱包；确认已配置 VITE_PERMIT2_ADDRESS。')
      return
    }
    if (chainId !== 11155111) {
      setError('Permit2 作业请使用 Sepolia 测试网（chainId 11155111）。')
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
      if (allowancePermit2 < amountWei) {
        const approveHash = await writeContractAsync({
          address: token,
          abi: erc20Abi,
          functionName: 'approve',
          args: [permit2Address, maxUint256],
          chain,
          account,
        })
        await publicClient.waitForTransactionReceipt({ hash: approveHash })
        await refetchAllowancePermit2()
      }
      const nonce = randomPermit2Nonce()
      const deadline = permit2Deadline()
      const domain = buildPermit2Domain({
        chainId,
        verifyingContract: permit2Address,
      })
      const message = buildPermit2TransferMessage({
        token,
        spender: bankAddress,
        nonce,
        deadline,
      })
      const signature = await walletClient.signTypedData({
        account,
        domain,
        types: permit2TransferTypes,
        primaryType: 'PermitTransferFrom',
        message,
      })
      const hash = await writeContractAsync({
        address: bankAddress,
        abi: tokenBankAbi,
        functionName: 'depositWithPermit2',
        args: [account, amountWei, nonce, deadline, signature],
        chain,
        account,
      })
      await publicClient.waitForTransactionReceipt({ hash })
      await Promise.all([
        refetchWallet(),
        refetchBank(),
        refetchAllowancePermit2(),
      ])
    } catch (e) {
      setError(e instanceof Error ? e.message : 'permit2 存款失败')
    } finally {
      setBusy(false)
    }
  }, [
    bankAddress,
    token,
    permit2Address,
    address,
    walletClient,
    publicClient,
    amountWei,
    chain,
    chainId,
    walletBalance,
    allowancePermit2,
    writeContractAsync,
    refetchWallet,
    refetchBank,
    refetchAllowancePermit2,
  ])

  const doPermitSign = useCallback(async () => {
    if (!token || !bankAddress || !address || !walletClient || !permitOwner || !permitAmountWei) {
      setError('请填写有效的持有人地址与金额，并连接钱包。')
      return
    }
    if (permitOwner.toLowerCase() !== address.toLowerCase()) {
      setError('签名须由持有人地址对应的钱包发起（地址与当前钱包不一致）。')
      return
    }
    if (permitAmountWei <= 0n) {
      setError('金额须大于 0')
      return
    }
    const domainName = tokenName ?? symbol
    setError(null)
    setPermitVerifyMsg(null)
    setPermitBusy(true)
    try {
      const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600)
      const message = {
        owner: permitOwner,
        spender: bankAddress,
        value: permitAmountWei,
        nonce: permitNonce,
        deadline,
      }
      const domain = buildPermitDomain({
        name: domainName,
        chainId,
        verifyingContract: token,
      })
      const signature = await walletClient.signTypedData({
        account: permitOwner,
        domain,
        types: permitTypes,
        primaryType: 'Permit',
        message,
      })
      const { v, r, s } = splitPermitSignature(signature)
      setPermitSig({ message, domain, signature, v, r, s })
    } catch (e) {
      setPermitSig(null)
      setError(e instanceof Error ? e.message : '签名失败')
    } finally {
      setPermitBusy(false)
    }
  }, [
    token,
    bankAddress,
    address,
    walletClient,
    permitOwner,
    permitAmountWei,
    tokenName,
    symbol,
    chainId,
    permitNonce,
  ])

  const doPermitVerify = useCallback(async () => {
    if (!permitSig) {
      setPermitVerifyMsg('请先完成「签名」。')
      return
    }
    setPermitBusy(true)
    setPermitVerifyMsg(null)
    try {
      const recovered = await verifyPermitSignature(
        permitSig.domain,
        permitSig.message,
        permitSig.signature,
      )
      const ok =
        recovered.toLowerCase() === permitSig.message.owner.toLowerCase()
      if (ok) {
        setPermitVerifyMsg(
          `验证成功：签名者 ${recovered} 与授权地址 ${permitSig.message.owner} 一致。`,
        )
      } else {
        setPermitVerifyMsg(
          `验证失败：恢复地址 ${recovered}，期望 ${permitSig.message.owner}。`,
        )
      }
    } catch (e) {
      setPermitVerifyMsg(
        e instanceof Error ? `验证失败：${e.message}` : '验证失败',
      )
    } finally {
      setPermitBusy(false)
    }
  }, [permitSig])

  const doPermitDeposit = useCallback(async () => {
    if (!bankAddress || !permitSig || !publicClient || !chain || !address) {
      setError('请先签名、连接钱包，并确保网络已连接。')
      return
    }
    setError(null)
    setPermitBusy(true)
    const account = address as `0x${string}`
    try {
      const { owner, value, deadline } = permitSig.message
      const { v, r, s } = permitSig
      const hash = await writeContractAsync({
        address: bankAddress,
        abi: tokenBankAbi,
        functionName: 'permitDeposit',
        args: [owner, value, deadline, v, r, s],
        chain,
        account,
      })
      await publicClient.waitForTransactionReceipt({ hash })
      await Promise.all([
        refetchWallet(),
        refetchBank(),
        refetchAllowance(),
        refetchPermitNonce(),
      ])
      setPermitSig(null)
      setPermitVerifyMsg(
        'permitDeposit 已确认。nonce 已更新，请重新签名后再存下一笔。',
      )
    } catch (e) {
      setError(e instanceof Error ? e.message : 'permitDeposit 失败')
    } finally {
      setPermitBusy(false)
    }
  }, [
    bankAddress,
    permitSig,
    publicClient,
    chain,
    address,
    writeContractAsync,
    refetchWallet,
    refetchBank,
    refetchAllowance,
    refetchPermitNonce,
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
              <br />
              EIP-7702：
              {!eoaCode || eoaCode === '0x'
                ? '尚未升级（仍是普通 EOA）'
                : isMetaMask7702Delegated(eoaCode)
                  ? `已指向 MetaMask Delegator（${MM_EIP7702_DELEGATOR}）`
                  : `已委托到其他合约（code ${eoaCode.slice(0, 20)}…）`}
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
            <button
              type="button"
              disabled={
                busy ||
                !amountWei ||
                amountWei <= 0n ||
                !permit2Address ||
                !walletClient ||
                walletBalanceReadError ||
                walletBalancePending ||
                (walletBalance !== undefined && amountWei > walletBalance)
              }
              title={
                !permit2Address
                  ? '请在 frontend/.env 配置 VITE_PERMIT2_ADDRESS'
                  : chainId !== 11155111
                    ? '请切换到 Sepolia'
                    : 'approve/签名须由持币人完成；提交交易时 owner 为当前连接地址（可由他人代付 gas）'
              }
              onClick={() => void doPermit2Deposit()}
              style={{
                ...btnStyle,
                background: '#1a4d8c',
                opacity:
                  busy ||
                  !amountWei ||
                  amountWei <= 0n ||
                  !permit2Address ||
                  !walletClient ||
                  walletBalanceReadError ||
                  walletBalancePending ||
                  (walletBalance !== undefined && amountWei > walletBalance)
                    ? 0.45
                    : 1,
              }}
            >
              {busy ? '处理中…' : 'permit2存款'}
            </button>
            <button
              type="button"
              disabled={
                busy ||
                !walletClient ||
                !token ||
                !amountWei ||
                amountWei <= 0n ||
                walletBalanceReadError ||
                walletBalancePending ||
                (walletBalance !== undefined && amountWei > walletBalance)
              }
              title="通过 wallet_sendCalls 在一笔 Type 4 交易中完成：升级到 MetaMask Delegator（若尚未升级）+ approve + deposit。金额取自上方输入框。已升级后将跳过升级步骤。"
              onClick={() => void doEip7702Deposit()}
              style={{
                ...btnStyle,
                background: '#6b3fa0',
                opacity:
                  busy ||
                  !walletClient ||
                  !token ||
                  !amountWei ||
                  amountWei <= 0n ||
                  walletBalanceReadError ||
                  walletBalancePending ||
                  (walletBalance !== undefined && amountWei > walletBalance)
                    ? 0.45
                    : 1,
              }}
            >
              {busy ? '处理中…' : 'EOA升级账户并授权存款'}
            </button>
          </div>
          <p
            style={{
              margin: 0,
              fontSize: '0.75rem',
              color: '#666',
              maxWidth: 420,
              textAlign: 'center',
              lineHeight: 1.5,
            }}
          >
            「EOA升级账户并授权存款」使用上方金额框。请用 MetaMask 并切换到
            Sepolia 等 EIP-7702 网络；第一次会提示升级智能账户，之后同一按钮只做
            approve + deposit。
          </p>

          {error ? (
            <p style={{ margin: 0, color: '#b00020', fontSize: '0.85rem', maxWidth: 400, textAlign: 'center' }}>
              {error}
            </p>
          ) : null}
          <hr style={{ width: '100%', maxWidth: 420, border: 'none', borderTop: '1px solid #eee' }} />

          <h2 style={{ margin: 0, fontSize: '1rem', fontWeight: 600 }}>
            Permit 离线签名存款（EIP-2612）
          </h2>
          <p style={{ margin: 0, fontSize: '0.8rem', color: '#666', maxWidth: 420, textAlign: 'center', lineHeight: 1.5 }}>
            授权 TokenBank 代扣你的 {symbol}。须用持有人钱包签名；金额单位为代币（非原生 ETH）。
          </p>

          <label style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
            <span style={{ fontSize: '0.85rem' }}>持有人地址（存款人）</span>
            <input
              type="text"
              value={permitOwnerStr}
              onChange={(e) => {
                setPermitOwnerStr(e.target.value.trim())
                setPermitSig(null)
                setPermitVerifyMsg(null)
              }}
              placeholder="0x…"
              style={inputStyle}
            />
          </label>

          <label style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
            <span style={{ fontSize: '0.85rem' }}>金额（{symbol}）</span>
            <input
              type="text"
              inputMode="decimal"
              value={permitAmountStr}
              onChange={(e) => {
                setPermitAmountStr(e.target.value)
                setPermitSig(null)
                setPermitVerifyMsg(null)
              }}
              placeholder="0.0"
              style={inputStyle}
            />
          </label>

          {permitOwner && token ? (
            <p style={{ margin: 0, fontSize: '0.75rem', color: '#666' }}>
              当前 nonce：{permitNonce.toString()}
            </p>
          ) : null}

          <div style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap', justifyContent: 'center' }}>
            <button
              type="button"
              disabled={
                permitBusy ||
                !permitOwner ||
                !permitAmountWei ||
                permitAmountWei <= 0n ||
                !walletClient
              }
              onClick={() => void doPermitSign()}
              style={{ ...btnStyle, opacity: permitBusy ? 0.5 : 1 }}
            >
              {permitBusy ? '处理中…' : '签名'}
            </button>
            <button
              type="button"
              disabled={permitBusy || !permitSig}
              onClick={() => void doPermitVerify()}
              style={{ ...btnStyle, opacity: permitBusy || !permitSig ? 0.5 : 1 }}
            >
              验证签名
            </button>
            <button
              type="button"
              disabled={permitBusy || !permitSig}
              onClick={() => void doPermitDeposit()}
              style={{
                ...btnStyle,
                background: '#2a5',
                opacity: permitBusy || !permitSig ? 0.5 : 1,
              }}
              title="验证通过后，可由任意账户代提交 permitDeposit"
            >
              提交存款
            </button>
          </div>

          {permitSig ? (
            <pre
              style={{
                margin: 0,
                padding: '0.75rem',
                fontSize: '0.7rem',
                maxWidth: 420,
                width: '100%',
                boxSizing: 'border-box',
                overflow: 'auto',
                background: '#f6f6f6',
                borderRadius: 8,
                textAlign: 'left',
              }}
            >
              {JSON.stringify(
                {
                  owner: permitSig.message.owner,
                  spender: permitSig.message.spender,
                  value: permitSig.message.value.toString(),
                  nonce: permitSig.message.nonce.toString(),
                  deadline: permitSig.message.deadline.toString(),
                  v: permitSig.v,
                  r: permitSig.r,
                  s: permitSig.s,
                  signature: permitSig.signature,
                },
                null,
                2,
              )}
            </pre>
          ) : (
            <p style={{ margin: 0, fontSize: '0.8rem', color: '#888' }}>签名结果将显示在此处</p>
          )}

          {permitVerifyMsg ? (
            <p
              style={{
                margin: 0,
                fontSize: '0.85rem',
                maxWidth: 420,
                textAlign: 'center',
                color: permitVerifyMsg.startsWith('验证成功') ? '#0a6b0a' : '#b00020',
                lineHeight: 1.5,
              }}
            >
              {permitVerifyMsg}
            </p>
          ) : null}
        </>
      )}
    </div>
  )
}

const inputStyle: CSSProperties = {
  padding: '0.5rem 0.65rem',
  borderRadius: 8,
  border: '1px solid #ccc',
  minWidth: 220,
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
