import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      // 浏览器走同源代理，避免 WSL 下 Windows 浏览器访问不到 127.0.0.1:8545
      '/rpc-anvil': {
        target: 'http://127.0.0.1:8545',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/rpc-anvil/, ''),
      },
    },
  },
})
