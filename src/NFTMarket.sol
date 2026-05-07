// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/IERC20Interface.sol";
import "src/IERC721Interface.sol";

contract NFTMarket{

    IERC20 public erc20Token;
    IERC721 public erc721Token;

    event List(uint tokenId,address sellPeople,uint amount);
    event BuyNFT(address buyer,uint tokenID,uint amount);
    /// @notice ERC20 通过 tokensReceived 回调成交时触发（与直接 buyNFT 区分，便于链下监听）
    event PurchaseViaERC20Callback(address buyer, uint256 tokenId, uint256 amount);

// tokenID 对应的  价格
    mapping (uint =>uint)public tokenPrice;
    mapping (uint => address)public tokenSeller;

     constructor(IERC20 erc20,IERC721 erc721){
         erc20Token = erc20;
         erc721Token = erc721;
     }

    // 上架 NFT
     function list(uint tokenId,uint amount) external  returns (bool){
        require(tokenId!=0 && amount >0,"tokenId must !=0, amount must >0");
        require(erc721Token.ownerOf(tokenId)==msg.sender,"you are not owner");
        require(tokenPrice[tokenId] == 0, "already listed");
        // 验证授权
        require(erc721Token.getApproved(tokenId) == address(this) ||erc721Token.isApprovedForAll(msg.sender, address(this)),"NFTMarket: not approved");
        tokenPrice[tokenId] = amount;
        tokenSeller[tokenId] = msg.sender;
        emit List(tokenId,msg.sender, amount);
        return true;
     }

//   买家购买NFT
     function buyNFT(uint tokenID, uint amount) external returns (bool){
        require(tokenID!=0 && amount ==tokenPrice[tokenID],"tokenId must !=0, amount must == tokenPrice[tokenID]");
        address NFTOwnerOf = erc721Token.ownerOf(tokenID);
        // 检查当前的 拥有者和储存的拥有者是否同一人
        require(NFTOwnerOf == tokenSeller[tokenID],"The sellers are not the same address");
        // 先删除状态
        delete tokenPrice[tokenID];
        delete tokenSeller[tokenID];
        // 通过ERC20购买，先转账
        bool result = erc20Token.transferFrom(msg.sender, NFTOwnerOf, amount);
        if (!result){
            revert("transferFrom error");
        }
        //  ERC721进行交易转让 NFT
        erc721Token. safeTransferFrom(NFTOwnerOf, msg.sender, tokenID);

        emit BuyNFT(msg.sender,tokenID,amount);

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
        uint256 tokenID = abi.decode(data, (uint256));
        require(tokenPrice[tokenID]!=0,"Market: token not for sale");
        require(amount>=tokenPrice[tokenID]," Market: insufficient amount");
        address NFTOwnerOf = erc721Token.ownerOf(tokenID);
        // 检查当前的 拥有者和储存的拥有者是否同一人
        require(NFTOwnerOf == tokenSeller[tokenID],"The sellers are not the same address");
        // 先缓存价格
        uint256 price = tokenPrice[tokenID];  
        // 卖家
        address seller = tokenSeller[tokenID]; 
        // 删除 NFT 价格
        delete tokenPrice[tokenID];
        delete tokenSeller[tokenID];

        // 把 NFT的钱转给卖家
        bool result = erc20Token.transfer(seller,price);
        require(result,"Transfer to seller failed");
        // 多余的钱退给买家
        if (amount>price){
            bool result2 = erc20Token.transfer(from,amount-price);
            require(result2," erc20Token.transfer is error");
        }
        // NFT 转让
        erc721Token.safeTransferFrom(seller,from,tokenID);

        emit BuyNFT(from,tokenID,amount);
        emit PurchaseViaERC20Callback(from, tokenID, amount);
        return true;
     }
}




