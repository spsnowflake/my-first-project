// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Meme is Initializable {
    

    string public name;                                               
    string public symbol;                                                
    uint256 public totalSupply;       // 总发行量
    mapping(address => uint256) public balanceOf;    // 余额         
    mapping(address => mapping(address => uint256)) public allowance;   // 授权额度

    address public factory;          // 工厂合约地址，用于 mint 权限校验 
    address public issuer;           // Meme 发行者地址，用于收取 99% 费用 
    uint256 public totalSupplyLimit; // 总发行量上限     
    uint256 public perMintAmount;    // 每次铸造数量     
    uint256 public mintPrice;        // 每个 Token 的铸造价格（wei 计价）

    uint8 public constant decimals = 18;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);


    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_,
        uint256 perMintAmount_,
        uint256 mintPrice_,
        address issuer_
    ) external initializer {
        name = name_;
        symbol = symbol_;
        totalSupplyLimit = totalSupply_;
        perMintAmount = perMintAmount_;
        mintPrice = mintPrice_;
        issuer = issuer_;
        factory = msg.sender;
    }



    /**
     * @notice 铸造 Token，只有工厂合约可以调用
     * @dev 权限卡死在工厂，用户必须通过工厂的 mintMeme() 付费后才能触发
     *      任何人直接调用此函数都会 revert，防止绕过付费逻辑免费铸币
     * @param to 接收 Token 的地址
     */
    function mint(address to) external {
        require(msg.sender == factory, "Meme: only factory can mint");
        require(totalSupply + perMintAmount <= totalSupplyLimit, "Meme: total supply limit reached");
        require(address(to) != address(0), "Meme: cannot mint to zero address");

        totalSupply += perMintAmount;
        balanceOf[to] += perMintAmount;
        emit Transfer(address(0), to, perMintAmount);
    }



    /**
     * @notice 转账
     */
    function transfer(address to, uint256 value) external returns (bool) {
        return _transfer(msg.sender, to, value);
    }

    /**
     * @notice 授权
     */
    function approve(address spender, uint256 value) external returns (bool) {
        require(spender != address(0), "MemeToken: approve to zero address");
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @notice 第三方使用授权额度转账
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        require(
            allowance[from][msg.sender] >= value,
            "MemeToken: insufficient allowance"
        );
        allowance[from][msg.sender] -= value;
        return _transfer(from, to, value);
    }


    function _transfer(address from, address to, uint256 value) internal returns (bool) {
        require(to   != address(0), "MemeToken: transfer to zero address");
        require(from != address(0), "MemeToken: transfer from zero address");
        require(balanceOf[from] >= value, "MemeToken: insufficient balance");

        balanceOf[from] -= value;
        balanceOf[to]   += value;

        emit Transfer(from, to, value);
        return true;
    }
}
