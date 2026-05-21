// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "src/IERC20Interface.sol";
import "src/ITokenReceiver.sol";
import {IPermit2} from "src/IPermit2Interface.sol";

contract TokenBank {
    // 一开始就固定币种
    IERC20 public immutable erc20_address;
    IERC20Permit public immutable erc20_permit;
    IPermit2 public immutable permit2;

    // constructor(IERC20 erc20_token,IPermit2 permit_2) {
    //     erc20_address = erc20_token;
    //     erc20_permit = IERC20Permit(address(erc20_token));
    //     permit2 = permit_2;
    // }

    constructor(IERC20 erc20_token) {
        erc20_address = erc20_token;
        erc20_permit = IERC20Permit(address(erc20_token));
    }

// 用户存钱事件
    event Deposit(address, uint);
    // 用户取钱事件
    event Withdraw(address, uint);
    // 用户余额映射
    mapping (address => uint) public balances;

// owner 离线签名存钱,用于解决用户离线签名存钱的问题
function depositWithPermit2(address owner,uint value,uint256 nonce,uint deadline,bytes calldata signature)external {
    permit2.permitTransferFrom(
        IPermit2.PermitTransferFrom({
            permitted: IPermit2.TokenPermissions({
                token: address(erc20_address),
                amount: type(uint256).max
            }),
            nonce: nonce,
            deadline: deadline
        }),
        IPermit2.SignatureTransferDetails({
            to: address(this),
            requestedAmount: value
        }),
        owner,
        signature
    );
    balances[owner] += value;
    emit Deposit(owner,value);
    
}

function permitDeposit(address owner,uint value,uint deadline,uint8 v,bytes32 r,bytes32 s)external {
    erc20_permit.permit(owner, address(this), value, deadline, v, r, s);
    erc20_address.transferFrom(owner,address(this),value);
    balances[owner] += value;
    emit Deposit(owner,value);
}


// 供合约调用的回调函数
function tokensReceived(address from,uint value)external returns (bool){
    if (msg.sender == address(erc20_address)){
        balances[from] += value;
        emit Deposit(from, value);
        return true;
    }else {
        revert ("invalid");
    }

}



// 用户存钱
    function deposit(uint amount) external  {
        require(amount >0,"amount must >0");
        bool result = erc20_address.transferFrom(msg.sender,address(this),amount);
        require(result,"transferFrom is false");
        balances[msg.sender] += amount;
           
    
        emit Deposit(msg.sender,amount);
    }

// 用户取钱
    function withdraw(uint amount) external {
        require(amount >0,"amount must >0");
        require(amount <= balances[msg.sender],"amount must <= balances[msg.sender]");
        // 先扣除此合约的余额，再执行转账
        balances[msg.sender] -= amount;
        bool result = erc20_address.transfer(msg.sender,amount);
        require(result,"transfer is false");
        emit Withdraw(msg.sender,amount);

    }

}


