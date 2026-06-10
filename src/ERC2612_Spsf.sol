// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract ERC2612_Spsf is ERC20Permit {
    constructor() ERC20("ERC2612_Spsf", "ERC2612_Spsf") ERC20Permit("ERC2612_Spsf") {
        _mint(msg.sender, 1000 * 10 ** 18);
    }















}