// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.6;

import {WETH9} from "@uniswap/v2-periphery/contracts/test/WETH9.sol";

/// @dev Forces Foundry to compile WETH9 for deployCode("WETH9.sol:WETH9")
contract CompileWeth {
    function deploy() external returns (address) {
        return address(new WETH9());
    }
}
