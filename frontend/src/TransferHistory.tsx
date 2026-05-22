import { useState, type CSSProperties } from 'react'
import { useQuery } from '@tanstack/react-query'
import { useAppKit, useAppKitAccount } from '@reown/appkit/react'
import {
  fetchTransfers,
  type TransferDirection,
  type TransferItem,
} from './api/transfers'

function shortAddr(addr: string): string {
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`
}

function shortHash(hash: string): string {
  return `${hash.slice(0, 10)}…${hash.slice(-8)}`
}

function formatTime(iso: string): string {
  const d = new Date(iso)
  return Number.isNaN(d.getTime()) ? iso : d.toLocaleString()
}

function transferDirection(
  item: TransferItem,
  userAddress: string,
): 'in' | 'out' | 'other' {
  const user = userAddress.toLowerCase()
  if (item.from.toLowerCase() === user) return 'out'
  if (item.to.toLowerCase() === user) return 'in'
  return 'other'
}

export default function TransferHistory() {
  const { open } = useAppKit()
  const { address, isConnected } = useAppKitAccount()
  const [direction, setDirection] = useState<TransferDirection>('all')

  const {
    data,
    error,
    isPending,
    isFetching,
    refetch,
  } = useQuery({
    queryKey: ['transfers', address, direction],
    queryFn: () => fetchTransfers(address!, { direction, limit: 50 }),
    enabled: Boolean(isConnected && address),
  })

  return (
    <div style={pageStyle}>
      <h1 style={{ margin: '0 0 0.5rem', fontSize: '1.25rem' }}>ERC20 转账记录</h1>
      <p style={{ margin: '0 0 1rem', fontSize: '0.875rem', color: '#555' }}>
        连接钱包后，从后端查询该地址在 MyToken 上的 Transfer 记录。
      </p>

      <button type="button" onClick={() => open()} style={primaryBtn}>
        {isConnected ? '钱包已连接（点击可切换）' : '连接钱包（WalletConnect）'}
      </button>

      {!isConnected || !address ? (
        <p style={{ marginTop: '1rem', color: '#666' }}>请先连接钱包后再查看转账记录。</p>
      ) : (
        <>
          <div style={infoBox}>
            <p style={{ margin: '0 0 0.35rem' }}>
              <strong>当前地址</strong>
              <br />
              {address}
            </p>
            <p style={{ margin: 0, fontSize: '0.8rem', color: '#666' }}>
              数据来源：backend REST API
            </p>
          </div>

          <div style={toolbar}>
            {(['all', 'out', 'in'] as const).map((d) => (
              <button
                key={d}
                type="button"
                onClick={() => setDirection(d)}
                style={filterBtn(direction === d)}
              >
                {d === 'all' ? '全部' : d === 'out' ? '发出' : '收到'}
              </button>
            ))}
            <button
              type="button"
              onClick={() => void refetch()}
              disabled={isFetching}
              style={secondaryBtn}
            >
              {isFetching ? '刷新中…' : '刷新'}
            </button>
          </div>

          {isPending ? (
            <p style={{ marginTop: '1rem' }}>加载转账记录中…</p>
          ) : error ? (
            <p style={{ marginTop: '1rem', color: '#b00020' }}>
              {(error as Error).message}
              <br />
              <span style={{ fontSize: '0.8rem' }}>
                请确认 backend 已运行（<code>cd backend && npm run api</code>），并重启 frontend（
                <code>npm run dev</code>）以启用 Vite 代理。
              </span>
            </p>
          ) : !data || data.total === 0 ? (
            <p style={{ marginTop: '1rem', color: '#666' }}>暂无转账记录。</p>
          ) : (
            <>
              <p style={{ margin: '1rem 0 0.5rem', fontSize: '0.875rem' }}>
                共 {data.total} 条，当前显示 {data.items.length} 条
              </p>
              <div style={{ overflowX: 'auto', width: '100%', maxWidth: '56rem' }}>
                <table style={tableStyle}>
                  <thead>
                    <tr>
                      <th style={thStyle}>时间</th>
                      <th style={thStyle}>方向</th>
                      <th style={thStyle}>对方</th>
                      <th style={thStyle}>数量</th>
                      <th style={thStyle}>交易</th>
                      <th style={thStyle}>区块</th>
                    </tr>
                  </thead>
                  <tbody>
                    {data.items.map((item) => {
                      const dir = transferDirection(item, address)
                      const counterparty =
                        dir === 'out'
                          ? item.to
                          : dir === 'in'
                            ? item.from
                            : '—'
                      return (
                        <tr key={`${item.txHash}-${item.logIndex}`}>
                          <td style={tdStyle}>{formatTime(item.blockTimestamp)}</td>
                          <td style={{ ...tdStyle, color: dir === 'out' ? '#b00020' : '#0a7a2f' }}>
                            {dir === 'out' ? '发出' : dir === 'in' ? '收到' : '—'}
                          </td>
                          <td style={tdStyle} title={counterparty}>
                            {counterparty === '—' ? '—' : shortAddr(counterparty)}
                          </td>
                          <td style={tdStyle}>{item.valueFormatted}</td>
                          <td style={tdStyle} title={item.txHash}>
                            {shortHash(item.txHash)}
                          </td>
                          <td style={tdStyle}>{item.blockNumber}</td>
                        </tr>
                      )
                    })}
                  </tbody>
                </table>
              </div>
            </>
          )}
        </>
      )}
    </div>
  )
}

const pageStyle: CSSProperties = {
  display: 'flex',
  flexDirection: 'column',
  alignItems: 'center',
  padding: '1.5rem 1rem 2rem',
}

const primaryBtn: CSSProperties = {
  padding: '0.5rem 1rem',
  borderRadius: 6,
  border: '1px solid #111',
  background: '#111',
  color: '#fafafa',
  cursor: 'pointer',
}

const secondaryBtn: CSSProperties = {
  padding: '0.35rem 0.75rem',
  borderRadius: 6,
  border: '1px solid #ccc',
  background: '#fff',
  cursor: 'pointer',
}

const infoBox: CSSProperties = {
  marginTop: '1rem',
  padding: '0.75rem 1rem',
  border: '1px solid #eee',
  borderRadius: 8,
  width: '100%',
  maxWidth: '56rem',
  fontSize: '0.875rem',
  wordBreak: 'break-word',
}

const toolbar: CSSProperties = {
  display: 'flex',
  flexWrap: 'wrap',
  gap: '0.5rem',
  marginTop: '1rem',
  width: '100%',
  maxWidth: '56rem',
}

function filterBtn(active: boolean): CSSProperties {
  return {
    padding: '0.35rem 0.75rem',
    borderRadius: 6,
    border: '1px solid #ccc',
    background: active ? '#111' : '#fff',
    color: active ? '#fafafa' : '#111',
    cursor: 'pointer',
  }
}

const tableStyle: CSSProperties = {
  width: '100%',
  borderCollapse: 'collapse',
  fontSize: '0.8125rem',
}

const thStyle: CSSProperties = {
  textAlign: 'left',
  padding: '0.5rem',
  borderBottom: '2px solid #ddd',
  whiteSpace: 'nowrap',
}

const tdStyle: CSSProperties = {
  padding: '0.5rem',
  borderBottom: '1px solid #eee',
  verticalAlign: 'top',
}
