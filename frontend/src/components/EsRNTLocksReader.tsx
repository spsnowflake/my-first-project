import { useState } from 'react'
import {
  readEsRNTLocks,
  formatLockLine,
  ESRNT_CONTRACT_ADDRESS,
  type LockInfo,
} from '../lib/readEsRNTLocks'

export default function EsRNTLocksReader() {
  const [locks, setLocks] = useState<LockInfo[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [status, setStatus] = useState<string | null>(null)

  async function handleRead() {
    setLoading(true)
    setError(null)
    setStatus('正在连接本地链并读取 storage…')
    setLocks([])
    try {
      const data = await readEsRNTLocks()
      setLocks(data)
      setStatus(`读取成功，共 ${data.length} 条（详见下方与浏览器控制台）`)
      data.forEach((lock) => console.log(formatLockLine(lock)))
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e)
      setError(msg)
      setStatus(null)
      console.error('[esRNT locks]', e)
    } finally {
      setLoading(false)
    }
  }

  return (
    <section style={{ padding: 16, maxWidth: 960, margin: '0 auto' }}>
      <h2>esRNT _locks（getStorageAt）</h2>
      <p style={{ fontFamily: 'monospace', fontSize: 13, wordBreak: 'break-all' }}>
        合约：{ESRNT_CONTRACT_ADDRESS}
      </p>
      <p style={{ fontSize: 13, color: '#666' }}>
        需先运行 <code>anvil</code>，并用 <code>forge create … --broadcast</code> 部署到上述地址。
        开发环境 RPC 走 Vite 代理 <code>/rpc-anvil</code>。
      </p>
      <button type="button" onClick={handleRead} disabled={loading}>
        {loading ? '读取中…' : '从链上读取 _locks'}
      </button>
      {status && (
        <p style={{ marginTop: 12, color: '#0a6b0a' }} role="status">
          {status}
        </p>
      )}
      {error && (
        <pre
          style={{
            marginTop: 12,
            color: 'crimson',
            whiteSpace: 'pre-wrap',
            background: '#fff5f5',
            padding: 12,
            borderRadius: 6,
          }}
        >
          {error}
        </pre>
      )}
      <ul style={{ marginTop: 12, fontFamily: 'monospace', fontSize: 13, lineHeight: 1.6 }}>
        {locks.map((lock) => (
          <li key={lock.index}>{formatLockLine(lock)}</li>
        ))}
      </ul>
    </section>
  )
}
