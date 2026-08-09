/**
 * 用 Flashbots `eth_sendBundle` 捆绑 OpenspaceNFT 的
 *   1) enablePresale（项目方）
 *   2) presale（买家）
 * 发送到 Sepolia，再用 `flashbots_getBundleStats` 查询状态。
 *
 * ---------------------------------------------------------------------------
 * 运行方式（在 backend 目录）：
 *   npx tsx flashbots-presale-bundle.ts
 *
 * 或在项目根目录：
 *   npx tsx backend/flashbots-presale-bundle.ts
 *
 * ---------------------------------------------------------------------------
 * 需要的环境变量（项目根目录 .env）：
 *   SEPOLIA_RPC_URL                  — 普通 Sepolia RPC（查区块、nonce、gas）
 *   FLASH_BOT_SEPOLIA                — Flashbots Sepolia Relay，例如
 *                                      https://relay-sepolia.flashbots.net
 *   FLASH_BOT_SEPOLIA_PRIVATE_KEY    — 仅用于给 Relay 请求做签名鉴权（可为空钱包）
 *   PRIVATE_KEY                      — 项目方（部署者 / owner），发 enablePresale
 *   PRIVATE_KEY2                     — 买家，发 presale（不能是 owner）
 *   OpenspaceNFT                     — 已部署的合约地址
 *
 * 可选：
 *   PRESALE_AMOUNT                   — 购买数量，默认 1
 *                                      注意：合约 nextTokenId 从 1 开始，且要求
 *                                      amount + nextTokenId <= 1024，所以最大是 1023，
 *                                      不能直接填 1024。
 */

import * as path from 'node:path'
import { fileURLToPath } from 'node:url'
import { randomUUID } from 'node:crypto'

import dotenv from 'dotenv'
import {
  createPublicClient,
  encodeFunctionData,
  http,
  keccak256,
  parseEther,
  serializeTransaction,
  stringToBytes,
  type Hex,
  type TransactionSerializableEIP1559,
} from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { sepolia } from 'viem/chains'

// ---------------------------------------------------------------------------
// 1. 加载 .env
// ---------------------------------------------------------------------------

// 本文件在 backend/ 下，.env 在上一级项目根目录
const __dirname = path.dirname(fileURLToPath(import.meta.url))
dotenv.config({ path: path.join(__dirname, '..', '.env') })

// ---------------------------------------------------------------------------
// 2. 合约 ABI：只写本脚本会用到的函数，够用即可
// ---------------------------------------------------------------------------

const openspaceNftAbi = [
  {
    type: 'function',
    name: 'enablePresale',
    stateMutability: 'nonpayable',
    inputs: [],
    outputs: [],
  },
  {
    type: 'function',
    name: 'presale',
    stateMutability: 'payable',
    inputs: [{ name: 'amount', type: 'uint256' }],
    outputs: [],
  },
  {
    type: 'function',
    name: 'isPresaleActive',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'bool' }],
  },
  {
    type: 'function',
    name: 'owner',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'address' }],
  },
] as const

// ---------------------------------------------------------------------------
// 3. 小工具函数
// ---------------------------------------------------------------------------

/** 读取必需环境变量；缺了立刻报错，避免后面静默失败 */
function requireEnv(name: string): string {
  const v = process.env[name]?.trim()
  if (!v) {
    throw new Error(`缺少环境变量 ${name}，请在项目根目录 .env 中填写。`)
  }
  return v
}

