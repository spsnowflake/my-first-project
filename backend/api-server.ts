/**
 * REST API：查询某地址的 ERC20 转账记录。
 * 启动时会先执行一次扫块，之后按间隔继续扫块追最新。
 *
 * 用法（backend 目录）：
 *   npm run api
 *
 * GET /api/transfers/:address?direction=all|in|out&page=1&limit=20
 */

import * as path from 'node:path'
import { fileURLToPath } from 'node:url'

import dotenv from 'dotenv'
import express from 'express'
import { formatUnits, isAddress } from 'viem'

import { initDb, pingDb, queryTransfersByAddress, type TokenTransferRow } from './db.js'
import { scanTransfers } from './transfer-indexer.js'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
dotenv.config({ path: path.join(__dirname, '..', '.env') })

const PORT = Number(process.env.API_PORT ?? 3000)
const SCAN_INTERVAL_MS = Number(process.env.SCAN_INTERVAL_MS ?? 30_000)
const TOKEN_DECIMALS = Number(process.env.TOKEN_DECIMALS ?? 18)

const app = express()

app.get('/health', async (_req, res) => {
  try {
    await pingDb()
    res.json({ ok: true })
  } catch (err) {
    res.status(500).json({
      ok: false,
      error: err instanceof Error ? err.message : String(err),
    })
  }
})

app.get('/api/transfers/:address', async (req, res) => {
  const { address } = req.params
  if (!isAddress(address)) {
    res.status(400).json({ error: '无效的以太坊地址' })
    return
  }

  const direction = (req.query.direction as string | undefined) ?? 'all'
  if (direction !== 'all' && direction !== 'in' && direction !== 'out') {
    res.status(400).json({ error: 'direction 只能是 all、in 或 out' })
    return
  }

  const page = Number(req.query.page ?? 1)
  const limit = Number(req.query.limit ?? 20)

  try {
    const { total, items } = await queryTransfersByAddress(address, {
      direction,
      page: Number.isFinite(page) ? page : 1,
      limit: Number.isFinite(limit) ? limit : 20,
    })

    res.json({
      address: address.toLowerCase(),
      total,
      page: Number.isFinite(page) && page > 0 ? page : 1,
      limit: Number.isFinite(limit) && limit > 0 ? Math.min(limit, 100) : 20,
      items: items.map((row: TokenTransferRow) => ({
        txHash: row.tx_hash,
        logIndex: row.log_index,
        blockNumber: Number(row.block_number),
        blockTimestamp: row.block_timestamp.toISOString(),
        from: row.from_address,
        to: row.to_address,
        value: row.value,
        valueFormatted: formatUnits(BigInt(row.value), TOKEN_DECIMALS),
        createdAt: row.created_at.toISOString(),
      })),
    })
  } catch (err) {
    res.status(500).json({
      error: err instanceof Error ? err.message : String(err),
    })
  }
})

let scanning = false

async function runScanLoop(): Promise<void> {
  if (scanning) return
  scanning = true
  try {
    await scanTransfers((line: string) => console.log(line))
  } catch (err) {
    console.error('[scan]', err)
  } finally {
    scanning = false
  }
}

async function start(): Promise<void> {
  await initDb()
  await runScanLoop()

  setInterval(() => {
    void runScanLoop()
  }, SCAN_INTERVAL_MS)

  app.listen(PORT, () => {
    console.log(
      `[api] 已启动 http://127.0.0.1:${PORT}，` +
        `每 ${SCAN_INTERVAL_MS / 1000}s 扫块一次`,
    )
  })
}

start().catch((err) => {
  console.error(err)
  process.exit(1)
})
