// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import  "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract CallOptionToken is ERC20 {
    IUniswapV2Router02 public immutable uniswapV2Router;


    // 行权价格
    uint256 public immutable strikePrice;


    // 标的（ETH）
    // uint256 public underlyingETH;

    // 行权日期,一年后
    uint256 public immutable expiry ;

// 模拟USDC
    IERC20 public usdt; 

    // uint256 public constant DECIMALS = 18;
    address public immutable owner;

    constructor(uint256 _strikePrice,address _usdt,address _uniswapV2Router) ERC20("COToken", "COToken") {
        require(_strikePrice > 0, "Strike price must be greater than 0");
        require(_usdt != address(0), "Invalid usdt address");
        require(_uniswapV2Router != address(0), "Invalid uniswapV2Router address");
        usdt = IERC20(_usdt);

        uniswapV2Router = IUniswapV2Router02(_uniswapV2Router);
        address weth = uniswapV2Router.WETH();
        address factory = uniswapV2Router.factory();
        address pair = IUniswapV2Factory(factory).getPair(weth, _usdt);
        require(pair != address(0), "pair not exists");

// TODO 添加流动性，比例未确认，还有 router的approve
        uniswapV2Router.addLiquidityETH ( _usdt, 1000000000000000000, 0, 0, address(this), block.timestamp + 600 seconds);

        (uint112 r0, uint112 r1,) = IUniswapV2Pair(pair).getReserves();
        require(r0 > 0 && r1 > 0, "no liquidity in pair");
        owner = msg.sender;
// 行权价格
        strikePrice = _strikePrice*10**18;
        expiry = block.timestamp + 365 days;

    }

// 销毁期权 token,赎回标的资产
    function burnOption() external onlyOwner {
        require(block.timestamp >= expiry + 2 days, "Not after expiry");
        uint ethAmount = address(this).balance;
        (bool success, ) = payable(owner).call{value: ethAmount}("");
        require(success, "Transfer eth failed");
    }

// 行权,每个token期权价值 strikePrice usdt
    function exerciseOption() external onlyAfterExpiry {
        require(balanceOf(msg.sender) > 0, "You don't have any option to exercise");
        uint balanceToken = balanceOf(msg.sender);
        require(address(this).balance >= balanceToken, "Insufficient eth balance");

        // 从用户账户中转移usdt到合约账户
        bool success = usdt.transferFrom(msg.sender, address(this), balanceToken*strikePrice / 1e18);
        require(success, "Transfer usdt failed");
        // 销毁期权 token
        _burn(msg.sender, balanceToken);

        // 将usdt 1:1 的 eth发送到用户账户
        (bool success2, ) = payable(msg.sender).call{value: balanceToken}("");
        require(success2, "Transfer eth failed");
    }

// 发行方法
    function mint(address to) external onlyOwner payable {
        require(msg.value > 0, "Amount must be greater than 0");
        require(to != address(0), "Invalid address");
        // eth 1:1 token发行
        uint amount = msg.value;
        _mint(to, amount);
        // underlyingETH += amount;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

// 到期日当天可以行权
    modifier onlyAfterExpiry() {
        require(block.timestamp >= expiry && block.timestamp < expiry + 1 days, "Only after expiry can call this function");
        _;
    }

    receive() external payable {}





}




