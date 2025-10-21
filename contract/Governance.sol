// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title Governance - CreatorToken平台的去中心化治理系统
/// @notice 实现提案、投票和执行机制的治理合约
/// @dev 基于时间锁定的治理系统，与ERC20代币集成
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract Governance is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    // 提案状态
    enum ProposalState {
        Pending,     // 待处理
        Active,      // 活跃中（可投票）
        Canceled,    // 已取消
        Defeated,    // 被否决
        Succeeded,   // 已通过
        Queued,      // 已入队
        Expired,     // 已过期
        Executed     // 已执行
    }

    // 提案结构
    struct Proposal {
        // 提案ID
        uint256 id;
        // 提案创建者
        address proposer;
        // 提案描述
        string description;
        // 提案目标合约
        address target;
        // 提案调用数据
        bytes data;
        // 提案值（ETH）
        uint256 value;
        // 提案开始时间
        uint256 startTime;
        // 提案结束时间
        uint256 endTime;
        // 赞成票计数
        uint256 forVotes;
        // 反对票计数
        uint256 againstVotes;
        // 提案执行时间锁
        uint256 eta;
        // 提案已取消
        bool canceled;
        // 提案已执行
        bool executed;
        // 投票映射 (投票者 => 已投票)
        mapping(address => bool) hasVoted;
    }

    // 提案计数器
    uint256 public proposalCount;
    // 提案映射
    mapping(uint256 => Proposal) public proposals;
    // 投票代币
    IERC20 public token;
    // 提案所需最低代币数量
    uint256 public proposalThreshold;
    // 投票期长度 (秒)
    uint256 public votingPeriod;
    // 执行延迟 (秒)
    uint256 public executionDelay;
    // 提案最大有效期 (秒)
    uint256 public maxExecutionPeriod;

    // 事件
    event ProposalCreated(
        uint256 indexed id,
        address indexed proposer,
        address indexed target,
        string description,
        bytes data,
        uint256 startTime,
        uint256 endTime
    );
    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        bool support
    );
    event ProposalCanceled(uint256 indexed id);
    event ProposalExecuted(uint256 indexed id);
    event ProposalQueued(uint256 indexed id, uint256 eta);

    constructor(
        address _token,
        uint256 _proposalThreshold,
        uint256 _votingPeriod,
        uint256 _executionDelay,
        uint256 _maxExecutionPeriod
    ) {
        require(_token != address(0), "Governance: token address cannot be zero");
        token = IERC20(_token);
        proposalThreshold = _proposalThreshold;
        votingPeriod = _votingPeriod;
        executionDelay = _executionDelay;
        maxExecutionPeriod = _maxExecutionPeriod;
    }

    /// @notice 创建一个新的治理提案
    /// @param target 目标合约地址
    /// @param data 调用数据
    /// @param value 发送的ETH金额
    /// @param description 提案描述
    function propose(
        address target,
        bytes calldata data,
        uint256 value,
        string calldata description
    ) external returns (uint256) {
        require(token.balanceOf(msg.sender) >= proposalThreshold, "Governance: proposer below threshold");
        require(target.isContract(), "Governance: not a valid contract");

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime.add(votingPeriod);

        proposalCount += 1;
        Proposal storage proposal = proposals[proposalCount];
        proposal.id = proposalCount;
        proposal.proposer = msg.sender;
        proposal.target = target;
        proposal.data = data;
        proposal.value = value;
        proposal.description = description;
        proposal.startTime = startTime;
        proposal.endTime = endTime;

        emit ProposalCreated(
            proposalCount,
            msg.sender,
            target,
            description,
            data,
            startTime,
            endTime
        );

        return proposalCount;
    }

    /// @notice 对提案进行投票
    /// @param proposalId 提案ID
    /// @param support 是否支持该提案
    function castVote(uint256 proposalId, bool support) external {
        require(state(proposalId) == ProposalState.Active, "Governance: voting is closed");
        require(!proposals[proposalId].hasVoted[msg.sender], "Governance: already voted");

        uint256 votes = token.balanceOf(msg.sender);
        require(votes > 0, "Governance: no votes");

        Proposal storage proposal = proposals[proposalId];
        proposal.hasVoted[msg.sender] = true;

        if (support) {
            proposal.forVotes = proposal.forVotes.add(votes);
        } else {
            proposal.againstVotes = proposal.againstVotes.add(votes);
        }

        emit VoteCast(msg.sender, proposalId, support);
    }

    /// @notice 取消提案
    /// @param proposalId 提案ID
    function cancel(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.proposer == msg.sender, "Governance: only proposer can cancel");
        require(state(proposalId) != ProposalState.Executed, "Governance: cannot cancel executed proposal");

        proposal.canceled = true;

        emit ProposalCanceled(proposalId);
    }

    /// @notice 将提案入队以执行
    /// @param proposalId 提案ID
    function queue(uint256 proposalId) external {
        require(state(proposalId) == ProposalState.Succeeded, "Governance: proposal not successful");

        Proposal storage proposal = proposals[proposalId];
        uint256 eta = block.timestamp.add(executionDelay);
        proposal.eta = eta;

        emit ProposalQueued(proposalId, eta);
    }

    /// @notice 执行提案
    /// @param proposalId 提案ID
    function execute(uint256 proposalId) external payable {
        require(state(proposalId) == ProposalState.Queued, "Governance: proposal not queued");

        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;

        (bool success, ) = proposal.target.call{value: proposal.value}(proposal.data);
        require(success, "Governance: proposal execution failed");

        emit ProposalExecuted(proposalId);
    }

    /// @notice 获取提案的当前状态
    /// @param proposalId 提案ID
    function state(uint256 proposalId) public view returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Governance: invalid proposal id");

        if (proposal.canceled) return ProposalState.Canceled;
        if (block.timestamp <= proposal.endTime) return ProposalState.Active;
        if (proposal.forVotes <= proposal.againstVotes) return ProposalState.Defeated;
        if (proposal.executed) return ProposalState.Executed;
        if (proposal.eta == 0) return ProposalState.Succeeded;
        if (block.timestamp >= proposal.eta.add(maxExecutionPeriod)) return ProposalState.Expired;
        if (block.timestamp >= proposal.eta) return ProposalState.Queued;

        return ProposalState.Pending;
    }

    /// @notice 更新治理参数
    /// @param _proposalThreshold 新的提案阈值
    /// @param _votingPeriod 新的投票周期
    /// @param _executionDelay 新的执行延迟
    function updateGovernanceParameters(
        uint256 _proposalThreshold,
        uint256 _votingPeriod,
        uint256 _executionDelay
    ) external onlyOwner {
        proposalThreshold = _proposalThreshold;
        votingPeriod = _votingPeriod;
        executionDelay = _executionDelay;
    }
}