// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {TokenBank2} from "src/TokenBank2.sol";
import {IERC20} from "src/IERC20Interface.sol";

contract BankUpkeep {
    TokenBank2 public immutable bank;
    IERC20 public immutable token;
    uint256 public immutable threshold;

    // Gelato dedicatedMsgSender 地址
    address public gelatoSender;

    // 绑定 TokenBank2 与触发阈值
    constructor(TokenBank2 _bank, uint256 _threshold) {
        bank = _bank;
        token = _bank.erc20_address();
        threshold = _threshold;
    }

    // 设置 Gelato dedicated sender（仅 TokenBank2 owner）
    function setGelatoSender(address _sender) external {
        require(msg.sender == bank.bankOwner(), "not owner");
        gelatoSender = _sender;
    }

    // Gelato 周期性调用，检查 Bank 代币余额是否超过阈值
    function checker() external view returns (bool canExec, bytes memory execPayload) {
        if (token.balanceOf(address(bank)) <= threshold) {
            return (false, bytes("balance not above threshold"));
        }
        execPayload = abi.encodeCall(this.performUpkeep, (""));
        return (true, execPayload);
    }

    // Gelato 实际执行，再次校验后触发 Bank 转出半数代币
    function performUpkeep(bytes calldata) external {
        require(msg.sender == gelatoSender, "not gelato");
        require(token.balanceOf(address(bank)) > threshold, "condition not met");
        bank.withdrawHalfToOwner();
    }
}
