// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Vesting} from "src/Vesting.sol";
import {IERC20} from "src/IERC20Interface.sol";
import {ERC2612_Spsf} from "src/ERC2612_Spsf.sol";

contract VestingTest is Test {
    Vesting public vesting;
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address seller = makeAddr("seller");
    address seller2 = makeAddr("seller2");
    address buyer = makeAddr("buyer");
    address buyer2 = makeAddr("buyer2");
    ERC2612_Spsf public erc2612_spsf;

    function setUp() public {
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(seller, 100 ether);
        vm.deal(seller2, 100 ether);
        vm.deal(buyer, 100 ether);
        vm.deal(buyer2, 100 ether);
        vm.startPrank(user1);
        vm.stopPrank();

        vm.startPrank(user1);
        erc2612_spsf = new ERC2612_Spsf();
        vesting = new Vesting(IERC20(address(erc2612_spsf)), buyer);
        erc2612_spsf.approve(address(vesting), 1000000 * 10 ** 18);
        vm.stopPrank();
    }

    function test_Vesting() public {
        vm.startPrank(user1);
        bool result = vesting.depositInitialAmount(1000000 * 10 ** 18);
        assertEq(result, true);
        vm.stopPrank();

        // 预期失败，报错Cliff not reached
        vm.expectRevert("Cliff not reached");
        vesting.release();

// 差一天
        vm.warp(block.timestamp + 365 days + 29 days);
        vm.expectRevert("No release count");
        vesting.release();

        vm.warp(block.timestamp + 1 days);
        bool result3 = vesting.release();
        assertEq(result3, true);
        assertEq(vesting.releasedAmount(),  1000000e18 / uint256(24));
        assertEq(vesting.releaseCount(), 1);

// 重复释放，预期报错
        vm.expectRevert("No release count");
        vesting.release();


        vm.warp(block.timestamp + 30 days);
        bool result4 = vesting.release();
        assertEq(result4, true);
        assertEq(vesting.releasedAmount(),  1000000e18 / uint256(24) + 1000000e18 / uint256(24) );
        assertEq(vesting.releaseCount(), 2);

        vm.warp(block.timestamp + 30 days *22);

        bool result5 = vesting.release();
        assertEq(result5, true);
        assertEq(vesting.releasedAmount(),  1000000e18 );
        assertEq(vesting.releaseCount(), 24);
        
        assertEq(erc2612_spsf.balanceOf(buyer), 1000000e18);

        


        
    }
}

