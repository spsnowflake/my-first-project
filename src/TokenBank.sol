// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "src/IERC20Interface.sol";
import "src/ITokenReceiver.sol";

contract TokenBank {
    // 一开始就固定币种
    IERC20 public immutable erc20_address;
    constructor(IERC20 erc20_token){
        erc20_address = erc20_token;
    }

    event Deposit(address, uint);
    event Withdraw(address, uint);
    mapping (address => uint) public  balances;

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


