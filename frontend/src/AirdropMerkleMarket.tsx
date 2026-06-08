import { useCallback, useEffect, useMemo, useState, type CSSProperties } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { useAppKit, useAppKitAccount } from '@reown/appkit/react'
import { encodeFunctionData, formatUnits, getAddress, isAddress, parseUnits } from 'viem'
import {
  useAccount,
  useAccountEffect,
  useBalance,
  useChainId,
  useChains,
  useConnections,
  usePublicClient,
  useReadContract,
  useWalletClient,
  useWriteContract,
} from 'wagmi'
import {
  airdropMerkleMarketAbi,
  erc721MarketAbi,
} from './abis/airdropMerkleMarket'
import { erc20Abi, erc20PermitAbi } from './abis/tokenBank'
import {
  buildPermitDomain,
  permitTypes,
  splitPermitSignature,
} from './permitEip2612'
import {
  MERKLE_ROOT,
  getProofForAddress,
  isWhitelisted,
} from './lib/whitelist'
import { ANVIL_CHAIN_ID } from './lib/anvilRpc'

function isMarketAddress(v: string | undefined): v is `0x${string}` {
  return Boolean(v && isAddress(v))
}

/** 本地部署的 ERC2612 Token（与 Market 内 erc20Token 一致） */
const ERC2612_TOKEN_FALLBACK =
  '0x057ef64E23666F000b34aE31332854aCBd1c8544' as const

