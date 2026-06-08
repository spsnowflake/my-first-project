import { getAddress, isAddress } from 'viem'
import whitelistData from '../data/whitelist.json'
import type { WhitelistJson } from '../data/whitelist.types'

const data = whitelistData as WhitelistJson

export type WhitelistEntry = WhitelistJson['entries'][number]

export const MERKLE_ROOT = data.root

/** 统一 checksum，避免 WC / MetaMask 返回格式不一致 */
function normalizeAddress(address: string): `0x${string}` | undefined {
  if (!isAddress(address)) return undefined
  try {
    return getAddress(address)
  } catch {
    return undefined
  }
}

const entriesByAddress = new Map(
  data.entries.map((e) => [normalizeAddress(e.address)!, e]),
)

export function getWhitelistEntry(
  address: string,
): WhitelistEntry | undefined {
  const key = normalizeAddress(address)
  if (!key) return undefined
  return entriesByAddress.get(key)
}

export function isWhitelisted(address: string): boolean {
  return getWhitelistEntry(address) != null
}

export function getProofForAddress(
  address: string,
): `0x${string}`[] | undefined {
  return getWhitelistEntry(address)?.proof
}
