import { useCallback, useMemo, useState, type CSSProperties } from 'react'
import { useAppKit, useAppKitAccount } from '@reown/appkit/react'
import { formatUnits, isAddress, parseUnits } from 'viem'
import {
  useBalance,
  useChainId,
  useChains,
  usePublicClient,
  useReadContract,
  useWriteContract,
} from 'wagmi'
import { erc20Abi } from './abis/tokenBank'
import { erc721MarketAbi, nftMarketAbi } from './abis/nftMarket'

function isMarketAddress(v: string | undefined): v is `0x${string}` {
  return Boolean(v && isAddress(v))
}

export default function NftMarket() {
  const { open } = useAppKit()
  const { address, isConnected } = useAppKitAccount()
  const chainId = useChainId()
  const chains = useChains()
  const chainName =
    chains.find((c) => c.id === chainId)?.name ?? `未知链`
  const chain = chains.find((c) => c.id === chainId)

  const marketRaw =
    import.meta.env.VITE_NFT_MARKET_ADDRESS?.trim() || undefined
  const marketAddress = isMarketAddress(marketRaw)
    ? marketRaw
    : undefined

  const [tokenIdStr, setTokenIdStr] = useState('1')
  const [priceStr, setPriceStr] = useState('1')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const tokenIdBigInt = useMemo(() => {
    try {
      const n = BigInt(tokenIdStr.trim() || '0')
      return n > 0n ? n : null
    } catch {
      return null
    }
  }, [tokenIdStr])

  const { data: erc20Addr } = useReadContract({
    address: marketAddress,
    abi: nftMarketAbi,
    functionName: 'erc20Token',
    query: { enabled: Boolean(marketAddress) },
  })

  const { data: erc721Addr } = useReadContract({
    address: marketAddress,
    abi: nftMarketAbi,
    functionName: 'erc721Token',
    query: { enabled: Boolean(marketAddress) },
  })

  const erc20 = erc20Addr && isAddress(erc20Addr) ? erc20Addr : undefined
  const erc721 =
    erc721Addr && isAddress(erc721Addr) ? erc721Addr : undefined

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

  const { data: listingPrice = 0n, refetch: refetchPrice } =
    useReadContract({
      address: marketAddress,
      abi: nftMarketAbi,
      functionName: 'tokenPrice',
      args: tokenIdBigInt !== null ? [tokenIdBigInt] : undefined,
      query: {
        enabled: Boolean(marketAddress && tokenIdBigInt !== null),
      },
    })

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
    query: {
      enabled: Boolean(erc721 && tokenIdBigInt !== null),
    },
  })

  /** ownerOf 能读到地址说明该 tokenId 已铸造 */
  const tokenAlreadyMinted = Boolean(
    erc721 && tokenIdBigInt !== null && owner && !ownerQueryError,
  )

  const { data: approvedForAll = false, refetch: refetchApproval721 } =
    useReadContract({
      address: erc721,
      abi: erc721MarketAbi,
      functionName: 'isApprovedForAll',
      args:
        erc721 && address && marketAddress
          ? [address as `0x${string}`, marketAddress]
          : undefined,
      query: {
        enabled: Boolean(erc721 && address && marketAddress && isConnected),
      },
    })

  const { data: tokenBalance = 0n, refetch: refetchTokenBal } =
    useReadContract({
      address: erc20,
      abi: erc20Abi,
      functionName: 'balanceOf',
      args: address ? [address as `0x${string}`] : undefined,
      query: { enabled: Boolean(erc20 && address && isConnected) },
    })

  const { data: allowance = 0n, refetch: refetchAllowance } =
    useReadContract({
      address: erc20,
      abi: erc20Abi,
      functionName: 'allowance',
      args:
        erc20 && address && marketAddress
          ? [address as `0x${string}`, marketAddress]
          : undefined,
      query: {
        enabled: Boolean(erc20 && address && marketAddress && isConnected),
      },
    })

  const { data: balance, isLoading: balanceLoading, isError: balanceError } =
    useBalance({
      address: address as `0x${string}` | undefined,
      query: {
        enabled: Boolean(address && isConnected),
      },
    })

  const publicClient = usePublicClient()
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

  const doList = useCallback(async () => {
    if (!marketAddress || !address || !erc721 || !publicClient || !chain) {
      setError('请连接钱包并配置 NFTMarket 地址')
      return
    }
    if (!tokenIdBigInt) {
      setError('请输入有效的 tokenId（正整数）')
      return
    }
    if (!listPriceWei || listPriceWei <= 0n) {
      setError('请输入有效的标价（TOKEN）')
      return
    }
    if (!owner || owner.toLowerCase() !== address.toLowerCase()) {
      setError(
        ownerQueryError
          ? '该 tokenId 可能尚未铸造，请先点「铸造 NFT」'
          : '当前钱包不是该 NFT 的持有人，无法上架',
      )
      return
    }
    if (listingPrice > 0n) {
      setError('该 tokenId 已在售，请先撤单或换 tokenId')
      return
    }
    setError(null)
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
        abi: nftMarketAbi,
        functionName: 'list',
        args: [tokenIdBigInt, listPriceWei],
        chain,
        account,
      })
      await publicClient.waitForTransactionReceipt({ hash: h2 })
      await Promise.all([refetchPrice(), refetchOwner()])
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
    refetchPrice,
    refetchOwner,
    ownerQueryError,
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

  const doBuy = useCallback(async () => {
    if (!marketAddress || !address || !erc20 || !publicClient || !chain) {
      setError('请连接钱包并配置 NFTMarket 地址')
      return
    }
    if (!tokenIdBigInt) {
      setError('请输入有效的 tokenId')
      return
    }
    if (listingPrice <= 0n) {
      setError('该 tokenId 未上架或已售出')
      return
    }
    if (tokenBalance < listingPrice) {
      setError(`${symbol} 余额不足支付标价`)
      return
    }
    setError(null)
    setBusy(true)
    const account = address as `0x${string}`
    try {
      if (allowance < listingPrice) {
        const h = await writeContractAsync({
          address: erc20,
          abi: erc20Abi,
          functionName: 'approve',
          args: [marketAddress, listingPrice],
          chain,
          account,
        })
        await publicClient.waitForTransactionReceipt({ hash: h })
        await refetchAllowance()
      }
      const h2 = await writeContractAsync({
        address: marketAddress,
        abi: nftMarketAbi,
        functionName: 'buyNFT',
        args: [tokenIdBigInt, listingPrice],
        chain,
        account,
      })
      await publicClient.waitForTransactionReceipt({ hash: h2 })
      await Promise.all([
        refetchPrice(),
        refetchOwner(),
        refetchTokenBal(),
        refetchAllowance(),
      ])
    } catch (e) {
      setError(e instanceof Error ? e.message : '购买失败')
    } finally {
      setBusy(false)
    }
  }, [
    marketAddress,
    address,
    erc20,
    publicClient,
    chain,
    tokenIdBigInt,
    listingPrice,
    tokenBalance,
    symbol,
    allowance,
    writeContractAsync,
    refetchAllowance,
    refetchPrice,
    refetchOwner,
    refetchTokenBal,
  ])

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
        style={btnPrimary}
      >
        扫码连接钱包（WalletConnect）
      </button>

      <div
        style={{
          display: 'flex',
          gap: '0.75rem',
          flexWrap: 'wrap',
          justifyContent: 'center',
        }}
      >
        <button
          type="button"
          title={
            tokenAlreadyMinted
              ? '该 tokenId 已有持有人'
              : ownerFetching
                ? '正在查询链上是否已铸造…'
                : '将当前输入的 tokenId 铸给当前钱包'
          }
          disabled={
            busy ||
            !isConnected ||
            !erc721 ||
            !tokenIdBigInt ||
            tokenAlreadyMinted ||
            ownerFetching
          }
          onClick={() => void doMint()}
          style={{
            ...btnPrimary,
            background: '#2e7d32',
            borderColor: '#1b5e20',
            opacity:
              busy ||
              !isConnected ||
              !erc721 ||
              !tokenIdBigInt ||
              tokenAlreadyMinted ||
              ownerFetching
                ? 0.45
                : 1,
          }}
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
          style={{
            ...btnPrimary,
            opacity:
              busy ||
              !isConnected ||
              !marketAddress ||
              !tokenIdBigInt ||
              !listPriceWei
                ? 0.45
                : 1,
          }}
        >
          {busy ? '处理中…' : '上架'}
        </button>
        <button
          type="button"
          disabled={
            busy ||
            !isConnected ||
            !marketAddress ||
            !tokenIdBigInt ||
            listingPrice <= 0n
          }
          onClick={() => void doBuy()}
          style={{
            ...btnPrimary,
            opacity:
              busy ||
              !isConnected ||
              !marketAddress ||
              !tokenIdBigInt ||
              listingPrice <= 0n
                ? 0.45
                : 1,
          }}
        >
          {busy ? '处理中…' : '购买'}
        </button>
      </div>

      <div
        style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: '0.65rem',
          width: '100%',
          maxWidth: 'min(100%, 22rem)',
        }}
      >
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
          <span>标价（{symbol}，仅上架用）</span>
          <input
            type="text"
            inputMode="decimal"
            value={priceStr}
            onChange={(e) => setPriceStr(e.target.value)}
            disabled={!isConnected}
            style={inputStyle}
          />
        </label>
        <p
          style={{
            margin: 0,
            fontSize: '0.8rem',
            color: '#555',
            textAlign: 'center',
          }}
        >
          链上标价：{listingHuman}
        </p>
        {!marketAddress ? (
          <p style={{ margin: 0, fontSize: '0.8rem', color: '#b00020', textAlign: 'center' }}>
            请在 <code style={{ fontSize: '0.75rem' }}>frontend/.env</code> 中配置{' '}
            <code style={{ fontSize: '0.75rem' }}>VITE_NFT_MARKET_ADDRESS</code>
            后重启 dev。
          </p>
        ) : null}
        {!isConnected ? (
          <p style={{ margin: 0, fontSize: '0.8rem', color: '#666', textAlign: 'center' }}>
            铸造：把当前 tokenId 发给当前钱包；上架：需已持有该 NFT；购买：需另一账号并持有足够 {symbol}。
          </p>
        ) : null}
        {isConnected && erc721 && tokenIdBigInt !== null ? (
          <p style={{ margin: 0, fontSize: '0.8rem', color: '#555', textAlign: 'center' }}>
            {ownerFetching
              ? '正在查询该 tokenId 是否已铸造…'
              : tokenAlreadyMinted
                ? `该 tokenId 持有人：${owner}`
                : ownerQueryError
                  ? '该 tokenId 尚未铸造（或查询失败），可先点「铸造 NFT」'
                  : '该 tokenId 尚未铸造，可先点「铸造 NFT」'}
          </p>
        ) : null}
        {error ? (
          <p style={{ margin: 0, fontSize: '0.8rem', color: '#b00020', textAlign: 'center' }}>
            {error}
          </p>
        ) : null}
      </div>

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
          <p style={{ margin: '0 0 0.35rem' }}>
            <strong>原生币余额</strong>
            <br />
            {balanceLoading
              ? '读取中…'
              : balanceError
                ? '余额读取失败'
                : balance
                  ? `${formatUnits(balance.value, balance.decimals)} ${balance.symbol}`
                  : `0 ${chains.find((c) => c.id === chainId)?.nativeCurrency.symbol ?? ''}`}
          </p>
          {erc20 ? (
            <p style={{ margin: 0 }}>
              <strong>
                {symbol} 余额
              </strong>
              <br />
              {formatUnits(tokenBalance, Number(decimals))}
            </p>
          ) : null}
        </div>
      ) : null}
    </div>
  )
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
