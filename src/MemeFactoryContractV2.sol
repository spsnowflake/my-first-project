// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./MemeV2.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract MemeFactoryContractV2 {
    // 合约母体地址，克隆合约专用
    address public immutable memeTokenImplementation;
    IUniswapV2Router02 public immutable uniswapV2Router;
    // 项目方地址
    address public projectOwner;

// 流动性凭证
    mapping(address => uint256) public liquidityOfToken;

    // 记录每个 Token 地址是否由本工厂创建，防止传入恶意合约
    mapping(address => bool) public isMemeToken;

    event MemeDeployed(
        address indexed tokenAddr,
        address indexed issuer,
        string  symbol,
        uint256 totalSupply,
        uint256 perMintAmount,
        uint256 mintPrice
    );

    event MemeMinted(
        address indexed tokenAddr,
        address indexed minter,
        uint256 amount,
        uint256 price
    );

    event LiquidityAdded(
        address indexed tokenAddr,
        uint256 realAmountToken,
        uint256 realAmountETH,
        uint256 liquidity
    );
    event BuyMeme(
        address indexed tokenAddr,
        address indexed buyer,
        uint256 amount,
        uint256 price
    );

// 初始化
    constructor(address _uniswapV2Router) {
        memeTokenImplementation = address(new MemeV2());
        projectOwner = msg.sender;
        uniswapV2Router = IUniswapV2Router02(_uniswapV2Router);
    }

    // 部署 Meme 合约
    function deployMeme(string memory name,string memory symbol, uint totalSupply, uint perMint, uint price) public returns (address) {
        require(bytes(name).length > 0, "Name is required");
        require(bytes(symbol).length > 0, "Symbol is required");
        require(totalSupply > 0, "Total supply must be greater than 0");
        require(perMint > 0, "Per mint must be greater than 0");
        // 每次铸造数量不能超过总发行量
        require(perMint <= totalSupply, "Per mint must be less than or equal to total supply");

        // 克隆 Meme 合约
        MemeV2 memeToken = MemeV2(Clones.clone(memeTokenImplementation));
        // 初始化 Meme 合约
        memeToken.initialize(name, symbol, totalSupply, perMint, price, msg.sender);
        // 记录 token 地址是否由本工厂创建
        isMemeToken[address(memeToken)] = true;
        emit MemeDeployed(address(memeToken), msg.sender, symbol, totalSupply, perMint, price);
        return address(memeToken);
    }

    // 铸造 Meme （购买meme代币）
    function mintMeme(address tokenAddr) public payable {
        require(isMemeToken[tokenAddr], "Token is not deployed by this factory");
        MemeV2 token = MemeV2(tokenAddr);

        // 计算本次铸造需支付费用
        uint256 totalCost = token.mintPrice() * token.perMintAmount() / 1e18;
        require(msg.value >= totalCost, "Insufficient funds");
        

        // 分配费用
        // 单位费用 1%
        uint256 unitFee = totalCost / 100;           // 1%
        // 手续费用 5%
        uint256 projectFee = unitFee*5;           // 5%

        // 剩余费用 95%
        uint256 issuerFee  = totalCost - projectFee;    // 95%

        (bool success2, ) = payable(token.issuer()).call{value: issuerFee}("");
        require(success2, "Transfer to issuer failed");


        // 计算token数量
        uint256 tokenAmount = projectFee*1e18 / token.mintPrice();

//     铸造后转给工厂
        token.mintToFactory(address(this), tokenAmount);

        // 授权流动性合约
        token.approve(address(uniswapV2Router), tokenAmount);
        // 添加流动性
        (uint256 realAmountToken, uint256 realAmountETH, uint256 liquidity) = IUniswapV2Router02(uniswapV2Router).addLiquidityETH{value: projectFee}(
            address(token),
            tokenAmount,
            tokenAmount*30/100,
            projectFee*30/100,
            address(this),
            block.timestamp+600 // 600秒后过期
        );
        liquidityOfToken[tokenAddr] += liquidity;

        // 铸造，Token 进入用户钱包
        token.mint(msg.sender);

        // 如果用户多付了 ETH，退还多余部分
        uint256 refund = msg.value - totalCost;
        if (refund > 0) {
            // payable(msg.sender).transfer(refund);
            (bool success3, ) = payable(msg.sender).call{value: refund}("");
            require(success3, "Transfer to msg.sender failed");
        }
        emit LiquidityAdded(tokenAddr, realAmountToken, realAmountETH, liquidity);
        emit MemeMinted(tokenAddr,  msg.sender, token.perMintAmount(), totalCost);

    }

// 从池子中购买Token,token数量用户手动输入
    function buyMeme(address tokenAddr,uint256 amountToken) public payable {
        require(msg.value > 0, "Amount must be greater than 0");
        require(tokenAddr!=address(0), "Token address cannot be 0");
        require(isMemeToken[tokenAddr], "Token is not deployed by this factory");
        MemeV2 token = MemeV2(tokenAddr);
        // uint256 amountToken = token.perMintAmount();

        // 获取池子中token的储备量，如果储备量小于用户输入的token数量，则不允许购买
        (uint256 tokenReserve,) = getPoolTokenReserve(tokenAddr);
        require(tokenReserve > 0, "Token reserve is 0");
        require(amountToken <= tokenReserve, "Amount token is greater than token reserve");


// 计算从池子中购买 amountToken 个 Token 需要支付的ETH数量
        address[] memory path = new address[](2);
        path[0] = address(uniswapV2Router.WETH());
        path[1] = tokenAddr;
        uint256[] memory amounts = IUniswapV2Router02(uniswapV2Router).getAmountsIn(amountToken,path);
        uint256 uniswapAmountETH = amounts[0];

// 正常铸造需要花费的金额
        uint256 totalCost = token.mintPrice() * amountToken / 1e18;

// 如果池子的token价格比铸造价格低，则允许购买
        require(uniswapAmountETH < totalCost, "Uniswap price not better than mint price");

        require(msg.value >= uniswapAmountETH, "Insufficient funds");
        uint256[] memory amountsSwapToken = IUniswapV2Router02(uniswapV2Router).swapETHForExactTokens{value: msg.value}(
                    amountToken,
                    path,
                    msg.sender,
                    block.timestamp+600 // 600秒后过期
                );

        uint256 realCostAmountETH = amountsSwapToken[0];
        
        // 如果用户多付了 ETH，退还多余部分
        uint256 refund = msg.value - realCostAmountETH;
        if (refund > 0) {
            (bool success3, ) = payable(msg.sender).call{value: refund}("");
            require(success3, "Transfer to msg.sender failed");
        }
        emit BuyMeme(tokenAddr, msg.sender, amountToken, realCostAmountETH);
    }


// 获取池子中token和eth的储备量
    function getPoolTokenReserve(address tokenAddr) public view returns (uint256 tokenReserve, uint256 ethReserve) {
        address weth = uniswapV2Router.WETH();
        address factory = uniswapV2Router.factory();

        address pair = IUniswapV2Factory(factory).getPair(tokenAddr, weth);
        require(pair != address(0), "pair not exists");

        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pair).getReserves();

        address token0 = IUniswapV2Pair(pair).token0();

        if (token0 == tokenAddr) {
            tokenReserve = reserve0;
            ethReserve   = reserve1;
        } else {
            tokenReserve = reserve1;
            ethReserve   = reserve0;
        }
    }

    receive() external payable {}

    fallback() external payable {}




}
