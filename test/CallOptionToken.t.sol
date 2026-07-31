// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import  "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {CallOptionToken} from "../src/CallOptionToken.sol";
import {Test} from "forge-std/Test.sol";
import {MyToken} from "../src/MyToken.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract CallOptionTokenTest is Test {
    address internal constant SEPOLIA_UNISWAP_ROUTER = 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3;
    uint256 internal constant SEPOLIA_FORK_BLOCK = 11383580;

    CallOptionToken public callOptionToken;
    IUniswapV2Router02 public uniswapV2Router;
    IUniswapV2Factory public uniswapV2Factory;
    IUniswapV2Pair public uniswapV2Pair;
    MyToken public usdt;
    uint256 ownerKey = 0xA00CE;
    uint256 user1Key = 0xA11CE;
    uint256 user2Key = 0xA21CE;
    uint256 sellerKey = 0xA31CE;
    uint256 seller2Key = 0xA41CE;
    uint256 buyerKey = 0xA51CE;
    uint256 buyer2Key = 0xA61CE;
    address owner = vm.addr(ownerKey);
    address user1 = vm.addr(user1Key);
    address user2 = vm.addr(user2Key);
    address user3 = vm.addr(sellerKey);
    address user4 = vm.addr(seller2Key);
    address seller = vm.addr(buyerKey);
    address buyer = vm.addr(buyer2Key);

    function setUp() public {
        vm.startPrank(owner);
        vm.createSelectFork("sepolia", SEPOLIA_FORK_BLOCK);
        usdt = new MyToken("USDT", "USDT");
        uniswapV2Router = IUniswapV2Router02(SEPOLIA_UNISWAP_ROUTER);
        callOptionToken = new CallOptionToken(3000, address(usdt), address(uniswapV2Router));

        vm.deal(owner, 1000 ether);
        vm.deal(user1, 1000 ether);
        vm.deal(user2, 1000 ether);
        vm.deal(user3, 1000 ether);
        vm.deal(user4, 1000 ether);
        vm.deal(seller, 1000 ether);
        vm.deal(buyer, 1000 ether);

        usdt.approve(address(callOptionToken), 5000*1e18);
        usdt.transfer( user1, 100000*1e18);
        usdt.transfer( user2, 100000*1e18);
        usdt.transfer( user3, 100000*1e18);
        usdt.transfer( user4, 100000*1e18);
        usdt.transfer( seller, 100000*1e18);
        usdt.transfer( buyer, 100000*1e18);

        vm.stopPrank();

    }
    
// 测试过期销毁期权
    function test_burnOption() public{
        vm.startPrank(owner);
        vm.expectRevert("Not after expiry");
        callOptionToken.burnOption();

// 铸造
        callOptionToken.mint{value: 10 ether}(owner);
        assertEq(callOptionToken.balanceOf(owner), 10*1e18);

        assertEq(owner.balance, 990 ether);


        // owner给user1 2个期权
        callOptionToken.transfer(user1, 2*1e18);
        assertEq(callOptionToken.balanceOf(user1), 2*1e18);

        // owner给user2 2个期权
        callOptionToken.transfer(user2, 2*1e18);
        assertEq(callOptionToken.balanceOf(user2), 2*1e18);
        vm.stopPrank();

// user1到时间当天行权
        vm.startPrank(user1);

        vm.warp(block.timestamp + 365 days);
        usdt.approve(address(callOptionToken), 6000*1e18);
        uint beforeETHUser1 = address(user1).balance;
        callOptionToken.exerciseOption();
        assertEq(callOptionToken.balanceOf(user1), 0);
        uint afterETHUser1 = address(user1).balance;

        // user1赎回2eth
        assertEq(afterETHUser1 - beforeETHUser1,2 ether);
        vm.stopPrank();

        // user2不行权
        vm.startPrank(owner);

        // 未到期销毁期权，应该会revert
        vm.expectRevert("Not after expiry");
        callOptionToken.burnOption();

        vm.warp(callOptionToken.expiry() + 2 days);
        callOptionToken.burnOption();

        assertEq(owner.balance, 998 ether);

    }
    
    // 测试购买期权
    function test_buyOption() public{
        vm.startPrank(owner);
        callOptionToken.initLiquidity{value: 50 ether}();
        vm.stopPrank();

        vm.startPrank(user1);
        usdt.approve(address(uniswapV2Router), 500*1e18);
        address[] memory path = new address[](2);
        path[0] = address(usdt);              // 付出u
        path[1] = address(callOptionToken);   // 得到期权
        uint256[] memory amounts = uniswapV2Router.swapTokensForExactTokens( 2e18, 500*1e18,path, user1, block.timestamp + 600 seconds);
        // 买到2个期权
        assertEq(amounts[1], 2e18);
        assertEq(callOptionToken.balanceOf(user1), 2*1e18);

// 测试购买期权后行权
        vm.warp(callOptionToken.expiry() );
        usdt.approve(address(callOptionToken), 2*3000*1e18);
        callOptionToken.exerciseOption();

        vm.stopPrank();


    }