export default function AirdropMerkleMarketPage() {
  const queryClient = useQueryClient()
  const { open } = useAppKit()
  const { address: appKitAddress, isConnected: appKitConnected } =
    useAppKitAccount()
  const { address: wagmiAddress, isConnected: wagmiConnected, connector } =
    useAccount()
  const connections = useConnections()
  const isConnected = wagmiConnected || appKitConnected
  const chainId = useChainId()
  const chains = useChains()
  const chain = chains.find((c) => c.id === chainId)
  const chainName = chain?.name ?? `未知链`

  const marketRaw =
    import.meta.env.VITE_AIRDROP_MERKLE_MARKET_ADDRESS?.trim() || undefined
  const marketAddress = isMarketAddress(marketRaw) ? marketRaw : undefined

  const [tokenIdStr, setTokenIdStr] = useState('1')
  const [priceStr, setPriceStr] = useState('100')
  /** 勿默认填 #1 地址，避免与连接账户混淆 */
  const [transferToStr, setTransferToStr] = useState('')
  const [transferAmountStr, setTransferAmountStr] = useState('200')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [status, setStatus] = useState<string | null>(null)
  const [connectedAddress, setConnectedAddress] = useState<
    `0x${string}` | undefined
  >(undefined)

  const resolveConnectedAddress = useCallback((): `0x${string}` | undefined => {
    const candidates: (string | undefined)[] = []
    for (const c of connections) {
      for (const acc of c.accounts) candidates.push(acc)
    }
    candidates.push(wagmiAddress, appKitAddress)
    for (const raw of candidates) {
      if (raw && isAddress(raw)) {
        try {
          return getAddress(raw)
        } catch {
          /* try next */
        }
      }
    }
    return undefined
  }, [connections, wagmiAddress, appKitAddress])

  useAccountEffect({
    onConnect() {
      setConnectedAddress(resolveConnectedAddress())
      setError(null)
      setStatus(null)
      void queryClient.invalidateQueries()
    },
    onDisconnect() {
      setConnectedAddress(undefined)
      setError(null)
      setStatus(null)
      void queryClient.invalidateQueries()
    },
  })

  useEffect(() => {
    setConnectedAddress(resolveConnectedAddress())
  }, [resolveConnectedAddress, connector?.id])

  useEffect(() => {
    type EthereumLike = {
      on?: (event: string, handler: () => void) => void
      removeListener?: (event: string, handler: () => void) => void
    }
    const eth = (window as Window & { ethereum?: EthereumLike }).ethereum
    if (!eth?.on) return

    const syncFromProvider = () => {
      setConnectedAddress(resolveConnectedAddress())
      setError(null)
      setStatus(null)
      void queryClient.invalidateQueries()
    }

    eth.on('accountsChanged', syncFromProvider)
    eth.on('chainChanged', syncFromProvider)
    return () => {
      eth.removeListener?.('accountsChanged', syncFromProvider)
      eth.removeListener?.('chainChanged', syncFromProvider)
    }
  }, [queryClient, resolveConnectedAddress])

  const tokenIdBigInt = useMemo(() => {
    try {
      const n = BigInt(tokenIdStr.trim() || '0')
      return n > 0n ? n : null
    } catch {
      return null
    }
  }, [tokenIdStr])

  const proof = connectedAddress
    ? getProofForAddress(connectedAddress)
    : undefined
  const whitelisted = connectedAddress
    ? isWhitelisted(connectedAddress)
    : false

  const address = connectedAddress

  const { data: erc20Addr } = useReadContract({
    address: marketAddress,
    abi: airdropMerkleMarketAbi,
    functionName: 'erc20Token',
    query: { enabled: Boolean(marketAddress) },
  })

  const { data: erc721Addr } = useReadContract({
    address: marketAddress,
    abi: airdropMerkleMarketAbi,
    functionName: 'erc721Token',
    query: { enabled: Boolean(marketAddress) },
  })

  const { data: onChainRoot } = useReadContract({
    address: marketAddress,
    abi: airdropMerkleMarketAbi,
    functionName: 'merkleRoot',
    query: { enabled: Boolean(marketAddress) },
  })

  const erc20EnvRaw =
    import.meta.env.VITE_ERC2612_TOKEN_ADDRESS?.trim() ||
    ERC2612_TOKEN_FALLBACK
  const erc20FromEnv = isAddress(erc20EnvRaw)
    ? (erc20EnvRaw as `0x${string}`)
    : undefined

  const erc20 = erc20Addr && isAddress(erc20Addr) ? erc20Addr : erc20FromEnv
  const erc721 =
    erc721Addr && isAddress(erc721Addr) ? erc721Addr : undefined

  const rootMatches =
    onChainRoot != null &&
    onChainRoot.toLowerCase() === MERKLE_ROOT.toLowerCase()

  const { data: decimals = 18 } = useReadContract({
    address: erc20,
    abi: erc20Abi,
    functionName: 'decimals',
    query: { enabled: Boolean(erc20) },
  })

  const { data: symbol = 'TOKEN' } = useReadContract({
    address: erc20,
    abi: erc20Abi,
    functionName: 'symbol',
    query: { enabled: Boolean(erc20) },
  })

  const { data: tokenName } = useReadContract({
    address: erc20,
    abi: erc20PermitAbi,
    functionName: 'name',
    query: { enabled: Boolean(erc20) },
  })

  const { data: listing, refetch: refetchListing } = useReadContract({
    address: marketAddress,
    abi: airdropMerkleMarketAbi,
    functionName: 'tokenListing',
    args: tokenIdBigInt !== null ? [tokenIdBigInt] : undefined,
    query: {
      enabled: Boolean(marketAddress && tokenIdBigInt !== null),
    },
  })

  const listingPrice = listing?.[0] ?? 0n
  const halfPrice = listingPrice > 0n ? listingPrice / 2n : 0n

  const {
    data: owner,
    isError: ownerQueryError,
    isFetching: ownerFetching,
    refetch: refetchOwner,
  } = useReadContract({
    address: erc721,
    abi: erc721MarketAbi,
    functionName: 'ownerOf',
    args: tokenIdBigInt !== null ? [tokenIdBigInt] : undefined,
    query: { enabled: Boolean(erc721 && tokenIdBigInt !== null) },
  })

  const tokenAlreadyMinted = Boolean(
    erc721 && tokenIdBigInt !== null && owner && !ownerQueryError,
  )

  const { data: approvedForAll = false, refetch: refetchApproval721 } =
    useReadContract({
      address: erc721,
      abi: erc721MarketAbi,
      functionName: 'isApprovedForAll',
      args:
        connectedAddress && marketAddress
          ? [connectedAddress, marketAddress]
          : undefined,
      query: {
        enabled: Boolean(erc721 && connectedAddress && marketAddress && isConnected),
      },
    })

  const { data: tokenBalance = 0n, refetch: refetchTokenBal, isError: tokenBalError, isFetching: tokenBalFetching } =
    useReadContract({
      address: erc20,
      abi: erc20Abi,
      functionName: 'balanceOf',
      args: connectedAddress ? [connectedAddress] : undefined,
      query: {
        enabled: Boolean(erc20 && connectedAddress && isConnected),
        refetchInterval: 5_000,
      },
    })

  const { data: permitNonce = 0n } = useReadContract({
    address: erc20,
    abi: erc20PermitAbi,
    functionName: 'nonces',
    args: connectedAddress ? [connectedAddress] : undefined,
    query: { enabled: Boolean(erc20 && connectedAddress && isConnected) },
  })

  const { data: balance, isLoading: balanceLoading, isError: balanceError } =
    useBalance({
      address: connectedAddress,
      query: { enabled: Boolean(connectedAddress && isConnected) },
    })

  const publicClient = usePublicClient()
  const { data: walletClient } = useWalletClient()
  const { writeContractAsync } = useWriteContract()

  const listPriceWei = useMemo(() => {
    try {
      if (!priceStr.trim()) return null
      return parseUnits(priceStr, Number(decimals))
    } catch {
      return null
    }
  }, [priceStr, decimals])

  const listingHuman =
    listingPrice > 0n
      ? `${formatUnits(listingPrice, Number(decimals))} ${symbol}`
      : '未上架'

  const halfPriceHuman =
    halfPrice > 0n
      ? `${formatUnits(halfPrice, Number(decimals))} ${symbol}`
      : '—'

  const transferTo = useMemo(() => {
    const v = transferToStr.trim()
    return v && isAddress(v) ? (v as `0x${string}`) : null
  }, [transferToStr])

  const transferAmountWei = useMemo(() => {
    try {
      if (!transferAmountStr.trim()) return null
      return parseUnits(transferAmountStr, Number(decimals))
    } catch {
      return null
    }
  }, [transferAmountStr, decimals])

  const doTransferToken = useCallback(async () => {
    if (!address || !erc20 || !publicClient || !chain) {
      setError('请连接钱包并确认 Token 地址')
      return
    }
    if (!transferTo) {
      setError('请输入有效的收款地址')
      return
    }
    if (!transferAmountWei || transferAmountWei <= 0n) {
      setError('请输入有效的转账数量')
      return
    }
    if (tokenBalance < transferAmountWei) {
      setError(`${symbol} 余额不足`)
      return
    }
    setError(null)
    setStatus(null)
    setBusy(true)
    const account = address as `0x${string}`
    try {
      const hash = await writeContractAsync({
        address: erc20,
        abi: erc20Abi,
        functionName: 'transfer',
        args: [transferTo, transferAmountWei],
        chain,
        account,
      })
      await publicClient.waitForTransactionReceipt({ hash })
      await refetchTokenBal()
      setStatus(
        `已向 ${transferTo.slice(0, 6)}…${transferTo.slice(-4)} 转账 ${transferAmountStr} ${symbol}`,
      )
    } catch (e) {
      setError(e instanceof Error ? e.message : '转账失败')
    } finally {
      setBusy(false)
    }
  }, [
    address,
    erc20,
    publicClient,
    chain,
    transferTo,
    transferAmountWei,
    transferAmountStr,
    tokenBalance,
    symbol,
    writeContractAsync,
    refetchTokenBal,
  ])

  const doMint = useCallback(async () => {
    if (!address || !erc721 || !publicClient || !chain || !tokenIdBigInt) {
      setError('请连接钱包并等待合约地址加载完成')
      return
    }
    if (tokenAlreadyMinted) {
      setError('该 tokenId 已铸造，请换其他 tokenId')
      return
    }
    setError(null)
    setStatus(null)
    setBusy(true)
    const account = address as `0x${string}`
    try {
      const h = await writeContractAsync({
        address: erc721,
        abi: erc721MarketAbi,
        functionName: 'mint',
        args: [account, tokenIdBigInt],
        chain,
        account,
      })
      await publicClient.waitForTransactionReceipt({ hash: h })
      await refetchOwner()
      setStatus('铸造成功')
    } catch (e) {
      setError(e instanceof Error ? e.message : '铸造失败')
    } finally {
      setBusy(false)
    }
  }, [
    address,
    erc721,
    publicClient,
    chain,
    tokenIdBigInt,
    tokenAlreadyMinted,
    writeContractAsync,
    refetchOwner,
  ])

  const doList = useCallback(async () => {
    if (!marketAddress || !address || !erc721 || !publicClient || !chain) {
      setError('请连接钱包并配置 Market 地址')
      return
    }
    if (!tokenIdBigInt || !listPriceWei || listPriceWei <= 0n) {
      setError('请输入有效的 tokenId 和标价')
      return
    }
    if (!owner || owner.toLowerCase() !== address.toLowerCase()) {
      setError('当前钱包不是该 NFT 持有人，无法上架')
      return
    }
    if (listingPrice > 0n) {
      setError('该 tokenId 已在售')
      return
    }
    setError(null)
    setStatus(null)
    setBusy(true)
    const account = address as `0x${string}`
    try {
      if (!approvedForAll) {
        const h = await writeContractAsync({
          address: erc721,
          abi: erc721MarketAbi,
          functionName: 'setApprovalForAll',
          args: [marketAddress, true],
          chain,
          account,
        })
        await publicClient.waitForTransactionReceipt({ hash: h })
        await refetchApproval721()
      }
      const h2 = await writeContractAsync({
        address: marketAddress,
        abi: airdropMerkleMarketAbi,
        functionName: 'list',
        args: [tokenIdBigInt, listPriceWei],
        chain,
        account,
      })
      await publicClient.waitForTransactionReceipt({ hash: h2 })
      await Promise.all([refetchListing(), refetchOwner()])
      setStatus('上架成功')
    } catch (e) {
      setError(e instanceof Error ? e.message : '上架失败')
    } finally {
      setBusy(false)
    }
  }, [
    marketAddress,
    address,
    erc721,
    publicClient,
    chain,
    tokenIdBigInt,
    listPriceWei,
    owner,
    listingPrice,
    approvedForAll,
    writeContractAsync,
    refetchApproval721,
    refetchListing,
    refetchOwner,
  ])

  const doWhitelistBuy = useCallback(async () => {
    if (
      !marketAddress ||
      !address ||
      !erc20 ||
      !publicClient ||
      !chain ||
      !walletClient
    ) {
      setError('请连接钱包并配置 Market 地址')
      return
    }
    if (!tokenIdBigInt) {
      setError('请输入有效的 tokenId')
      return
    }
    if (!whitelisted || !proof) {
      setError('当前钱包不在 Merkle 白名单（Anvil 账户 1–4）')
      return
    }
    if (!rootMatches) {
      setError('链上 merkleRoot 与 whitelist.json 不一致，请重新部署合约')
      return
    }
    if (listingPrice <= 0n) {
      setError('该 tokenId 未上架或已售出')
      return
    }
    if (tokenBalance < halfPrice) {
      setError(`${symbol} 余额不足支付半价 ${halfPriceHuman}`)
      return
    }
    if (!tokenName) {
      setError('无法读取 Token name（Permit 签名需要）')
      return
    }

    setError(null)
    setStatus('请在钱包中签名 Permit…')
    setBusy(true)
    const account = address as `0x${string}`
    const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600)

    try {
      const domain = buildPermitDomain({
        name: tokenName,
        chainId,
        verifyingContract: erc20,
      })
      const message = {
        owner: account,
        spender: marketAddress,
        value: halfPrice,
        nonce: permitNonce,
        deadline,
      }

      const signature = await walletClient.signTypedData({
        account,
        domain,
        types: permitTypes,
        primaryType: 'Permit',
        message,
      })
      const { v, r, s } = splitPermitSignature(signature)

      setStatus('签名完成，正在提交 multicall…')

      const permitData = encodeFunctionData({
        abi: airdropMerkleMarketAbi,
        functionName: 'permitPrePay',
        args: [account, halfPrice, deadline, v, r, s],
      })
      const claimData = encodeFunctionData({
        abi: airdropMerkleMarketAbi,
        functionName: 'claimNFT',
        args: [tokenIdBigInt, proof],
      })

      const hash = await writeContractAsync({
        address: marketAddress,
        abi: airdropMerkleMarketAbi,
        functionName: 'multicall',
        args: [[permitData, claimData]],
        chain,
        account,
      })
      await publicClient.waitForTransactionReceipt({ hash })
      await Promise.all([
        refetchListing(),
        refetchOwner(),
        refetchTokenBal(),
      ])
      setStatus(`白名单半价购买成功（${halfPriceHuman}）`)
    } catch (e) {
      setError(e instanceof Error ? e.message : '购买失败')
      setStatus(null)
    } finally {
      setBusy(false)
    }
  }, [
    marketAddress,
    address,
    erc20,
    publicClient,
    chain,
    walletClient,
    tokenIdBigInt,
    whitelisted,
    proof,
    rootMatches,
    listingPrice,
    tokenBalance,
    halfPrice,
    halfPriceHuman,
    symbol,
    tokenName,
    chainId,
    permitNonce,
    writeContractAsync,
    refetchListing,
    refetchOwner,
    refetchTokenBal,
  ])

  return (
    <div style={pageStyle}>
      <h1 style={{ margin: 0, fontSize: '1.25rem', fontWeight: 600 }}>
        基于 Merkle 树白名单验证的 NFT 市场
      </h1>

      <button type="button" onClick={() => open()} style={btnPrimary}>
        扫码连接钱包（WalletConnect）
      </button>

      <div style={infoBox}>
        <p style={infoLine}>
          <strong>Merkle Root（静态）</strong>
          <br />
          <code style={codeStyle}>{MERKLE_ROOT}</code>
        </p>
        {onChainRoot ? (
          <p style={infoLine}>
            <strong>Merkle Root（链上）</strong>
            <br />
            <code style={codeStyle}>{onChainRoot}</code>
            {rootMatches ? (
              <span style={{ color: '#2e7d32' }}> ✓ 一致</span>
            ) : (
              <span style={{ color: '#b00020' }}> ✗ 不一致</span>
            )}
          </p>
        ) : null}
        {isConnected && connectedAddress ? (
          <p key={connectedAddress} style={infoLine}>
            <strong>当前连接地址</strong>
            <br />
            <code style={codeStyle}>{connectedAddress}</code>
          </p>
        ) : null}
        {isConnected && connectedAddress ? (
          <p key={`wl-${connectedAddress}`} style={infoLine}>
            <strong>白名单状态</strong>
            <br />
            {whitelisted ? (
              <span style={{ color: '#2e7d32' }}>✓ 在白名单（可 5 折购买）</span>
            ) : (
              <span style={{ color: '#b00020' }}>
                ✗ 不在白名单（Anvil 账户 1–4 可测）
              </span>
            )}
          </p>
        ) : null}
        {isConnected && chainId !== ANVIL_CHAIN_ID ? (
          <p style={errStyle}>
            当前链 ID 为 {chainId}，不是本地 Anvil（{ANVIL_CHAIN_ID}）。
            请在钱包中切换到 Foundry / 本地链，否则 Token 余额会显示为 0。
          </p>
        ) : null}
      </div>

      <section style={sectionStyle}>
        <h2 style={sectionTitle}>卖家：铸造 / 授权 / 上架</h2>
        <div style={btnRow}>
          <button
            type="button"
            disabled={
              busy ||
              !isConnected ||
              !erc721 ||
              !tokenIdBigInt ||
              tokenAlreadyMinted ||
              ownerFetching
            }
            onClick={() => void doMint()}
            style={{ ...btnPrimary, background: '#2e7d32' }}
          >
            {busy ? '处理中…' : '铸造 NFT'}
          </button>
          <button
            type="button"
            disabled={
              busy ||
              !isConnected ||
              !marketAddress ||
              !tokenIdBigInt ||
              !listPriceWei
            }
            onClick={() => void doList()}
            style={btnPrimary}
          >
            {busy ? '处理中…' : '授权并上架'}
          </button>
        </div>
      </section>

      <section style={sectionStyle}>
        <h2 style={sectionTitle}>测试：转账 ERC2612 Token</h2>
        <div style={{ ...formStyle, maxWidth: '28rem' }}>
          <p style={hintStyle}>
            Token：<code style={codeStyle}>{erc20 ?? '—'}</code>
          </p>
          <label style={labelStyle}>
            <span>收款地址</span>
            <input
              type="text"
              value={transferToStr}
              onChange={(e) => setTransferToStr(e.target.value)}
              placeholder="0x7099… 或任意收款地址"
              disabled={!isConnected}
              style={inputStyle}
            />
          </label>
          <label style={labelStyle}>
            <span>转账数量（{symbol}）</span>
            <input
              type="text"
              inputMode="decimal"
              value={transferAmountStr}
              onChange={(e) => setTransferAmountStr(e.target.value)}
              disabled={!isConnected}
              style={inputStyle}
            />
          </label>
          <button
            type="button"
            disabled={
              busy ||
              !isConnected ||
              !erc20 ||
              !transferTo ||
              !transferAmountWei
            }
            onClick={() => void doTransferToken()}
            style={{ ...btnPrimary, background: '#6a1b9a' }}
          >
            {busy ? '处理中…' : '转账 Token'}
          </button>
        </div>
      </section>

      <section style={sectionStyle}>
        <h2 style={sectionTitle}>白名单买家：Permit + Multicall 半价购</h2>
        <button
          type="button"
          disabled={
            busy ||
            !isConnected ||
            !marketAddress ||
            !tokenIdBigInt ||
            listingPrice <= 0n ||
            !whitelisted ||
            !rootMatches
          }
          onClick={() => void doWhitelistBuy()}
          style={{ ...btnPrimary, background: '#1565c0', minWidth: '14rem' }}
        >
          {busy ? '处理中…' : '白名单半价购买（签名 + multicall）'}
        </button>
      </section>

      <div style={formStyle}>
        <label style={labelStyle}>
          <span>tokenId</span>
          <input
            type="text"
            inputMode="numeric"
            value={tokenIdStr}
            onChange={(e) => setTokenIdStr(e.target.value)}
            disabled={!isConnected}
            style={inputStyle}
          />
        </label>
        <label style={labelStyle}>
          <span>标价（{symbol}，上架用，存原价）</span>
          <input
            type="text"
            inputMode="decimal"
            value={priceStr}
            onChange={(e) => setPriceStr(e.target.value)}
            disabled={!isConnected}
            style={inputStyle}
          />
        </label>
        <p style={hintStyle}>链上标价（原价）：{listingHuman}</p>
        <p style={hintStyle}>白名单半价：{halfPriceHuman}</p>
        {!marketAddress ? (
          <p style={errStyle}>
            请在 frontend/.env 配置{' '}
            <code>VITE_AIRDROP_MERKLE_MARKET_ADDRESS</code> 后重启 dev
          </p>
        ) : null}
        {status ? <p style={{ ...hintStyle, color: '#1565c0' }}>{status}</p> : null}
        {error ? <p style={errStyle}>{error}</p> : null}
      </div>

      {isConnected && connectedAddress ? (
        <div style={infoBox}>
          <p style={infoLine}>
            <strong>地址</strong>
            <br />
            {connectedAddress}
          </p>
          <p style={infoLine}>
            <strong>网络</strong>
            <br />
            {chainName}（chainId {chainId}）
          </p>
          <p style={infoLine}>
            <strong>原生币余额</strong>
            <br />
            {balanceLoading
              ? '读取中…'
              : balanceError
                ? '读取失败'
                : balance
                  ? `${formatUnits(balance.value, balance.decimals)} ${balance.symbol}`
                  : '0'}
          </p>
          {erc20 ? (
            <p style={{ margin: 0 }}>
              <strong>{symbol} 余额</strong>
              <br />
              {tokenBalFetching
                ? '读取中…'
                : tokenBalError
                  ? '读取失败（请确认在 Anvil 31337 且 RPC 正常）'
                  : formatUnits(tokenBalance, Number(decimals))}
              <br />
              <span style={{ fontSize: '0.75rem', color: '#666' }}>
                Token 合约：{erc20}
              </span>
              <br />
              <button
                type="button"
                onClick={() => void refetchTokenBal()}
                style={{
                  marginTop: 4,
                  fontSize: '0.75rem',
                  cursor: 'pointer',
                  padding: '2px 8px',
                }}
              >
                刷新 Token 余额
              </button>
            </p>
          ) : null}
        </div>
      ) : null}
    </div>
  )
}

