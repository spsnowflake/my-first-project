// SPDX-License-Identifier: MIT

// lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol

// OpenZeppelin Contracts (last updated v5.6.0) (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.20;

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS
    }

    /**
     * @dev The signature is invalid.
     */
    error ECDSAInvalidSignature();

    /**
     * @dev The signature has an invalid length.
     */
    error ECDSAInvalidSignatureLength(uint256 length);

    /**
     * @dev The signature has an S value that is in the upper half order.
     */
    error ECDSAInvalidSignatureS(bytes32 s);

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with `signature` or an error. This will not
     * return address(0) without also returning an error description. Errors are documented using an enum (error type)
     * and a bytes32 providing additional information about the error.
     *
     * If no error is returned, then the address can be used for verification purposes.
     *
     * The `ecrecover` EVM precompile allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * NOTE: This function only supports 65-byte signatures. ERC-2098 short signatures are rejected. This restriction
     * is DEPRECATED and will be removed in v6.0. Developers SHOULD NOT use signatures as unique identifiers; use hash
     * invalidation or nonces for replay protection.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {MessageHashUtils-toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     *
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     */
    function tryRecover(
        bytes32 hash,
        bytes memory signature
    ) internal pure returns (address recovered, RecoverError err, bytes32 errArg) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly ("memory-safe") {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength, bytes32(signature.length));
        }
    }

    /**
     * @dev Variant of {tryRecover} that takes a signature in calldata
     */
    function tryRecoverCalldata(
        bytes32 hash,
        bytes calldata signature
    ) internal pure returns (address recovered, RecoverError err, bytes32 errArg) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, calldata slices would work here, but are
            // significantly more expensive (length check) than using calldataload in assembly.
            assembly ("memory-safe") {
                r := calldataload(signature.offset)
                s := calldataload(add(signature.offset, 0x20))
                v := byte(0, calldataload(add(signature.offset, 0x40)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength, bytes32(signature.length));
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM precompile allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * NOTE: This function only supports 65-byte signatures. ERC-2098 short signatures are rejected. This restriction
     * is DEPRECATED and will be removed in v6.0. Developers SHOULD NOT use signatures as unique identifiers; use hash
     * invalidation or nonces for replay protection.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {MessageHashUtils-toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, signature);
        _throwError(error, errorArg);
        return recovered;
    }

    /**
     * @dev Variant of {recover} that takes a signature in calldata
     */
    function recoverCalldata(bytes32 hash, bytes calldata signature) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecoverCalldata(hash, signature);
        _throwError(error, errorArg);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[ERC-2098 short signatures]
     */
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address recovered, RecoverError err, bytes32 errArg) {
        unchecked {
            bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
            // We do not check for an overflow here since the shift operation results in 0 or 1.
            uint8 v = uint8((uint256(vs) >> 255) + 27);
            return tryRecover(hash, v, r, s);
        }
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r` and `vs` short-signature fields separately.
     */
    function recover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, r, vs);
        _throwError(error, errorArg);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address recovered, RecoverError err, bytes32 errArg) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS, s);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature, bytes32(0));
        }

        return (signer, RecoverError.NoError, bytes32(0));
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, v, r, s);
        _throwError(error, errorArg);
        return recovered;
    }

    /**
     * @dev Parse a signature into its `v`, `r` and `s` components. Supports 65-byte and 64-byte (ERC-2098)
     * formats. Returns (0,0,0) for invalid signatures.
     *
     * For 64-byte signatures, `v` is automatically normalized to 27 or 28.
     * For 65-byte signatures, `v` is returned as-is and MUST already be 27 or 28 for use with ecrecover.
     *
     * Consider validating the result before use, or use {tryRecover}/{recover} which perform full validation.
     */
    function parse(bytes memory signature) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        assembly ("memory-safe") {
            // Check the signature length
            switch mload(signature)
            // - case 65: r,s,v signature (standard)
            case 65 {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            // - case 64: r,vs signature (cf https://eips.ethereum.org/EIPS/eip-2098)
            case 64 {
                let vs := mload(add(signature, 0x40))
                r := mload(add(signature, 0x20))
                s := and(vs, shr(1, not(0)))
                v := add(shr(255, vs), 27)
            }
            default {
                r := 0
                s := 0
                v := 0
            }
        }
    }

    /**
     * @dev Variant of {parse} that takes a signature in calldata
     */
    function parseCalldata(bytes calldata signature) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        assembly ("memory-safe") {
            // Check the signature length
            switch signature.length
            // - case 65: r,s,v signature (standard)
            case 65 {
                r := calldataload(signature.offset)
                s := calldataload(add(signature.offset, 0x20))
                v := byte(0, calldataload(add(signature.offset, 0x40)))
            }
            // - case 64: r,vs signature (cf https://eips.ethereum.org/EIPS/eip-2098)
            case 64 {
                let vs := calldataload(add(signature.offset, 0x20))
                r := calldataload(signature.offset)
                s := and(vs, shr(1, not(0)))
                v := add(shr(255, vs), 27)
            }
            default {
                r := 0
                s := 0
                v := 0
            }
        }
    }

    /**
     * @dev Optionally reverts with the corresponding custom error according to the `error` argument provided.
     */
    function _throwError(RecoverError error, bytes32 errorArg) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert ECDSAInvalidSignature();
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert ECDSAInvalidSignatureLength(uint256(errorArg));
        } else if (error == RecoverError.InvalidSignatureS) {
            revert ECDSAInvalidSignatureS(errorArg);
        }
    }
}

// src/IERC20Interface.sol

pragma solidity ^0.8.0;

interface IERC20 {
    function balanceOf(address _owner) external  view returns (uint256 balance);
    function transfer(address _to, uint256 _value) external returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    function approve(address _spender, uint256 _value) external returns (bool success);
    function allowance(address _owner, address _spender) external view returns (uint256 remaining);
    function tokensReceived(address from,uint value)external returns (bool);
}

/// EIP-2612：支持离线签名授权（permit）的 ERC20 扩展
interface IERC20Permit {
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

// src/IERC721Interface.sol

pragma solidity ^0.8.0;

interface IERC721 {
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

}

// src/NFTMarket.sol

pragma solidity ^0.8.0;

contract NFTMarket{

    // IERC20 public erc20Token;
    // IERC721 public erc721Token;
    // address owner;
    IERC20 public immutable erc20Token;
    IERC721 public immutable erc721Token;
    address public immutable owner;

    event List(uint tokenId,address sellPeople,uint amount);
    event BuyNFT(address buyer,uint tokenId,uint amount);
    /// @notice ERC20 通过 tokensReceived 回调成交时触发（与直接 buyNFT 区分，便于链下监听）
    event PurchaseViaERC20Callback(address buyer, uint256 tokenId, uint256 amount);

// tokenId 对应的  价格
    struct Listing {
        uint96 price;   // 12 bytes
        address seller; // 20 bytes  
    }                   // 合计 32 bytes，刚好一个 slot
    mapping(uint => Listing) public tokenListing;

    // mapping (uint =>uint)public tokenPrice;
    // mapping (uint => address)public tokenSeller;
    mapping (uint => uint) public buyNonces;

    bytes32 public immutable DOMAIN_SEPARATOR;

     constructor(IERC20 erc20,IERC721 erc721){
         erc20Token = erc20;
         erc721Token = erc721;
         owner = msg.sender;

         DOMAIN_SEPARATOR = keccak256(
             abi.encode(
                 keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                 keccak256(bytes("NFTMarket")),
                 keccak256(bytes("1")),
                 block.chainid,
                 address(this)
             )
         );
     }

    // 白名单用户离线签名，项目方来操作购买NFT
    function permitBuyNFT(uint tokenId,address buyer,uint amount,uint nonce,uint deadline,uint8 v,bytes32 r,bytes32 s)external{
        require(deadline >= block.timestamp,"deadline is in the past");
        require(nonce == buyNonces[tokenId],"nonce is not correct");
        require(buyer == msg.sender,"buyer is not correct");

        bytes32 hashStruct = keccak256(abi.encode(
            keccak256("PermitBuyNFT(uint tokenId,address buyer,uint amount,uint nonce,uint deadline)"),
            tokenId,
            buyer,
            amount,
            nonce,
            deadline
        ));
        bytes32 hash = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            hashStruct
        ));
        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == owner,"invalid signer");
        buyNonces[tokenId]++;
        buyNFT(tokenId,amount);
    
    }

    // 上架 NFT
     function list(uint tokenId,uint96 amount) external  returns (bool){
        require(tokenId!=0 && amount >0,"tokenId must !=0, amount must >0");
        require(erc721Token.ownerOf(tokenId)==msg.sender,"you are not owner");
        require(tokenListing[tokenId].price == 0, "already listed");
        // 验证授权
        require(erc721Token.getApproved(tokenId) == address(this) ||erc721Token.isApprovedForAll(msg.sender, address(this)),"NFTMarket: not approved");
        // tokenListing[tokenId].price = amount;
        // tokenListing[tokenId].seller = msg.sender;
        tokenListing[tokenId] = Listing({
            price: amount,
            seller: msg.sender
        });
        emit List(tokenId,msg.sender, amount);
        return true;
     }

//   买家购买NFT
     function buyNFT(uint tokenId, uint amount) public returns (bool){
        require(tokenId!=0 && amount ==tokenListing[tokenId].price,"tokenId must !=0, amount must == tokenListing[tokenId].price");
        address NFTOwnerOf = erc721Token.ownerOf(tokenId);
        // 检查当前的 拥有者和储存的拥有者是否同一人
        require(NFTOwnerOf == tokenListing[tokenId].seller,"The sellers are not the same address");
        // 先删除状态
        // delete tokenListing[tokenId].price;
        // delete tokenListing[tokenId].seller;
        delete tokenListing[tokenId];
        // 通过ERC20购买，先转账
        bool result = erc20Token.transferFrom(msg.sender, NFTOwnerOf, amount);
        if (!result){
            revert("transferFrom error");
        }
        //  ERC721进行交易转让 NFT
        erc721Token. safeTransferFrom(NFTOwnerOf, msg.sender, tokenId);

        emit BuyNFT(msg.sender,tokenId,amount);

        return true;
     }

// 安全检查
// 1.检验是不是ERC20
// 2.检测 目标NFT是否上架
// 3.检测转账的金额是否大于等于NFT价格
// 成交逻辑
// 1.把钱给卖家
// 2.有多余的钱退回给买家
// 3.NFT 转让

     function tokensReceived(address from,uint amount,bytes calldata data) external returns (bool){
        require(msg.sender == address(erc20Token), "only erc20Token can call this function");
        // 将 bytes 还原成 uint256 的 tokenId
        uint256 tokenId = abi.decode(data, (uint256));
        require(tokenListing[tokenId].price!=0,"Market: token not for sale");
        require(amount>=tokenListing[tokenId].price," Market: insufficient amount");
        address NFTOwnerOf = erc721Token.ownerOf(tokenId);
        // 检查当前的 拥有者和储存的拥有者是否同一人
        require(NFTOwnerOf == tokenListing[tokenId].seller,"The sellers are not the same address");
        // 先缓存价格
        uint256 price = tokenListing[tokenId].price;  
        // 卖家
        address seller = tokenListing[tokenId].seller; 
        // 删除 NFT 价格
        // delete tokenListing[tokenId].price;
        // delete tokenListing[tokenId].seller;
        delete tokenListing[tokenId];

        // 把 NFT的钱转给卖家
        bool result = erc20Token.transfer(seller,price);
        require(result,"Transfer to seller failed");
        // 多余的钱退给买家
        if (amount>price){
            bool result2 = erc20Token.transfer(from,amount-price);
            require(result2," erc20Token.transfer is error");
        }
        // NFT 转让
        erc721Token.safeTransferFrom(seller,from,tokenId);

        emit BuyNFT(from,tokenId,amount);
        emit PurchaseViaERC20Callback(from, tokenId, amount);
        return true;
    }

    /// @dev 兼容旧 ABI：读取上架价格
    function tokenPrice(uint256 tokenId) external view returns (uint256) {
        return tokenListing[tokenId].price;
    }

    /// @dev 兼容旧 ABI：读取卖家地址
    function tokenSeller(uint256 tokenId) external view returns (address) {
        return tokenListing[tokenId].seller;
    }
}

