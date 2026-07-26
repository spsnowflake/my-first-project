// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import  "@openzeppelin/contracts/token/ERC20/IERC20.sol";


// 极简的杠杆 DEX 实现
contract SimpleLeverageDEX {

    uint public vK;  // 100000 
    uint public vETHAmount;
    uint public vUSDCAmount;

    IERC20 public USDC;  // 创建一个币来模拟 USDC

    struct PositionInfo {
        uint256 margin; // 保证金，真实的资金， 如 USDC 
        uint256 borrowed; // 借入的资金
        int256 position;    // 虚拟 eth 持仓
    }
    mapping(address => PositionInfo) public positions;

    constructor(uint vEth, uint vUSDC) {
        vETHAmount = vEth;    // 100
        vUSDCAmount = vUSDC;  // 10000
        vK = vEth * vUSDC;

    }


    // 开启杠杆头寸
    function openPosition(uint256 _margin, uint level, bool long) external {
        require(positions[msg.sender].position == 0, "Position already open");

        PositionInfo storage pos = positions[msg.sender] ;

        USDC.transferFrom(msg.sender, address(this), _margin); // 用户提供保证金
        // 加杠杆后的总金额
        uint amount = _margin * level;   
        // require(int256(vETHAmount) > pos.position, "Not enough ETH to open position");

        // 借入的资金
        uint256 borrowAmount = amount - _margin;

        pos.margin = _margin;
        pos.borrowed = borrowAmount;

        // TODO:
        if (long) {
            uint256 vETH = vK / (vUSDCAmount += amount);
            require(vETH < vETHAmount, "Not enough ETH to open position");
            pos.position = int256(vETHAmount-vETH);
            vETHAmount = vETH;
        } else {
            require(vUSDCAmount > amount, "Not enough USDC to open position");
            uint256 vETH = vK / (vUSDCAmount -= amount);
            pos.position = -int256(vETH - vETHAmount);
            vETHAmount = vETH;
        }
        
    }

    // 关闭头寸并结算, 不考虑协议亏损
    function closePosition() external {
        // TODO:
        PositionInfo memory position = positions[msg.sender];
        require(position.position != 0, "No open position");
        int256 pnl = calculatePnL(msg.sender);
        int256 payout = int256(position.margin) + pnl;
        // 结算多头
        if(position.position > 0) {
            uint256 vETH = vETHAmount + uint256(position.position);
            vUSDCAmount = vK / vETH;
            vETHAmount = vETH;
        } else {
            // 结算空头
            uint256 vETH = uint256(int256(vETHAmount) + position.position);
            vUSDCAmount = vK / vETH;
            vETHAmount = vETH;
        }
        if (payout>0) {
            USDC.transfer(msg.sender, uint256(payout));
        }
        delete positions[msg.sender];
    }

    // 清算头寸， 清算的逻辑和关闭头寸类似，不过利润由清算用户获取
    // 注意： 清算人不能是自己，同时设置一个清算条件，例如亏损大于保证金的 80%
    function liquidatePosition(address _user) external {
        // TODO:
        require(msg.sender != _user, "Cannot liquidate yourself");
        PositionInfo memory position = positions[_user];
        require(position.position != 0, "No open position");
        int256 pnl = calculatePnL(_user);
        // 清算条件：必须是亏损
        require(pnl < 0, "Not enough loss to liquidate");

        require(-pnl>int256(position.margin) * 80 / 100, "Not enough loss to liquidate");

         // 结算多头,恢复池子
        if(position.position > 0) {
            uint256 vETH = vETHAmount + uint256(position.position);
            vUSDCAmount = vK / vETH;
            vETHAmount = vETH;
        } else {
         // 结算空头，恢复池子
            uint256 vETH = uint256(int256(vETHAmount) + position.position);
            vUSDCAmount = vK / vETH;
            vETHAmount = vETH;
        }
        // 清算用户获得的利润
        int256 payout = int256(position.margin) + pnl; 
        if (payout>0) {
            USDC.transfer(msg.sender, uint256(payout));
        }
        delete positions[_user];
    }

    // 计算盈亏： 对比当前的仓位和借的 vUSDC
    // 多头：当前价值 − 开仓价值；空头：开仓价值 − 当前价值
    function calculatePnL(address user) public view returns (int256) {
        // TODO:
        PositionInfo memory position = positions[user];
        // uint vUSDC = vK / (vETHAmount + uint256(position.position));
        // 开仓价值
            uint price = position.margin+position.borrowed ;

        if (position.position > 0) {
            return int256(vUSDCAmount) - int256(vK / (vETHAmount + uint256(position.position)))  - int256(price);
// 空头
        } else {
            return int256(price) - (int256(vK) / (int256(vETHAmount) + int256(position.position)) -int256(vUSDCAmount) );
            
        }
  

    }
}