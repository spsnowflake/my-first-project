// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import {ERC721V1} from "src/ERC721V1.sol";
import {ERC721V1_1} from "src/ERC721V1_1.sol";
import {IERC721V1} from "src/IERC721V1Interface.sol";

import {NFTMarketV1} from "src/NFTMarketV1.sol";
import {NFTMarketV2} from "src/NFTMarketV2.sol";

import {INFTMarketV1} from "src/INFTMarketV1.sol";
import {INFTMarketV2} from "src/INFTMarketV2.sol";

import {BaseERC20} from "src/ERC20.sol";
import {IERC20} from "src/IERC20Interface.sol";
import {Test} from "forge-std/Test.sol";

import {ERC2612_Spsf} from "src/ERC2612_Spsf.sol";

import {UUPSProxyERC721} from "src/UUPSProxyERC721.sol";
import {UUPSProxyNFTMarket} from "src/UUPSProxyNFTMarket.sol";


contract UUPSProxyNFTMarketTest is Test {
    IERC20 public ierc20;
    BaseERC20 public baseERC20;
    ERC721V1 public erc721V1;
    IERC721V1 public ierc721v1;
    NFTMarketV1 public nftMarketV1;
    NFTMarketV2 public nftMarketV2;
    INFTMarketV1 public inftMarketV1;
    INFTMarketV2 public inftMarketV2;
    ERC2612_Spsf public erc2612_spsf;
    UUPSProxyERC721 public uupsProxyERC721;
    UUPSProxyNFTMarket public uupsProxyNFTMarket;

    address master = makeAddr("master");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address seller = makeAddr("seller");
    address seller2 = makeAddr("seller2");
    address buyer = makeAddr("buyer");
    address buyer2 = makeAddr("buyer2");



    function setUp() public {
        vm.startPrank(master);
        baseERC20 = new BaseERC20();
        erc721V1 = new ERC721V1();
        uupsProxyERC721 = new UUPSProxyERC721(address(erc721V1), abi.encodeWithSelector(ERC721V1.initialize.selector, "Test721", "Test721", "ipfs://test/"));
        ierc721v1 = IERC721V1(address(uupsProxyERC721));
        nftMarketV1 = new NFTMarketV1();
        nftMarketV2 = new NFTMarketV2();

        uupsProxyNFTMarket = new UUPSProxyNFTMarket(address(nftMarketV1), abi.encodeWithSelector(NFTMarketV1.initialize.selector, IERC20(address(baseERC20)), IERC721V1(address(ierc721v1))));
        inftMarketV1 = INFTMarketV1(address(uupsProxyNFTMarket));
        inftMarketV2 = INFTMarketV2(address(uupsProxyNFTMarket));
        vm.stopPrank();

        vm.deal(master, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(seller, 100 ether);
        vm.deal(seller2, 100 ether);
        vm.deal(buyer, 100 ether);
        vm.deal(buyer2, 100 ether);

        vm.startPrank(master);
        baseERC20.transfer(user1, 100 ether);
        baseERC20.transfer(user2, 100 ether);
        baseERC20.transfer(seller, 100 ether);
        baseERC20.transfer(seller2, 100 ether);
        baseERC20.transfer(buyer, 100 ether);
        baseERC20.transfer(buyer2, 100 ether);
        vm.stopPrank();

    }

    function test_nftMarket() public {
        // 测试卖家上架NFT
        vm.startPrank(seller);
        ierc721v1.mint(seller, 1);
        ierc721v1.mint(seller, 2);
        ierc721v1.mint(seller, 3);
        ierc721v1.mint(seller, 4);
        ierc721v1.mint(seller, 5);
        ierc721v1.setApprovalForAll(address(inftMarketV1), true);
        inftMarketV1.list(1, 10 ether);
        inftMarketV1.list(2, 10 ether);
        inftMarketV1.list(3, 10 ether);
        inftMarketV1.list(4, 10 ether);
        assertEq(inftMarketV1.tokenSeller(1), seller);
        assertEq(inftMarketV1.tokenSeller(2), seller);
        assertEq(inftMarketV1.tokenSeller(3), seller);
        assertEq(inftMarketV1.tokenSeller(4), seller);
        vm.stopPrank();

        // 测试买家购买NFT
        vm.startPrank(buyer);
        baseERC20.approve(address(inftMarketV1), 30 ether);
        inftMarketV1.buyNFT(1, 10 ether);
        inftMarketV1.buyNFT(2, 10 ether);
        inftMarketV1.buyNFT(3, 10 ether);
        assertEq(ierc721v1.ownerOf(1), buyer);
        assertEq(ierc721v1.ownerOf(2), buyer);
        assertEq(ierc721v1.ownerOf(3), buyer);
        vm.stopPrank();

        // 测试升级nftMarketV2合约
        vm.startPrank(master);
        inftMarketV1.upgradeTo(address(nftMarketV2));
        inftMarketV2.initializeV2();
        vm.stopPrank();

        // 测试 NFTMarketV2 原有数据
        vm.startPrank(seller);
        assertEq(inftMarketV2.tokenSeller(4), seller);
        // 测试 NFTMarketV2 上架NFT
        inftMarketV2.list(5, 10 ether);
        assertEq(inftMarketV2.tokenSeller(5), seller);
        vm.stopPrank();

        // 测试 NFTMarketV2 买家购买NFT
        vm.startPrank(buyer);
        baseERC20.approve(address(inftMarketV1), 20 ether);
        inftMarketV2.buyNFT(4, 10 ether);
        inftMarketV2.buyNFT(5, 10 ether);
        assertEq(ierc721v1.ownerOf(4), buyer);
        assertEq(ierc721v1.ownerOf(5), buyer);
        vm.stopPrank();

        // 测试 NFTMarketV2 卖家离线签名
        // 卖家签名拼 vrs
        vm.startPrank(seller);
        // 先铸造 tokenid 为6的NFT 
        ierc721v1.mint(seller, 6);
        uint256 nonce = inftMarketV2.listNonces(seller);
        uint256 deadline = block.timestamp + 3600;
        uint96 amount = 10 ether;
        uint256 tokenId = 6;
        uint256 sellerPrivateKey = uint256(keccak256(abi.encodePacked("seller")));
        bytes32 structHash = keccak256(abi.encode(
            keccak256("permitListNFT(uint tokenId,address seller,uint96 amount,uint nonce,uint deadline)"),
            tokenId,
            seller,
            amount,
            nonce,
            deadline
        ));
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            inftMarketV2.DOMAIN_SEPARATOR_LISTNFT(),
            structHash
        ));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, digest);
        vm.stopPrank();

        vm.startPrank(user1); // 任意一方调用都可，离线签名
        inftMarketV2.permitListNFT(tokenId, seller, amount, nonce, deadline, v, r, s);
        assertEq(inftMarketV2.tokenSeller(tokenId), seller);
        vm.stopPrank();

        // 测试 NFTMarketV2 买家购买NFT
        vm.startPrank(buyer);
        baseERC20.approve(address(inftMarketV1), 10 ether);
        inftMarketV2.buyNFT(6, 10 ether);
        assertEq(ierc721v1.ownerOf(6), buyer);
        vm.stopPrank();


    }




















}

