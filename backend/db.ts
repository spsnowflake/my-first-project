import * as path from 'node:path'
import { fileURLToPath } from 'node:url'

import dotenv from 'dotenv'
import mysql from 'mysql2/promise'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
dotenv.config({ path: path.join(__dirname, '..', '.env') })

const pool = mysql.createPool({
  host: process.env.MYSQL_HOST ?? '127.0.0.1',
  port: Number(process.env.MYSQL_PORT ?? 3306),
  user: process.env.MYSQL_USER ?? 'root',
  password: process.env.MYSQL_PASSWORD ?? '',
  database: process.env.MYSQL_DATABASE ?? 'solidity',
  waitForConnections: true,
  connectionLimit: 10,
})

/** 与库表 token_transfers 字段一致 */
export type TokenTransferRow = {
  id: number
  tx_hash: string
  block_number: number
  block_timestamp: Date
  from_address: string
  to_address: string
  value: string
  log_index: number
  created_at: Date
}

/** 仅初始化索引进度表；token_transfers 由作业库表提供，不在此建表 */
export async function initDb(): Promise<void> {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS indexer_state (
      id         TINYINT PRIMARY KEY DEFAULT 1,
      last_block BIGINT NOT NULL,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )
  `)
}

export async function getLastSyncedBlock(
  fallback: bigint,
): Promise<bigint> {
  const [rows] = await pool.query<mysql.RowDataPacket[]>(
    'SELECT last_block FROM indexer_state WHERE id = 1',
  )
  if (rows.length === 0) return fallback
  return BigInt(rows[0].last_block)
}

export async function setLastSyncedBlock(block: bigint): Promise<void> {
  await pool.query(
    `INSERT INTO indexer_state (id, last_block) VALUES (1, ?)
     ON DUPLICATE KEY UPDATE last_block = VALUES(last_block)`,
    [block.toString()],
  )
}

export type TransferInsert = {
  txHash: string
  blockNumber: bigint
  blockTimestamp: Date
  from: string
  to: string
  value: bigint
  logIndex: number
}

export async function insertTransfers(
  transfers: TransferInsert[],
): Promise<number> {
  if (transfers.length === 0) return 0

  let inserted = 0
  for (const t of transfers) {
    const [result] = await pool.query<mysql.ResultSetHeader>(
      `INSERT IGNORE INTO token_transfers
       (tx_hash, block_number, block_timestamp, from_address, to_address, value, log_index)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        t.txHash,
        t.blockNumber.toString(),
        t.blockTimestamp,
        t.from.toLowerCase(),
        t.to.toLowerCase(),
        t.value.toString(),
        t.logIndex,
      ],
    )
    inserted += result.affectedRows
  }
  return inserted
}

export async function queryTransfersByAddress(
  address: string,
  options: {
    direction?: 'all' | 'in' | 'out'
    page?: number
    limit?: number
  } = {},
): Promise<{ total: number; items: TokenTransferRow[] }> {
  const direction = options.direction ?? 'all'
  const page = Math.max(1, options.page ?? 1)
  const limit = Math.min(100, Math.max(1, options.limit ?? 20))
  const offset = (page - 1) * limit
  const addr = address.toLowerCase()

  let where = 'from_address = ? OR to_address = ?'
  const params: (string | number)[] = [addr, addr]

  if (direction === 'in') {
    where = 'to_address = ?'
    params.length = 0
    params.push(addr)
  } else if (direction === 'out') {
    where = 'from_address = ?'
    params.length = 0
    params.push(addr)
  }

  const [countRows] = await pool.query<mysql.RowDataPacket[]>(
    `SELECT COUNT(*) AS cnt FROM token_transfers WHERE ${where}`,
    params,
  )
  const total = Number(countRows[0].cnt)

  const [rows] = await pool.query<(TokenTransferRow & mysql.RowDataPacket)[]>(
    `SELECT id, tx_hash, block_number, block_timestamp,
            from_address, to_address, value, log_index, created_at
     FROM token_transfers
     WHERE ${where}
     ORDER BY block_number DESC, log_index DESC
     LIMIT ? OFFSET ?`,
    [...params, limit, offset],
  )

  return { total, items: rows as TokenTransferRow[] }
}

export async function pingDb(): Promise<void> {
  await pool.query('SELECT 1')
}

export { pool }