/** 把私钥统一成 `0x` 开头的 32 字节 hex，供 viem 使用 */
function normalizePrivateKey(raw: string, envName: string): `0x${string}` {
  const s = raw.trim().replace(/^['"]|['"]$/g, '')
  const with0x = (s.startsWith('0x') ? s : `0x${s}`) as `0x${string}`
  if (!/^0x[0-9a-fA-F]{64}$/.test(with0x)) {
    throw new Error(`${envName} 不是合法的 32 字节私钥（需要 64 位 hex）。`)
  }
  return with0x
}

/** 数字转成 0x 开头的十六进制字符串（Flashbots 的 blockNumber 要这种格式） */
function toHexQuantity(n: number | bigint): Hex {
  return `0x${BigInt(n).toString(16)}` as Hex
}

/**
 * Flashbots 要求：请求头带 X-Flashbots-Signature: <地址>:<签名>
 *
 * 官方文档 Authentication 段（ethers.js 示例）写法是：
 *   signature = address + ':' + wallet.signMessage(id(body))
 * 其中 id(body) = keccak256(utf8(body))，返回带 0x 的 hex 字符串。
 *
 * 注意：这里 signMessage 签的是「这个 hex 字符串本身的 UTF-8 文本」
 * （EIP-191，前缀里的长度是 66），不是把 32 字节 raw hash 直接当 bytes 签。
 * 若写成 signMessage({ message: { raw: bodyHash } })，会和官方示例不一致，Relay 可能报
 * signature is required / invalid flashbots signature。
 *
 * 签名必须和真正 POST 出去的 body 字节完全一致，
 * 所以下面统一用 JSON.stringify 生成 body，签名和发送都用同一份字符串。
 */
async function flashbotsFetch(
  relayUrl: string,
  authPrivateKey: `0x${string}`,
  method: string,
  params: unknown[],
): Promise<unknown> {
  const authAccount = privateKeyToAccount(authPrivateKey)

  // JSON-RPC 请求体（字段顺序固定，保证签名与发送一致）
  const payload = {
    jsonrpc: '2.0',
    id: 1,
    method,
    params,
  }
  const body = JSON.stringify(payload)

  // 等价于 ethers.id(body)：keccak256(utf8(body)) → "0x" + 64 hex
  const bodyHashHex = keccak256(stringToBytes(body))

  // 等价于 ethers: wallet.signMessage(id(body))
  // 把 hex 字符串当普通文本做 EIP-191 personal_sign
  const signature = await authAccount.signMessage({
    message: bodyHashHex,
  })

  const res = await fetch(relayUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      // 格式必须是：0x地址:0x签名
      'X-Flashbots-Signature': `${authAccount.address}:${signature}`,
    },
    body,
  })

  const json = (await res.json()) as {
    result?: unknown
    error?: { code?: number; message?: string }
  }

  if (!res.ok || json.error) {
    throw new Error(
      `Flashbots ${method} 失败：HTTP ${res.status} ${JSON.stringify(json.error ?? json)}`,
    )
  }

  return json.result
}

/** 从已签名的原始交易字节算出交易哈希（keccak256(rawTx)） */
function txHashFromRaw(rawTx: Hex): Hex {
  return keccak256(rawTx)
}

// ---------------------------------------------------------------------------
// 4. 主流程
// ---------------------------------------------------------------------------

