// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console2} from "../lib/forge-std/src/Script.sol";
// import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
// import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
// import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FlashSwap} from "../src/FlashSwap.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FlashSwapScript is Script {
    function run() public {

        // 其他账户私钥，其他账户来执行闪电贷 闪电兑换
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY2");
        address pair1 = vm.envAddress("Pair1");
        address owner = vm.addr(deployerPrivateKey);
        // IERC20 token1 = IERC20(vm.envAddress("MyToken1"));
        IERC20 token2 = IERC20(vm.envAddress("MyToken2"));
        address factory1 = vm.envAddress("Factory1");
        address router2 = vm.envAddress("Router2");

        vm.startBroadcast(deployerPrivateKey);


        FlashSwap flashSwap = new FlashSwap(factory1, router2);

        console2.log("FlashSwap deployed", address(flashSwap));

        flashSwap.flashSwap(pair1, address(token2), 10 * 1e18);

        console2.log("flashSwap tx done");

        vm.stopBroadcast();



    }
}