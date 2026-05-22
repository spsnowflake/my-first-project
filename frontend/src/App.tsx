import { useState, type CSSProperties } from 'react'
import NftMarket from './NftMarket'
import TokenBank from './TokenBank'
import TransferHistory from './TransferHistory'

function App() {
  const [page, setPage] = useState<'nft' | 'bank' | 'transfers'>('nft')

  return (
    <>
      <nav
        style={{
          display: 'flex',
          gap: '0.5rem',
          padding: '0.75rem 1rem',
          borderBottom: '1px solid #eee',
          justifyContent: 'center',
        }}
      >
        <button
          type="button"
          onClick={() => setPage('nft')}
          style={navBtn(page === 'nft')}
        >
          NFT 登录 Demo
        </button>
        <button
          type="button"
          onClick={() => setPage('bank')}
          style={navBtn(page === 'bank')}
        >
          Token Bank
        </button>
        <button
          type="button"
          onClick={() => setPage('transfers')}
          style={navBtn(page === 'transfers')}
        >
          转账记录
        </button>
      </nav>
      {page === 'nft' ? (
        <NftMarket />
      ) : page === 'bank' ? (
        <TokenBank />
      ) : (
        <TransferHistory />
      )}
    </>
  )
}

function navBtn(active: boolean): CSSProperties {
  return {
    padding: '0.35rem 0.75rem',
    borderRadius: 6,
    border: '1px solid #ccc',
    background: active ? '#111' : '#fff',
    color: active ? '#fafafa' : '#111',
    cursor: 'pointer',
  }
}

export default App
