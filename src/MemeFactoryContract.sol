// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./Meme.sol";

contract MemeFactoryContract {
    // 合约母体地址，克隆合约专用
    address public immutable memeTokenImplementation;
    // 项目方地址，收取每次铸造费用的 1%
    address public projectOwner;
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

// 初始化
    constructor() {
        memeTokenImplementation = address(new Meme());
        projectOwner = msg.sender;
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
        Meme memeToken = Meme(Clones.clone(memeTokenImplementation));
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
        Meme token = Meme(tokenAddr);

        // 计算本次铸造需支付费用
        uint256 totalCost = token.mintPrice() * token.perMintAmount() / 1e18;
        require(msg.value >= totalCost, "Insufficient funds");
        
        // 铸造，Token 进入用户钱包
        token.mint(msg.sender);

        // 分配费用
        uint256 projectFee = totalCost / 100;           // 1%
        uint256 issuerFee  = totalCost - projectFee;    // 99%
        // payable(projectOwner).transfer(projectFee);
        (bool success1, ) = payable(projectOwner).call{value: projectFee}("");
        require(success1, "Transfer to projectOwner failed");
        (bool success2, ) = payable(token.issuer()).call{value: issuerFee}("");
        require(success2, "Transfer to issuer failed");

        // 如果用户多付了 ETH，退还多余部分
        uint256 refund = msg.value - totalCost;
        if (refund > 0) {
            // payable(msg.sender).transfer(refund);
            (bool success3, ) = payable(msg.sender).call{value: refund}("");
            require(success3, "Transfer to msg.sender failed");

        }

        emit MemeMinted(tokenAddr, msg.sender, token.perMintAmount(), totalCost);
    }


}
