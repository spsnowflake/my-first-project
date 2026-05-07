/**
 * 本文件是「后端」脚本：在 Node.js 里跑，用 viem 连区块链（和浏览器里的前端不是一回事）。
 *
 * 常见名词：
 * - import：从别的包/文件「拉进来」工具或数据。
 * - const：定义一个不会重新赋值的变量（地址、配置常用 const）。
 * - async/await：异步流程；await 表示「等链上结果返回再继续」。
 * - export：把函数或变量暴露出去，给别的 .ts 文件 import 使用。
 */

// viem：和链交互的库。public = 只读；wallet = 需要私钥签名的写入。
import {
  createPublicClient,
  createWalletClient,
  decodeEventLog,
  formatUnits,
  getContract,
  http,
  parseUnits,
} from 'viem'
// 把「私钥字符串」转成账户对象，供 wallet 使用
import { privateKeyToAccount } from 'viem/accounts'
// Foundry/Anvil 本地链配置（链 ID 31337 等）
import { foundry } from 'viem/chains'
import type { Abi } from 'viem'

// 从 JSON 读入合约 ABI（告诉程序：合约有哪些函数、参数类型）
import ERC20_ABI from './ERC20.json' with { type: 'json' }
import ERC721_ABI from './ERC721.json' with { type: 'json' }
import NFTMARKET_ABI from './NFTMarket.json' with { type: 'json' }

// `as Abi`：告诉 TypeScript 把 JSON 当成 viem 认识的 ABI 类型
const erc20Abi = ERC20_ABI as Abi
const erc721Abi = ERC721_ABI as Abi
const nftMarketAbi = NFTMARKET_ABI as Abi

/** 代币 ERC20 合约部署在链上的地址 */
const ERC20_ADDRESS = '0x5FbDB2315678afecb367f032d93F642f64180aa3' as `0x${string}`

/** NFT（ERC721）合约地址 */
const ERC721_ADDRESS = '0x5FC8d32690cc91D4c39d9d3abcBD16989F875707' as `0x${string}`

/** NFT 市场合约地址：721 授权里的「被授权方」也是它 */
const NFTMARKET_ADDRESS =
  '0x0165878A594ca255338adfa4d48449f69242Eb8F' as `0x${string}`

/**
 * 示例里要查 ERC20 余额的钱包地址。
 * `0x${string}`：TypeScript 写法，表示「必须是 0x 开头的地址字符串」。
 */
const USER_ADDRESS =
  '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266' as `0x${string}`

/** 节点 RPC：Anvil 默认端口 8545 */
const RPC_URL = 'http://127.0.0.1:8545'

/** 本地测试用默认私钥；正式环境请用环境变量 PRIVATE_KEY，勿提交真私钥 */
const DEFAULT_ANVIL_PRIVATE_KEY =
  '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80' as const

/**
 * 公共客户端：只读链上数据（balance、decimals、事件日志等），不需要私钥。
 */
const publicClient = createPublicClient({
  chain: foundry,
  transport: http(RPC_URL),
})

/**
 * ERC20 合约封装：只有 public，所以只能 .read.xxx，不能 .write。
 */
const erc20Contract = getContract({
  address: ERC20_ADDRESS,
  abi: erc20Abi,
  client: {
    public: publicClient,
  },
})

/**
 * NFTMarket 只读实例：例如读 tokenPrice、后面 watchContractEvent 监听 List/BuyNFT。
 */
const nftMarketContract = getContract({
  address: NFTMARKET_ADDRESS,
  abi: nftMarketAbi,
  client: {
    public: publicClient,
  },
})

/**
 * 根据私钥创建「钱包客户端」：用来发交易（write），会消耗 gas。
 * process.env.PRIVATE_KEY：从环境变量读私钥；没设就用上面 Anvil 默认钥。
 */
function getWalletClient() {
  const pk = (process.env.PRIVATE_KEY ??
    DEFAULT_ANVIL_PRIVATE_KEY) as `0x${string}`
  const account = privateKeyToAccount(pk)
  return createWalletClient({
    account,
    chain: foundry,
    transport: http(RPC_URL),
  })
}

