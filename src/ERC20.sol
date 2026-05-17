// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/IERC20Interface.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract BaseERC20 {

    string public name; 
    string public symbol; 
    uint8 public decimals; 

    uint256 public totalSupply; 
// 余额
    mapping (address => uint256) balances; 
// 授权方授权被授权方多少token
    mapping (address => mapping (address => uint256)) allowances;
    bytes32 public immutable DOMAIN_SEPARATOR;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() { 
        // write your code here
        // set name,symbol,decimals,totalSupply
        name = "BaseERC20";
        symbol = "BERC20";
        decimals = 18;
        totalSupply = 100000000*10**decimals;
        balances[msg.sender] = totalSupply;
    }

    function transferWithCallback(address to,uint value)external returns (bool){
        transfer(to,value);
        if (to.code.length > 0){
            bool success = IERC20(to).tokensReceived(msg.sender,value);
            require(success,"No ERC20");
        }
        return true;
    }

// 任何人都能查询任何地址的余额
    function balanceOf(address _owner) public view returns (uint256 balance) {
        // write your code here
        return balances[_owner];

    }

// 允许 token 所有者将拥有的token 发送给任何人
    function transfer(address _to, uint256 _value) public returns (bool success) {
        // write your code here

        require(_value<=balances[msg.sender],"ERC20: transfer amount exceeds balance");
        require(_to != address(0),"address must not be address(0)");

        balances[msg.sender]-=_value;
        balances[_to]+=_value;

        emit Transfer(msg.sender, _to, _value);  
        return true;   
    }

// 允许被授权者去操作被授权的地址的token拿去消费
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        // write your code here
        require(_value<=balances[_from],"ERC20: transfer amount exceeds balance");
        require(_value<=allowances[_from][msg.sender],"ERC20: transfer amount exceeds allowance");
        require(_to!=address(0),"address must not be address(0)");
        balances[_from]-=_value;
        balances[_to]+=_value;
        allowances[_from][msg.sender]-=_value;
        
        emit Transfer(_from, _to, _value); 
        return true; 
    }

// 授权者去授权某个地址允许消费自己的指定数量的token
    function approve(address _spender, uint256 _value) public returns (bool success) {
        // write your code here
        allowances[msg.sender][_spender]=_value;

        emit Approval(msg.sender, _spender, _value); 
        return true; 
    }

// 允许任何人查看某个被授权者（地址）能够消费授权方消费多少token
    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {   
        // write your code here     
        return allowances[_owner][_spender];

    }
}