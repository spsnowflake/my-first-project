/**
 * Generate Merkle root + proofs for Anvil accounts (1)-(4).
 * Leaf format matches AirdropMerkleNFTMarket.sol:
 *   keccak256(bytes.concat(keccak256(abi.encode(address))))
 */
import { StandardMerkleTree } from '@openzeppelin/merkle-tree'
import { mkdirSync, writeFileSync } from 'fs'
import { dirname, resolve } from 'path'
import { fileURLToPath } from 'url'

const __dirname = dirname(fileURLToPath(import.meta.url))

const WHITELIST = [
  '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
  '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC',
  '0x90F79bf6EB2c4f870365E785982E1f101E93b906',
  '0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65',
]

const tree = StandardMerkleTree.of(
  WHITELIST.map((address) => [address]),
  ['address'],
)

const output = {
  description: 'Anvil accounts (1)-(4) Merkle whitelist',
  leafEncoding: 'keccak256(bytes.concat(keccak256(abi.encode(address))))',
  root: tree.root,
  entries: WHITELIST.map((address, i) => ({
    address,
    index: i,
    proof: tree.getProof(i),
  })),
}

const outDir = resolve(__dirname, '../frontend/src/data')
mkdirSync(outDir, { recursive: true })
const outPath = resolve(outDir, 'whitelist.json')
writeFileSync(outPath, JSON.stringify(output, null, 2))

console.log('Merkle root:', tree.root)
console.log('Written to:', outPath)
