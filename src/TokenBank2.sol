// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/IERC20Interface.sol";
import "src/ITokenReceiver.sol";
import {IPermit2} from "src/IPermit2Interface.sol";

contract TokenBank2 {
    // 一开始就固定币种
    IERC20 public immutable erc20_address;
    IERC20Permit public immutable erc20_permit;
    IPermit2 public immutable permit2;

    // 用户存钱事件
    event Deposit(address, uint256);
    // 用户取钱事件
    event Withdraw(address, uint256);
    // 自动化转出半数代币事件
    event HalfWithdrawn(address indexed to, uint256 amount);

    // 用户余额映射
    mapping(address => uint256) public balances;

    address public bankOwner;
    address public upkeep;

    // 初始化代币地址与 owner
    constructor(IERC20 erc20_token) {
        erc20_address = erc20_token;
        erc20_permit = IERC20Permit(address(erc20_token));
        bankOwner = msg.sender;
    }

    // 仅 owner 可调用
    modifier onlyOwner() {
        require(msg.sender == bankOwner, "not owner");
        _;
    }

    // 仅 Chainlink Upkeep 合约可调用
    modifier onlyUpkeep() {
        require(msg.sender == upkeep, "not upkeep");
        _;
    }

    // 设置 Chainlink Automation Upkeep 合约地址
    function setUpkeep(address _upkeep) external onlyOwner {
        upkeep = _upkeep;
    }

    // 监控触发：将合约内一半 ERC20 转给 owner（不更新 balances 账本）
    function withdrawHalfToOwner() external onlyUpkeep {
        uint256 half = erc20_address.balanceOf(address(this)) / 2;
        require(half > 0, "nothing to withdraw");
        bool ok = erc20_address.transfer(bankOwner, half);
        require(ok, "transfer failed");
        emit HalfWithdrawn(bankOwner, half);
    }

    // 通过 Permit2 离线签名存款
    function depositWithPermit2(address owner, uint256 value, uint256 nonce, uint256 deadline, bytes calldata signature)
        external
    {
        permit2.permitTransferFrom(
            IPermit2.PermitTransferFrom({
                permitted: IPermit2.TokenPermissions({token: address(erc20_address), amount: type(uint256).max}),
                nonce: nonce,
                deadline: deadline
            }),
            IPermit2.SignatureTransferDetails({to: address(this), requestedAmount: value}),
            owner,
            signature
        );
        balances[owner] += value;
        emit Deposit(owner, value);
    }

    // 通过 EIP-2612 permit 离线签名存款
    function permitDeposit(address owner, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        erc20_permit.permit(owner, address(this), value, deadline, v, r, s);
        erc20_address.transferFrom(owner, address(this), value);
        balances[owner] += value;
        emit Deposit(owner, value);
    }

    // ERC20 转账回调，供支持 tokensReceived 的代币调用
    function tokensReceived(address from, uint256 value) external returns (bool) {
        if (msg.sender == address(erc20_address)) {
            balances[from] += value;
            emit Deposit(from, value);
            return true;
        } else {
            revert("invalid");
        }
    }

    // 用户存款，需先 approve 本合约
    function deposit(uint256 amount) external {
        require(amount > 0, "amount must >0");
        bool result = erc20_address.transferFrom(msg.sender, address(this), amount);
        require(result, "transferFrom is false");
        balances[msg.sender] += amount;

        emit Deposit(msg.sender, amount);
    }

    // 用户按账本余额取款
    function withdraw(uint256 amount) external {
        require(amount > 0, "amount must >0");
        require(amount <= balances[msg.sender], "amount must <= balances[msg.sender]");
        balances[msg.sender] -= amount;
        bool result = erc20_address.transfer(msg.sender, amount);
        require(result, "transfer is false");
        emit Withdraw(msg.sender, amount);
    }
}
