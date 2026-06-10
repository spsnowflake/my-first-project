import { StandardMerkleTree } from '@openzeppelin/merkle-tree'
import { keccak256 } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'

/** 与 forge-std StdCheats.makeAddr / makeAddrAndKey 一致 */
function makeAddr(name) {
  const privateKey = keccak256(new TextEncoder().encode(name))
  return privateKeyToAccount(privateKey).address
}

const names = ['user1', 'user2', 'buyer', 'buyer2']
const addresses = names.map(makeAddr)
const tree = StandardMerkleTree.of(
  addresses.map((a) => [a]),
  ['address'],
)

console.log('Addresses (forge-std makeAddr):')
names.forEach((n, i) => console.log(`  ${n}: ${addresses[i]}`))
console.log('\nMerkle root:')
console.log(tree.root)
console.log('\nProofs:')
names.forEach((n, i) => {
  console.log(`  ${n}:`, JSON.stringify(tree.getProof(i)))
})
