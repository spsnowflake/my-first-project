// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/IERC20Interface.sol";

contract Vesting {
    IERC20 public immutable erc20;

    // 受益人
    address public immutable beneficiary;

    address public immutable owner;

    // 首次解锁等待期
    uint256 public immutable Cliff = 365 days;

    // 初始化时间
    uint256 public immutable initialTime;

    // 初始合约份额
    uint256 public initialAmount;

    // 已释放份额
    uint256 public releasedAmount;

    // 已解锁次数
    uint256 public releaseCount;



    constructor(IERC20 _erc20, address _beneficiary) {
        require(address(_erc20) != address(0), "ERC20 address is 0");
        require(_beneficiary != address(0), "Beneficiary address is 0");
        erc20 = _erc20;
        beneficiary = _beneficiary;
        owner = msg.sender;
        initialTime = block.timestamp;
    }

    // 释放当前解锁的 ERC20 给受益人
    function release() external returns (bool) {
        require(initialAmount > 0, "Initial amount not set");
        require(block.timestamp >= initialTime + Cliff, "Cliff not reached");
        require(releaseCount < 24, "Release count reached");
        require(releasedAmount < initialAmount, "Released amount reached");

        uint256 count = calculateReleaseCount();

        require(count > 0, "No release count");

        //     计算当前要释放的份额
        uint256 Amount = initialAmount * count / 24;

// 如果已释放份额 + 本次要释放的份额 > 初始份额，或者已释放次数 + 本次要释放的次数 >= 24，则释放剩余份额
        if (releasedAmount + Amount > initialAmount || releaseCount + count >=24) {
            Amount = initialAmount - releasedAmount;
        }

        releasedAmount += Amount;
        releaseCount += count;
        bool result =erc20.transfer(beneficiary, Amount);
        require(result, "transfer is false");
        return true;
    }

    // 计算本次需要解锁的次数
    function calculateReleaseCount() internal view returns (uint256) {
        // 先计算到今天为止理论上要解锁的次数，最多24次
        uint256 countTotal = (block.timestamp - initialTime - Cliff) / 30 days;
        if (countTotal > 24) {
            countTotal = 24;
        }
        return countTotal-releaseCount;
    }

    // 初始化合约份额 100W
    function depositInitialAmount(uint256 _initialAmount) external returns (bool) {
        require(msg.sender == owner, "Only owner can set initial amount");
        require(_initialAmount == 1000000 * 10 ** 18, "Initial amount must be 1000000 *10**18");
        require(initialAmount==0, "Initial amount already set");
        bool result = erc20.transferFrom(msg.sender, address(this), _initialAmount);
        require(result, "transferFrom is false");
        initialAmount = _initialAmount;
        return true;
    }
}
