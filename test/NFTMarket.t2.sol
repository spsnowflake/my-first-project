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
import {TokenBank} from "src/TokenBank.sol";



contract NFTMarketT2Test is Test {
    NFTMarket public nft_market;
    BaseERC20 public erc20;
    BaseERC721 public erc721;
    ERC2612_Spsf public erc2612_spsf;
    TokenBank public tokenbank;
    address owner;
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address seller = makeAddr("seller");
    address seller2 = makeAddr("seller2");
    address buyer = makeAddr("buyer");
    address buyer2 = makeAddr("buyer2");


// 初始化 ERC20，ERC721，NFTMarket,ERC2612_Spsf,TokenBank
    function setUp() public{
       // 由 user1 部署
        vm.startPrank(user1);
        erc20 = new BaseERC20();
        erc721 = new BaseERC721("BaseERC721", "BERC721", "ipfs://base/");
        erc2612_spsf = new ERC2612_Spsf();
        tokenbank = new TokenBank(IERC20(address(erc2612_spsf)));
        nft_market = new NFTMarket(IERC20(address(erc2612_spsf)), IERC721(address(erc721)));
        vm.stopPrank();
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(seller, 100 ether);
        vm.deal(seller2, 100 ether);
        vm.deal(buyer, 100 ether);
        vm.deal(buyer2, 100 ether);
    }

// 测试2612_spsf 离线签名存钱，以及nft购买成功
    function test_permitDeposit() public{
        vm.startPrank(user1);
        erc2612_spsf.transfer(user2, 1000);
        erc2612_spsf.transfer(seller, 1000);
        erc2612_spsf.transfer(buyer, 1000);
        vm.stopPrank();
        vm.startPrank(user2);
        console.log("user2 balance", erc2612_spsf.balanceOf(user2));
        erc2612_spsf.approve(address(tokenbank), 1000);
        // 获取user2私钥
        uint256 user2PrivateKey = uint256(keccak256(abi.encodePacked("user2")));

        // 拼 EIP-712 digest
        bytes32 PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        // 获取nonce
        uint256 nonce = erc2612_spsf.nonces(user2);
        uint256 deadline = block.timestamp + 3600;
        uint256 value = 1000;

        bytes32 structHash = keccak256(abi.encode(
            PERMIT_TYPEHASH,
            user2,
            address(tokenbank),
            value,
            nonce,
            deadline
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            erc2612_spsf.DOMAIN_SEPARATOR(),
            structHash
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user2PrivateKey, digest);
        vm.stopPrank();
        // 任意一方调用都可，离线签名
        tokenbank.permitDeposit(user2, value, deadline, v, r, s);

        console.log("user2 balance", erc2612_spsf.balanceOf(user2));
        console.log("tokenbank.balances(user2)", tokenbank.balances(user2));
        // user2 的余额应该为0,tokenbank的user2 余额应该为1000
        assertEq(erc2612_spsf.balanceOf(user2), 0);
        assertEq(tokenbank.balances(user2), 1000);

        vm.startPrank(seller);
        erc721.mint(seller, 1);
        erc721.setApprovalForAll(address(nft_market), true);
        owner = erc721.ownerOf(1);
        assertEq(owner, seller);
        console.log("NFT tokenId 1 owner:", owner);
        console.log("address seller:", owner);

        nft_market.list(1, 500);
        vm.stopPrank();

        vm.prank(buyer);
        erc2612_spsf.approve(address(nft_market), 500);

        vm.startPrank(user1);
        // 开始拼签名
        uint256 tokenId = 1;
        uint256 amount = 500;
        uint256 buyNonce = nft_market.buyNonces(tokenId);
        uint256 buyDeadline = block.timestamp + 3600;
        uint256 ownerKey = uint256(keccak256(abi.encodePacked("user1")));

        bytes32 PERMIT_BUY_TYPEHASH = keccak256("PermitBuyNFT(uint tokenId,address buyer,uint amount,uint nonce,uint deadline)");

        bytes32 buyStructHash = keccak256(abi.encode(
            PERMIT_BUY_TYPEHASH,
            tokenId,
            amount,
            buyer,
            buyNonce,
            buyDeadline
        ));

        bytes32 buyDigest = keccak256(abi.encodePacked("\x19\x01", nft_market.DOMAIN_SEPARATOR(), buyStructHash));

        (uint8 buyV, bytes32 buyR, bytes32 buyS) = vm.sign(ownerKey, buyDigest);
        vm.stopPrank();

        vm.prank(buyer);
        nft_market.permitBuyNFT(tokenId, buyer, amount, buyNonce, buyDeadline, buyV, buyR, buyS);

        owner = erc721.ownerOf(1);
        // 购买成功后，buyer 为 tokenid 1 的owner
        assertEq(owner, buyer);
        console.log("NFT tokenId 1 owner:", owner);
        console.log("address buyer:", owner);


    }




}


