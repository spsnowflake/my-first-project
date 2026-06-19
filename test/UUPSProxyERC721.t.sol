// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {UUPSProxyERC721} from "src/UUPSProxyERC721.sol";
import {ERC721V1} from "src/ERC721V1.sol";
import {ERC721V1_1} from "src/ERC721V1_1.sol";
import {IERC721V1} from "src/IERC721V1Interface.sol";



contract UUPSProxyERC721Test is Test {
    UUPSProxyERC721 public uupsProxyERC721;
    ERC721V1 public erc721V1;
    ERC721V1_1 public erc721V1_1;
    IERC721V1 public ierc721v1;
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address seller = makeAddr("seller");
    address seller2 = makeAddr("seller2");
    address buyer = makeAddr("buyer");
    address buyer2 = makeAddr("buyer2");


    function setUp() public {
        vm.startPrank(user1);
        erc721V1 = new ERC721V1();
        erc721V1_1 = new ERC721V1_1();
        uupsProxyERC721 = new UUPSProxyERC721(address(erc721V1), abi.encodeWithSelector(ERC721V1.initialize.selector, "Test721", "Test721", "ipfs://test/"));
        ierc721v1 = IERC721V1(address(uupsProxyERC721));
        vm.stopPrank();
    }

// 测试代理合约V1
    function test_proxyERC721() public {
        // 部署并测试代理合约V1
        vm.startPrank(user1);
        assertEq(ierc721v1.name(), "Test721");
        assertEq(ierc721v1.symbol(), "Test721");
        ierc721v1.mint(user1, 1);
        assertEq(ierc721v1.ownerOf(1), user1);
        assertEq(ierc721v1.balanceOf(user1), 1);
        assertEq(ierc721v1.tokenURI(1), "ipfs://test/1");

//      升级/切换 合约V1 为合约V1_1
        ierc721v1.upgradeTo(address(erc721V1_1));

        // 测试代理合约V1_1
        assertEq(ierc721v1.name(), "Test721");
        assertEq(ierc721v1.symbol(), "Test721");
        assertEq(ierc721v1.tokenURI(1), "ipfs://test/1");
        assertEq(ierc721v1.ownerOf(1), user1);
        assertEq(ierc721v1.balanceOf(user1), 1);
        assertEq(ierc721v1.getApproved(1), address(0));
        assertEq(ierc721v1.isApprovedForAll(user1, address(0)), false);

// 测试升级后的合约的铸造功能
        ierc721v1.mint(user1, 2);
        assertEq(ierc721v1.ownerOf(2), user1);
        assertEq(ierc721v1.balanceOf(user1), 2);
        assertEq(ierc721v1.tokenURI(2), "ipfs://test/2");
        assertEq(ierc721v1.getApproved(2), address(0));
        assertEq(ierc721v1.isApprovedForAll(user1, address(0)), false);

// 测试升级后的合约的转账功能
        ierc721v1.transferFrom(user1, user2, 1);
        assertEq(ierc721v1.ownerOf(1), user2);
        assertEq(ierc721v1.balanceOf(user2), 1);
        assertEq(ierc721v1.tokenURI(1), "ipfs://test/1");
        assertEq(ierc721v1.getApproved(1), address(0));
        assertEq(ierc721v1.isApprovedForAll(user1, address(0)), false);

        vm.stopPrank();
    }















}