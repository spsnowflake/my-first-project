/** AirdropMerkleNFTMarket ABI（与 src/AirdropMerkleNFTMarket.sol 一致） */
export const airdropMerkleMarketAbi = [
  {
    type: 'function',
    name: 'list',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'tokenId', type: 'uint256' },
      { name: 'amount', type: 'uint96' },
    ],
    outputs: [{ type: 'bool' }],
  },
  {
    type: 'function',
    name: 'claimNFT',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'tokenId', type: 'uint256' },
      { name: 'proof', type: 'bytes32[]' },
    ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'permitPrePay',
    stateMutability: 'nonpayable',
    inputs: [
      { name: '_owner', type: 'address' },
      { name: 'value', type: 'uint256' },
      { name: 'deadline', type: 'uint256' },
      { name: 'v', type: 'uint8' },
      { name: 'r', type: 'bytes32' },
      { name: 's', type: 'bytes32' },
    ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'multicall',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'data', type: 'bytes[]' }],
    outputs: [{ name: 'results', type: 'bytes[]' }],
  },
  {
    type: 'function',
    name: 'tokenListing',
    stateMutability: 'view',
    inputs: [{ name: '', type: 'uint256' }],
    outputs: [
      { name: 'price', type: 'uint96' },
      { name: 'seller', type: 'address' },
    ],
  },
  {
    type: 'function',
    name: 'merkleRoot',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'bytes32' }],
  },
  {
    type: 'function',
    name: 'erc20Token',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'address' }],
  },
  {
    type: 'function',
    name: 'erc721Token',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'address' }],
  },
] as const

export { erc721MarketAbi } from './nftMarket'
