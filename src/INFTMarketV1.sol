// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/IERC20Interface.sol";
import "src/IERC721Interface.sol";

interface INFTMarketV1 {
    // tokenId 对应的上架信息：价格 + 卖家
    struct Listing {
        uint96 price;
        address seller;
    }
    // 卖家上架 NFT 时触发
    event List(uint256 tokenId, address sellPeople, uint256 amount);
    // 买家购买 NFT 成功时触发
    event BuyNFT(address buyer, uint256 tokenId, uint256 amount);
    // ERC20 回调方式购买成功时触发
    event PurchaseViaERC20Callback(address buyer, uint256 tokenId, uint256 amount);


    // 查询 tokenId 的上架信息
    function tokenListing(uint256 tokenId) external view returns (uint96 price, address seller);

    // 查询 tokenId 的 permitBuyNFT nonce
    function buyNonces(uint256 tokenId) external view returns (uint256);

    // 返回购买签名的 EIP-712 域分隔符
    function DOMAIN_SEPARATOR_BUYNFT() external view returns (bytes32);

    // 返回合约管理员地址
    function owner() external view returns (address);

    // 初始化市场（Proxy 部署时调用一次）
    function initialize(IERC20 erc20, IERC721 erc721) external;

    // UUPS 升级，切换 Implementation 地址
    function upgradeTo(address newImplementation) external;

    // 项目方离线签名，买家上链购买 NFT
    function permitBuyNFT(
        uint256 tokenId,
        address buyer,
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    // 卖家链上上架 NFT
    function list(uint256 tokenId, uint96 amount) external returns (bool);

    // 买家链上购买 NFT
    function buyNFT(uint256 tokenId, uint256 amount) external returns (bool);

    // ERC20 转账回调方式购买 NFT
    function tokensReceived(address from, uint256 amount, bytes calldata data) external returns (bool);

    // 查询上架价格（兼容旧 ABI）
    function tokenPrice(uint256 tokenId) external view returns (uint256);
    // 查询卖家地址（兼容旧 ABI）
    function tokenSeller(uint256 tokenId) external view returns (address);

    


    // 返回市场使用的 ERC20 地址
    function erc20Token() external view returns (IERC20);

    // 返回市场使用的 ERC721 地址

    function erc721Token() external view returns (IERC721);
}
