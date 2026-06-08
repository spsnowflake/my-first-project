// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/IERC20Interface.sol";
import "src/IERC721Interface.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";

contract AirdropMerkleNFTMarket is Multicall{

    IERC20 public immutable erc20Token;
    IERC721 public immutable erc721Token;
    address public immutable owner;
    IERC20Permit public immutable erc20Permit;

    // 默克尔树根
    bytes32 public immutable merkleRoot;

    event List(uint tokenId,address sellPeople,uint amount);
    event BuyNFT(address buyer,uint tokenId,uint amount);
    /// @notice ERC20 通过 tokensReceived 回调成交时触发（与直接 buyNFT 区分，便于链下监听）
    event PurchaseViaERC20Callback(address buyer, uint256 tokenId, uint256 amount);

    // 购买NFT的nonce
    mapping (uint => uint) public buyNonces;
    // tokenId 对应的  价格
    struct Listing {
        uint96 price;   
        address seller;  
    }                   // 合计 32 bytes，刚好一个 slot
    mapping(uint => Listing) public tokenListing;

    constructor(IERC20 erc20,IERC721 erc721,bytes32 _merkleRoot){
        erc20Token = erc20;
        erc20Permit = IERC20Permit(address(erc20));
        erc721Token = erc721;
        owner = msg.sender;
        merkleRoot = _merkleRoot;
    }

// 通过默克尔树证明，购买NFT
    function claimNFT(uint tokenId,bytes32[] calldata proof) public {
        require(tokenId!=0,"tokenId must !=0");
        require(tokenListing[tokenId].price != 0, "not listed");
    
        address NFTOwnerOf = erc721Token.ownerOf(tokenId);
        // 检查当前的 拥有者和储存的拥有者是否同一人
        require(NFTOwnerOf == tokenListing[tokenId].seller,"The sellers are not the same address");
        // 验证授权
        require(erc721Token.getApproved(tokenId) == address(this) ||erc721Token.isApprovedForAll(NFTOwnerOf, address(this)),"NFTMarket: not approved");
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender))));
        // 验证默克尔树proof
        require(MerkleProof.verify(proof, merkleRoot, leaf), "Invalid proof");

        // 查询价格
        uint256 price = tokenListing[tokenId].price;
        // 半价
        uint256 halfPrice = price / 2;

        // 先删除状态
        delete tokenListing[tokenId];
        // 通过ERC20购买，先转账
        bool result = erc20Token.transferFrom(msg.sender, NFTOwnerOf, halfPrice);
        if (!result){
            revert("transferFrom error");
        }
        //  ERC721进行交易转让 NFT
        erc721Token.safeTransferFrom(NFTOwnerOf, msg.sender, tokenId);
        emit BuyNFT(msg.sender,tokenId,halfPrice);
   }

//  买家离线签名授权token给市场合约
     function permitPrePay(address _owner,uint256 value,uint256 deadline,uint8 v, bytes32 r, bytes32 s) external {
        // spender 通常是 address(this)，即 Market
        erc20Permit.permit(_owner, address(this), value, deadline, v, r, s);
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

}