const pageStyle: CSSProperties = {
  minHeight: '100vh',
  display: 'flex',
  flexDirection: 'column',
  alignItems: 'center',
  gap: '1rem',
  padding: '1rem',
  boxSizing: 'border-box',
}

const sectionStyle: CSSProperties = {
  width: '100%',
  maxWidth: '28rem',
  display: 'flex',
  flexDirection: 'column',
  alignItems: 'center',
  gap: '0.5rem',
}

const sectionTitle: CSSProperties = {
  margin: 0,
  fontSize: '1rem',
  fontWeight: 600,
}

const btnRow: CSSProperties = {
  display: 'flex',
  gap: '0.75rem',
  flexWrap: 'wrap',
  justifyContent: 'center',
}

const formStyle: CSSProperties = {
  display: 'flex',
  flexDirection: 'column',
  gap: '0.65rem',
  width: '100%',
  maxWidth: '22rem',
}

const infoBox: CSSProperties = {
  fontSize: '0.875rem',
  lineHeight: 1.6,
  textAlign: 'center',
  maxWidth: 'min(100%, 32rem)',
  wordBreak: 'break-word',
}

const infoLine: CSSProperties = { margin: '0 0 0.35rem' }

const codeStyle: CSSProperties = { fontSize: '0.72rem', wordBreak: 'break-all' }

const hintStyle: CSSProperties = {
  margin: 0,
  fontSize: '0.8rem',
  color: '#555',
  textAlign: 'center',
}

const errStyle: CSSProperties = {
  margin: 0,
  fontSize: '0.8rem',
  color: '#b00020',
  textAlign: 'center',
}

const btnPrimary: CSSProperties = {
  padding: '0.6rem 1.25rem',
  fontSize: '1rem',
  cursor: 'pointer',
  borderRadius: '8px',
  border: '1px solid #ccc',
  background: '#111',
  color: '#fafafa',
}

const labelStyle: CSSProperties = {
  display: 'flex',
  flexDirection: 'column',
  gap: 4,
  width: '100%',
  fontSize: '0.85rem',
}

const inputStyle: CSSProperties = {
  padding: '0.5rem 0.65rem',
  borderRadius: 8,
  border: '1px solid #ccc',
  width: '100%',
  boxSizing: 'border-box',
}
