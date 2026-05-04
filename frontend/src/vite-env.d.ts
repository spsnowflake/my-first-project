/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_PROJECT_ID: string
  readonly VITE_TOKEN_BANK_ADDRESS?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
