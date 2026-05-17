import {
  type Address,
  type Hex,
  recoverTypedDataAddress,
  hexToSignature,
} from 'viem'

/** OpenZeppelin ERC20Permit 的 EIP-712 类型 */
export const permitTypes = {
  Permit: [
    { name: 'owner', type: 'address' },
    { name: 'spender', type: 'address' },
    { name: 'value', type: 'uint256' },
    { name: 'nonce', type: 'uint256' },
    { name: 'deadline', type: 'uint256' },
  ],
} as const

export type PermitMessage = {
  owner: Address
  spender: Address
  value: bigint
  nonce: bigint
  deadline: bigint
}

export function buildPermitDomain(params: {
  name: string
  chainId: number
  verifyingContract: Address
}) {
  return {
    name: params.name,
    version: '1' as const,
    chainId: params.chainId,
    verifyingContract: params.verifyingContract,
  }
}

export type StoredPermitSignature = {
  message: PermitMessage
  domain: ReturnType<typeof buildPermitDomain>
  signature: Hex
  v: number
  r: Hex
  s: Hex
}

export function splitPermitSignature(signature: Hex): {
  v: number
  r: Hex
  s: Hex
} {
  const { v, r, s } = hexToSignature(signature)
  return { v: Number(v), r, s }
}

export async function verifyPermitSignature(
  domain: ReturnType<typeof buildPermitDomain>,
  message: PermitMessage,
  signature: Hex,
): Promise<Address> {
  return recoverTypedDataAddress({
    domain,
    types: permitTypes,
    primaryType: 'Permit',
    message,
    signature,
  })
}
