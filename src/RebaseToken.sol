// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


/**
 * @title 
 * @author 
 * @notice 
 * y：看到的余额，x：保存的余额。k = 系数，total/supply
 * y = x / k
 */
contract RebaseToken {

    string public name; 
    string public symbol; 
    uint8 public constant decimals = 18; 
    uint32 public constant year = 365 days; 
    uint public createTime;
    uint256 private immutable _totalShares ;


    
// 余额
    mapping (address => uint256) balances ; 
// 授权方授权被授权方多少token
    mapping (address => mapping (address => uint256)) allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        _totalShares = 1e8*10**decimals;
        createTime = block.timestamp;
        balances[msg.sender] = _totalShares;
    }

// 通缩计算
    function rebase() internal view returns (uint256 supply) {
        uint yearsSinceCreation = (block.timestamp - createTime)/ year;
        return supply = _totalShares * (99**yearsSinceCreation)/(100**yearsSinceCreation);
    }

// 获取总供应量
    function totalSupply() public view returns (uint256) {
        return rebase();
    }


    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner]*rebase()/_totalShares;
    }

    function transfer(address _to, uint256 _value) external returns (bool success) {
        require(_value<=balanceOf(msg.sender),"ERC20: transfer amount exceeds balance");
        require(_to != address(0),"address must not be address(0)");
        uint originalValue = _value;
        _value = convertToShares(_value);

        balances[msg.sender]-=_value;
        balances[_to]+=_value;

        emit Transfer(msg.sender, _to, originalValue);  
        return true;  
    }

    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success) {
        require(_value<=balanceOf(_from),"ERC20: transfer amount exceeds balance");
        require(_value<=allowances[_from][msg.sender]*rebase()/_totalShares,"ERC20: transfer amount exceeds allowance");
        require(_to!=address(0),"address must not be address(0)");
        uint originalValue = _value;
        _value = convertToShares(_value);

        balances[_from]-=_value;
        balances[_to]+=_value;
        allowances[_from][msg.sender]-=_value;
        
        emit Transfer(_from, _to, originalValue); 
        return true; 
    }

    function approve(address _spender, uint256 _value) external  returns (bool success) {
        uint originalValue = _value;
        _value = convertToShares(_value);

        allowances[msg.sender][_spender]=_value;

        emit Approval(msg.sender, _spender, originalValue); 
        return true; 
    }


    function allowance( address _owner, address _spender) external view returns (uint256 remaining) {
        // 存入的是shares，需要转换为真实的余额
        return allowances[_owner][_spender]*rebase()/_totalShares;

    }

// 把传入的金额转换为shares
    function convertToShares(uint256 _value) internal view returns (uint256 shares) {
        return  _value * _totalShares/rebase();
    }
}