/**
 * 返回带钱包的 NFTMarket 实例：可同时 .read 和 .write。
 * 上架示例：await m.write.list([tokenId, 价格wei], { account })
 */
export function getNftMarketContractWithWallet() {
  const walletClient = getWalletClient()
  return getContract({
    address: NFTMARKET_ADDRESS,
    abi: nftMarketAbi,
    client: {
      public: publicClient,
      wallet: walletClient,
    },
  })
}

/**
 * 供其他文件复用：监听脚本可 import 这些，避免重复写地址/ABI。
 * export { A, B }：把本文件里已有的名字批量导出。
 */
export { nftMarketContract, nftMarketAbi, NFTMARKET_ADDRESS, publicClient }

/**
 * 在 ERC721 上调用 setApprovalForAll(市场地址, true)，
 * 允许 NFTMarket 合约转移你持有的 NFT（上架/成交需要）。
 */
export async function approveNftMarketForAll(): Promise<void> {
  const walletClient = getWalletClient()
  const account = walletClient.account

  const erc721Contract = getContract({
    address: ERC721_ADDRESS,
    abi: erc721Abi,
    client: {
      public: publicClient,
      wallet: walletClient,
    },
  })

  // write 发交易；返回 hash，再等链上收据 receipt
  const hash = await erc721Contract.write.setApprovalForAll(
    [NFTMARKET_ADDRESS, true],
    { account },
  )

  const receipt = await publicClient.waitForTransactionReceipt({ hash })
  console.log(
    `setApprovalForAll(operator=${NFTMARKET_ADDRESS}, approved=true)\n` +
      `tx: ${hash}\n` +
      `status: ${receipt.status}`,
  )
}

/** 演示上架用的 tokenId（Anvil 默认账户 mint） */
const DEMO_LIST_TOKEN_ID = 1n
/** 上架标价：1 * 10^18（与 ERC20 decimals 一致；按你代币精度改） */
const DEMO_LIST_PRICE = parseUnits('1', 18)

/** 控制台打印 ERC20 可读数额时用（与 BaseERC20/MyToken 一致可改为读链上 decimals） */
const ERC20_DECIMALS_FOR_LOG = 18

/**
 * 作业要求：代码里先写「上架」逻辑（再写监听函数）。
 * 用当前私钥：必要时 mint NFT → 授权市场 → market.list。
 */
export async function executeMarketList(): Promise<void> {
  const walletClient = getWalletClient()
  const account = walletClient.account

  const erc721Write = getContract({
    address: ERC721_ADDRESS,
    abi: erc721Abi,
    client: {
      public: publicClient,
      wallet: walletClient,
    },
  })

  const marketWrite = getNftMarketContractWithWallet()

  let minted = false
  try {
    await publicClient.readContract({
      address: ERC721_ADDRESS,
      abi: erc721Abi,
      functionName: 'ownerOf',
      args: [DEMO_LIST_TOKEN_ID],
    })
  } catch {
    const mintHash = await erc721Write.write.mint(
      [account.address, DEMO_LIST_TOKEN_ID],
      { account },
    )
    await publicClient.waitForTransactionReceipt({ hash: mintHash })
    minted = true
    console.log(
      `[上架] 已 mint tokenId=${DEMO_LIST_TOKEN_ID} tx=${mintHash}`,
    )
  }

  if (!minted) {
    console.log(
      `[上架] tokenId=${DEMO_LIST_TOKEN_ID} 已存在，跳过 mint`,
    )
  }

  const approveHash = await erc721Write.write.setApprovalForAll(
    [NFTMARKET_ADDRESS, true],
    { account },
  )
  await publicClient.waitForTransactionReceipt({ hash: approveHash })
  console.log(`[上架] setApprovalForAll tx=${approveHash}`)

  const listHash = await marketWrite.write.list(
    [DEMO_LIST_TOKEN_ID, DEMO_LIST_PRICE],
    { account },
  )
  await publicClient.waitForTransactionReceipt({ hash: listHash })
  console.log(`[上架] list(${DEMO_LIST_TOKEN_ID}, ${DEMO_LIST_PRICE}) tx=${listHash}`)
}

