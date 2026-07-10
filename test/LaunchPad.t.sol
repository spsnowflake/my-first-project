// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MemeV2} from "../src/MemeV2.sol";
import {MemeFactoryContractV2} from "../src/MemeFactoryContractV2.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

/// @dev Sepolia 官方 Uniswap V2 部署地址
/// https://developers.uniswap.org/docs/protocols/v2/deployments
contract LaunchPadTest is Test {
    address internal constant SEPOLIA_UNISWAP_FACTORY = 0xF62c03E08ada871A0bEb309762E260a7a6a880E6;
    address internal constant SEPOLIA_UNISWAP_ROUTER = 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3;
    uint256 internal constant SEPOLIA_FORK_BLOCK = 11149797;

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

    function test_memeFactoryContract() public {
        vm.startPrank(user1);
        // 非工厂addr调用mint，是否触发revert
        memeToken = new MemeV2();

        vm.expectRevert("Meme: only factory can mint");
        memeToken.mint(user1);

//    验证meme合约是否部署成功，参数是否初始化成功
        address tokenAddr = memeFactoryContract.deployMeme("Meme", "Meme", 10000e18, 100e18, 1 ether);
        memeToken = MemeV2(tokenAddr);

        assertEq("Meme", (MemeV2(tokenAddr).name()));
        assertEq("Meme", (MemeV2(tokenAddr).symbol()));
        assertEq(10000e18, (MemeV2(tokenAddr).totalSupplyLimit()));
        assertEq(100e18, (MemeV2(tokenAddr).perMintAmount()));
        assertEq(1 ether, (MemeV2(tokenAddr).mintPrice()));
        assertEq(user1, (MemeV2(tokenAddr).issuer()));
        assertEq(address(memeFactoryContract), (MemeV2(tokenAddr).factory()));
        vm.stopPrank();


// 2、测试一次铸造的数量是否正确，3、余额是否正确
        vm.startPrank(buyer);
        uint256 buyerBeforeBalance = buyer.balance;
        uint256 user1BeforeBalance = user1.balance;
        uint256 totalCost = 1 ether * 100e18 / 1e18; 
        uint256 unitFee = totalCost / 100;           // 单位：1%
        uint256 projectFee = unitFee * 5;           // 项目方：5%
        uint256 issuerFee  = totalCost - projectFee;    // 个人：95%
        memeFactoryContract.mintMeme{value: 105 ether}(tokenAddr);
        assertEq(100e18, MemeV2(tokenAddr).balanceOf(buyer));

        // 计算每次铸造价格对应的token数量，会转给工厂
        uint256 tokenAmount = projectFee*1e18 / memeToken.mintPrice();
        // 断言工厂的token数量是否正确(工厂的token数量拿到后立马放进了流动池)
        assertEq(0, MemeV2(tokenAddr).balanceOf(address(memeFactoryContract)));

        // 断言总发行量是否正确
        assertEq(100e18+tokenAmount, MemeV2(tokenAddr).totalSupply());


        // 断言买家余额是否正确，多了5eth，会退还给买家
        assertEq(buyer.balance, buyerBeforeBalance - 100 ether);
        // 断言发行者余额是否正确，拿到了95%的费用
        assertEq(user1.balance, user1BeforeBalance + issuerFee);
        vm.stopPrank();

// 断言池子中token和eth的储备量是否正确
        (uint256 tokenReserve, uint256 ethReserve) = memeFactoryContract.getPoolTokenReserve(tokenAddr);
        assertEq(tokenReserve, 5e18);
        assertEq(ethReserve, 5 ether);



//      计算从池子中购买 3e18 个 Token 需要支付的ETH数量
        {
        address[] memory path = new address[](2);
        path[0] = address(router.WETH());
        path[1] = tokenAddr;
        uint256[] memory amounts = router.getAmountsIn(3e18,path);
        uint256 uniswapAmountETH = amounts[0];

        // 根据公式计算出来如果需要买3个token，大概在 7.5ether 正负0.1 ether
        assertApproxEqAbs(uniswapAmountETH, 7.5 ether, 0.1 ether);

        vm.expectRevert("Amount token is greater than token reserve");
        memeFactoryContract.buyMeme{value: uniswapAmountETH}(tokenAddr, 10e18);

        vm.expectRevert("Uniswap price not better than mint price");
        memeFactoryContract.buyMeme{value: uniswapAmountETH}(tokenAddr, 3e18);
        }

        // 卖家铸造100个token，把池子价格打低，测试buymeme购买功能
        vm.prank(seller);
        memeFactoryContract.mintMeme{value: 100 ether}(tokenAddr);

        address[] memory sellPath = new address[](2);
        sellPath[0] = tokenAddr;
        sellPath[1] = router.WETH();   

        vm.startPrank(seller);
        memeToken.approve(address(router), 100e18);
        router.swapExactTokensForETH(
            100e18,
            0,             
            sellPath,
            seller,
            block.timestamp + 600
        );
        vm.stopPrank();

        uint256 buyAmount = 10e18;  // 买 10 个 token
        uint256 mintCost = 10 ether; // mint 价 1 ETH/token

        address[] memory buyPath = new address[](2);
        buyPath[0] = router.WETH();
        buyPath[1] = tokenAddr;

        uint256 uniCost = router.getAmountsIn(buyAmount, buyPath)[0];

        // 必须满足池子价格低于铸造价格
        assertLt(uniCost, mintCost);

        uint256 beforeToken = memeToken.balanceOf(buyer2);
        uint256 beforeEth   = buyer2.balance;

        vm.prank(buyer2);
        memeFactoryContract.buyMeme{value: 50 ether}(tokenAddr, buyAmount);

        assertEq(memeToken.balanceOf(buyer2), beforeToken + buyAmount); 

        // 多付了ETH，退还给买家
        assertEq(buyer2.balance, beforeEth - uniCost);

        // 断言 totalSupply 是否正确
        assertEq(memeToken.totalSupply(), 210e18);
    }

    function test_fork_usesOfficialSepoliaUniswap() public view {
        assertEq(address(memeFactoryContract.uniswapV2Router()), SEPOLIA_UNISWAP_ROUTER);
        assertEq(router.factory(), SEPOLIA_UNISWAP_FACTORY);
        assertTrue(router.WETH() != address(0));
    }
}
