// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
// UUPSUpgradeable
// import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";

contract ERC721V1 is Initializable, OwnableUpgradeable {
    using Strings for uint256;
    using Address for address;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Token baseURI
    string private _baseURI;

    address public _owner; // 合约所有者

    // Mapping from token ID to owner address
    //
    // token 的归属
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    //
    // 该地址下有多少个 token
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    //
    // 授权 token 给某个 地址
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    //
    // 对A地址下的所有操作权限授予B地址
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    bytes32 IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Initializes the contract by setting a `name`, a `symbol` and a `baseURI` to the token collection.
     */
    // constructor(
    //     string memory name_,
    //     string memory symbol_,
    //     string memory baseURI_
    // ) {
    //     _name = name_;
    //     _symbol = symbol_;
    //     _baseURI = baseURI_;

    // }

    function initialize(string memory name_, string memory symbol_, string memory baseURI_) internal initializer {
        _name = name_;
        _symbol = symbol_;
        _baseURI = baseURI_;
        _owner = msg.sender;
        // 初始化 合约所有者以及权限控制
        __Ownable_init(msg.sender);
    }

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

    function _getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     * @dev 查询支持的接口
     */
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == 0x01ffc9a7 // ERC165 Interface ID for ERC165
            || interfaceId == 0x80ac58cd // ERC165 Interface ID for ERC721
            || interfaceId == 0x5b5e139f; // ERC165 Interface ID for ERC721Metadata
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     *
     * 查询token的 uri
     */
    function tokenURI(uint256 tokenId) public view returns (string memory) {
        require(_owners[tokenId] != address(0), "ERC721Metadata: URI query for nonexistent token");
        return string.concat(_baseURI, tokenId.toString());
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` must not exist.
     *
     *  铸造token并转移到 to 地址。
     *
     * Emits a {Transfer} event.
     */
    function mint(address to, uint256 tokenId) public {
        require(to != address(0), "ERC721: mint to the zero address");
        require(address(0) == _owners[tokenId], "ERC721: token already minted");
        _owners[tokenId] = to;
        _balances[to]++;
        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     *
     * 该地址下有多少个 token
     */
    function balanceOf(address owner) public view returns (uint256) {
        require(owner != address(0), "address must be not address(0)");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     *
     * 返回该 token 的拥有者
     */
    function ownerOf(uint256 tokenId) public view returns (address) {
        require(_owners[tokenId] != address(0), "ERC721: invalid token ID");
        return _owners[tokenId];
    }

    /**
     * @dev See {IERC721-approve}.
     *
     * 将 token 授权给 to。
     */
    function approve(address to, uint256 tokenId) public {
        address owner = ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            msg.sender == owner || isApprovedForAll(owner, msg.sender),
            "ERC721: approve caller is not owner nor approved for all"
        );
        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     *
     * 获取该 token 的具有权限操作的地址
     */
    function getApproved(uint256 tokenId) public view returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");
        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     *
     * 开启/关闭 某地址具有所有操作权限
     */
    function setApprovalForAll(address operator, bool approved) public {
        address sender = msg.sender;
        require(operator != sender, "ERC721: approve to caller");
        _operatorApprovals[sender][operator] = approved;

        emit ApprovalForAll(sender, operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     *
     * 查看 A 地址下的 B地址是否具有操作所有权限
     */
    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     *
     * 普通转账
     */
    function transferFrom(address from, address to, uint256 tokenId) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
        require(ownerOf(tokenId) == from, "address from must be owner");
        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     *
     * 安全转账入口
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory _data) internal {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     *
     * 该代币是否存在
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     *  入参的 地址 是否是该 代币 的拥有者或者权限操作者
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(address from, address to, uint256 tokenId) internal {
        require(ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");

        require(to != address(0), "ERC721: transfer to the zero address");
        _owners[tokenId] = to;
        _balances[to]++;
        _balances[from]--;
        _approve(address(0), tokenId);

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     *
     *
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        address owner = _owners[tokenId];
        require(to != owner, "ERC721: approval to current owner");
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     *
     * 在目标地址上调用{IERC721Receiver-onERC721RReceived}的内部函数。如果目标地址不是合约，则不会执行调用。
     */
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data)
        private
        returns (bool)
    {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }
}

contract BaseERC721Receiver is IERC721Receiver {
    constructor() {}

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
