// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.5.16;

import {UniswapV2Factory} from "@uniswap/v2-core/contracts/UniswapV2Factory.sol";

/// @dev Forces Foundry to compile UniswapV2Factory for deployCode("UniswapV2Factory.sol:UniswapV2Factory")
contract CompileFactory {
    function deploy(address feeToSetter) external returns (address) {
        return address(new UniswapV2Factory(feeToSetter));
    }
}
