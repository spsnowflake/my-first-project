// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {MemeFactoryContractV2} from "./MemeFactoryContractV2.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
// import {UniswapV2OracleLibrary} from "@uniswap/v2-periphery/contracts/libraries/UniswapV2OracleLibrary.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract LaunchPadTWAP {
    MemeFactoryContractV2 public immutable memeFactoryContract;

    IUniswapV2Router02 public immutable uniswapV2Router;

    address public immutable pair;

    address public immutable tokenAddr;

    uint256 public constant PERIOD = 12 hours;

    uint256 public weiPerToken; // TWAP价格


    // 最后计算出的token价格
    uint256 public priceCumulativeLast;

    // 最后计算出token价格的时间戳
    uint32 public blockTimestampLast;

    constructor(MemeFactoryContractV2 _memeFactoryContract, address _tokenAddr) {
        require(_memeFactoryContract.isMemeToken(_tokenAddr), "not a meme token");
        memeFactoryContract = _memeFactoryContract;
        uniswapV2Router = memeFactoryContract.uniswapV2Router();
        address weth = uniswapV2Router.WETH();
        address factory = uniswapV2Router.factory();
        tokenAddr = _tokenAddr;
        pair = IUniswapV2Factory(factory).getPair(_tokenAddr, weth);
        require(pair != address(0), "pair not exists");
        (uint112 r0, uint112 r1,) = IUniswapV2Pair(pair).getReserves();
        require(r0 > 0 && r1 > 0, "no liquidity in pair");
    }

// 更新TWAP价格
    function update() public returns (uint256 priceAverage) {
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) = _currentCumulativePrices(pair);
        address token0 = IUniswapV2Pair(pair).token0();

        if (priceCumulativeLast == 0 && blockTimestampLast == 0) {
            if (token0 == tokenAddr) {
                priceCumulativeLast = price0Cumulative;
            } else {
                priceCumulativeLast = price1Cumulative;
            }
            blockTimestampLast = blockTimestamp;
            return 0;
        }
        // 时间差
        uint256 timeElapsed = blockTimestamp - blockTimestampLast;
        require(timeElapsed >= PERIOD, "timeElapsed < PERIOD");
        // (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pair).getReserves();
        if (token0 == tokenAddr) {
            priceAverage = (price0Cumulative - priceCumulativeLast) / timeElapsed;
            priceCumulativeLast = price0Cumulative;
            blockTimestampLast = blockTimestamp;
        } else {
            priceAverage = (price1Cumulative - priceCumulativeLast) / timeElapsed;
            priceCumulativeLast = price1Cumulative;
            blockTimestampLast = blockTimestamp;
        }

        weiPerToken = (priceAverage * 1e18) >> 112;

        return weiPerToken;
    }

// 获取TWAP价格
    function getTwapPrice() public view returns (uint256) {
        return weiPerToken;
    }


// 计算购买 amountToken 个 token 需要支付的 ETH 数量
    function consult(uint256 amountToken) external view returns (uint256 amountEth) {
        return (getTwapPrice() * amountToken) / 1e18;
}

//    获取当前累计价格 ，用于计算TWAP价格
    function _currentCumulativePrices(address pairAddress)internal view returns (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp){
        blockTimestamp = uint32(block.timestamp % 2 ** 32);
        price0Cumulative = IUniswapV2Pair(pairAddress).price0CumulativeLast();
        price1Cumulative = IUniswapV2Pair(pairAddress).price1CumulativeLast();

        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast_) =
            IUniswapV2Pair(pairAddress).getReserves();

        if (blockTimestampLast_ != blockTimestamp) {
            uint32 timeElapsed = blockTimestamp - blockTimestampLast_;
            price0Cumulative += ((uint256(reserve1) << 112) / reserve0) * timeElapsed;
            price1Cumulative += ((uint256(reserve0) << 112) / reserve1) * timeElapsed;
        }
    }


}
