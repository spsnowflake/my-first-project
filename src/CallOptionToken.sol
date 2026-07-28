// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";






contract CallOptionToken is ERC20 {

    // 标的价格
    uint256 public immutable strikePrice;

    // 标的（ETH）
    uint256 public immutable underlyingETH;

    // 行权日期
    uint256 public immutable expiry;

    uint256 public constant DECIMALS = 18;
    address public immutable owner;
    constructor() ERC20("COToken", "COToken") {
        owner = msg.sender;

    }





}




