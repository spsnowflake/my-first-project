#!/usr/bin/env bash
# 一键：启动 Anvil（本地链）→ 编译 → 部署 ERC20 / ERC721 / NFTMarket
# 用法：
#   ./scripts/start-local.sh           只起链 + 部署（与 backend 里固定地址一致）
#   ./scripts/start-local.sh --with-fe  额外后台启动 frontend（npm run dev）
#
# 要求：8545 未被占用（否则请先关掉旧的 anvil / 其他节点）。
# 启动命令：npm run local。只启动 anvil 本地链，erc20/721/market，前后端不启动，需要手动启动。
#
# 地址约定（关机/重启后再跑本脚本即可复现，无需改代码）：
#   使用 Anvil 默认私钥对应账户 0xf39F…，在**空链**上连续 3 次 forge create，CREATE 地址 = nonce 0/1/2，
#   与 backend/index.ts 中 ERC20 / ERC721 / NFTMARKET 写死地址一致。
#   若 8545 上已有旧链或其它交易打乱 nonce，部署会失败校验，请先 killall anvil 再执行。

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

WITH_FE=false
for arg in "$@"; do
  if [[ "$arg" == "--with-fe" ]]; then WITH_FE=true; fi
done

if ! command -v anvil >/dev/null 2>&1; then
  echo "未找到 anvil，请先安装 Foundry: https://book.getfoundry.sh/getting-started/installation"
  exit 1
fi
if ! command -v forge >/dev/null 2>&1; then
  echo "未找到 forge，请先安装 Foundry。"
  exit 1
fi

if curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","id":1}' \
  http://127.0.0.1:8545 >/dev/null 2>&1; then
  echo "错误: http://127.0.0.1:8545 已有节点在跑。请先结束该进程再执行本脚本，否则部署地址会与 backend 不一致。"
  exit 1
fi

echo ">>> 启动 Anvil（后台）…"
anvil > /tmp/my-first-project-anvil.log 2>&1 &
ANVIL_PID=$!
echo "    PID=$ANVIL_PID 日志: /tmp/my-first-project-anvil.log"

for _ in $(seq 1 50); do
  if curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_chainId","id":1}' \
    http://127.0.0.1:8545 >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

cleanup_fe() {
  kill "$ANVIL_PID" 2>/dev/null || true
  if [[ -n "${FE_PID:-}" ]]; then kill "$FE_PID" 2>/dev/null || true; fi
}

ANVIL_PK=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
RPC_URL=http://127.0.0.1:8545

echo ">>> forge build …"
forge build --quiet

echo ">>> 部署合约（forge create ×3，与 backend/index.ts 写死地址一致）…"
# forge 行为因版本而异：可能输出 JSON、多行 JSON，或仅人类可读（Deployed to: 0x…）；stderr 也可能有内容
deployed_to() {
  node -e "$(cat <<'NODE'
const fs = require('fs');
const text = fs.readFileSync(0, 'utf8');
const start = text.indexOf('{');
const end = text.lastIndexOf('}');
if (start !== -1 && end > start) {
  try {
    const j = JSON.parse(text.slice(start, end + 1));
    if (j.deployedTo) {
      process.stdout.write(j.deployedTo);
      process.exit(0);
    }
  } catch (_) {}
}
const human = text.match(/^Deployed to:\s*(0x[a-fA-F0-9]{40})\b/m);
if (human) {
  process.stdout.write(human[1]);
  process.exit(0);
}
console.error('未能解析合约地址（既无 JSON deployedTo 也无 Deployed to: 行），前 800 字:\n' + text.slice(0, 800));
process.exit(1);
NODE
)"
}

ERC20_ADDR="$(
  forge create src/ERC20.sol:BaseERC20 \
    --rpc-url "$RPC_URL" \
    --private-key "$ANVIL_PK" \
    --broadcast \
    --json 2>&1 | deployed_to
)"
ERC721_ADDR="$(
  forge create src/ERC721.sol:BaseERC721 \
    --rpc-url "$RPC_URL" \
    --private-key "$ANVIL_PK" \
    --broadcast \
    --constructor-args "BaseERC721" "BERC721" "ipfs://base/" \
    --json 2>&1 | deployed_to
)"
MARKET_ADDR="$(
  forge create src/NFTMarket.sol:NFTMarket \
    --rpc-url "$RPC_URL" \
    --private-key "$ANVIL_PK" \
    --broadcast \
    --constructor-args "$ERC20_ADDR" "$ERC721_ADDR" \
    --json 2>&1 | deployed_to
)"

# 与 backend/index.ts 一致须为下列地址（cast compute-address 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --nonce N）
EXPECT_ERC20=0x5FbDB2315678afecb367f032d93F642f64180aa3
EXPECT_ERC721=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
EXPECT_MARKET=0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
if [[ "$(lc "$ERC20_ADDR")" != "$(lc "$EXPECT_ERC20")" ]] ||
   [[ "$(lc "$ERC721_ADDR")" != "$(lc "$EXPECT_ERC721")" ]] ||
   [[ "$(lc "$MARKET_ADDR")" != "$(lc "$EXPECT_MARKET")" ]]; then
  echo ""
  echo "错误: 部署地址与 backend 预期不一致（需要空链且仅本脚本三次 create）。"
  echo "  得到  ERC20=$ERC20_ADDR  ERC721=$ERC721_ADDR  Market=$MARKET_ADDR"
  echo "  预期  ERC20=$EXPECT_ERC20  ERC721=$EXPECT_ERC721  Market=$EXPECT_MARKET"
  echo "请先结束占用 8545 的节点后重试: killall anvil"
  kill "$ANVIL_PID" 2>/dev/null || true
  exit 1
fi

echo ""
echo "链与合约已就绪:"
echo "  ERC20      $ERC20_ADDR"
echo "  ERC721     $ERC721_ADDR"
echo "  NFTMarket  $MARKET_ADDR"
echo ""
echo "frontend/.env 中 VITE_NFT_MARKET_ADDRESS 应为 $EXPECT_MARKET（与 backend 一致）。"
echo ""
echo "另开终端可运行:"
echo "  cd backend && npm run start|listen|market-demo"
echo ""

if [[ "$WITH_FE" == true ]]; then
  trap cleanup_fe INT TERM
  if [[ ! -d frontend/node_modules ]]; then
    echo ">>> 安装 frontend 依赖…"
    (cd frontend && npm install)
  fi
  echo ">>> 启动 Vite（后台）…"
  (cd frontend && npm run dev) &
  FE_PID=$!
  echo "    前端 PID=$FE_PID  默认 http://localhost:5173"
  echo "按 Ctrl+C 结束 Anvil 与前端。"
  wait "$FE_PID"
else
  echo "Anvil 仍在后台运行 (PID=$ANVIL_PID)。若要停止: kill $ANVIL_PID"
fi
