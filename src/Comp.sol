// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;



// 可投票的治理代币
contract Comp {

    address public immutable owner;

    // 代币名称
    string public constant name = "Compound";

    //  代币符号
    string public constant symbol = "COMP";

    //  代币精度
    uint8 public constant decimals = 18;

    //  代币总供应量（1000 万枚）
    uint public constant totalSupply = 10000000e18; // 10 million Comp

    //  授权额度：owner => spender => amount
    mapping (address => mapping (address => uint)) internal allowances;

    //  各账户代币余额
    mapping (address => uint) internal balances;

    //  各账户当前委托给谁（投票权指向的地址）
    mapping (address => address) public delegates;

    //  每个账户的投票权检查点列表：account => index => Checkpoint
    mapping (address => mapping (uint => Checkpoint)) public checkpoints;

    //  每个账户已有的检查点数量
    mapping (address => uint) public numCheckpoints;


    //  投票权检查点：记录从某区块起的票数（用于历史查询）
    struct Checkpoint {
        uint fromBlock; // 该快照生效的起始区块
        uint votes;     // 该区块起的投票权数量
    }



    //  账户变更委托对象时触发
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    //  被委托人的投票权余额变化时触发
    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);

    //  标准 EIP-20 转账事件
    event Transfer(address indexed from, address indexed to, uint256 amount);

    //  标准 EIP-20 授权事件
    event Approval(address indexed owner, address indexed spender, uint256 amount);


    constructor(address _owner) {
        require(_owner != address(0), "Invalid owner address");
        owner = _owner;
        balances[owner] = totalSupply;
        emit Transfer(address(0), owner, totalSupply);
    }




    // 内部转账：改余额，并按双方当前委托对象移动投票权
    function _transferTokens(address from_address, address to_address, uint amount) internal {
        balances[from_address] = subUint(balances[from_address], amount, "Comp::_transferTokens: transfer amount exceeds balance");
        balances[to_address] = addUint(balances[to_address], amount, "Comp::_transferTokens: transfer amount overflows");
        emit Transfer(from_address, to_address, amount);
        _moveDelegates(delegates[from_address], delegates[to_address], amount);

    }

    // 写入投票权检查点；同一区块内多次变更则覆盖最新一条
    function _writeCheckpoint(address delegatee, uint nCheckpoints, uint oldVotes, uint newVotes) internal {
        // 如果是同一个区块，则覆盖最新一条（且不是第一次写入）   
        if(nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == block.number) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            // 如果是第一次写入或者不是同一个区块，则创建新检查点
            checkpoints[delegatee][nCheckpoints] = Checkpoint(block.number, newVotes);
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }
        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);

    }

    // 在旧委托人与新委托人之间移动投票权，并写入检查点
    function _moveDelegates(address from_address, address to_address, uint amount) internal {
        if(from_address != to_address && amount > 0) {
            if(from_address != address(0)) {
                uint nCheckpoints = numCheckpoints[from_address];
                // nCheckpoints - 1: 获取最后一个检查点
                uint oldVotes = nCheckpoints > 0 ? checkpoints[from_address][nCheckpoints - 1].votes : 0;
                uint newVotes = subUint(oldVotes, amount, "Comp::_moveDelegates: vote amount underflows");
                _writeCheckpoint(from_address, nCheckpoints, oldVotes, newVotes);
            }
            if(to_address != address(0)) {
                uint nCheckpoints = numCheckpoints[to_address];
                uint oldVotes = nCheckpoints > 0 ? checkpoints[to_address][nCheckpoints - 1].votes : 0;
                uint newVotes = addUint(oldVotes, amount, "Comp::_moveDelegates: vote amount overflows");
                _writeCheckpoint(to_address, nCheckpoints, oldVotes, newVotes);
            }
        }
    }


    // 内部委托逻辑：更新委托关系，并移动对应投票权
    function _delegate(address delegator, address delegatee) internal {
        address currentDelegate = delegates[delegator];
        uint currentVotes = getCurrentVotes(delegator);
        delegates[delegator] = delegatee;
        _moveDelegates(currentDelegate, delegatee, currentVotes);
        emit DelegateChanged(delegator, currentDelegate, delegatee);

    }


    //  查询账户在指定历史区块时的投票权（治理计票核心）
    function getPriorVotes(address account, uint blockNumber) public view returns (uint) {
        require(blockNumber < block.number, "Comp::getPriorVotes: block not yet reached");
        uint nCheckpoints = numCheckpoints[account];
        // 如果账户没有检查点，则返回 0，说明该账户没有投票权
        if(nCheckpoints == 0) {
            return 0;
        }

// 如果最后一个检查点的起始区块小于等于 blockNumber，说明该账户后面没有检查点，直接返回最后一个检查点的投票权数量
        if (checkpoints[account][nCheckpoints-1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints-1].votes;
        }

        // 如果最早的检查点的起始区块比 blockNumber 还大，则返回 0，说明该账户在 blockNumber 之前没有投票权
        if(checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        // 二分查找，查找比 blockNumber 小的最大检查点
        uint low = 0;
        uint high = nCheckpoints - 1;
        while(low < high) {
            // 用hith来减，而不是选择(high-low)/2+low，是选择偏向上界。Solidity除法默认丢掉小数
            uint mid = high - (high-low)/2;
            Checkpoint memory cp = checkpoints[account][mid];
            // 如果刚好等于blockNumber，则返回该快照的票数
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            }else if(cp.fromBlock < blockNumber) {
                low = mid;
            } else {
                // 因为之前已经判断过mid=blockNumber的情况，所以这里high=mid-1
                high = mid - 1;
            }
        }
        return checkpoints[account][low].votes;
    }

// 查询账户最新检查点的投票权
    function getCurrentVotes(address account) public view returns (uint) {
        uint nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    /**
     *  将 msg.sender 的投票权委托给 delegatee（可委托给自己）
     * @param delegatee 接受委托的地址
     */
    function delegate(address delegatee) public {
        return _delegate(msg.sender, delegatee);
    }


    function transfer(address to_address, uint amount) external returns (bool) {
        _transferTokens(msg.sender, to_address, amount);
        return true;
    }

    //  获取账户代币余额
    function balanceOf(address account) external view returns (uint) {
        return balances[account];
    }

    //  授权额度
    function approve(address spender, uint amount) external returns (bool) {
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    //  获取授权额度
    function allowance(address account, address spender) external view returns (uint) {
        return allowances[account][spender];
    }

    // 从 from_address 向 to_address 转账（需授权）；同时按委托关系移动投票权
    function transferFrom(address from_address, address to_address, uint amount) external returns (bool) {
        address spender = msg.sender;
        uint spenderAllowance = allowances[from_address][spender];

        if (spender != from_address && spenderAllowance != type(uint96).max) {
            uint newAllowance = subUint(spenderAllowance, amount, "Comp::transferFrom: transfer amount exceeds spender allowance");
            allowances[from_address][spender] = newAllowance;

            emit Approval(from_address, spender, newAllowance);
        }

        _transferTokens(from_address, to_address, amount);
        return true;
    }



    //uint 安全减法
    function subUint(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        require(b <= a, errorMessage);
        return a - b;
    }

    //uint 安全加法
    function addUint(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        require(b + a >= a, errorMessage);
        return a + b;
    }
}