// 测试行权
    function test_exerciseOption() public{
        vm.startPrank(owner);
        callOptionToken.mint{value: 2 ether}(owner);
        callOptionToken.mint{value: 2 ether}(owner);
        callOptionToken.transfer(user1, 2*1e18);
        callOptionToken.transfer(user2, 2*1e18);
        assertEq(callOptionToken.balanceOf(owner), 0);
        assertEq(callOptionToken.balanceOf(user1), 2*1e18);
        assertEq(callOptionToken.balanceOf(user2), 2*1e18);
  
        vm.stopPrank();

// 测试未到时间行权
        vm.startPrank(user1);
        vm.expectRevert("Only after expiry can call this function");
        callOptionToken.exerciseOption();

// 测试到时间当天行权
        vm.warp(block.timestamp + 365 days);
        usdt.approve(address(callOptionToken), 6000*1e18);
        uint beforeETHUser1 = address(user1).balance;
        callOptionToken.exerciseOption();
        assertEq(callOptionToken.balanceOf(user1), 0);
        uint afterETHUser1 = address(user1).balance;

        // 赎回2eth
        assertEq(afterETHUser1 - beforeETHUser1,2 ether);
        vm.stopPrank();

// 测试过期后行权
        vm.startPrank(user2);
        vm.warp(block.timestamp + 700 days);
        vm.expectRevert("Only after expiry can call this function");
        callOptionToken.exerciseOption();



    }


    function test_constructor() public view{
        assertEq(callOptionToken.name(), "COToken");
        assertEq(callOptionToken.symbol(), "COToken");
        assertEq(callOptionToken.owner(), owner);
        assertEq(callOptionToken.strikePrice(), 3000*1e18);
        assertEq(callOptionToken.expiry(), block.timestamp + 365 days);
    }



// 测试发行期权
    function test_mint() public{
        vm.startPrank(owner);

        vm.expectRevert("Amount must be greater than 0");
        callOptionToken.mint{value: 0}(address(this));

        vm.expectRevert("Invalid address");
        callOptionToken.mint{value: 1}(address(0));

        callOptionToken.mint{value: 5 ether}(address(this));
        assertEq(callOptionToken.balanceOf(address(this)), 5*1e18);

        callOptionToken.mint{value: 10 ether}(address(this));
        assertEq(callOptionToken.balanceOf(address(this)), 15*1e18);


        vm.stopPrank();


    }

// 测试初始化流动性
    function test_initLiquidity() public {
        vm.startPrank(owner);
        callOptionToken.initLiquidity{value: 50 ether}();

// 重复测试初始化流动性，应该会revert
        vm.expectRevert("Already initialized");
        callOptionToken.initLiquidity{value: 50 ether}();

        assertEq(callOptionToken.totalSupply(), 50*1e18);

        address factory = uniswapV2Router.factory();
        address pairAddr = IUniswapV2Factory(factory).getPair(address(usdt),address(callOptionToken));
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddr);
        (uint112 r0, uint112 r1,) = pair.getReserves();

        if (pair.token0() == address(usdt)) {
            assertEq(uint256(r0), 5000 ether); // USDT
            assertEq(uint256(r1), 50 ether);   // COToken
        } else {
            assertEq(uint256(r0), 50 ether);   // COToken
            assertEq(uint256(r1), 5000 ether); // USDT
        }        

// 首次铸造，锁1000 LP token
        uint256 expectedLp = uint256(Math.sqrt(5000 ether * 50 ether)) - 1000;
        assertEq(pair.balanceOf(address(callOptionToken)), expectedLp);

        vm.stopPrank();
    }





}