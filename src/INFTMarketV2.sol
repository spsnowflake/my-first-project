// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/INFTMarketV1.sol";

interface INFTMarketV2 is INFTMarketV1 {
    // 卖家离线签名上架成功时触发
    event permitList(uint256 tokenId, address sellPeople, uint256 amount);

    // 返回上架签名的 EIP-712 域分隔符
    function DOMAIN_SEPARATOR_LISTNFT() external view returns (bytes32);

    // 查询卖家的 permitListNFT nonce
    function listNonces(address seller) external view returns (uint256);

    // V2 升级后初始化（写入 DOMAIN_SEPARATOR_LISTNFT，仅可调用一次）
    function initializeV2() external;

    // 卖家离线签名，任何人可代为提交上架
    function permitListNFT(
        uint256 tokenId,
        address seller,
        uint96 amount,
        uint256 nonce,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (bool);
}
