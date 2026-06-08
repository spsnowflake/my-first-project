import { useState, type CSSProperties } from 'react'
import NftMarket from './NftMarket'
import TokenBank from './TokenBank'
import EsRNTLocksReader from './components/EsRNTLocksReader'
import AirdropMerkleMarketPage from './AirdropMerkleMarket'

function App() {
  const [page, setPage] = useState<'nft' | 'bank' | 'esrnt' | 'merkle'>('esrnt')

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
          onClick={() => setPage('esrnt')}
          style={navBtn(page === 'esrnt')}
        >
          esRNT Storage
        </button>
        <button
          type="button"
          onClick={() => setPage('merkle')}
          style={navBtn(page === 'merkle')}
        >
          Merkle 白名单市场
        </button>
      </nav>
      {page === 'nft' && <NftMarket />}
      {page === 'bank' && <TokenBank />}
      {page === 'esrnt' && <EsRNTLocksReader />}
      {page === 'merkle' && <AirdropMerkleMarketPage />}
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