async function main() {
  console.log('========== Flashbots Bundle：enablePresale + presale ==========\n')

  // ---- 4.1 读配置 ----
  const rpcUrl = requireEnv('SEPOLIA_RPC_URL')
  const relayUrl = requireEnv('FLASH_BOT_SEPOLIA')
  const authKey = normalizePrivateKey(
    requireEnv('FLASH_BOT_SEPOLIA_PRIVATE_KEY'),
    'FLASH_BOT_SEPOLIA_PRIVATE_KEY',
  )
  const ownerKey = normalizePrivateKey(requireEnv('PRIVATE_KEY'), 'PRIVATE_KEY')
  const buyerKey = normalizePrivateKey(requireEnv('PRIVATE_KEY2'), 'PRIVATE_KEY2')
  const nftAddress = requireEnv('OpenspaceNFT') as `0x${string}`

  // 购买数量：默认买 1 个，便宜也更不容易失败
  const amount = BigInt(process.env.PRESALE_AMOUNT?.trim() || '1')
  if (amount <= 0n) throw new Error('PRESALE_AMOUNT 必须 > 0')
  if (amount > 1023n) {
    throw new Error('PRESALE_AMOUNT 最大 1023（合约：amount + nextTokenId <= 1024，且 nextTokenId 从 1 起）')
  }

  // 合约：msg.value 必须等于 amount * 0.00001 ether
  const value = amount * parseEther('0.00001')

  const owner = privateKeyToAccount(ownerKey)
  const buyer = privateKeyToAccount(buyerKey)
  const auth = privateKeyToAccount(authKey)

  console.log('配置：')
  console.log(`  Sepolia RPC     : ${rpcUrl}`)
  console.log(`  Flashbots Relay : ${relayUrl}`)
  console.log(`  Auth 地址       : ${auth.address}`)
  console.log(`  项目方 Owner    : ${owner.address}`)
  console.log(`  买家 Buyer      : ${buyer.address}`)
  console.log(`  NFT 合约        : ${nftAddress}`)
  console.log(`  购买数量 amount : ${amount}`)
  console.log(`  支付 value      : ${value} wei\n`)

  if (owner.address.toLowerCase() === buyer.address.toLowerCase()) {
    throw new Error('PRIVATE_KEY 与 PRIVATE_KEY2 不能是同一个地址：合约禁止 owner 调用 presale。')
  }

  // ---- 4.2 普通 RPC 客户端：读链上状态（Relay 不能当普通节点用）----
  const publicClient = createPublicClient({
    chain: sepolia,
    transport: http(rpcUrl),
  })

  // 基本检查：合约是否已部署、owner 是否匹配、预售是否仍关闭
  const code = await publicClient.getCode({ address: nftAddress })
  if (!code || code === '0x') {
    throw new Error(`地址 ${nftAddress} 上没有合约代码，请先确认 OpenspaceNFT 已部署到 Sepolia。`)
  }

  const onchainOwner = await publicClient.readContract({
    address: nftAddress,
    abi: openspaceNftAbi,
    functionName: 'owner',
  })
  if (onchainOwner.toLowerCase() !== owner.address.toLowerCase()) {
    throw new Error(
      `PRIVATE_KEY 对应地址不是合约 owner。\n  链上 owner: ${onchainOwner}\n  你的 PRIVATE_KEY: ${owner.address}`,
    )
  }

  const isActive = await publicClient.readContract({
    address: nftAddress,
    abi: openspaceNftAbi,
    functionName: 'isPresaleActive',
  })
  if (isActive) {
    throw new Error(
      '预售已经是开启状态。本作业演示的是「先 enable 再 presale」的捆绑；请重新部署一个新的 OpenspaceNFT 再跑。',
    )
  }

  // ---- 4.3 准备两笔交易的 calldata ----
  // enablePresale()：无参数
  const enableData = encodeFunctionData({
    abi: openspaceNftAbi,
    functionName: 'enablePresale',
  })

  // presale(amount)：买家支付 value
  const presaleData = encodeFunctionData({
    abi: openspaceNftAbi,
    functionName: 'presale',
    args: [amount],
  })

  // ---- 4.4 取 nonce、gas 价格、当前区块 ----
  const [ownerNonce, buyerNonce, blockNumber, fee] = await Promise.all([
    publicClient.getTransactionCount({ address: owner.address }),
    publicClient.getTransactionCount({ address: buyer.address }),
    publicClient.getBlockNumber(),
    publicClient.estimateFeesPerGas(),
  ])

  // gas 给宽裕一点，避免估算偏低导致 bundle 模拟失败
  // enablePresale 很轻；presale 要 mint，amount 越大 gas 越高
  const enableGas = 100_000n
  const presaleGas = 150_000n + amount * 120_000n

  // 略微提高 tip，提高被 builder 看中的概率（测试网也不用太激进）
  const maxPriorityFeePerGas = (fee.maxPriorityFeePerGas ?? parseEther('0.000000001')) * 2n
  const maxFeePerGas = (fee.maxFeePerGas ?? maxPriorityFeePerGas) * 2n

  console.log('链上状态：')
  console.log(`  当前区块     : ${blockNumber}`)
  console.log(`  owner nonce  : ${ownerNonce}`)
  console.log(`  buyer nonce  : ${buyerNonce}`)
  console.log(`  maxFeePerGas : ${maxFeePerGas}`)
  console.log(`  maxPriority  : ${maxPriorityFeePerGas}\n`)

  // ---- 4.5 组装并签名两笔 EIP-1559 交易 ----
  //
  // 关键点：
  //   - 这两笔来自「不同账户」，所以各自用自己的 nonce（不是同一地址的 nonce / nonce+1）
  //   - 顺序靠 bundle 数组顺序保证：先 enablePresale，再 presale
  //   - 只签名，不通过普通 RPC 广播；交给 Flashbots Relay

  const enableTx: TransactionSerializableEIP1559 = {
    chainId: sepolia.id,
    type: 'eip1559',
    to: nftAddress,
    data: enableData,
    value: 0n,
    nonce: ownerNonce,
    gas: enableGas,
    maxFeePerGas,
    maxPriorityFeePerGas,
  }

  const presaleTx: TransactionSerializableEIP1559 = {
    chainId: sepolia.id,
    type: 'eip1559',
    to: nftAddress,
    data: presaleData,
    value,
    nonce: buyerNonce,
    gas: presaleGas,
    maxFeePerGas,
    maxPriorityFeePerGas,
  }

  // account.signTransaction 得到签名后的字段，再 serialize 成 raw tx（0x...）
  const signedEnable = await owner.signTransaction(enableTx)
  const signedPresale = await buyer.signTransaction(presaleTx)

  // viem 的 signTransaction 在多数版本直接返回序列化后的 raw hex；
  // 为兼容起见，如果已经是 0x 字符串就直接用。
  const rawEnable = (
    typeof signedEnable === 'string'
      ? signedEnable
      : serializeTransaction(enableTx, signedEnable as never)
  ) as Hex
  const rawPresale = (
    typeof signedPresale === 'string'
      ? signedPresale
      : serializeTransaction(presaleTx, signedPresale as never)
  ) as Hex

  const enableTxHash = txHashFromRaw(rawEnable)
  const presaleTxHash = txHashFromRaw(rawPresale)

  console.log('已签名交易（尚未广播）：')
  console.log(`  enablePresale txHash : ${enableTxHash}`)
  console.log(`  presale txHash       : ${presaleTxHash}\n`)

  // ---- 4.6（推荐）eth_callBundle：先模拟，避免无效交易浪费提交 ----
  // 文档：https://docs.flashbots.net/flashbots-auction/advanced/rpc-endpoint#eth_callbundle
  const simTarget = Number(blockNumber) + 1
  console.log(`先用 eth_callBundle 模拟目标区块 ${simTarget} ...`)
  try {
    const simulation = await flashbotsFetch(relayUrl, authKey, 'eth_callBundle', [
      {
        txs: [rawEnable, rawPresale],
        blockNumber: toHexQuantity(simTarget),
        stateBlockNumber: 'latest',
      },
    ])
    console.log('eth_callBundle 模拟结果：')
    console.log(JSON.stringify(simulation, null, 2), '\n')
  } catch (err) {
    console.warn('eth_callBundle 模拟失败（仍会继续 sendBundle）：', err)
  }

  // ---- 4.7 eth_sendBundle：把两笔打成一个 bundle ----
  // 文档参数：
  //   txs            — 已签名 raw tx 数组（最多 100 笔）
  //   blockNumber    — hex 编码的目标区块号
  //   replacementUuid — 可选；同一 uuid 再次提交会「替换」旧 bundle
  //
  // 注意：向后投多个区块时，不要共用同一个 replacementUuid，
  // 否则后一次会把前一次替换掉，等于只剩最后一个目标块。

  const blocksToTry = 10 // 向后试 10 个块（Sepolia Flashbots 覆盖有限）
  const targetBlocks: number[] = []
  for (let i = 1; i <= blocksToTry; i++) {
    targetBlocks.push(Number(blockNumber) + i)
  }

  console.log(`开始发送 eth_sendBundle，目标区块：${targetBlocks[0]} ~ ${targetBlocks[targetBlocks.length - 1]}\n`)

  // 记录「每个目标块」对应的 bundleHash，后面查 stats 用
  const submitted: Array<{ targetBlock: number; bundleHash: string; replacementUuid: string }> = []

  for (const target of targetBlocks) {
    const replacementUuid = randomUUID() // 每个目标块单独一个，避免互相替换

    // eth_sendBundle 参数格式与官方文档一致
    const result = (await flashbotsFetch(relayUrl, authKey, 'eth_sendBundle', [
      {
        txs: [rawEnable, rawPresale], // 顺序：先开预售，再购买
        blockNumber: toHexQuantity(target),
        replacementUuid,
      },
    ])) as { bundleHash?: string }

    if (!result.bundleHash) {
      throw new Error(`eth_sendBundle 未返回 bundleHash：${JSON.stringify(result)}`)
    }

    submitted.push({ targetBlock: target, bundleHash: result.bundleHash, replacementUuid })
    console.log(
      `  -> block=${target} bundleHash=${result.bundleHash} uuid=${replacementUuid}`,
    )
  }

  if (submitted.length === 0) {
    throw new Error('没有成功提交任何 bundle。')
  }

  // 作业查 stats：用第一次提交（常见做法；也可改成查全部）
  const primary = submitted[0]

  // ---- 4.8 flashbots_getBundleStats：查询这次捆绑的状态 ----
  //
  // 说明：rpc-endpoint 主文档页目前没列出该方法，但官方 SDK / 排错文档仍在用。
  // 方法名是 flashbots_getBundleStats（作业 PPT 也是这个名字；个别文档写成 eth_getBundleStats）。
  // 参数与官方 JS SDK 一致：
  //   params: [{ bundleHash, blockNumber: "0x..." }]  // blockNumber = 目标区块
  //
  // 刚提交完立刻查，可能信息较少；稍等几秒再查。
  console.log('\n等待 5 秒后查询 flashbots_getBundleStats ...')
  await new Promise((r) => setTimeout(r, 5000))

  const stats = await flashbotsFetch(relayUrl, authKey, 'flashbots_getBundleStats', [
    {
      bundleHash: primary.bundleHash,
      blockNumber: toHexQuantity(primary.targetBlock),
    },
  ])

  // ---- 4.9 打印作业需要提交的信息 ----
  console.log('\n==================== 提交作业用信息 ====================')
  console.log('1) 交易哈希')
  console.log(`   enablePresale : ${enableTxHash}`)
  console.log(`   presale       : ${presaleTxHash}`)
  console.log(`2) bundleHash    : ${primary.bundleHash}`)
  console.log(`3) 查询用的区块  : ${primary.targetBlock} (${toHexQuantity(primary.targetBlock)})`)
  console.log('4) flashbots_getBundleStats 返回：')
  console.log(JSON.stringify(stats, null, 2))
  console.log('========================================================\n')

  // 额外：轮询链上，看交易是否真的上链（方便你自己确认，不是作业硬性要求）
  console.log('正在链上确认交易是否被打包（最多等约 2 分钟）...')
  const deadline = Date.now() + 120_000
  let enableReceipt = null
  let presaleReceipt = null

  while (Date.now() < deadline) {
    enableReceipt = await publicClient.getTransactionReceipt({ hash: enableTxHash }).catch(() => null)
    presaleReceipt = await publicClient.getTransactionReceipt({ hash: presaleTxHash }).catch(() => null)
    if (enableReceipt && presaleReceipt) break
    await new Promise((r) => setTimeout(r, 6000))
  }

  if (enableReceipt && presaleReceipt) {
    console.log('链上已确认：')
    console.log(`  enablePresale 区块: ${enableReceipt.blockNumber} status=${enableReceipt.status}`)
    console.log(`  presale       区块: ${presaleReceipt.blockNumber} status=${presaleReceipt.status}`)
  } else {
    console.log(
      '暂时还没在链上看到回执。测试网 Flashbots 覆盖有限，可再跑一次脚本，或把目标区块范围加大。',
    )
    console.log('作业仍可先提交：上面的 txHash、bundleHash、stats 返回值。')
  }
}

main().catch((err) => {
  console.error('\n脚本失败：', err)
  process.exit(1)
})
