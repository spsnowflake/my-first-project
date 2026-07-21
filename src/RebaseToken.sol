// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {IERC20} from "./IERC20Interface.sol";


contract RebaseToken {

    string public name; 
    string public symbol; 
    uint8 public constant decimals = 18; 
    uint32 public constant year = 365 days; 

    uint public createTime;

    uint256 public totalSupply;


    
// 余额
    mapping (address => uint256) balances ; 
// 授权方授权被授权方多少token
    mapping (address => mapping (address => uint256)) allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        totalSupply = 1e8*10**decimals;
        createTime = block.timestamp;
    }

// 通缩计算
    function rebase() internal view returns (uint supply) {
        uint yearsSinceCreation = (block.timestamp - createTime) % year;
        supply = totalSupply;

// 第一年，不进行通缩
        if (yearsSinceCreation == 0) {
            return supply;
// 第二年开始，每年乘以上一年的99%
        } else {
            for (uint i = 1; i <= yearsSinceCreation; i++) {
                supply = supply * 99/100;
            }
            return supply;
        }
    }


    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner]*rebase()/totalSupply;
    }

    function transfer(address _to, uint256 _value) external convertToShares(_value) returns (bool success) {
        require(_value<=balances[msg.sender],"ERC20: transfer amount exceeds balance");
        require(_to != address(0),"address must not be address(0)");

        balances[msg.sender]-=_value;
        balances[_to]+=_value;

        emit Transfer(msg.sender, _to, _value);  
        return true;  
    }

    function transferFrom(address _from, address _to, uint256 _value) external convertToShares(_value)  returns (bool success) {
        require(_value<=balances[_from],"ERC20: transfer amount exceeds balance");
        require(_value<=allowances[_from][msg.sender],"ERC20: transfer amount exceeds allowance");
        require(_to!=address(0),"address must not be address(0)");
        balances[_from]-=_value;
        balances[_to]+=_value;
        allowances[_from][msg.sender]-=_value;
        
        emit Transfer(_from, _to, _value); 
        return true; 
    }

    function approve(address _spender, uint256 _value) external convertToShares(_value)  returns (bool success) {
        allowances[msg.sender][_spender]=_value;

        emit Approval(msg.sender, _spender, _value); 
        return true; 
    }

    function allowance( address _owner, address _spender) external view returns (uint256 remaining) {
        return allowances[_owner][_spender];

    }

// 把传入的金额转换为shares，并检查是否为0
    modifier convertToShares(uint256 _value) {
        require(_value!=0,"transfer amount must not be 0");
        _value = _value * totalSupply/rebase();
        _;
        
    }

    // function tokensReceived(address from, uint value) external returns (bool) {

    // }
}



















