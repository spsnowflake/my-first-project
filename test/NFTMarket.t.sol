// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "../lib/forge-std/src/Test.sol";
import {console} from "../lib/forge-std/src/console.sol";
import {NFTMarket} from "../src/NFTMarket.sol";
import {IERC20} from "src/IERC20Interface.sol";
import {IERC721} from "src/IERC721Interface.sol";
import {BaseERC20} from "src/ERC20.sol";
import {BaseERC721} from "src/ERC721.sol";
import {ERC2612_Spsf} from "src/ERC2612_Spsf.sol";



contract NFTMarketTest is Test {
    NFTMarket public nft_market;
    BaseERC20 public erc20;
    BaseERC721 public erc721;
    ERC2612_Spsf public erc2612_spsf;
    address user1 = makeAddr("1");
    address user2 = makeAddr("2");
    address seller = makeAddr("seller");
    address seller2 = makeAddr("seller2");
    address buyer = makeAddr("buyer");
    address buyer2 = makeAddr("buyer2");


// 初始化 ERC20，ERC721，NFTMarket
    function setUp() public{
        erc20 = new BaseERC20();
        erc721 = new BaseERC721("BaseERC721", "BERC721", "ipfs://base/");


        nft_market = new NFTMarket(IERC20(address(erc20)), IERC721(address(erc721)));
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(seller, 100 ether);
        vm.deal(seller2, 100 ether);
        vm.deal(buyer, 100 ether);
        vm.deal(buyer2, 100 ether);
    }

    /// 模糊测试：测试随机使用 0.01-10000 Token价格上架NFT，
    ///          并随机使用任意Address购买NFT
    function testFuzz_list(uint amount,address any_address) public{
        // 设置条件
        vm.assume(any_address != address(0));
        amount = bound(amount, 0.01*10**18, 10000*10**18);

        vm.startPrank(seller);
        uint tokenId1 = 1;
        erc721.mint(seller, tokenId1);
        erc721.setApprovalForAll(address(nft_market), true);
        bool result = nft_market.list(tokenId1, amount);
        assertEq(result, true);
        vm.stopPrank();

        erc20.transfer(any_address, 10000 ether);

        vm.startPrank(any_address);
        erc721.setApprovalForAll(address(nft_market), true);
        // vm.deal(any_address, 10000 ether);
        erc20.approve(address(nft_market), 10000 ether);
        vm.expectEmit(true, true,false, false);
        emit NFTMarket.BuyNFT(any_address,tokenId1,amount);
        bool buy_result = nft_market.buyNFT(tokenId1, amount);
        assertEq(buy_result, true);
        vm.stopPrank();

    }

    

    function test_buyNFT() public {
        // 1.初始化ERC20，并带有一定的货币
        // 2.自己上架 NFT 
        // 3.购买成功NFT。 
        // 4.自己购买自己的NFT
        // 5.NFT重复购买
        // 6.token支付过少
        // 7.token支付过多
        // 8.断言错误信息和购买事件
        erc20.transfer(seller, 100 ether);
        erc20.transfer(buyer, 100 ether);

        // 卖家上架NFT
        vm.startPrank(seller);
        uint tokenId1 = 1;
        erc721.mint(seller, tokenId1);
        // 授权 nft_market
        erc721.approve(address(nft_market), tokenId1);
        erc20.approve(address(nft_market), 100 ether);
        bool list_result = nft_market.list(tokenId1, 10 ether);
        assertEq(list_result, true);
        vm.stopPrank();

        // 测试——买家成功购买NFT
        vm.startPrank(buyer);
        // 授权
        erc20.approve(address(nft_market), 100 ether);
        vm.expectEmit(true, true,false, false);
        emit NFTMarket.BuyNFT(address(buyer),tokenId1,10 ether);
        bool buy_result = nft_market.buyNFT(tokenId1, 10 ether);
        assertEq(buy_result, true);
        vm.stopPrank();

//      测试——自己购买自己的NFT
        vm.startPrank(seller);
        // 铸造 NFT
        uint tokenId2 = 2;
        erc721.mint(seller, tokenId2);
        erc721.approve(address(nft_market), tokenId2);
        bool list_result2 =nft_market.list(tokenId2, 10 ether);
        assertEq(list_result2, true);
        bool buy_result2 = nft_market.buyNFT(tokenId2, 10 ether);
        assertEq(buy_result2, true);
        // 重复购买
        vm.expectRevert("tokenId must !=0, amount must == tokenPrice[tokenID]");
        bool buy_result3 = nft_market.buyNFT(tokenId2, 10 ether);
        // assertEq(buy_result3, false);
        vm.stopPrank();

        // 测试——token支付过少
        vm.startPrank(seller);
        // 铸造 NFT
        uint tokenId3 = 3;
        erc721.mint(seller, tokenId3);
        // 授权所有
        erc721.setApprovalForAll(address(nft_market),true);
        bool list_result3 =nft_market.list(tokenId3, 10 ether);
        assertEq(list_result3, true);
        vm.stopPrank();

        vm.startPrank(buyer);
        vm.expectRevert("tokenId must !=0, amount must == tokenPrice[tokenID]");
        bool buy_result4 = nft_market.buyNFT(tokenId3, 1 ether);
        
        // 测试——token支付过多
        vm.startPrank(seller2);
        uint tokenId99 = 99;
        // 授权
        erc721.setApprovalForAll(address(nft_market),true);
        erc20.approve(address(nft_market), 100 ether);
        erc721.mint(seller2, tokenId99);
        bool list_result99 =nft_market.list(tokenId99, 10 ether);
        vm.stopPrank();

        vm.startPrank(buyer2);
        erc721.setApprovalForAll(address(nft_market),true);
        erc20.approve(address(nft_market), 100 ether);
        vm.stopPrank();
        // 超额支付
        vm.startPrank(buyer);
        vm.expectRevert("tokenId must !=0, amount must == tokenPrice[tokenID]");
        bool buy_result5 = nft_market.buyNFT(tokenId3, 50 ether);
        vm.stopPrank();
    }


    function test_list() public{
        // 生成tokenId，并铸造token转移到sender
        uint tokenId1 = 1;
        uint tokenId2 = 2;
        // uint tokenId3 = 3;
        uint tokenId4 = 4;
        erc721.mint(user1, tokenId1);
        address owner = user1; 

        vm.startPrank(owner);
        erc721.mint(owner, tokenId2);
        // 测试上架的代币为0
        vm.expectRevert("tokenId must !=0, amount must >0");
        nft_market.list(tokenId2, 0);
        vm.stopPrank();

        // 测试上架的归属不属于sender

        vm.expectRevert("you are not owner");
        nft_market.list(tokenId2, 10);
        
        vm.startPrank(user2);
        erc721.mint(user2, tokenId4);
        erc721.approve(address(nft_market), tokenId4);
        vm.expectEmit(true, true, true, false);
        emit NFTMarket.List(tokenId4,user2,4 ether);
        nft_market.list(tokenId4, 4 ether);
        assertEq(nft_market.tokenPrice(tokenId4), 4 ether);
        assertEq(nft_market.tokenSeller(tokenId4), user2);
    }


}


