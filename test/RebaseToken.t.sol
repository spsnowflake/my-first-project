// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import {Test} from "../lib/forge-std/src/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken public rebaseToken;
    uint8 public constant decimals = 18; 
    uint32 public constant year = 365 days; 
    address owner = makeAddr("owner");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    address seller = makeAddr("seller");
    address seller2 = makeAddr("seller2");
    address buyer = makeAddr("buyer");
    address buyer2 = makeAddr("buyer2");

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken("RebaseToken", "RBT");
        vm.stopPrank();

    }


    function test_transferFrom_afterRebase() public {
        vm.prank(owner);
        rebaseToken.transfer(user1, 100 ether);
        
        vm.prank(user1);
        rebaseToken.approve(user2, 100 ether);
        
        // 一年后
        vm.warp(block.timestamp + year);
        
        // 授权额度通缩后只有99，transferFrom 100应该失败
        vm.prank(user2);
        vm.expectRevert();
        rebaseToken.transferFrom(user1, user2, 100 ether);
        
        // 转99应该成功
        vm.prank(user2);
        rebaseToken.transferFrom(user1, user2, 99 ether);
    }

    function test_transferFrom() public {
        vm.prank(owner);
        rebaseToken.transfer(user1, 100 ether);
        
        vm.prank(user1);
        rebaseToken.approve(user2, 50 ether);
        
        vm.prank(user2);
        rebaseToken.transferFrom(user1, user2, 50 ether);
        
        assertEq(rebaseToken.balanceOf(user1), 50 ether);
        assertEq(rebaseToken.balanceOf(user2), 50 ether);
        assertEq(rebaseToken.allowance(user1, user2), 0);
    }

// 测试用户之间转账
    function test_transfer_afterRebase() public {
    vm.startPrank(owner);
    rebaseToken.transfer(user1, 100 ether);
    vm.stopPrank();

    vm.warp(block.timestamp + year);

    uint256 balance;
    balance = rebaseToken.balanceOf(user1); // ≈ 99 ether
    vm.prank(user1);
    rebaseToken.transfer(user2, balance);

    assertEq(rebaseToken.balanceOf(user1), 0);
    assertEq(rebaseToken.balanceOf(user2), balance);


    vm.warp(block.timestamp + year);

    balance = rebaseToken.balanceOf(user2); 
    vm.prank(user2);
    rebaseToken.transfer(user3, balance);

    assertEq(rebaseToken.balanceOf(user1), 0);
    assertEq(rebaseToken.balanceOf(user2), 0);
    assertEq(rebaseToken.balanceOf(user3), balance);
    assertEq(rebaseToken.balanceOf(user3), 100 ether*99**2/100**2);

}




    function test_approve() public {
        vm.startPrank(owner);
        rebaseToken.approve(user1, 100 ether);
        uint256 allowance;
        // 查看 allowance 授权额度
        allowance = rebaseToken.allowance(owner, user1);
        assertEq(allowance, 100 ether);

        // 一年后，授权额度进行通缩
        vm.warp(block.timestamp + year);
        allowance = rebaseToken.allowance(owner, user1);
        assertEq(allowance, 100 ether *99**1/100**1);

        vm.stopPrank();
    }

// 测试多用户的余额通缩变化，以及最后是否总量守恒
    function test_balanceOf() public {
        vm.startPrank(owner);
        // 给 user1 转账
        rebaseToken.transfer(user1, 100 ether);
        rebaseToken.transfer(user2, 200 ether);
        rebaseToken.transfer(user3, 500 ether);
        uint256 balance;
        uint256 balance2;
        uint256 balance3;
        // 查看 user1 的余额
        balance = rebaseToken.balanceOf(user1);
        assertEq(balance, 100 ether);

        balance2 = rebaseToken.balanceOf(user2);
        assertEq(balance2, 200 ether);

        balance3 = rebaseToken.balanceOf(user3);
        assertEq(balance3, 500 ether);

        // 一年后，user1 的余额应该通缩减少
        vm.warp(block.timestamp + year );
        balance = rebaseToken.balanceOf(user1);
        balance2 = rebaseToken.balanceOf(user2);
        balance3 = rebaseToken.balanceOf(user3);

        assertEq(balance, 100 ether *99**1/100**1);
        assertEq(balance2, 200 ether *99**1/100**1);
        assertEq(balance3, 500 ether *99**1/100**1);

// 过了2年
        vm.warp(block.timestamp + year );
        balance = rebaseToken.balanceOf(user1);
        balance2 = rebaseToken.balanceOf(user2);
        balance3 = rebaseToken.balanceOf(user3);
        assertEq(balance, 100 ether *99**2/100**2);
        assertEq(balance2, 200 ether *99**2/100**2);
        assertEq(balance3, 500 ether *99**2/100**2);

        uint256 balance_owner = rebaseToken.balanceOf(owner);

// totalSupply 应该等于所有用户的余额之和
        assertEq(rebaseToken.totalSupply(), balance + balance2 + balance3 + balance_owner);

        vm.stopPrank();
    }


    function test_rebase() public {
        vm.startPrank(owner);
        uint256 totalSupply;
        totalSupply = rebaseToken.totalSupply();
        assertEq(totalSupply, 1e8*10**decimals);
// 不足一年
        vm.warp(block.timestamp + 364 days);
        totalSupply = rebaseToken.totalSupply();
        assertEq(totalSupply, 1e8*10**decimals);

// 刚好过一年
        vm.warp(block.timestamp + 1 days);
        totalSupply = rebaseToken.totalSupply();
        assertEq(totalSupply, 1e8*10**decimals*99/100);

// 过了2年
        vm.warp(block.timestamp + year);
        totalSupply = rebaseToken.totalSupply();
        assertEq(totalSupply, 1e8*10**decimals*99**2/100**2);

// 过了10年
        vm.warp(block.timestamp + year*8);
        totalSupply = rebaseToken.totalSupply();
        assertEq(totalSupply, 1e8*10**decimals*99**10/100**10);

        vm.stopPrank();
    }





}











