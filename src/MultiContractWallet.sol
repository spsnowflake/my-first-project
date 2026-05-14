// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;



contract MultiContractWallet {
    // 多签钱包的拥有者
    address[] public owners;
    // 多签钱包的所需签名数量
    uint64 public requiredNum;

    // 多签钱包的提案列表
    Proposal[] public proposals;

    mapping(address => bool) public isOwnerMap;

    // 多签钱包的签名数量
    // uint64 public signatureCount;


// 构造函数，初始化拥有者和所需签名数量
    constructor(address[] memory _owners, uint64 _requiredNum) {
        // 检查拥有者数量是否大于所需签名数量
        require(_owners.length >= _requiredNum, "Owners length must be greater than required num");

        // 检查拥有者数量是否大于0
        require(_owners.length > 0, "Owners length must be greater than 0");

        // 检查所需签名数量是否大于0
        require(_requiredNum > 0, "Required num must be greater than 0");

        // 初始化需要带上自己
        // 初始化拥有者列表
        // 去重防止重复添加拥有者
        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "Owner cannot be zero address");
            require(!isOwnerMap[_owners[i]], "Duplicate owner");  
            isOwnerMap[_owners[i]] = true;
            owners.push(_owners[i]);
        }
        
        // 初始化所需签名数量
        requiredNum = _requiredNum;
    }

    // 多签钱包的提案结构体
    struct Proposal {
    address to;          // 目标合约或地址
    uint256 value;       // 附带的 ETH 数量
    bytes data;          // 调用的函数+参数编码
    bool executed;       // 是否已执行，防止重复执行
    uint256 confirmCount;  // 当前确认数
    mapping(address => bool) confirmed;  // 谁确认过了，防止重复签名
}

    
// 创建提案(多签持有⼈可提交提案)
    function createProposal(address _to, uint256 _value, bytes memory _data) public {

        // 检查是否是提案人,只有提案人才能创建提案
        require(isOwnerMap[msg.sender], "Only owners can create proposals");
        // 检查目标合约或地址是否为空
        require(_to != address(0), "To address cannot be 0");
        // 检查附带的 ETH 数量是否大于0
        // require(_value >= 0, "Value must be greater than or equal to 0");

        if(_data.length == 0) {
            require(_value > 0, "Value must be greater than 0 when data is empty");
        }

        // 创建提案
        proposals.push();
        Proposal storage proposal = proposals[proposals.length - 1];
        proposal.to = _to;
        proposal.value = _value;
        proposal.data = _data;
        proposal.executed = false;
        proposal.confirmCount = 1;
        proposal.confirmed[msg.sender] = true;
    }

// 确认提案(多签持有⼈可确认提案)
    function confirmProposal(uint256 _proposalId) public  {
        // 检查是否是提案人
        bool isOwner = false;
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == msg.sender) {
                isOwner = true;
                break;
            }
        }
        // 检查是否是提案人,只有提案人才能确认提案
        require(isOwner, "Only owners can confirm proposals");
        // 检查提案是否存在,提案id不能大于提案列表长度
        require(_proposalId < proposals.length, "Proposal does not exist");
        // 检查提案是否已执行
        require(!proposals[_proposalId].executed, "Proposal has already been executed");
        // 检查提案是否已确认,防止重复确认
        require(!proposals[_proposalId].confirmed[msg.sender], "Proposal has already been confirmed");
        proposals[_proposalId].confirmCount++;
        proposals[_proposalId].confirmed[msg.sender] = true;
    }

// 执行提案(达到门槛，任何⼈都可执行提案)
    function executeProposal(uint256 _proposalId) public {
        // 检查是否是提案人
        // bool isOwner = false;
        // for (uint256 i = 0; i < owners.length; i++) {
        //     if (owners[i] == msg.sender) {
        //         isOwner = true;
        //         break;
        //     }
        // }
        // // 检查是否是提案人,只有提案人才能执行提案
        // require(isOwner, "Only owners can execute proposals");
        // 检查提案是否存在,提案id不能大于提案列表长度
        require(_proposalId < proposals.length, "Proposal does not exist");
        // 检查提案是否已执行
        require(!proposals[_proposalId].executed, "Proposal has already been executed");
        // 检查提案是否已确认,确认数量是否大于所需签名数量
        require(proposals[_proposalId].confirmCount >= requiredNum, "Proposal has not been confirmed");
        // 执行提案
        proposals[_proposalId].executed = true;
        (bool success, ) = proposals[_proposalId].to.call{value: proposals[_proposalId].value}(proposals[_proposalId].data);
        // 检查执行是否成功
        require(success, "Proposal execution failed");
    }

    receive() external payable {}




    
}