/**
 * 监听「上架」事件 List（list 函数 emit）
 */
export function watchListEvent(onLog?: (line: string) => void): () => void {
  const out = onLog ?? ((s: string) => console.log(s))
  return publicClient.watchContractEvent({
    address: NFTMARKET_ADDRESS,
    abi: nftMarketAbi,
    eventName: 'List',
    onLogs(logs) {
      for (const log of logs) {
        const d = decodeEventLog({
          abi: nftMarketAbi,
          data: log.data,
          topics: log.topics,
        })
        if (d.eventName !== 'List') continue
        const args = d.args as unknown as {
          tokenId: bigint
          sellPeople: `0x${string}`
          amount: bigint
        }
        const priceHuman = formatUnits(args.amount, ERC20_DECIMALS_FOR_LOG)
        out(
          [
            '========== [监听 · 上架 List] ==========',
            `  tokenId     : ${args.tokenId.toString()}`,
            `  卖家        : ${args.sellPeople}`,
            `  标价(wei)   : ${args.amount.toString()}`,
            `  标价(可读)  : ${priceHuman} (decimals=${ERC20_DECIMALS_FOR_LOG})`,
            `  tx          : ${log.transactionHash}`,
            `  block       : ${log.blockNumber?.toString() ?? '?'}`,
            '========================================',
          ].join('\n'),
        )
      }
    },
  })
}

/**
 * 监听 buyNFT() 与 tokensReceived() **都会**发出的 BuyNFT 事件。
 * 单靠本事件无法区分是哪一种成交方式；请配合 watchTokensReceivedPurchaseEvent。
 */
export function watchBuyNftEvent(onLog?: (line: string) => void): () => void {
  const out = onLog ?? ((s: string) => console.log(s))
  return publicClient.watchContractEvent({
    address: NFTMARKET_ADDRESS,
    abi: nftMarketAbi,
    eventName: 'BuyNFT',
    onLogs(logs) {
      for (const log of logs) {
        const d = decodeEventLog({
          abi: nftMarketAbi,
          data: log.data,
          topics: log.topics,
        })
        if (d.eventName !== 'BuyNFT') continue
        const args = d.args as unknown as {
          buyer: `0x${string}`
          tokenID: bigint
          amount: bigint
        }
        const payHuman = formatUnits(args.amount, ERC20_DECIMALS_FOR_LOG)
        out(
          [
            '========== [监听 · 买卖 BuyNFT 事件] ==========',
            '  说明: 合约函数 buyNFT() 成交时 emit；tokensReceived() 成交时也会 emit 同一事件。',
            `  买家 buyer   : ${args.buyer}`,
            `  tokenID     : ${args.tokenID.toString()}`,
            `  支付(wei)    : ${args.amount.toString()}`,
            `  支付(可读)   : ${payHuman}`,
            `  tx          : ${log.transactionHash}`,
            `  block       : ${log.blockNumber?.toString() ?? '?'}`,
            '  （若同一 tx 还出现下方「tokensReceived 回调」日志，则本次为 ERC20 回调路径）',
            '==============================================',
          ].join('\n'),
        )
      }
    },
  })
}

/**
 * 仅监听 tokensReceived() 路径：合约额外 emit PurchaseViaERC20Callback。
 * 未走回调的 buyNFT() 成交**不会**出现本条日志。
 */
