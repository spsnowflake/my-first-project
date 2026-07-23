// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {KKToken} from "./KKToken.sol";
import {IStaking} from "./IStaking.sol";



contract StakingPool is IStaking{

    KKToken public immutable kkToken;
    uint256 public constant BONUS_MULTIPLIER = 10*1e18;
    mapping(address => UserInfo) public stakingBalance;

    // 最后结算奖励的区块
    uint256 public lastRewardBlock;

    // 池子总质押的eth数量
    uint256 public totalEth;    

// 每个eth可以拿到多少kkToken，带有1e12小数精度
    uint256 public accKKPerShare;

    struct UserInfo {
        // 用户质押的eth
        uint256 amount; 
        // 用户债务
        uint256 rewardDebt; 
    }


    constructor(address _kkToken){
        kkToken = KKToken(_kkToken);
        lastRewardBlock = block.number;
    }

    /**
     * @dev 质押 ETH 到合约
     */
    function stake()  payable external{
        require(msg.value > 0, "amount must be greater than 0");
        updatePool();

        UserInfo storage user = stakingBalance[msg.sender];

        // 如果用户之前就质押了，先结算KK Token收益
        if (user.amount > 0) {
            uint256 pending = user.amount * accKKPerShare / 1e12 - user.rewardDebt;
            if (pending > 0) kkToken.transfer(msg.sender, pending);
        }

        user.amount += msg.value;
        totalEth += msg.value;
        user.rewardDebt = user.amount * accKKPerShare / 1e12;

    }

// 获取奖励区间的kktoken数量
    function getMultiplier() public view returns (uint256){
        if (block.number <= lastRewardBlock) return 0;

        return (block.number - lastRewardBlock) * BONUS_MULTIPLIER;
    }


    /**
     * @dev 赎回质押的 ETH
     * @param amount 赎回数量
     */
    function unstake(uint256 amount) external{
        require(amount > 0, "amount must be greater than 0");
        UserInfo storage user = stakingBalance[msg.sender];
        require(user.amount >= amount, "insufficient balance");
        updatePool();
// 领取 KK Token 收益
        uint256 pending = user.amount * accKKPerShare / 1e12 - user.rewardDebt;
        if (pending > 0) kkToken.transfer(msg.sender, pending);

        totalEth -= amount;
        user.amount -= amount;
        user.rewardDebt = user.amount * accKKPerShare / 1e12;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "transfer failed");
    }

        /**
     * @dev 领取 KK Token 收益
     */
    function claim() external{
        UserInfo storage user = stakingBalance[msg.sender];
        updatePool();
        uint256 pending = user.amount * accKKPerShare / 1e12 - user.rewardDebt;
        if (pending > 0) kkToken.transfer(msg.sender, pending);
        user.rewardDebt = user.amount * accKKPerShare / 1e12;
    }

    /**
     * @dev 获取质押的 ETH 数量
     * @param account 质押账户
     * @return 质押的 ETH 数量
     */
    function balanceOf(address account) external view returns (uint256){
        return stakingBalance[account].amount;
    }

    /**
     * @dev 获取待领取的 KK Token 收益
     * @param account 质押账户
     * @return 待领取的 KK Token 收益
     */
    function earned(address account) external view returns (uint256){
        require(account != address(0), "account is not the zero address");
        uint256 reward = getMultiplier();
        if (totalEth == 0) {
            return 0;
        }
        uint256 acc = accKKPerShare + reward * 1e12 / totalEth;
        return stakingBalance[account].amount * acc / 1e12 - stakingBalance[account].rewardDebt;
    }


// 更新池子状态
    function updatePool() public{
        if (block.number <= lastRewardBlock) return;
        if (totalEth == 0) {
            lastRewardBlock = block.number;
            return;
        }
        uint256 reward = getMultiplier();
        // 铸造到池子，再按份额分给用户
        kkToken.mint(address(this), reward);
        accKKPerShare += reward * 1e12 / totalEth;
        lastRewardBlock = block.number;
    }


    receive() external payable {
        revert("Use stake() to deposit ETH");
    }
    
    
}












