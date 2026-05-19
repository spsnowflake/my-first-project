import type { Address, Hex } from 'viem'

/** 与合约里 permitted.amount = type(uint256).max 一致 */
export const PERMIT2_MAX_AMOUNT = (1n << 256n) - 1n

/** Uniswap Permit2 SignatureTransfer（PermitHash.sol） */
export const permit2TransferTypes = {
  PermitTransferFrom: [
    { name: 'permitted', type: 'TokenPermissions' },
    { name: 'spender', type: 'address' },
    { name: 'nonce', type: 'uint256' },
    { name: 'deadline', type: 'uint256' },
  ],
  TokenPermissions: [
    { name: 'token', type: 'address' },
    { name: 'amount', type: 'uint256' },
  ],
} as const

export function buildPermit2Domain(params: {
  chainId: number
  verifyingContract: Address
}) {
  return {
    name: 'Permit2' as const,
    chainId: params.chainId,
    verifyingContract: params.verifyingContract,
  }
}

export type Permit2TransferMessage = {
  permitted: { token: Address; amount: bigint }
  spender: Address
  nonce: bigint
  deadline: bigint
}

export function buildPermit2TransferMessage(params: {
  token: Address
  spender: Address
  nonce: bigint
  deadline: bigint
}): Permit2TransferMessage {
  return {
    permitted: { token: params.token, amount: PERMIT2_MAX_AMOUNT },
    spender: params.spender,
    nonce: params.nonce,
    deadline: params.deadline,
  }
}

/** 生成 Permit2 无序 nonce（本地 demo 用时间戳，避免连续两次撞 nonce） */
export function randomPermit2Nonce(): bigint {
  return BigInt(Date.now()) * 1_000_000n + BigInt(Math.floor(Math.random() * 1_000_000))
}

export function permit2Deadline(secondsFromNow = 3600): bigint {
  return BigInt(Math.floor(Date.now() / 1000) + secondsFromNow)
}

export type StoredPermit2Signature = {
  message: Permit2TransferMessage
  domain: ReturnType<typeof buildPermit2Domain>
  signature: Hex
  depositAmount: bigint
}
