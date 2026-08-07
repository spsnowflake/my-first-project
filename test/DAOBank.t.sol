// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {GovernorAlpha} from "../src/GovernorAlpha.sol";
import {Timelock} from "../src/Timelock.sol";
import {Comp} from "../src/Comp.sol";
import {Bank} from "../src/Bank.sol";

contract DAOBankTest is Test {
    GovernorAlpha public governor;
    Timelock public timelock;
    Comp public comp;
    Bank public bank;

    address owner = makeAddr("owner");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    address user4 = makeAddr("user4");
    address user5 = makeAddr("user5");
    address user6 = makeAddr("user6");
    address buyer2 = makeAddr("buyer2");

    function setUp() public {
        vm.startPrank(owner);
        comp = new Comp(owner);
        // 自委托后，才有投票权
        comp.delegate(owner);
        timelock = new Timelock(owner, 2 days);
        governor = new GovernorAlpha(timelock, comp, owner);
        bank = new Bank(address(timelock));
        // 调用Timelock更改owner为governor合约
        // 部署阶段：owner 仍是 Timelock.admin，可直接 queue/execute，无需投票
        // 但仍必须走 Timelock 的「先排队 → 过 delay → 再执行」
        bytes memory data = abi.encode(address(governor));
        uint eta = block.timestamp + timelock.delay();
        timelock.queueTransaction(address(timelock), 0, "setPendingAdmin(address)", data, eta);
        vm.warp(eta);
        timelock.executeTransaction(address(timelock), 0, "setPendingAdmin(address)", data, eta);
        vm.stopPrank();

        // 接受admin权限
        vm.startPrank(address(governor));
        timelock.acceptAdmin();
        vm.stopPrank();


        vm.deal(owner, 10000 ether);
        vm.deal(user1, 10000 ether);
        vm.deal(user2, 10000 ether);
        vm.deal(user3, 10000 ether);
        vm.deal(user4, 10000 ether);
        vm.deal(user5, 10000 ether);
        vm.deal(user6, 10000 ether);
        vm.deal(buyer2, 10000 ether);
    }
    

// 延迟未结束，不能execute
    function test_notEnoughDelay() public {
        vm.roll(1);
        vm.startPrank(user1);
        comp.delegate(user1);
        vm.stopPrank();
        vm.startPrank(user2);
        comp.delegate(user2);
        vm.stopPrank();

        vm.startPrank(owner);
        comp.transfer(user1, 100000 ether);
        comp.transfer(user2, 400000 ether);
        vm.stopPrank();

        // 准备入参，调用提案
        address[] memory targets = new address[](1);
        targets[0] = address(bank);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        string[] memory signatures = new string[](1);
        signatures[0] = "withdraw()";
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";

        vm.roll(10);
        vm.startPrank(user1);
        uint256 proposalId = governor.propose(targets, values, signatures, calldatas, "withdraw 1 eth from bank");
        // 提案成功，proposalId 为1
        assertEq(proposalId, 1);
        // 提案状态处于 Pending 状态
        assertEq(governor.state(proposalId) == GovernorAlpha.ProposalState.Pending, true);
        // 投票开始
        vm.roll(12);
        // 提案状态处于 Active 状态
        assertEq(governor.state(proposalId) == GovernorAlpha.ProposalState.Active, true);
// user1投票，同意
        governor.castVote(proposalId, true);
        vm.stopPrank();

// user2投票，同意
        vm.startPrank(user2);
        governor.castVote(proposalId, true);
        vm.stopPrank();

// 跳过区块，入队
        vm.roll(block.number+governor.votingPeriod());
        governor.queue(proposalId);

        // 跳过1天时间。因为延迟未结束，不能执行
        vm.warp(block.timestamp+1 days);
        vm.expectRevert("Timelock::executeTransaction: Transaction hasn't surpassed time lock.");
        governor.execute(proposalId);

    }

// 非 Timelock 不能 Bank.withdraw
    function test_bankWithdraw() public {
        vm.roll(1);
        vm.startPrank(owner);

        // bank存入 1000 eth
        bank.saveMoney{value: 1000 ether}();
        assertEq(address(bank).balance, 1000 ether);
        vm.stopPrank();

// 非 Timelock 不能 Bank.withdraw . 失败
        vm.startPrank(address(governor));
        vm.expectRevert();
        bank.withdraw();
        vm.stopPrank();

    }


// 测试赞成票数不够，提案失败
    function test_notEnoughVotes() public {
        vm.roll(1);
        vm.startPrank(user1);
        comp.delegate(user1);
        vm.stopPrank();
        vm.startPrank(user2);
        comp.delegate(user2);
        vm.stopPrank();
        vm.startPrank(user3);
        comp.delegate(user3);
        vm.stopPrank();

        vm.startPrank(owner);
        comp.transfer(user1, 100000 ether);
        comp.transfer(user2, 100000 ether);
        comp.transfer(user3, 150000 ether);
        vm.stopPrank();

        
        // 准备入参，调用提案
        address[] memory targets = new address[](1);
        targets[0] = address(bank);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        string[] memory signatures = new string[](1);
        signatures[0] = "withdraw()";
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";

        vm.roll(10);
        vm.startPrank(user1);
        uint256 proposalId = governor.propose(targets, values, signatures, calldatas, "withdraw 1 eth from bank");
        // 提案成功，proposalId 为1
        assertEq(proposalId, 1);
        // 提案状态处于 Pending 状态
        assertEq(governor.state(proposalId) == GovernorAlpha.ProposalState.Pending, true);
        // 投票开始
        vm.roll(12);
        // 提案状态处于 Active 状态
        assertEq(governor.state(proposalId) == GovernorAlpha.ProposalState.Active, true);
// user1投票，同意
        governor.castVote(proposalId, true);
        vm.stopPrank();

// user2投票，同意
        vm.startPrank(user2);
        governor.castVote(proposalId, true);
        vm.stopPrank();

// user3投票，同意
        vm.startPrank(user3);
        governor.castVote(proposalId, true);
        vm.stopPrank();

        vm.roll(4 days);
        // 时间推进到4天后，投票数35W，小于最低要求40W，，提案失败
        assertEq(governor.state(proposalId) == GovernorAlpha.ProposalState.Defeated, true);
        // 提案失败，不能进入 Timelock 排队
        vm.startPrank(owner);
        vm.expectRevert("GovernorAlpha::queue: proposal can only be queued if it is succeeded");
        governor.queue(proposalId);
        vm.stopPrank();
    }

// 测试反对票数大于同意票数，提案失败
    function test_againstVotes() public {
        vm.roll(1);
        vm.startPrank(user2);
        comp.delegate(user2);
        vm.stopPrank();
        vm.startPrank(user3);
        comp.delegate(user3);
        vm.stopPrank();
        vm.startPrank(user4);
        comp.delegate(user4);
        vm.stopPrank();
        vm.startPrank(user5);
        comp.delegate(user5);
        vm.startPrank(owner);
        comp.transfer(user2, 200000 ether);
        comp.transfer(user3, 300000 ether);
        comp.transfer(user4, 400000 ether);
        comp.transfer(user5, 3000000 ether);
        vm.stopPrank();

        // 准备入参，调用提案
        address[] memory targets = new address[](1);
        targets[0] = address(bank);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        string[] memory signatures = new string[](1);
        signatures[0] = "withdraw()";
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";

        vm.roll(10);
        vm.startPrank(user2);
        uint256 proposalId = governor.propose(targets, values, signatures, calldatas, "withdraw 1 eth from bank");
        // 提案成功，proposalId 为1
        assertEq(proposalId, 1);
        // 提案状态处于 Pending 状态
        assertEq(governor.state(proposalId) == GovernorAlpha.ProposalState.Pending, true);
        // 投票开始
        vm.roll(12);
        // 提案状态处于 Active 状态
        assertEq(governor.state(proposalId) == GovernorAlpha.ProposalState.Active, true);
// user2投票，同意
        governor.castVote(proposalId, true);
        vm.stopPrank();

// user3投票，同意
        vm.startPrank(user3);
        governor.castVote(proposalId, true);
        vm.stopPrank();

// user4投票，同意
        vm.startPrank(user4);
        governor.castVote(proposalId, true);
        vm.stopPrank();

// user5投票，反对
        vm.startPrank(user5);
        governor.castVote(proposalId, false);
        vm.stopPrank();

// 时间推进到4天后，投票 反对票数 大于 同意票数，提案失败
        vm.roll(4 days);
        assertEq(governor.state(proposalId) == GovernorAlpha.ProposalState.Defeated, true);

// 提案失败，不能进入 Timelock 排队
        vm.startPrank(owner);
        vm.expectRevert("GovernorAlpha::queue: proposal can only be queued if it is succeeded");
        governor.queue(proposalId);
        vm.stopPrank();

    }

    // 测试主流程：存款、投票治理、提现
    // 1.先让几个用户拥有投票权（owner转账给用户）
    // 2.某个用户发起提案（提案权不够和足够的两种情况）
    // 3.用户投票.投票数不够，不通过。
//     4.提案通过后，进入Timelock排队
//     5.Timelock过delay后，执行提案
//     6.提现成功
    function test_bank() public {
        // 自委托后，才有投票权
        vm.roll(1);
        vm.startPrank(user1);
        comp.delegate(user1);
        vm.stopPrank();
        vm.startPrank(user2);
        comp.delegate(user2);
        vm.stopPrank();
        vm.startPrank(user3);
        comp.delegate(user3);
        vm.stopPrank();
        vm.startPrank(user4);
        comp.delegate(user4);
        vm.stopPrank();
        vm.startPrank(user5);
        comp.delegate(user5);
        vm.stopPrank();
        vm.startPrank(user6);
        comp.delegate(user6);
        vm.stopPrank();

        // owner 转账给用户，用户才有投票权
        vm.startPrank(owner);
        comp.transfer(user1, 99999 ether);
        comp.transfer(user2, 200000 ether);
        comp.transfer(user3, 300000 ether);
        comp.transfer(user4, 400000 ether);
        comp.transfer(user5, 3000000 ether);
        comp.transfer(user6, 5000000 ether);

        // bank存入 1000 eth
        bank.saveMoney{value: 1000 ether}();
        assertEq(address(bank).balance, 1000 ether);

        vm.stopPrank();
        // 抽查用户4的投票权
        (uint256 fromBlock, uint256 votes) = comp.checkpoints(user4, 0);
        assertEq(votes, 400000 ether);

        // 准备入参，调用提案
        address[] memory targets = new address[](1);
        targets[0] = address(bank);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        string[] memory signatures = new string[](1);
        signatures[0] = "withdraw()";
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";

        vm.roll(10);

        // 用户1提案权不够，抛出异常
        vm.startPrank(user1);
        vm.expectRevert("GovernorAlpha::propose: proposer does not have enough votes to propose");
        governor.propose(targets, values, signatures, calldatas, "withdraw 1 eth from bank");
        vm.stopPrank();

        vm.startPrank(user2);
        uint256 proposalId = governor.propose(targets, values, signatures, calldatas, "withdraw 1 eth from bank");
        // 提案成功，proposalId 为1
        assertEq(proposalId, 1);
        // 投票未开始，抛出异常
        vm.expectRevert("GovernorAlpha::_castVote: voting is closed");
        governor.castVote(proposalId, true);
        // 提案状态处于 Pending 状态
        assertEq(governor.state(proposalId) == GovernorAlpha.ProposalState.Pending, true);
        // 投票开始
        vm.roll(12);
        // 提案状态处于 Active 状态
        assertEq(governor.state(proposalId) == GovernorAlpha.ProposalState.Active, true);

        governor.castVote(proposalId, true);

        // 再次投票同一个提案，抛出异常
        vm.expectRevert("GovernorAlpha::_castVote: voter already voted");
        governor.castVote(proposalId, true);

        // 投票未通过，不能进入 Timelock 排队
        vm.expectRevert("GovernorAlpha::queue: proposal can only be queued if it is succeeded");
        governor.queue(proposalId);
        vm.stopPrank();

        vm.roll(20);
        vm.startPrank(user3);
        governor.castVote(proposalId, true);
        // 投票回执记录,支持票，300000 ether
        assertEq(governor.getReceipt(proposalId, user3).support, true);
        assertEq(governor.getReceipt(proposalId, user3).votes, 300000 ether);
        vm.stopPrank();

        // 时间推进到3天后，时间到，提案成功通过
        vm.roll(20+governor.votingPeriod());
        assertEq(governor.state(proposalId) == GovernorAlpha.ProposalState.Succeeded, true);

// 入队
        vm.startPrank(owner);
        governor.queue(proposalId);
        // 提案状态处于 Queued 状态
        assertEq(governor.state(proposalId) == GovernorAlpha.ProposalState.Queued, true);
        vm.stopPrank();

// 执行
        vm.startPrank(address(governor));
        // 跳过时间。之前是跳过区块号。现在跳过时间
        vm.warp(block.timestamp+3 days);
        governor.execute(proposalId);
        vm.stopPrank();
        assertEq(governor.state(proposalId) == GovernorAlpha.ProposalState.Executed, true);
        // 
        // 提现成功
        assertEq(address(timelock).balance, 1000 ether);
    }

    // 测试二分查找
    function test_getPriorVotes() public {
        vm.roll(1);
        vm.startPrank(user1);
        comp.delegate(user1);
        vm.stopPrank();

        vm.startPrank(owner);
        comp.transfer(user1, 100 ether);

        vm.roll(5);
        comp.transfer(user1, 300 ether);

        vm.roll(10);
        comp.transfer(user1, 500 ether);

        vm.roll(14);
        comp.transfer(user1, 800 ether);

        vm.roll(30);
        comp.transfer(user1, 500 ether);

        vm.roll(50);
        comp.transfer(user1, 1000 ether);

        vm.stopPrank();
        vm.roll(80);

        assertEq(comp.getPriorVotes(user1, 1), 100 ether);
        assertEq(comp.getPriorVotes(user1, 5), 400 ether);
        assertEq(comp.getPriorVotes(user1, 6), 400 ether);
        assertEq(comp.getPriorVotes(user1, 9), 400 ether);
        assertEq(comp.getPriorVotes(user1, 11), 900 ether);
        assertEq(comp.getPriorVotes(user1, 20), 1700 ether);
        assertEq(comp.getPriorVotes(user1, 40), 2200 ether);
        assertEq(comp.getPriorVotes(user1, 48), 2200 ether);
        assertEq(comp.getPriorVotes(user1, 50), 3200 ether);
        assertEq(comp.getPriorVotes(user1, 70), 3200 ether);

        vm.roll(82);
        vm.startPrank(user1);
        comp.transfer(user2, 200 ether);

        vm.roll(85);
        assertEq(comp.getPriorVotes(user1, 83), 3000 ether);
    }

// 测试转账后，检测余额和投票权
    function test_compTransferAndCurrentVotes() public {
        vm.roll(1);
        vm.startPrank(user1);
        comp.delegate(user1);
        vm.stopPrank();

        // owner 转账给 user1，user1 的投票权和余额增加 100 ether
        vm.startPrank(owner);
        comp.transfer(user1, 100 ether);
        assertEq(comp.balanceOf(user1), 100 ether);
        assertEq(comp.numCheckpoints(user1), 1);
        (uint256 fromBlock, uint256 votes) = comp.checkpoints(user1, 0);
        assertEq(votes, 100 ether);
        assertEq(fromBlock, 1);

        // 检查 owner 的投票权和余额减少 100 ether
        assertEq(comp.balanceOf(owner), comp.totalSupply() - 100 ether);
        assertEq(comp.numCheckpoints(owner), 1);
        (uint256 owner_fromBlock, uint256 owner_votes) = comp.checkpoints(owner, 0);
        assertEq(owner_votes, comp.totalSupply() - 100 ether);
        assertEq(owner_fromBlock, 1);
        vm.stopPrank();

        vm.roll(5);
        vm.startPrank(owner);
        comp.transfer(user1, 900 ether);
        vm.stopPrank();

        assertEq(comp.getCurrentVotes(user1), 1000 ether);

        vm.roll(9);
        vm.startPrank(owner);
        comp.transfer(user1, 1000 ether);
        vm.stopPrank();

        assertEq(comp.getCurrentVotes(user1), 2000 ether);
    }
}
