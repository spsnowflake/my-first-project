// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "../lib/forge-std/src/Test.sol";
import {NFTMarket} from "../src/NFTMarket.sol";
import {IERC20} from "src/IERC20Interface.sol";
import {IERC721} from "src/IERC721Interface.sol";
import {BaseERC20} from "src/ERC20.sol";
import {BaseERC721} from "src/ERC721.sol";

// Handler 会被 Foundry 随机调用其 external 函数，
// 用来模拟“多路径、长序列”的用户行为。
contract NFTMarketHandler is Test {
    NFTMarket internal market;
    BaseERC20 internal erc20;
    BaseERC721 internal erc721;

    address internal sellerA;
    address internal sellerB;
    address internal buyerA;
    address internal buyerB;

    // nextTokenId: 每次上架前自增，保证 mint 的 tokenId 唯一
    uint256 internal nextTokenId;
    // 记录“当前仍可能可买”的 tokenId，供 buy() 随机挑选
    uint256[] internal listedTokenIds;

    constructor(
        NFTMarket _market,
        BaseERC20 _erc20,
        BaseERC721 _erc721,
        address _sellerA,
        address _sellerB,
        address _buyerA,
        address _buyerB
    ) {
        market = _market;
        erc20 = _erc20;
        erc721 = _erc721;
        sellerA = _sellerA;
        sellerB = _sellerB;
        buyerA = _buyerA;
        buyerB = _buyerB;
    }

    // 随机上架：
    // - rawPrice 由 fuzzer 生成，再 bound 到 [1e18, 10_000e18]
    // - sellerSeed 决定是 sellerA 还是 sellerB 发起
    function list(uint96 rawPrice, uint8 sellerSeed) external {
        address seller = (sellerSeed % 2 == 0) ? sellerA : sellerB;
        uint256 price = bound(uint256(rawPrice), 1e18, 10_000e18);
        uint256 tokenId = ++nextTokenId;

        vm.startPrank(seller);
        erc721.mint(seller, tokenId);
        erc721.approve(address(market), tokenId);
        // 用 try/catch 防止某次随机调用 revert 后中断整轮 invariant 测试
        try market.list(tokenId, price) returns (bool ok) {
            if (ok) {
                listedTokenIds.push(tokenId);
            }
        } catch {}
        vm.stopPrank();
    }

    // 随机购买：
    // - indexSeed 决定从 listedTokenIds 里挑哪一个
    // - buyerSeed 决定 buyerA / buyerB
    function buy(uint8 buyerSeed, uint256 indexSeed) external {
        // 没有可选标的时直接返回，避免无意义操作
        if (listedTokenIds.length == 0) return;

        uint256 pick = indexSeed % listedTokenIds.length;
        uint256 tokenId = listedTokenIds[pick];
        uint256 price = market.tokenPrice(tokenId);
        // 如果该 token 在 market 状态里已不在售，清理本地列表中的脏数据
        if (price == 0) {
            _removeListedAt(pick);
            return;
        }

        address seller = market.tokenSeller(tokenId);
        address buyer = (buyerSeed % 2 == 0) ? buyerA : buyerB;
        // 避免买家和卖家是同一地址，减少无效场景
        if (buyer == seller) {
            buyer = (buyer == buyerA) ? buyerB : buyerA;
        }

        vm.startPrank(buyer);
        // buyNFT 走 ERC20 transferFrom，因此先授权 market 花费 price
        erc20.approve(address(market), price);
        try market.buyNFT(tokenId, price) returns (bool ok) {
            if (ok) {
                // 成功成交后，从可售列表移除该 tokenId
                _removeListedAt(pick);
            }
        } catch {}
        vm.stopPrank();
    }

    // O(1) 删除数组下标：用末尾元素覆盖，再 pop
    function _removeListedAt(uint256 idx) internal {
        uint256 last = listedTokenIds.length - 1;
        if (idx != last) {
            listedTokenIds[idx] = listedTokenIds[last];
        }
        listedTokenIds.pop();
    }
}

contract NFTMarketInvariantTest is Test {
    NFTMarket internal market;
    BaseERC20 internal erc20;
    BaseERC721 internal erc721;
    NFTMarketHandler internal handler;

    address internal sellerA = makeAddr("sellerA");
    address internal sellerB = makeAddr("sellerB");
    address internal buyerA = makeAddr("buyerA");
    address internal buyerB = makeAddr("buyerB");

    function setUp() public {
        // 部署被测系统
        erc20 = new BaseERC20();
        erc721 = new BaseERC721("BaseERC721", "BERC721", "ipfs://base/");
        market = new NFTMarket(IERC20(address(erc20)), IERC721(address(erc721)));

        // 给买家和卖家都分配足够 ERC20，避免由于余额不足导致大面积无效调用。
        erc20.transfer(sellerA, 1_000_000e18);
        erc20.transfer(sellerB, 1_000_000e18);
        erc20.transfer(buyerA, 1_000_000e18);
        erc20.transfer(buyerB, 1_000_000e18);

        handler = new NFTMarketHandler(
            market,
            erc20,
            erc721,
            sellerA,
            sellerB,
            buyerA,
            buyerB
        );

        // 告诉 Foundry：随机调用入口来自 handler
        targetContract(address(handler));
    }

    // 不变量：无论随机执行多少次 list / buy，market 都不应持有 ERC20
    function invariant_marketNeverHoldsERC20() public view {
        assertEq(erc20.balanceOf(address(market)), 0);
    }
}
