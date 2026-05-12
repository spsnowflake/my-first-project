/**
 * Sepolia 命令行钱包（作业用）：生成私钥、查余额、构建 EIP-1559 的 ERC20 transfer、签名、广播。
 *
 * 用法（在 backend 目录下）：
 *   npx tsx wallet-cli.ts gen-key
 *   npx tsx wallet-cli.ts balance
 *   npx tsx wallet-cli.ts send-erc20 <收款地址> <代币数量 human-readable，如 0.1>
 *
 * 环境变量（写在项目根目录 .env，由本脚本自动加载）：
 *   SEPOLIA_RPC_URL      — Sepolia HTTPS RPC（Alchemy / Infura 等）
 *   CLI_PRIVATE_KEY      — 0x 开头的 32 字节私钥（balance / send-erc20 需要）
 *   SEPOLIA_ERC20        — Sepolia 上测试 ERC20 合约地址（balance / send-erc20 需要）
 *
 * 安全：私钥只放本地 .env，勿提交仓库（.gitignore 已忽略 .env）。
 */

import * as path from 'node:path'
import { fileURLToPath } from 'node:url'

import dotenv from 'dotenv'
import {
  createPublicClient,
  createWalletClient,
  encodeFunctionData,
  formatUnits,
  http,
  parseUnits,
} from 'viem'
import { generatePrivateKey, privateKeyToAccount } from 'viem/accounts'
import { sepolia } from 'viem/chains'

// 从「本文件所在目录」往上一级找项目根目录的 .env（与 backend/index.ts 平级）
const __dirname = path.dirname(fileURLToPath(import.meta.url))
dotenv.config({ path: path.join(__dirname, '..', '.env') })

