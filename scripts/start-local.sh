#!/usr/bin/env bash
# 一键：启动 Anvil（本地链）→ 编译 → 部署 ERC20 / ERC721 / NFTMarket
# 用法：
#   ./scripts/start-local.sh           只起链 + 部署（与 backend 里固定地址一致）
#   ./scripts/start-local.sh --with-fe  额外后台启动 frontend（npm run dev）
#
# 要求：8545 未被占用（否则请先关掉旧的 anvil / 其他节点）。
# 启动命令：npm run local。只启动 anvil 本地链，erc20/721/market，前后端不启动，需要手动启动。

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
deployed_to() {
  node -e "process.stdout.write(JSON.parse(require('fs').readFileSync(0,'utf8')).deployedTo)"
}

ERC20_ADDR="$(
  forge create src/ERC20.sol:BaseERC20 \
    --rpc-url "$RPC_URL" \
    --private-key "$ANVIL_PK" \
    --broadcast \
    --json 2>/dev/null | deployed_to
)"
ERC721_ADDR="$(
  forge create src/ERC721.sol:BaseERC721 \
    --rpc-url "$RPC_URL" \
    --private-key "$ANVIL_PK" \
    --broadcast \
    --constructor-args "BaseERC721" "BERC721" "ipfs://base/" \
    --json 2>/dev/null | deployed_to
)"
MARKET_ADDR="$(
  forge create src/NFTMarket.sol:NFTMarket \
    --rpc-url "$RPC_URL" \
    --private-key "$ANVIL_PK" \
    --broadcast \
    --constructor-args "$ERC20_ADDR" "$ERC721_ADDR" \
    --json 2>/dev/null | deployed_to
)"

echo ""
echo "链与合约已就绪:"
echo "  ERC20      $ERC20_ADDR"
echo "  ERC721     $ERC721_ADDR"
echo "  NFTMarket  $MARKET_ADDR"
echo ""
echo "请确认 frontend/.env 中 VITE_NFT_MARKET_ADDRESS=$MARKET_ADDR（与 backend 一致时可不改）。"
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
