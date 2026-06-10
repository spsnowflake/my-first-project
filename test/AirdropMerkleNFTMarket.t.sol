// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/IERC20Interface.sol";
import "src/IERC721Interface.sol";
import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {AirdropMerkleNFTMarket} from "src/AirdropMerkleNFTMarket.sol";

import {ERC2612_Spsf} from "src/ERC2612_Spsf.sol";
import {BaseERC721} from "src/ERC721.sol";

contract AirdropMerkleNFTMarketTest is Test {
    AirdropMerkleNFTMarket public airdropMerkleNFTMarket;
    ERC2612_Spsf public erc20;
    BaseERC721 public erc721;
    bytes32 public merkleRoot;

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address seller = makeAddr("seller");
    address seller2 = makeAddr("seller2");
    address buyer = makeAddr("buyer");
    address buyer2 = makeAddr("buyer2");


    function setUp() public {
        merkleRoot = bytes32(0x7ef01545f126faae8fd71a63541e533902c2b9ebb950f5daa2ee406f029274bf);
        vm.startPrank(user1);
        erc20 = new ERC2612_Spsf();
        erc721 = new BaseERC721("BaseERC721", "BERC721", "ipfs://base/");

        airdropMerkleNFTMarket = new AirdropMerkleNFTMarket(IERC20(address(erc20)), IERC721(address(erc721)), merkleRoot);

        erc20.transfer(seller, 500);
        erc20.transfer(seller2, 500);
        erc20.transfer(buyer, 500);
        erc20.transfer(buyer2, 500);


        vm.stopPrank();
        vm.deal(user1, 10000 ether);
        vm.deal(user2, 10000 ether);
        vm.deal(seller, 10000 ether);
        vm.deal(seller2, 10000 ether);
        vm.deal(buyer, 10000 ether);
        vm.deal(buyer2, 10000 ether);

    }

// user1:0x29E3b139f4393aDda86303fcdAa35F60Bb7092bF
// user2:0x537C8f3d3E18dF5517a58B3fB9D9143697996802
// buyer:0x0fF93eDfa7FB7Ad5E962E4C0EdB9207C03a0fe02
// buyer2:0x3a7e663c871351BbE7B6dD006cB4A46d75cCe61D

// user1:bytes32[] memory proof = [
    // 0xb14ec63abcb141035cf4c64f7ab43ccd991a1c89b4d34e4fc81d0122ecedbdae,
    // 0xcc95fe36bdd16cb5c59c913452a77861896d86cc29ffab560098fb3754610b2e
// ];

// user2:bytes32[] memory proof = [
    // 0x132e46ca414a574afafa7028a0be50271f51193d3b39bd91b76124d15e323104,
    // 0x040ba14c129cd6cafdd950dace9edf116980a6d96e74efd4997efd4c7c59fb88
// ];

// buyer:bytes32[] memory proof = [
    // 0x4e2ef3f4d279d23ce0933035d8c8fb3ce41acb03aa29a326c527a6c76b912f6e,
    // 0x040ba14c129cd6cafdd950dace9edf116980a6d96e74efd4997efd4c7c59fb88
// ];

// buyer2:bytes32[] memory proof = [
    // 0x9abe6538df951915d55c9917d0f7e1aa3bb7be7dcdb0adec0025066572b270b2,
    // 0xcc95fe36bdd16cb5c59c913452a77861896d86cc29ffab560098fb3754610b2e
// ];



    function test_multicall_permitAndClaim() public {
        // 1. seller 上架
        vm.startPrank(seller);
        erc721.mint(seller, 1);
        erc721.setApprovalForAll(address(airdropMerkleNFTMarket), true);
        airdropMerkleNFTMarket.list(1, 200);
        vm.stopPrank();
        // 2. buyer 签 permit，拼 v/r/s

        uint256 value = 500;
        uint256 deadline = block.timestamp + 3600;
        uint256 buyerPrivateKey = uint256(keccak256(abi.encodePacked("buyer")));

        bytes32 PERMIT_TYPEHASH =keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        uint256 nonce = erc20.nonces(buyer);

        bytes32 structHash = keccak256(abi.encode(
            PERMIT_TYPEHASH,
            buyer,                              // owner
            address(airdropMerkleNFTMarket),    // spender = 市场合约
            value,
            nonce,
            deadline
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            erc20.DOMAIN_SEPARATOR(),
            structHash
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerPrivateKey, digest);

        // buyer2 代为提交离线签名
        // vm.prank(buyer2);
        // airdropMerkleNFTMarket.permitPrePay(buyer, value, deadline, v, r, s);

        // 3. 编码 permitPrePay + claimNFT 的 calldata
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = bytes32(0x4e2ef3f4d279d23ce0933035d8c8fb3ce41acb03aa29a326c527a6c76b912f6e);
        proof[1] = bytes32(0x040ba14c129cd6cafdd950dace9edf116980a6d96e74efd4997efd4c7c59fb88);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(airdropMerkleNFTMarket.permitPrePay.selector, buyer, value, deadline, v, r, s);
        data[1] = abi.encodeWithSelector(airdropMerkleNFTMarket.claimNFT.selector, 1, proof);
        // 4. buyer 调 multicall([permitData, claimData])
        vm.prank(buyer);
        airdropMerkleNFTMarket.multicall(data);

        // 5. 断言：allowance 已设置、NFT 归 buyer、余额正确
        assertEq(erc20.allowance(buyer, address(airdropMerkleNFTMarket)), 400);
        assertEq(erc20.nonces(buyer), 1);
        assertEq(erc721.ownerOf(1), buyer);
        assertEq(erc20.balanceOf(buyer), 400);
        assertEq(erc20.balanceOf(seller), 600);
    }

    function test_claimNFT() public {
        // seller 铸造并上架NFT
        vm.startPrank(seller);
        erc721.mint(seller, 1);
        erc721.setApprovalForAll(address(airdropMerkleNFTMarket), true);
        airdropMerkleNFTMarket.list(1, 200);
        vm.stopPrank();

        // buyer 离线签名授权 token 给市场合约，buyer2 代为提交 permit
        uint256 value = 200;
        uint256 deadline = block.timestamp + 3600;
        uint256 buyerPrivateKey = uint256(keccak256(abi.encodePacked("buyer")));

        bytes32 PERMIT_TYPEHASH =keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        uint256 nonce = erc20.nonces(buyer);

        bytes32 structHash = keccak256(abi.encode(
            PERMIT_TYPEHASH,
            buyer,                              // owner
            address(airdropMerkleNFTMarket),    // spender = 市场合约
            value,
            nonce,
            deadline
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            erc20.DOMAIN_SEPARATOR(),
            structHash
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerPrivateKey, digest);

        // buyer2 代为提交离线签名
        vm.prank(buyer2);
        airdropMerkleNFTMarket.permitPrePay(buyer, value, deadline, v, r, s);

        assertEq(erc20.allowance(buyer, address(airdropMerkleNFTMarket)), value);
        assertEq(erc20.nonces(buyer), 1);


        bytes32[] memory proof = new bytes32[](2);
        proof[0] = bytes32(0x4e2ef3f4d279d23ce0933035d8c8fb3ce41acb03aa29a326c527a6c76b912f6e);
        proof[1] = bytes32(0x040ba14c129cd6cafdd950dace9edf116980a6d96e74efd4997efd4c7c59fb88);
        vm.startPrank(buyer);
        airdropMerkleNFTMarket.claimNFT(1, proof);
        vm.stopPrank();

        assertEq(erc721.ownerOf(1), buyer);
        assertEq(erc20.balanceOf(buyer), 400);
        assertEq(erc20.balanceOf(seller), 600);



    }



// buyer 离线签名授权 token 给市场合约，buyer2 代为提交 permit
    function test_permitPrePay() public {
        uint256 value = 500;
        uint256 deadline = block.timestamp + 3600;
        uint256 buyerPrivateKey = uint256(keccak256(abi.encodePacked("buyer")));

        bytes32 PERMIT_TYPEHASH =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        uint256 nonce = erc20.nonces(buyer);

        bytes32 structHash = keccak256(abi.encode(
            PERMIT_TYPEHASH,
            buyer,                              // owner
            address(airdropMerkleNFTMarket),    // spender = 市场合约
            value,
            nonce,
            deadline
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            erc20.DOMAIN_SEPARATOR(),
            structHash
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerPrivateKey, digest);

        // buyer2 代为提交离线签名
        vm.prank(buyer2);
        airdropMerkleNFTMarket.permitPrePay(buyer, value, deadline, v, r, s);

        assertEq(erc20.allowance(buyer, address(airdropMerkleNFTMarket)), value);
        assertEq(erc20.nonces(buyer), 1);
    }






}



