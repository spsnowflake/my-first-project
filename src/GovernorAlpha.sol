// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Timelock.sol";
import "./Comp.sol";

///  Compound 链上治理合约（Governor Alpha）
/// 负责提案、投票、计票，并把通过的提案交给 Timelock 延迟执行
contract GovernorAlpha {
    Timelock immutable public timelock;
    Comp immutable public comp;

    ///  治理守护者地址（紧急取消等权限）
    address public guardian;

    //  历史提案总数（也用作下一个提案 ID）
    uint public proposalCount;

   ///  提案数据结构：保存要执行的 target / calldata 等全部信息
    struct Proposal {
        uint id;         //  提案唯一 ID
        address proposer;  //  提案创建者
        uint eta;          //  可执行时间戳（eta），投票成功并入队后设置
        address[] targets; //  要调用的目标合约地址列表（按顺序）
        uint[] values;     //  每次调用附带的 ETH 数量（msg.value）列表
        string[] signatures; //  要调用的函数签名列表，如 "setDelay(uint256)"
        bytes[] calldatas; //  每次调用对应的 calldata（函数参数编码）列表
        uint startBlock;   //  投票开始区块；持币人须在此区块前完成委托，票数才生效
        uint endBlock;     //  投票结束区块；须在此区块前完成投票
        uint forVotes;     //  当前赞成票总数
        uint againstVotes; //  当前反对票总数
        bool canceled;     //  提案是否已被取消
        bool executed;     //  提案是否已被执行
        mapping (address => Receipt) receipts; //  所有投票人的投票回执记录
    }
    ///  单个投票人的投票回执
    struct Receipt {
        //  是否已投票
        bool hasVoted;    
        //  是否支持该提案（true=赞成，false=反对）
        bool support;
        //  该投票人实际投出的票数
        uint votes;
    }
    ///  所有历史提案的正式记录
    mapping (uint => Proposal) public proposals;
    ///  每个提案人最近一次提案的 ID（用于限制同时只能有一个进行中的提案）
    mapping (address => uint) public latestProposalIds;

    ///  提案可能处于的状态
    enum ProposalState {
        Pending,    // 等待投票开始
        Active,     // 投票进行中
        Canceled,   // 已取消
        Defeated,   // 未通过（赞成不足或未达法定人数）
        Succeeded,  // 投票通过，待入队
        Queued,     // 已进入 Timelock 排队，等待延迟结束
        Expired,    // 超过宽限期未执行而过期
        Executed    // 已执行
    }

    constructor(Timelock _timelock, Comp _comp, address _guardian) {
        timelock = Timelock(_timelock);
        comp = Comp(_comp);
        guardian = _guardian;
    }

     //  提交提案：保存要调用的 target、signature、calldata 等动作信息
    /// @param targets 目标合约地址列表
    /// @param values 每次调用附带的 ETH 数量
    /// @param signatures 函数签名列表
    /// @param calldatas 函数参数 calldata 列表
    /// @param description 提案描述
    /// @return 新提案 ID
    function propose(address[] memory targets, uint[] memory values, string[] memory signatures, bytes[] memory calldatas, string memory description) public returns (uint) {
        require(comp.getPriorVotes(msg.sender, block.number - 1) >= proposalThreshold(), "GovernorAlpha::propose: proposer does not have enough votes to propose");
        require(targets.length == values.length && targets.length == signatures.length && targets.length == calldatas.length, "GovernorAlpha::propose: invalid proposal length");
        require(targets.length > 0, "GovernorAlpha::propose: must have at least one action");
        require(targets.length <= proposalMaxOperations(), "GovernorAlpha::propose: proposal operation length exceeds");
        require(bytes(description).length > 0, "GovernorAlpha::propose: description is required");

// 创建新提案
        proposalCount++;
        uint proposalId = proposalCount;
        Proposal storage newProposal = proposals[proposalId];
        // 正常情况下不应发生，额外做一次碰撞检查
        require(newProposal.id == 0, "GovernorAlpha::propose: ProposalID collsion");
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.eta = 0;
        newProposal.targets = targets;
        newProposal.values = values;
        newProposal.signatures = signatures;
        newProposal.calldatas = calldatas;
        newProposal.startBlock = add256(block.number, votingDelay());
        newProposal.endBlock = add256(newProposal.startBlock, votingPeriod());
        newProposal.forVotes = 0;
        newProposal.againstVotes = 0;
        newProposal.canceled = false;
        newProposal.executed = false;

        latestProposalIds[msg.sender] = proposalId;
        return proposalId;
    }


      //  将投票通过的提案排队进入 Timelock（设置延迟执行时间 eta）
    /// @param proposalId 提案 ID
    function queue(uint proposalId) public {
        require(state(proposalId) == ProposalState.Succeeded, "GovernorAlpha::queue: proposal can only be queued if it is succeeded");
        Proposal storage proposal = proposals[proposalId];
        // 设置延迟执行时间 eta
        uint eta = add256(block.timestamp, timelock.delay());
        // 将每个 action 放入 Timelock
        for (uint i = 0; i < proposal.targets.length; i++) {
            _queueOrRevert(proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], eta);
        }
        proposal.eta = eta;

    }


     //  将单个 action 放入 Timelock；若同 eta 已排队则回滚
    function _queueOrRevert(address target, uint value, string memory signature, bytes memory data, uint eta) internal {
        require(!timelock.queuedTransactions(keccak256(abi.encode(target, value, signature, data, eta))), "GovernorAlpha::_queueOrRevert: proposal action already queued at eta");
        timelock.queueTransaction(target, value, signature, data, eta);
    }


     //  在延迟时间到达后，通过 Timelock 真正执行提案中的所有动作
    /// @param proposalId 提案 ID
    function execute(uint proposalId) public payable {
        require(state(proposalId) == ProposalState.Queued, "GovernorAlpha::execute: proposal can only be executed if it is queued");
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;
        for (uint i = 0; i < proposal.targets.length; i++) {
            timelock.executeTransaction{value: proposal.values[i]}(proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], proposal.eta);
        }
    }


      //  取消提案：守护者可随时取消；或提案人投票权已跌破门槛时任何人可取消
    /// @param proposalId 提案 ID
    function cancel(uint proposalId) public {
        require(state(proposalId) != ProposalState.Executed, "GovernorAlpha::cancel: cannot cancel executed proposal");
        Proposal storage proposal = proposals[proposalId];
        // 守护者或提案人投票权已跌破门槛时,任何人可取消
        require(msg.sender == guardian || comp.getPriorVotes(proposal.proposer, sub256(block.number, 1)) < proposalThreshold(), "GovernorAlpha::cancel: proposer above threshold");
        proposal.canceled = true;
        for (uint i = 0; i < proposal.targets.length; i++) {
            timelock.cancelTransaction(proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], proposal.eta);
        }
    }

    ///  链上投票：msg.sender 对提案投赞成/反对票
    /// @param proposalId 提案 ID
    /// @param support true=赞成，false=反对
    function castVote(uint proposalId, bool support) public {
        return _castVote(msg.sender, proposalId, support);
    }

        /// 计票核心：按提案 startBlock 的历史票数计票，并写入回执
    /// @dev 调用 Comp.getPriorVotes，防止提案后买票操纵
    function _castVote(address voter, uint proposalId, bool support) internal {
        // 开始计票，必须处于投票进行中状态
        require(state(proposalId) == ProposalState.Active, "GovernorAlpha::_castVote: voting is closed");
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        // 投票人不能重复投票
        require(!receipt.hasVoted, "GovernorAlpha::_castVote: voter already voted");
        // 获取投票人投票权
        uint votes = comp.getPriorVotes(voter, proposal.startBlock);
        // 支持则增加赞成票，反对则增加反对票
        if (support) {
            proposal.forVotes = add256(proposal.forVotes, votes);
        } else {
            proposal.againstVotes = add256(proposal.againstVotes, votes);
        }
        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

    }
    

        //  查询提案要执行的全部动作（targets / values / signatures / calldatas）
    function getActions(uint proposalId) public view returns (address[] memory targets, uint[] memory values, string[] memory signatures, bytes[] memory calldatas) {
        Proposal storage p = proposals[proposalId];
        return (p.targets, p.values, p.signatures, p.calldatas);
    }

        ///  查询某人对某提案的投票回执
    function getReceipt(uint proposalId, address voter) public view returns (Receipt memory) {
        return proposals[proposalId].receipts[voter];
    }


    ///  计算并返回提案当前状态（状态机核心）
    /// @dev Pending → Active → Succeeded → Queued → Executed（或 Canceled / Defeated / Expired）
    function state(uint proposalId) public view returns (ProposalState) {
        require(proposalCount >= proposalId && proposalId > 0, "GovernorAlpha::state: invalid proposal id");
        Proposal storage proposal = proposals[proposalId];
        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < quorumVotes()) {
            return ProposalState.Defeated;
        } else if (proposal.eta == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp >= add256(proposal.eta, timelock.GRACE_PERIOD())) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    
    ///  安全加法（防溢出）
    function add256(uint256 a, uint256 b) internal pure returns (uint) {
        uint c = a + b;
        require(c >= a, "addition overflow");
        return c;
    }

    ///  安全减法（防下溢）
    function sub256(uint256 a, uint256 b) internal pure returns (uint) {
        require(b <= a, "subtraction underflow");
        return a - b;
    }

    //  提案通过所需的法定赞成票数（达到法定人数且投票成功） 400,000 = 4% of Comp
    function quorumVotes() public pure returns (uint) { return 400000e18; }

    ///  发起提案所需的最低投票权门槛,100,000 = 1% of Comp
    function proposalThreshold() public pure returns (uint) { return 100000e18; } 

    ///  单个提案最多可包含的操作（actions）数量
    function proposalMaxOperations() public pure returns (uint) { return 10; } // 10 actions

    ///  提案提交后，到投票开始前的等待区块数
    function votingDelay() public pure returns (uint) { return 1; } // 1 block

    ///  投票持续的区块数（约 3 天 ,假设每个区块15秒）
    function votingPeriod() virtual public pure returns (uint) { return 17280; } 




}

