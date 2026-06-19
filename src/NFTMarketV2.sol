// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/IERC20Interface.sol";
import "src/IERC721Interface.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
// UUPSUpgradeable
// import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";

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