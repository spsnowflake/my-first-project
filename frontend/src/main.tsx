import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'
import { AppKitWagmiProvider } from './appkit'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <AppKitWagmiProvider>
      <App />
    </AppKitWagmiProvider>
  </StrictMode>,
)
