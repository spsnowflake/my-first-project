// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console2} from "../lib/forge-std/src/Script.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract DeployUniswapScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(deployerPrivateKey);

        IERC20 token1 = IERC20(vm.envAddress("MyToken1"));
        IERC20 token2 = IERC20(vm.envAddress("MyToken2"));

        vm.startBroadcast(deployerPrivateKey);

        address weth = deployCode("WETH9.sol:WETH9");

        address factory1 = deployCode("UniswapV2Factory.sol:UniswapV2Factory", abi.encode(owner));
        address router1 = deployCode("UniswapV2Router02.sol:UniswapV2Router02", abi.encode(factory1, weth));

        address factory2 = deployCode("UniswapV2Factory.sol:UniswapV2Factory", abi.encode(owner));
        address router2 = deployCode("UniswapV2Router02.sol:UniswapV2Router02", abi.encode(factory2, weth));

        _addPool(token1, token2, router1, owner, 100 * 1e18, 200 * 1e18);
        _addPool(token1, token2, router2, owner, 150 * 1e18, 200 * 1e18);

        vm.stopBroadcast();

        console2.log("WETH", weth);
        console2.log("Factory1", factory1);
        console2.log("Router1", router1);
        console2.log("Pair1", IUniswapV2Factory(factory1).getPair(address(token1), address(token2)));
        console2.log("Factory2", factory2);
        console2.log("Router2", router2);
        console2.log("Pair2", IUniswapV2Factory(factory2).getPair(address(token1), address(token2)));
    }

    function _addPool(
        IERC20 tokenA,
        IERC20 tokenB,
        address router,
        address lpOwner,
        uint256 amountA,
        uint256 amountB
    ) internal {
        tokenA.approve(router, amountA);
        tokenB.approve(router, amountB);
        IUniswapV2Router02(router).addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA,
            amountB,
            0,
            0,
            lpOwner,
            block.timestamp + 600
        );
    }
}
