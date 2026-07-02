// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IUniswapV2Callee} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {UniswapV2Library} from "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FlashSwap is IUniswapV2Callee {

    address public immutable factory;
    address public immutable router2;
    address public immutable owner;

    constructor(address _factory,address _router2) {
        factory = _factory;
        router2 = _router2;
        owner = msg.sender;
    }


// 闪电贷，先借token0，然后回调uniswapV2Call，然后还款
    function flashSwap(address pair,address borrowToken,uint amount) external {

        require(amount > 0,"Amount must be greater than 0");
        require(pair != address(0),"Pair must be set");
        require(borrowToken != address(0),"Borrow token must be set");

        address token0 = IUniswapV2Pair(pair).token0();
        if (token0 == borrowToken) {
            IUniswapV2Pair(router2).swap(amount,0,address(this),new bytes(0x11));
        }else {
            IUniswapV2Pair(router2).swap(0,amount,address(this),new bytes(0x11));
        }

    }

// 还款闪电贷，回调函数
    function uniswapV2Call(address sender,uint amount0,uint amount1,bytes calldata data) external override {
        require(amount0 == 0 || amount1 == 0,"Amount0 or amount1 must be 0");

        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();

        require(UniswapV2Library.pairFor(factory,token0,token1) == msg.sender,"Invalid pair");

        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));

// 如果收到token0，则兑换token1
        if(balance0 > 0) {

            address[] memory path = new address[](2);
            path[0] = token1;
            path[1] = token0;
            uint[] memory amounts = UniswapV2Library.getAmountsIn(factory,balance0,path);

            // 需要还的token1数量
            uint amountReadyToekn1 = amounts[0];

            // 兑换token1
            IERC20(token0).approve(router2,amountReadyToekn1*2);
            path[0] = token0;
            path[1] = token1;
            uint[] memory amountsOut = IUniswapV2Router02(router2).swapExactTokensForTokens(balance0,0,path,address(this),block.timestamp+60);

            // 换出来的token1数量
            uint amountToken1 = amountsOut[1];

//          判断是否能够获利
            require(amountToken1 > amountReadyToekn1,"Not enough profit");

            // 还款
            bool success = IERC20(token1).transfer(msg.sender,amountReadyToekn1);
            // 还款失败
            require(success,"Repay failed");

            // 获利
            uint profit = amountToken1 - amountReadyToekn1;
            IERC20(token1).transfer(owner,profit);
        }

        // 如果收到token1，则兑换token0
        if(balance1 > 0) {
            address[] memory path = new address[](2);
            path[0] = token0;
            path[1] = token1;
            uint[] memory amounts = UniswapV2Library.getAmountsIn(factory,balance1,path);

            // 需要还的token0数量
            uint amountReadyToekn0 = amounts[0];

            // 兑换token0
            IERC20(token1).approve(router2,amountReadyToekn0*2);
            path[0] = token1;
            path[1] = token0;
            uint[] memory amountsOut = IUniswapV2Router02(router2).swapExactTokensForTokens(balance1,0,path,address(this),block.timestamp+60);

            // 换出来的token0数量
            uint amountToken0 = amountsOut[1];

//          判断是否能够获利
            require(amountToken0 > amountReadyToekn0,"Not enough profit");

            // 还款
            bool success = IERC20(token0).transfer(msg.sender,amountReadyToekn0);
            // 还款失败
            require(success,"Repay failed");

            // 获利
            uint profit = amountToken0 - amountReadyToekn0;
            IERC20(token0).transfer(owner,profit);
            
        }

    }







}








