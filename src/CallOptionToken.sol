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
    bool private _initialized = false;

    constructor(uint256 _strikePrice,address _usdt,address _uniswapV2Router) ERC20("COToken", "COToken") {
        require(_strikePrice > 0, "Strike price must be greater than 0");
        require(_usdt != address(0), "Invalid usdt address");
        require(_uniswapV2Router != address(0), "Invalid uniswapV2Router address");
        uniswapV2Router = IUniswapV2Router02(_uniswapV2Router);

        owner = msg.sender;
        usdt = IERC20(_usdt);

// 行权价格
        strikePrice = _strikePrice*10**18;
        expiry = block.timestamp + 365 days;

    }

// 初始化流动性
    function initLiquidity() external payable onlyOwner {
        require(!_initialized, "Already initialized");
        require(msg.value > 0, "Amount must be greater than 0");
        _initialized = true;
// 初始化router
        address factory = uniswapV2Router.factory();

// 数量上 eth 和 cotoken 1:1
        uint amountCOToken = msg.value;
        uint amountUSDT = amountCOToken*100;
        _mint(address(this), amountCOToken);
        _approve(address(this), address(uniswapV2Router), amountCOToken);
        // require(approveSuccess1, "approveSuccess1 failed");

        // owner需要先approve usdt到合约账户
        bool success = usdt.transferFrom(owner, address(this), amountUSDT);
        require(success, "Transfer usdt failed");

        bool approveSuccess2 = usdt.approve(address(uniswapV2Router), amountUSDT);
        require(approveSuccess2, "approveSuccess2 failed");
        address _usdt = address(usdt);

// 初始化流动性
        // (uint256 realAmountToken, uint256 realAmountETH, uint256 liquidity) = uniswapV2Router.addLiquidity ( _usdt,address(this), 5000*1e18, 50*1e18, 10*1e18, 1*1e17, address(this), block.timestamp + 600 seconds);
        uniswapV2Router.addLiquidity( _usdt,address(this), amountUSDT, amountCOToken, 10*1e18, 1*1e17, address(this), block.timestamp + 600 seconds);

        address pair = IUniswapV2Factory(factory).getPair( _usdt,address(this));
        require(pair != address(0), "pair not exists");
        (uint112 r0, uint112 r1,) = IUniswapV2Pair(pair).getReserves();
        require(r0 > 0 && r1 > 0, "no liquidity in pair");
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
        // 合约eth余额需要大于等于期权数量
        require(address(this).balance >= balanceToken, "Insufficient eth balance");

        // 从用户账户中转移usdt到合约账户。
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




