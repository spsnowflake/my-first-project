// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


///  时间锁合约：对治理通过的操作做延迟执行
///  给社区审查、模拟执行、反对方退出的时间窗口；真正改协议参数由这里底层 call 完成
contract Timelock {
    
    ///  交易可执行的宽限期：eta 之后超过该时间未执行则过期（14 天）
    uint public constant GRACE_PERIOD = 14 days;
    ///  延迟时间下限（2 天）
    uint public constant MINIMUM_DELAY = 2 days;
    ///  延迟时间上限（30 天）
    uint public constant MAXIMUM_DELAY = 30 days;

    ///  管理员（通常为 Governor 合约）
    address public admin;
    ///  待接受的新管理员
    address public pendingAdmin;
    ///  当前延迟执行时间（秒）
    uint public delay;

    ///  已排队交易哈希 => 是否在队列中
    mapping (bytes32 => bool) public queuedTransactions;

    constructor(address _admin, uint _delay) {
        require(_delay >= MINIMUM_DELAY && _delay <= MAXIMUM_DELAY, "Timelock::constructor: invalid delay");
        admin = _admin;
        pendingAdmin = address(0);
        delay = _delay;
    }


    ///  延迟结束后执行交易：拼装 calldata，对 target 做底层 call
    /// @dev 须已排队、当前时间 >= eta、且未超过 eta + GRACE_PERIOD
    function executeTransaction(address target, uint value, string memory signature, bytes memory data, uint eta) public payable returns (bytes memory) {
        require(msg.sender == admin, "Timelock::executeTransaction: Call must come from admin.");
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(queuedTransactions[txHash], "Timelock::executeTransaction: Transaction hasn't been queued.");
        require(getBlockTimestamp() >= eta, "Timelock::executeTransaction: Transaction hasn't surpassed time lock.");
        require(getBlockTimestamp() <= eta + GRACE_PERIOD, "Timelock::executeTransaction: Transaction is stale.");
        queuedTransactions[txHash] = false;

// 要么data包含了全部信息，直接发起底层调用。
// 要么signature包含了函数签名字符串，例如 "setDelay(uint256)"，其他入参的信息在data里面，就需要取前四字节内容拼接data
        bytes memory callData;
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }
        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        require(success, "Timelock::executeTransaction: Transaction execution reverted.");
        return returnData;
    }



    ///  取消队列中的交易
    function cancelTransaction(address target, uint value, string memory signature, bytes memory data, uint eta) public {
        require(msg.sender == admin, "Timelock::cancelTransaction: Call must come from admin.");
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(queuedTransactions[txHash], "Timelock::cancelTransaction: Transaction hasn't been queued.");
        queuedTransactions[txHash] = false;
    }



    ///  将交易放入延迟执行队列
    /// @param target 目标合约
    /// @param value 附带 ETH 数量
    /// @param signature 函数签名；空字符串表示 data 已是完整 calldata
    /// @param data 函数参数编码（或完整 calldata）
    /// @param eta 预计执行时间戳，须 >= now + delay
    /// @return 交易哈希 txHash
    function queueTransaction(address target, uint value, string memory signature, bytes memory data, uint eta) public returns (bytes32) {
        require(msg.sender == admin, "Timelock::queueTransaction: Call must come from admin.");
        require(eta >= getBlockTimestamp() + delay, "Timelock::queueTransaction: Estimated execution block must satisfy delay.");
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = true;
        return txHash;
    }



        ///  获取当前区块时间戳
    function getBlockTimestamp() internal view returns (uint) {
        return block.timestamp;
    }

    ///  修改延迟时间
    /// @dev 只能由 Timelock 自己调用，即必须通过治理提案执行
    function setDelay(uint delay_) public {
        require(msg.sender == address(this), "Timelock::setDelay: Call must come from Timelock.");
        require(delay_ >= MINIMUM_DELAY, "Timelock::setDelay: Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Timelock::setDelay: Delay must not exceed maximum delay.");
        delay = delay_;

    }


        ///  设置 pendingAdmin，只能由 Timelock 自己调用（经治理提案），防止 admin 直接改自己
    function setPendingAdmin(address pendingAdmin_) public {
        require(msg.sender == address(this), "Timelock::setPendingAdmin: Call must come from Timelock.");
        pendingAdmin = pendingAdmin_;
    }

        ///  pendingAdmin 接受成为正式 admin（两步移交权限）
    function acceptAdmin() public {
        require(msg.sender == pendingAdmin, "Timelock::acceptAdmin: Call must come from pendingAdmin.");
        admin = msg.sender;
        pendingAdmin = address(0);
    }








    ///  接收纯 ETH（无 calldata；执行提案时可能需要转发 value）
    receive() external payable { }

    ///  接收带 calldata 的调用并附带 ETH
    fallback() external payable { }

    
}



