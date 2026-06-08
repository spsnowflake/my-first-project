export type WhitelistJson = {
  description: string
  leafEncoding: string
  root: `0x${string}`
  entries: {
    address: string
    index: number
    proof: `0x${string}`[]
  }[]
}
