// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "../lib/forge-std/src/Test.sol";
import {MemeV2} from "../src/MemeV2.sol";
import {MemeFactoryContractV2} from "../src/MemeFactoryContractV2.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {LaunchPadTWAP} from "../src/LaunchPadTWAP.sol";
import {console2} from "../lib/forge-std/src/console2.sol";

contract LaunchPadTwapTest is Test {
    address internal constant SEPOLIA_UNISWAP_FACTORY = 0xF62c03E08ada871A0bEb309762E260a7a6a880E6;
    address internal constant SEPOLIA_UNISWAP_ROUTER = 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3;
    uint256 internal constant SEPOLIA_FORK_BLOCK = 11254460;

    MemeFactoryContractV2 public memeFactoryContract;
    IUniswapV2Router02 public router;
    MemeV2 public memeToken;

    // 因为是fork 测试网，所以需要手动通过私钥创建地址，不然创建的地址会是合约地址
    uint256 user1Key = 0xA11CE;
    uint256 user2Key = 0xA21CE;
    uint256 sellerKey = 0xA31CE;
    uint256 seller2Key = 0xA41CE;
    uint256 buyerKey = 0xA51CE;
    uint256 buyer2Key = 0xA61CE;
    address user1 = vm.addr(user1Key);
    address user2 = vm.addr(user2Key);
    address seller = vm.addr(sellerKey);
    address seller2 = vm.addr(seller2Key);
    address buyer = vm.addr(buyerKey);
    address buyer2 = vm.addr(buyer2Key);

    function setUp() public {
        vm.createSelectFork("sepolia", SEPOLIA_FORK_BLOCK);
        router = IUniswapV2Router02(SEPOLIA_UNISWAP_ROUTER);
        memeFactoryContract = new MemeFactoryContractV2(SEPOLIA_UNISWAP_ROUTER);

        vm.deal(user1, 1000 ether);
        vm.deal(user2, 1000 ether);
        vm.deal(seller, 1000 ether);
        vm.deal(seller2, 1000 ether);
        vm.deal(buyer, 1000 ether);
        vm.deal(buyer2, 1000 ether);
    }

    function test_twap() public {
        vm.startPrank(user1);

        address tokenAddr = memeFactoryContract.deployMeme("Meme", "Meme", 10000e18, 100e18, 1 ether);
        memeToken = MemeV2(tokenAddr);

        vm.stopPrank();

        vm.startPrank(buyer);
        memeFactoryContract.mintMeme{value: 100 ether}(tokenAddr);
        // 必须铸造一次后，才能创建TWAP
        LaunchPadTWAP twap = new LaunchPadTWAP(memeFactoryContract, address(memeToken));
        vm.warp(block.timestamp + 13 hours);
        twap.update();
        // 5 token : 5 ETH  = 1 ETH/token 
        assertEq(twap.getTwapPrice(), 1 ether);

// 未满PERIOD时间，再次update应revert
        vm.expectRevert("timeElapsed < PERIOD");
        twap.update();

        memeFactoryContract.mintMeme{value: 100 ether}(tokenAddr);
        vm.warp(block.timestamp + 12 hours + 12 hours);
        twap.update();
        // 10 token : 10 ETH  = 1 ETH/token 
        assertEq(twap.getTwapPrice(), 1 ether);
        vm.stopPrank();

        // 打低池子价格

        vm.prank(seller);
        memeFactoryContract.mintMeme{value: 100 ether}(tokenAddr);

        address[] memory sellPath = new address[](2);
        sellPath[0] = tokenAddr;
        sellPath[1] = router.WETH();

        vm.startPrank(seller);
        memeToken.approve(address(router), 100e18);
        router.swapExactTokensForETH(100e18, 0, sellPath, seller, block.timestamp + 600);
        vm.warp(block.timestamp + 12 hours + 12 hours + 13 hours);
        twap.update();
        // 大量卖出后，此时应该小于 1 ETH/token
        assertLt(twap.getTwapPrice(), 1 ether);
        vm.stopPrank();

        uint256 priceLow = _spotPrice(tokenAddr);

        // 低价维持 12h
        vm.warp(block.timestamp + 12 hours + 12 hours + 13 hours + 12 hours);


        // 买入抬价
        vm.prank(buyer);
        memeFactoryContract.buyMeme{value: 50 ether}(tokenAddr, 1e18);
        uint256 priceMid = _spotPrice(tokenAddr);

        // 中价再维持 12h，然后 update：窗口 = 12h low + 12h mid
        vm.warp(block.timestamp + 12 hours + 12 hours + 13 hours + 12 hours + 12 hours);

        uint256 twapPrice = twap.update();
        uint256 expected = (priceLow * 12 hours + priceMid * 12 hours) / (12 hours + 12 hours);

        // 与手算加权平均对比（允许误差）
        assertApproxEqAbs(twapPrice, expected, 1e14);
        // TWAP 应落在两段价格之间
        assertGt(twapPrice, priceLow);
        assertLt(twapPrice, priceMid);


    }



    /// @dev 当前池子价（ETH/token），与 TWAP 同源：ethReserve / tokenReserve，不含 0.3% 手续费
    function _spotPrice(address tokenAddr) internal view returns (uint256) {
        (uint256 tokenReserve, uint256 ethReserve) = memeFactoryContract.getPoolTokenReserve(tokenAddr);
        return ethReserve * 1e18 / tokenReserve;
    }
}