export function watchTokensReceivedPurchaseEvent(
  onLog?: (line: string) => void,
): () => void {
  const out = onLog ?? ((s: string) => console.log(s))
  return publicClient.watchContractEvent({
    address: NFTMARKET_ADDRESS,
    abi: nftMarketAbi,
    eventName: 'PurchaseViaERC20Callback',
    onLogs(logs) {
      for (const log of logs) {
        const d = decodeEventLog({
          abi: nftMarketAbi,
          data: log.data,
          topics: log.topics,
        })
        if (d.eventName !== 'PurchaseViaERC20Callback') continue
        const args = d.args as unknown as {
          buyer: `0x${string}`
          tokenId: bigint
          amount: bigint
        }
        const payHuman = formatUnits(args.amount, ERC20_DECIMALS_FOR_LOG)
        out(
          [
            '========== [监听 · tokensReceived 回调成交] ==========',
            '  说明: 仅当买家通过 ERC20 的 tokensReceived 回调完成购买时出现。',
            `  买家 buyer   : ${args.buyer}`,
            `  tokenId     : ${args.tokenId.toString()}`,
            `  转入金额(wei): ${args.amount.toString()}`,
            `  金额(可读)   : ${payHuman}`,
            `  tx          : ${log.transactionHash}`,
            `  block       : ${log.blockNumber?.toString() ?? '?'}`,
            '====================================================',
          ].join('\n'),
        )
      }
    },
  })
}

/**
 * 同时注册：List、BuyNFT、PurchaseViaERC20Callback（作业：上架 + 两种买卖相关事件）
 */
export function startNftMarketEventWatchers(): () => void {
  const unwatchFns: (() => void)[] = []
  unwatchFns.push(watchListEvent())
  unwatchFns.push(watchBuyNftEvent())
  unwatchFns.push(watchTokensReceivedPurchaseEvent())
  return () => {
    for (const u of unwatchFns) u()
  }
}

/** 只挂监听、不上架；便于你在别处发起 buyNFT / transferWithCallback 后看日志 */
export async function runMarketListenOnly(): Promise<void> {
  console.log(
    '[listen] 已监听：List / BuyNFT / PurchaseViaERC20Callback。发起购买后看控制台，Ctrl+C 退出。',
  )
  startNftMarketEventWatchers()
  await new Promise<void>(() => {})
}

/**
 * 先注册监听，再发上架交易，这样能在控制台看到 List 日志。
 * （若先 list 再 watch，会错过同一块里刚发出的上架事件。）
 */
export async function runMarketDemo(): Promise<void> {
  console.log(
    '[market-demo] 已注册事件监听，接下来发送 list …（Ctrl+C 退出）\n' +
      '提示：请先启动 Anvil；若刚改过 NFTMarket.sol，请重新部署并更新 NFTMARKET_ADDRESS。',
  )
  startNftMarketEventWatchers()
  await executeMarketList()
  console.log('[market-demo] 上架交易已确认。持续监听买卖事件…')
  await new Promise<void>(() => {})
}

/**
 * 脚本入口：直接 `npm run start` 时执行。
 * process.argv：命令行参数数组；argv[2] === 'approve' 表示 `tsx index.ts approve`。
 */
async function main() {
  if (process.argv[2] === 'approve') {
    await approveNftMarketForAll()
    return
  }

  if (process.argv[2] === 'market-demo') {
    await runMarketDemo()
    return
  }

  if (process.argv[2] === 'listen') {
    await runMarketListenOnly()
    return
  }

  // 默认行为：读 ERC20 余额并打印（链上只读，不发交易）
  const rawBalance = (await erc20Contract.read.balanceOf([USER_ADDRESS])) as bigint
  const decimals = Number(
    (await erc20Contract.read.decimals()) as number | bigint,
  )
  const symbol = (await erc20Contract.read.symbol()) as string

  const human = formatUnits(rawBalance, decimals)
  console.log(
    `ERC20 合约: ${ERC20_ADDRESS}\n` +
      `账户: ${USER_ADDRESS}\n` +
      `余额(最小单位): ${rawBalance.toString()}\n` +
      `余额(可读): ${human} ${symbol}`,
  )
}

// 运行 main；若出错则打印错误（catch）
main().catch((err) => {
  console.error(err)
})
