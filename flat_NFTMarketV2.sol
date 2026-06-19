// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0 ^0.8.20;

// lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol

// OpenZeppelin Contracts (last updated v5.6.0) (utils/cryptography/ECDSA.sol)

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

// lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol

// OpenZeppelin Contracts (last updated v5.3.0) (proxy/utils/Initializable.sol)

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```solidity
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 *
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Storage of the initializable contract.
     *
     * It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions
     * when using with upgradeable contracts.
     *
     * @custom:storage-location erc7201:openzeppelin.storage.Initializable
     */
    struct InitializableStorage {
        /**
         * @dev Indicates that the contract has been initialized.
         */
        uint64 _initialized;
        /**
         * @dev Indicates that the contract is in the process of being initialized.
         */
        bool _initializing;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    /**
     * @dev The contract is already initialized.
     */
    error InvalidInitialization();

    /**
     * @dev The contract is not initializing.
     */
    error NotInitializing();

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint64 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that in the context of a constructor an `initializer` may be invoked any
     * number of times. This behavior in the constructor can be useful during testing and is not expected to be used in
     * production.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        // Cache values to avoid duplicated sloads
        bool isTopLevelCall = !$._initializing;
        uint64 initialized = $._initialized;

        // Allowed calls:
        // - initialSetup: the contract is not in the initializing state and no previous version was
        //                 initialized
        // - construction: the contract is initialized at version 1 (no reinitialization) and the
        //                 current contract is just being deployed
        bool initialSetup = initialized == 0 && isTopLevelCall;
        bool construction = initialized == 1 && address(this).code.length == 0;

        if (!initialSetup && !construction) {
            revert InvalidInitialization();
        }
        $._initialized = 1;
        if (isTopLevelCall) {
            $._initializing = true;
        }
        _;
        if (isTopLevelCall) {
            $._initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: Setting the version to 2**64 - 1 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint64 version) {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing || $._initialized >= version) {
            revert InvalidInitialization();
        }
        $._initialized = version;
        $._initializing = true;
        _;
        $._initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        _checkInitializing();
        _;
    }

    /**
     * @dev Reverts if the contract is not in an initializing state. See {onlyInitializing}.
     */
    function _checkInitializing() internal view virtual {
        if (!_isInitializing()) {
            revert NotInitializing();
        }
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing) {
            revert InvalidInitialization();
        }
        if ($._initialized != type(uint64).max) {
            $._initialized = type(uint64).max;
            emit Initialized(type(uint64).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint64) {
        return _getInitializableStorage()._initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _getInitializableStorage()._initializing;
    }

    /**
     * @dev Pointer to storage slot. Allows integrators to override it with a custom storage location.
     *
     * NOTE: Consider following the ERC-7201 formula to derive storage locations.
     */
    function _initializableStorageSlot() internal pure virtual returns (bytes32) {
        return INITIALIZABLE_STORAGE;
    }

    /**
     * @dev Returns a pointer to the storage namespace.
     */
    // solhint-disable-next-line var-name-mixedcase
    function _getInitializableStorage() private pure returns (InitializableStorage storage $) {
        bytes32 slot = _initializableStorageSlot();
        assembly {
            $.slot := slot
        }
    }
}

// lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC-1967 implementation slot:
 * ```solidity
 * contract ERC1967 {
 *     // Define the slot. Alternatively, use the SlotDerivation library to derive the slot.
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(newImplementation.code.length > 0);
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * TIP: Consider using this library along with {SlotDerivation}.
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    struct Int256Slot {
        int256 value;
    }

    struct StringSlot {
        string value;
    }

    struct BytesSlot {
        bytes value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Int256Slot` with member `value` located at `slot`.
     */
    function getInt256Slot(bytes32 slot) internal pure returns (Int256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `StringSlot` with member `value` located at `slot`.
     */
    function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` representation of the string storage pointer `store`.
     */
    function getStringSlot(string storage store) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }

    /**
     * @dev Returns a `BytesSlot` with member `value` located at `slot`.
     */
    function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` representation of the bytes storage pointer `store`.
     */
    function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }
}

// lib/openzeppelin-contracts-upgradeable/contracts/utils/ContextUpgradeable.sol

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    /// @custom:storage-location erc7201:openzeppelin.storage.Ownable
    struct OwnableStorage {
        address _owner;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Ownable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OwnableStorageLocation = 0x9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c199300;

    function _getOwnableStorage() private pure returns (OwnableStorage storage $) {
        assembly {
            $.slot := OwnableStorageLocation
        }
    }

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    function __Ownable_init(address initialOwner) internal onlyInitializing {
        __Ownable_init_unchained(initialOwner);
    }

    function __Ownable_init_unchained(address initialOwner) internal onlyInitializing {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        OwnableStorage storage $ = _getOwnableStorage();
        return $._owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        OwnableStorage storage $ = _getOwnableStorage();
        address oldOwner = $._owner;
        $._owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// src/NFTMarketV2.sol

// UUPSUpgradeable
// import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract NFTMarketV2 is Initializable, OwnableUpgradeable {

    IERC20 public erc20Token;
    IERC721 public erc721Token;
    bytes32 private constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
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

    mapping (uint => uint) public buyNonces;

    bytes32 public DOMAIN_SEPARATOR_BUYNFT;
    bytes32 public DOMAIN_SEPARATOR_LISTNFT;
    mapping ( address =>uint ) public listNonces;
    event permitList(uint tokenId,address sellPeople,uint amount);

     constructor(){
        _disableInitializers();
     }

// 初始化合约
    function initializeV2() external reinitializer(2) {
        DOMAIN_SEPARATOR_LISTNFT = keccak256(
             abi.encode(
                 keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                 keccak256(bytes("NFTMarketV2")),
                 keccak256(bytes("1")),
                 block.chainid,
                 address(this)
             )
         );
    }

// 
// 升级合约
    function upgradeTo(address newImplementation) external onlyOwner {
        require(newImplementation != address(0), "ERC721V1: new implementation is the zero address");
        require(
            newImplementation != address(this), "ERC721V1: new implementation is the same as the current implementation"
        );
        _setImplementation(newImplementation);
    }

    function _setImplementation(address newImplementation) internal {
        require(newImplementation.code.length > 0, "implementation is not contract");
        StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value = newImplementation;
    }

    // function _getImplementation() internal view returns (address) {
    //     return StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value;
    // }

    // 用户离线签名后,任何人都可以上架NFT
    function permitListNFT(uint tokenId,address seller,uint96 amount,uint nonce,uint deadline,uint8 v,bytes32 r,bytes32 s)external returns (bool){
        require(deadline >= block.timestamp,"deadline is in the past");
        require(nonce == listNonces[seller],"nonce is not correct");
        require(tokenId!=0 && amount >0,"tokenId must !=0, amount must >0");
        require(erc721Token.ownerOf(tokenId)==seller,"you are not owner");
        require(tokenListing[tokenId].price == 0, "already listed");
        require(erc721Token.getApproved(tokenId) == address(this) ||erc721Token.isApprovedForAll(seller, address(this)),"NFTMarket: not approved");

        // require(seller == msg.sender,"seller is not correct");

        bytes32 hashStruct = keccak256(abi.encode(
            keccak256("permitListNFT(uint tokenId,address seller,uint96 amount,uint nonce,uint deadline)"),
            tokenId,
            seller,
            amount,
            nonce,
            deadline
        ));
        bytes32 hash = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR_LISTNFT,
            hashStruct
        ));
        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == seller,"invalid signer");
        listNonces[seller]++;

        // 验证授权
        tokenListing[tokenId] = Listing({
            price: amount,
            seller: seller
        });
        emit permitList(tokenId,seller, amount);
        return true;
    
    }

    // 项目方离线签名，用户来操作购买NFT
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
            DOMAIN_SEPARATOR_BUYNFT,
            hashStruct
        ));
        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == owner(),"invalid signer");
        buyNonces[tokenId]++;
        buyNFT(tokenId,amount);
    
    }

    // 上架 NFT
     function list(uint tokenId,uint96 amount) public  returns (bool){
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
