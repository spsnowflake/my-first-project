// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface IERC721V1 {
// --- 事件 (Events) ---

    // 当 tokenId 从 from 转账给 to 时触发（铸造时 from 为 0 地址）
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    // 当 owner 授权 approved 地址管理某个 tokenId 时触发
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    // 当 owner 开启/关闭 operator 管理其所有资产的权限时触发
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);


    // 返回代币系列的名称（如："Bored Ape Yacht Club"）
    function name() external view returns (string memory);

    // 返回代币系列的缩写（如："BAYC"）
    function symbol() external view returns (string memory);

    // 返回特定 NFT 的资源链接（通常指向一个包含图片和属性的 JSON 文件）
    function tokenURI(uint256 tokenId) external view returns (string memory);



    // --- 只读查询函数 (View Functions) ---
    // 查询某个地址拥有的 NFT 总数
    function balanceOf(address owner) external view returns (uint256 balance);

    // 查询某个 NFT 当前的拥有者地址
    function ownerOf(uint256 tokenId) external view returns (address owner);

    // 查询某个 NFT 被单独授权给了哪个地址
    function getApproved(uint256 tokenId) external view returns (address operator);

    // 查询 operator 是否被授权管理 owner 的所有资产
    function isApprovedForAll(address owner, address operator) external view returns (bool);


    // --- 操作函数 (State-Changing Functions) ---
    // 授权某个地址操作特定的 NFT
    function approve(address to, uint256 tokenId) external;

    // 开启或关闭某地址（如市场合约）管理自己所有 NFT 的权限
    function setApprovalForAll(address operator, bool _approved) external;

    // 普通转账（不建议直接使用，除非确定接收方是人）
    function transferFrom(address from, address to, uint256 tokenId) external;

    // 安全转账（重载版本1）：不带附加数据
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    // 安全转账（重载版本2）：带附加数据，会检查接收方是否支持 ERC721
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

/**
     * @notice 处理 NFT 的接收
     * @return 返回函数选择器 (magic value) 以确认接收
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);

    // 铸造一个新的 NFT 给指定地址
    function mint(address to, uint256 tokenId) external;

    // 升级合约
    function upgradeTo(address newImplementation) external;

}