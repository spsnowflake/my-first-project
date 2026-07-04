// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console2} from "../lib/forge-std/src/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";





contract QueryERC20BalanceScript is Script {
    function run() public {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY2");
        address owner = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        IERC20 token1 = IERC20(vm.envAddress("MyToken1"));
        IERC20 token2 = IERC20(vm.envAddress("MyToken2"));

        uint256 balance1 = token1.balanceOf(owner);
        uint256 balance2 = token2.balanceOf(owner);

        console2.log("token1 balance", balance1);
        console2.log("token2 balance", balance2);

        vm.stopBroadcast();

    }
}












