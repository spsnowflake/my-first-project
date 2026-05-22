/**
 * ERC20 Transfer 扫块索引：按区块范围拉取 Transfer 事件并写入 MySQL。
 *
 * 用法（backend 目录）：
 *   npm run sync
 */

import * as path from 'node:path'
import { fileURLToPath } from 'node:url'

import dotenv from 'dotenv'
import {
  createPublicClient,
  decodeEventLog,
  http,
  type Log,
} from 'viem'
import { sepolia } from 'viem/chains'

import {
  getLastSyncedBlock,
  initDb,
  insertTransfers,
  setLastSyncedBlock,
  type TransferInsert,
} from './db.js'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
dotenv.config({ path: path.join(__dirname, '..', '.env') })

/** MyToken 在 Sepolia 的部署区块（broadcast/MyToken.s.sol/11155111） */
const DEFAULT_START_BLOCK = 10699125n

/** 每批扫描的区块数（Nodies 等公共 RPC 通常上限 500） */
const BLOCK_BATCH_SIZE = BigInt(process.env.BLOCK_BATCH_SIZE ?? 500)

const transferEvent = {
  type: 'event',
  name: 'Transfer',
  inputs: [
    { name: 'from', type: 'address', indexed: true },
    { name: 'to', type: 'address', indexed: true },
    { name: 'value', type: 'uint256', indexed: false },
  ],
} as const

const transferEventAbi = [transferEvent] as const

function requireEnv(name: string): string {
  const v = process.env[name]?.trim()
  if (!v) throw new Error(`缺少环境变量 ${name}`)
  return v
}

function getTokenAddress(): `0x${string}` {
  return requireEnv('SEPOLIA_ERC20').toLowerCase() as `0x${string}`
}

function getPublicClient() {
  return createPublicClient({
    chain: sepolia,
    transport: http(requireEnv('SEPOLIA_RPC_URL')),
  })
}

function unixToDate(ts: bigint): Date {
  return new Date(Number(ts) * 1000)
}

function parseTransferLog(log: Log): TransferInsert | null {
  try {
    const decoded = decodeEventLog({
      abi: transferEventAbi,
      data: log.data,
      topics: log.topics,
    })
    if (decoded.eventName !== 'Transfer') return null

    const args = decoded.args as {
      from: `0x${string}`
      to: `0x${string}`
      value: bigint
    }

    return {
      txHash: log.transactionHash ?? '',
      blockNumber: log.blockNumber ?? 0n,
      blockTimestamp: new Date(0),
      from: args.from,
      to: args.to,
      value: args.value,
      logIndex: Number(log.logIndex ?? 0),
    }
  } catch {
    return null
  }
}

async function fillBlockTimestamps(
  client: ReturnType<typeof getPublicClient>,
  transfers: TransferInsert[],
): Promise<void> {
  const blockNumbers = [...new Set(transfers.map((t) => t.blockNumber))]
  const timeMap = new Map<string, Date>()

  for (const bn of blockNumbers) {
    const block = await client.getBlock({ blockNumber: bn })
    timeMap.set(bn.toString(), unixToDate(block.timestamp))
  }

  for (const t of transfers) {
    const ts = timeMap.get(t.blockNumber.toString())
    if (!ts) {
      throw new Error(`缺少区块 ${t.blockNumber.toString()} 的时间戳`)
    }
    t.blockTimestamp = ts
  }
}

export async function scanTransfers(
  onProgress?: (line: string) => void,
): Promise<{ scannedTo: bigint; inserted: number }> {
  const log = onProgress ?? ((s: string) => console.log(s))
  const client = getPublicClient()
  const tokenAddress = getTokenAddress()

  await initDb()

  const latest = await client.getBlockNumber()
  let fromBlock = await getLastSyncedBlock(DEFAULT_START_BLOCK - 1n)
  fromBlock += 1n

  if (fromBlock > latest) {
    log(`[sync] 已是最新块 ${latest.toString()}，无需扫描`)
    return { scannedTo: latest, inserted: 0 }
  }

  log(
    `[sync] 开始扫块：${fromBlock.toString()} → ${latest.toString()}，` +
      `token=${tokenAddress}`,
  )

  let totalInserted = 0

  while (fromBlock <= latest) {
    const toBlock =
      fromBlock + BLOCK_BATCH_SIZE - 1n > latest
        ? latest
        : fromBlock + BLOCK_BATCH_SIZE - 1n

    const logs = await client.getLogs({
      address: tokenAddress,
      event: transferEvent,
      fromBlock,
      toBlock,
    })

    const transfers: TransferInsert[] = []
    for (const raw of logs) {
      const parsed = parseTransferLog(raw)
      if (parsed) transfers.push(parsed)
    }

    let batchInserted = 0
    if (transfers.length > 0) {
      await fillBlockTimestamps(client, transfers)
      batchInserted = await insertTransfers(transfers)
      totalInserted += batchInserted
    }

    await setLastSyncedBlock(toBlock)
    log(
      `[sync] ${fromBlock.toString()}-${toBlock.toString()}：` +
        `链上 ${logs.length} 条，新入库 ${batchInserted} 条`,
    )

    fromBlock = toBlock + 1n
  }

  log(`[sync] 完成，同步到块 ${latest.toString()}，本轮新入库 ${totalInserted} 条`)
  return { scannedTo: latest, inserted: totalInserted }
}

async function main() {
  await scanTransfers()
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})