/** 最小 ERC20 ABI：只包含本脚本用到的三个函数 */
const erc20Abi = [
  {
    type: 'function',
    name: 'balanceOf',
    stateMutability: 'view',
    inputs: [{ name: 'owner', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'decimals',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint8' }],
  },
  {
    type: 'function',
    name: 'transfer',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'to', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    outputs: [{ type: 'bool' }],
  },
] as const

/** 把私钥统一成 viem 要的 `0x${string}` 格式 */
function normalizePrivateKey(raw: string | undefined): `0x${string}` {
  if (!raw || !raw.trim()) {
    throw new Error('缺少 CLI_PRIVATE_KEY：请在项目根 .env 中配置，或先用 gen-key 生成再写入。')
  }
  const s = raw.trim()
  const with0x = s.startsWith('0x') ? s : `0x${s}`
  return with0x as `0x${string}`
}

/** 读必需的环境变量，缺了就直接报错，避免连错链或静默失败 */
function requireEnv(name: string): string {
  const v = process.env[name]?.trim()
  if (!v) throw new Error(`缺少环境变量 ${name}：请在项目根 .env 中填写。`)
  return v
}

/** 创建连 Sepolia 的只读客户端：查余额、估 gas、发 raw tx 等 */
function publicClient() {
  const url = requireEnv('SEPOLIA_RPC_URL')
  return createPublicClient({
    chain: sepolia,
    transport: http(url),
  })
}

/** 创建带私钥的 Wallet 客户端：只负责签名（广播仍用 publicClient.sendRawTransaction） */
function walletClientFromPrivateKey(privateKey: `0x${string}`) {
  const account = privateKeyToAccount(privateKey)
  const url = requireEnv('SEPOLIA_RPC_URL')
  return {
    account,
    client: createWalletClient({
      account,
      chain: sepolia,
      transport: http(url),
    }),
  }
}

/** 子命令：打印一把新私钥，提醒用户自行写入 .env 的 CLI_PRIVATE_KEY */
async function cmdGenKey() {
  const pk = generatePrivateKey()
  const account = privateKeyToAccount(pk)
  console.log('--- 新生成测试用私钥（请自行复制到项目根 .env）---')
  console.log(`CLI_PRIVATE_KEY=${pk}`)
  console.log(`对应地址: ${account.address}`)
  console.log('提示：仅用于测试网；不要把真实主网资金用的私钥写进脚本仓库。')
}

/** 子命令：查 Sepolia 上该地址的 ETH 与（若配置了）ERC20 余额 */
async function cmdBalance() {
  const pk = normalizePrivateKey(process.env.CLI_PRIVATE_KEY)
  const { account } = walletClientFromPrivateKey(pk)
  const client = publicClient()

  const ethWei = await client.getBalance({ address: account.address })
  console.log(`地址: ${account.address}`)
  console.log(`ETH 余额: ${formatUnits(ethWei, 18)} ETH`)

  const token = process.env.SEPOLIA_ERC20?.trim()
  if (!token) {
    console.log('未设置 SEPOLIA_ERC20：跳过 ERC20 余额。需要时请在 .env 填代币合约地址。')
    return
  }

  const decimals = await client.readContract({
    address: token as `0x${string}`,
    abi: erc20Abi,
    functionName: 'decimals',
  })
  const bal = await client.readContract({
    address: token as `0x${string}`,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: [account.address],
  })
  console.log(`ERC20 (${token}) 余额: ${formatUnits(bal, decimals)} （decimals=${decimals}）`)
}

/**
 * 子命令：对 ERC20 transfer 走完整 EIP-1559 流程：
 * 组装字段 → signTransaction → sendRawTransaction → 等收据
 */
async function cmdSendErc20(to: `0x${string}`, amountHuman: string) {
  const pk = normalizePrivateKey(process.env.CLI_PRIVATE_KEY)
  const token = requireEnv('SEPOLIA_ERC20') as `0x${string}`

  const { account, client: wallet } = walletClientFromPrivateKey(pk)
  const client = publicClient()

  const decimals = await client.readContract({
    address: token,
    abi: erc20Abi,
    functionName: 'decimals',
  })
  const amountWei = parseUnits(amountHuman, decimals)

  const data = encodeFunctionData({
    abi: erc20Abi,
    functionName: 'transfer',
    args: [to, amountWei],
  })

  const nonce = await client.getTransactionCount({
    address: account.address,
    blockTag: 'pending',
  })

  const gas = await client.estimateGas({
    account,
    to: token,
    data,
    value: 0n,
  })

  const fees = await client.estimateFeesPerGas()
  if (!fees.maxFeePerGas || !fees.maxPriorityFeePerGas) {
    throw new Error('estimateFeesPerGas 未返回 EIP-1559 字段，请检查 RPC / 网络。')
  }

  const tx = {
    chain: sepolia,
    account,
    type: 'eip1559' as const,
    to: token,
    data,
    value: 0n,
    gas,
    nonce,
    maxFeePerGas: fees.maxFeePerGas,
    maxPriorityFeePerGas: fees.maxPriorityFeePerGas,
  }

  console.log('--- 交易参数（EIP-1559 + ERC20 transfer）---')
  console.log(JSON.stringify({ ...tx, data: `${data.slice(0, 18)}...` }, (_, v) => (typeof v === 'bigint' ? v.toString() : v), 2))

  const serializedTransaction = await wallet.signTransaction(tx)
  console.log('已签名，正在广播到 Sepolia…')

  const hash = await client.sendRawTransaction({ serializedTransaction })
  console.log(`交易哈希: ${hash}`)

  const receipt = await client.waitForTransactionReceipt({ hash })
  console.log(`已上链，状态: ${receipt.status}，区块: ${receipt.blockNumber}`)
}

/** 简单校验地址字符串是否是 0x + 40 位十六进制 */
function parseAddress(a: string): `0x${string}` {
  if (!/^0x[a-fA-F0-9]{40}$/.test(a)) {
    throw new Error(`地址格式不正确: ${a}`)
  }
  return a as `0x${string}`
}

async function main() {
  const [, , cmd, ...rest] = process.argv

  if (!cmd || cmd === 'help' || cmd === '-h') {
    console.log(`命令:
  gen-key                          生成新私钥（自行写入 .env）
  balance                          查 ETH +（可选）ERC20 余额
  send-erc20 <to> <amount>         EIP-1559 签名并发送 ERC20 转账`)
    process.exit(0)
  }

  if (cmd === 'gen-key') {
    await cmdGenKey()
    return
  }
  if (cmd === 'balance') {
    await cmdBalance()
    return
  }
  if (cmd === 'send-erc20') {
    const [toRaw, amount] = rest
    if (!toRaw || !amount) {
      throw new Error('用法: send-erc20 <收款地址> <数量>')
    }
    await cmdSendErc20(parseAddress(toRaw), amount)
    return
  }

  throw new Error(`未知命令: ${cmd}，使用 wallet-cli.ts help 查看说明。`)
}

main().catch((e) => {
  console.error(e instanceof Error ? e.message : e)
  process.exit(1)
})
