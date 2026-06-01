import { createPublicClient, http, keccak256, toHex, type Address } from 'viem'
import { foundry } from 'viem/chains'

export const ESRNT_CONTRACT_ADDRESS =
  '0x5FbDB2315678afecb367f032d93F642f64180aa3' as Address

/** 开发时用 Vite 代理；生产/脚本可设 VITE_ANVIL_RPC_URL=http://127.0.0.1:8545 */
const ANVIL_RPC =
  import.meta.env.VITE_ANVIL_RPC_URL?.trim() ||
  (import.meta.env.DEV ? '/rpc-anvil' : 'http://127.0.0.1:8545')

export type LockInfo = {
  index: number
  user: Address
  startTime: bigint
  amount: bigint
}

function parseLockSlot0(raw: `0x${string}`): { user: Address; startTime: bigint } {
  const word = BigInt(raw)
  const user = `0x${(word & ((1n << 160n) - 1n)).toString(16).padStart(40, '0')}` as Address
  const startTime = (word >> 160n) & ((1n << 64n) - 1n)
  return { user, startTime }
}

export async function readEsRNTLocks(
  contractAddress: Address = ESRNT_CONTRACT_ADDRESS,
  rpcUrl: string = ANVIL_RPC
): Promise<LockInfo[]> {
  const client = createPublicClient({
    chain: foundry,
    transport: http(rpcUrl),
  })

  const code = await client.getBytecode({ address: contractAddress })
  if (!code || code === '0x') {
    throw new Error(
      `该地址无合约代码（${contractAddress}）。请先启动 anvil 并 forge create 部署 esRNT。`
    )
  }

  const lengthRaw = await client.getStorageAt({
    address: contractAddress,
    slot: '0x0',
  })
  if (!lengthRaw) throw new Error('无法读取 _locks 数组长度 (slot 0)')

  const length = Number(BigInt(lengthRaw))
  if (length === 0) {
    throw new Error('_locks 长度为 0：合约可能未初始化，或 Anvil 已重启需重新部署。')
  }
  const base = BigInt(keccak256(toHex(0n, { size: 32 })))
  const locks: LockInfo[] = []

  for (let i = 0; i < length; i++) {
    const slot0 = `0x${(base + BigInt(i * 2)).toString(16)}` as `0x${string}`
    const slot1 = `0x${(base + BigInt(i * 2 + 1)).toString(16)}` as `0x${string}`

    const raw0 = await client.getStorageAt({ address: contractAddress, slot: slot0 })
    const raw1 = await client.getStorageAt({ address: contractAddress, slot: slot1 })
    if (!raw0 || !raw1) throw new Error(`无法读取 locks[${i}] 的 storage`)

    const { user, startTime } = parseLockSlot0(raw0)
    locks.push({ index: i, user, startTime, amount: BigInt(raw1) })
  }

  return locks
}

export function formatLockLine(lock: LockInfo): string {
  return `locks[${lock.index}]: user:${lock.user}, startTime:${lock.startTime}, amount:${lock.amount}`
}
