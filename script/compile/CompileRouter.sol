// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.6;

import {UniswapV2Router02} from "@uniswap/v2-periphery/contracts/UniswapV2Router02.sol";

/// @dev Forces Foundry to compile UniswapV2Router02 for deployCode("UniswapV2Router02.sol:UniswapV2Router02")
contract CompileRouter {
    function deploy(address factory, address weth) external returns (address) {
        return address(new UniswapV2Router02(factory, weth));
    }
}
