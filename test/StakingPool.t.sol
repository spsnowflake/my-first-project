// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "../lib/forge-std/src/Test.sol";
import {StakingPool} from "../src/StakingPool.sol";
import {KKToken} from "../src/KKToken.sol";


contract StakingPoolTest is Test{
    uint256 public constant BONUS_MULTIPLIER = 10*1e18;

    StakingPool public stakingPool;
    KKToken public kkToken;
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address seller = makeAddr("seller");
    address seller2 = makeAddr("seller2");
    address buyer = makeAddr("buyer");
    address buyer2 = makeAddr("buyer2");

    function setUp() public {
        vm.startPrank(user1);
        kkToken = new KKToken( "KKToken", "KKToken" );
        stakingPool = new StakingPool(address(kkToken));
        kkToken.transferOwnership(address(stakingPool));
        vm.stopPrank();
        vm.deal(user1, 1000 ether);
        vm.deal(user2, 1000 ether);
        vm.deal(seller, 1000 ether);
        vm.deal(seller2, 1000 ether);
        vm.deal(buyer, 1000 ether);
        vm.deal(buyer2, 1000 ether);

    }



    function test_unstake() public {
        vm.startPrank(buyer);

        vm.expectRevert("amount must be greater than 0");
        stakingPool.unstake(0);

        stakingPool.stake{value: 100 ether}();
        vm.roll(3);

        vm.expectRevert("insufficient balance");
        stakingPool.unstake(200 ether);

        stakingPool.unstake(100 ether);
        assertEq(kkToken.balanceOf(buyer), 20 ether);
        assertEq(stakingPool.balanceOf(buyer), 0);
        assertEq(stakingPool.totalEth(), 0);
        assertEq(kkToken.totalSupply(), 20 ether);
        vm.stopPrank();

        vm.startPrank(buyer2);
        stakingPool.stake{value: 200 ether}();
        vm.roll(5);

        stakingPool.unstake(100 ether);
        assertEq(kkToken.balanceOf(buyer2), 20 ether);
        assertEq(stakingPool.balanceOf(buyer2), 100 ether);
        vm.stopPrank();

        vm.startPrank(buyer);
        stakingPool.stake{value: 400 ether}();
        vm.roll(9);
        stakingPool.unstake(400 ether);
        assertEq(kkToken.balanceOf(buyer), 32 ether + 20 ether);
        assertEq(stakingPool.balanceOf(buyer), 0);
        vm.stopPrank();

        vm.startPrank(buyer2);
        stakingPool.unstake(100 ether);
        assertEq(kkToken.balanceOf(buyer2), 8 ether + 20 ether);
        assertEq(stakingPool.balanceOf(buyer2), 0);



    }


    function test_stake() public {
        vm.startPrank(buyer);

        vm.expectRevert("amount must be greater than 0");
        stakingPool.stake{value: 0 ether}();
        uint256 rewardDebt;
        uint256 rewardDebt2;
        (, rewardDebt) =  stakingPool.stakingBalance(buyer);
        uint256 accKKPerShare;

// buyer 第一次质押
        stakingPool.stake{value: 100 ether}();
        assertEq(stakingPool.balanceOf(buyer), 100 ether);
        assertEq(stakingPool.lastRewardBlock(), block.number);
        assertEq(stakingPool.getMultiplier(), 0);
        assertEq(stakingPool.accKKPerShare(), 0);
        assertEq(stakingPool.totalEth(), 100 ether);
        assertEq(kkToken.totalSupply(), 0);
        assertEq(rewardDebt, 0);

        // buyer 第二次质押
        vm.roll(block.number + 2);

        assertEq(stakingPool.getMultiplier(), 2*BONUS_MULTIPLIER);

        stakingPool.stake{value: 50 ether}();
        (, rewardDebt) =  stakingPool.stakingBalance(buyer);

        assertEq(stakingPool.balanceOf(buyer), 150 ether);
        assertEq(stakingPool.lastRewardBlock(), block.number);
        // 根据代码逻辑，因为是先计算acc，再把用户的eth加到 totalEth 和 uer.amount，所以这里的 totalEth 是100 ether，
        accKKPerShare = getAccKKPerShare(2*BONUS_MULTIPLIER, 100 ether);
        assertEq(stakingPool.accKKPerShare(),accKKPerShare);
        
        assertEq(stakingPool.totalEth(), 150 ether);
        assertEq(kkToken.totalSupply(), 20 ether);
        assertEq(rewardDebt, 150 ether * accKKPerShare / 1e12);
        
        vm.stopPrank();

        vm.roll(block.number + 1);
        assertEq(stakingPool.getMultiplier(), 10 ether);

// buyer2，第一次质押
        vm.startPrank(buyer2);
        vm.expectRevert("amount must be greater than 0");
        stakingPool.stake{value: 0 ether}();

        stakingPool.stake{value: 100 ether}();
        (, rewardDebt2) =  stakingPool.stakingBalance(buyer2);

        assertEq(stakingPool.balanceOf(buyer2), 100 ether);
        accKKPerShare += getAccKKPerShare(1*BONUS_MULTIPLIER, 150 ether);

        assertEq(stakingPool.accKKPerShare(), accKKPerShare);
        assertEq(stakingPool.totalEth(), 250 ether);
        assertEq(kkToken.totalSupply(), 30 ether);
        assertEq(rewardDebt2, 100 ether * accKKPerShare / 1e12);
        
        
        

        
    }



    function test_updatePoolAndEarnedAndClaim() public {
        assertEq(stakingPool.lastRewardBlock(),1);
        stakingPool.updatePool();
        assertEq(stakingPool.lastRewardBlock(), 1);

        assertEq(stakingPool.earned(buyer), 0);

        vm.expectRevert("account is not the zero address");
        stakingPool.earned(address(0));
        

        vm.startPrank(buyer);
        stakingPool.stake{value: 50 ether}();
        vm.roll(block.number + 1);
        assertEq(stakingPool.getMultiplier(), 10 ether);


        stakingPool.updatePool();
        assertEq(kkToken.totalSupply(), 10 ether);

        uint256 accKKPerShare;
        accKKPerShare = getAccKKPerShare(10 ether, 50 ether);

        assertEq(stakingPool.accKKPerShare(), accKKPerShare);
        assertEq(stakingPool.lastRewardBlock(), 2);
        assertEq(stakingPool.earned(buyer), 10 ether);

        vm.stopPrank();

//  第二个用户质押
        vm.startPrank(buyer2);
        stakingPool.stake{value: 350 ether}();
        vm.roll(block.number + 5);
        assertEq(stakingPool.getMultiplier(), 50 ether);

        stakingPool.updatePool();
        assertEq(kkToken.totalSupply(), 60 ether);

        accKKPerShare += getAccKKPerShare(50 ether, 400 ether);
        assertEq(stakingPool.accKKPerShare(), accKKPerShare);
        assertEq(stakingPool.lastRewardBlock(), 7);

        assertEq(stakingPool.earned(buyer), accKKPerShare * 50 ether / 1e12);

        (, uint rewardDebt2) =  stakingPool.stakingBalance(buyer2);
        assertEq(stakingPool.earned(buyer2), accKKPerShare *350 ether / 1e12 - rewardDebt2);
        vm.stopPrank();

        vm.startPrank(buyer);
// 领取 buyer  的KK Token收益
        stakingPool.claim();
        assertEq(kkToken.balanceOf(buyer), accKKPerShare * 50 ether / 1e12);
        vm.stopPrank();


        vm.startPrank(buyer2);
// 领取 buyer2  的KK Token收益
        stakingPool.claim();
        assertEq(kkToken.balanceOf(buyer2), accKKPerShare * 350 ether / 1e12 - rewardDebt2);
        vm.stopPrank();


        
    }



    function test_getMultiplier() public {
        assertEq(stakingPool.getMultiplier(), 0);
        vm.roll(block.number + 2);
        assertEq(stakingPool.getMultiplier(), 2*BONUS_MULTIPLIER);
        vm.roll(block.number + 8);
        assertEq(stakingPool.getMultiplier(), 10*BONUS_MULTIPLIER);
    }


    function test_balanceOf() public {
        assertEq(stakingPool.balanceOf(user1), 0);
        vm.startPrank(user1);
        stakingPool.stake{value: 100 ether}();
        vm.stopPrank();
        assertEq(stakingPool.balanceOf(user1), 100 ether);


        vm.startPrank(user2);
        stakingPool.stake{value: 90 ether}();
        vm.stopPrank();
        assertEq(stakingPool.balanceOf(user2), 90 ether);

    }

    function getAccKKPerShare(uint256 reward, uint256 totalEth) public view returns (uint256) {
        return reward * 1e12 / totalEth;
    }









}
