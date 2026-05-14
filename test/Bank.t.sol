// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "../lib/forge-std/src/Test.sol";
import {Bank} from "../src/Bank.sol";

contract BankTest is Test {
    Bank public bank ;
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    address user4 = makeAddr("user4");


    function setUp() public {
        bank = new Bank(address(this));
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
        vm.deal(user4, 100 ether);
    }

    function test_withdraw()public{
        vm.prank(user2);
        bank.saveMoney{value: 10 ether}();
        uint money = address(bank).balance;
        assertEq(money, 10 ether);
        vm.prank(user1);
        vm.expectRevert();
        bank.withdraw();
        // vm.prank(address(this));
        bank.withdraw();
    }



    
    function test_saveMoney() public {
        uint beforeMoney = bank.savePrice(user1);
        vm.prank(user1);
        bank.saveMoney{value: 1 ether}();
        uint afterMoney = bank.savePrice(user1);
        assertEq(afterMoney, beforeMoney + 1 ether);
    }


    function test_saveMoney_top3User() public {
        vm.prank(user1);
        bank.saveMoney{value: 1 ether}();
        address[3] memory top3User = bank.getTop3User();
        assertEq(top3User[0], user1);
        assertEq(top3User[1], address(0));
        assertEq(top3User[2], address(0));
        vm.prank(user2);
        bank.saveMoney{value: 2 ether}();
        top3User = bank.getTop3User();
        assertEq(top3User[0], user2);
        assertEq(top3User[1], user1);
        assertEq(top3User[2], address(0));
        vm.prank(user3);
        bank.saveMoney{value: 3 ether}();
        top3User = bank.getTop3User();
        assertEq(top3User[0], user3);
        assertEq(top3User[1], user2);
        assertEq(top3User[2], user1);
        vm.prank(user4);
        bank.saveMoney{value: 4 ether}();
        top3User = bank.getTop3User();
        assertEq(top3User[0], user4);
        assertEq(top3User[1], user3);
        assertEq(top3User[2], user2);
        vm.prank(user3);
        bank.saveMoney{value: 3 ether}();
        top3User = bank.getTop3User();
        assertEq(top3User[0], user3);
        assertEq(top3User[1], user4);
        assertEq(top3User[2], user2);
    }

    // 让测试合约能接收 ETH
    receive() external payable {}



    
}





