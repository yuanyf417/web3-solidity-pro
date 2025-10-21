// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./MYBToken.sol";
import "./InvestorRegistry.sol";

/**
 * @title CrowdFundCore - 众筹核心合约
 * @dev 管理众筹活动的创建、资金募集和发放
 */
contract CrowdFundCore is Ownable, ReentrancyGuard, Pausable {
    // 众筹状态枚举
    enum CrowdfundStatus { PENDING, ACTIVE, SUCCESSFUL, FAILED, REFUNDED }
    
    // 众筹结构
    struct Crowdfund {
        uint256 id;
        string projectName;
        address creator;
        uint256 targetAmount;        // 目标金额（以ETH为单位，精度18）
        uint256 currentAmount;       // 当前募集金额
        uint256 deadline;            // 截止时间戳
        uint256 mybPerEth;           // 每ETH兑换的MYB数量
        CrowdfundStatus status;      // 众筹状态
        uint256 createdAt;           // 创建时间
        bool fundsReleased;          // 资金是否已释放
    }
    
    // 众筹ID计数器
    uint256 public crowdfundCounter;
    
    // 众筹ID到众筹详情的映射
    mapping(uint256 => Crowdfund) public crowdfunds;
    
    // MYB代币合约地址
    MYBToken public mybToken;
    
    // 投资者管理合约地址
    InvestorRegistry public investorRegistry;
    
    // 资金分配比例（基点，10000 = 100%）
    uint256 public constant INVESTOR_ALLOCATION = 7000;   // 70%
    uint256 public constant DEVELOPMENT_ALLOCATION = 2000; // 20%
    uint256 public constant COMMUNITY_ALLOCATION = 1000;  // 10%
    
    // 开发基金地址
    address public devFundAddress;
    
    // 社区基金地址
    address public communityFundAddress;
    
    // 事件定义
    event CrowdfundCreated(uint256 indexed crowdfundId, string projectName, address creator, uint256 targetAmount, uint256 deadline);
    event InvestmentReceived(uint256 indexed crowdfundId, address indexed investor, uint256 amount, uint256 mybTokens);
    event CrowdfundSuccessful(uint256 indexed crowdfundId, uint256 totalAmount);
    event CrowdfundFailed(uint256 indexed crowdfundId);
    event FundsReleased(uint256 indexed crowdfundId, address indexed recipient, uint256 amount);
    event RefundIssued(uint256 indexed crowdfundId, address indexed investor, uint256 amount);
    event TokensClaimed(uint256 indexed crowdfundId, address indexed investor, uint256 amount);
    
    /**
     * @dev 构造函数
     * @param _mybToken MYB代币合约地址
     * @param _investorRegistry 投资者管理合约地址
     * @param _devFundAddress 开发基金地址
     * @param _communityFundAddress 社区基金地址
     */
    constructor(
        address _mybToken,
        address _investorRegistry,
        address _devFundAddress,
        address _communityFundAddress
    ) {
        require(_mybToken != address(0), "Invalid MYB token address");
        require(_investorRegistry != address(0), "Invalid investor registry address");
        require(_devFundAddress != address(0), "Invalid dev fund address");
        require(_communityFundAddress != address(0), "Invalid community fund address");
        
        mybToken = MYBToken(_mybToken);
        investorRegistry = InvestorRegistry(_investorRegistry);
        devFundAddress = _devFundAddress;
        communityFundAddress = _communityFundAddress;
    }
    
    /**
     * @dev 创建众筹活动
     * @param projectName 项目名称
     * @param targetAmount 目标金额（ETH）
     * @param deadline 截止时间戳
     */
    function createCrowdfund(string memory projectName, uint256 targetAmount, uint256 deadline) external whenNotPaused {
        require(bytes(projectName).length > 0, "Project name cannot be empty");
        require(targetAmount > 0, "Target amount must be greater than 0");
        require(deadline > block.timestamp, "Deadline must be in the future");
        
        crowdfundCounter++;
        uint256 crowdfundId = crowdfundCounter;
        
        // 获取当前的ETH兑换MYB比例
        uint256 mybPerEth = mybToken.exchangeRate();
        
        // 创建众筹记录
        crowdfunds[crowdfundId] = Crowdfund({
            id: crowdfundId,
            projectName: projectName,
            creator: msg.sender,
            targetAmount: targetAmount,
            currentAmount: 0,
            deadline: deadline,
            mybPerEth: mybPerEth,
            status: CrowdfundStatus.ACTIVE,
            createdAt: block.timestamp,
            fundsReleased: false
        });
        
        emit CrowdfundCreated(crowdfundId, projectName, msg.sender, targetAmount, deadline);
    }
    
    /**
     * @dev 参与众筹
     * @param crowdfundId 众筹ID
     */
    function invest(uint256 crowdfundId) external payable nonReentrant whenNotPaused {
        require(msg.value > 0, "Investment amount must be greater than 0");
        
        Crowdfund storage crowdfund = crowdfunds[crowdfundId];
        require(crowdfund.status == CrowdfundStatus.ACTIVE, "Crowdfund is not active");
        require(block.timestamp < crowdfund.deadline, "Crowdfund has ended");
        
        // 计算获得的MYB代币数量
        uint256 mybTokens = (msg.value * crowdfund.mybPerEth) / 1 ether;
        
        // 更新众筹金额
        crowdfund.currentAmount += msg.value;
        
        // 注册投资者
        investorRegistry.registerInvestor(crowdfundId, msg.sender, msg.value);
        
        // 设置投资者的代币数量
        investorRegistry.setInvestorTokens(crowdfundId, msg.sender, mybTokens);
        
        emit InvestmentReceived(crowdfundId, msg.sender, msg.value, mybTokens);
        
        // 检查是否达到目标
        if (crowdfund.currentAmount >= crowdfund.targetAmount) {
            crowdfund.status = CrowdfundStatus.SUCCESSFUL;
            emit CrowdfundSuccessful(crowdfundId, crowdfund.currentAmount);
        }
    }
    
    /**
     * @dev 结束众筹
     * @param crowdfundId 众筹ID
     */
    function finalizeCrowdfund(uint256 crowdfundId) external whenNotPaused {
        Crowdfund storage crowdfund = crowdfunds[crowdfundId];
        require(crowdfund.status == CrowdfundStatus.ACTIVE, "Crowdfund is not active");
        require(block.timestamp >= crowdfund.deadline, "Crowdfund deadline not reached");
        
        // 判断众筹是否成功
        if (crowdfund.currentAmount >= crowdfund.targetAmount) {
            crowdfund.status = CrowdfundStatus.SUCCESSFUL;
            emit CrowdfundSuccessful(crowdfundId, crowdfund.currentAmount);
        } else {
            crowdfund.status = CrowdfundStatus.FAILED;
            emit CrowdfundFailed(crowdfundId);
        }
    }
    
    /**
     * @dev 释放筹集的资金给项目方和各类基金
     * @param crowdfundId 众筹ID
     */
    function releaseFunds(uint256 crowdfundId) external nonReentrant onlyOwner {
        Crowdfund storage crowdfund = crowdfunds[crowdfundId];
        require(crowdfund.status == CrowdfundStatus.SUCCESSFUL, "Crowdfund not successful");
        require(!crowdfund.fundsReleased, "Funds already released");
        
        uint256 totalFunds = crowdfund.currentAmount;
        
        // 计算各方应得金额
        uint256 projectCreatorAmount = (totalFunds * INVESTOR_ALLOCATION) / 10000;
        uint256 devFundAmount = (totalFunds * DEVELOPMENT_ALLOCATION) / 10000;
        uint256 communityFundAmount = (totalFunds * COMMUNITY_ALLOCATION) / 10000;
        
        // 标记资金已释放
        crowdfund.fundsReleased = true;
        
        // 转账给项目方
        (bool successCreator, ) = crowdfund.creator.call{value: projectCreatorAmount}("");
        require(successCreator, "Transfer to creator failed");
        emit FundsReleased(crowdfundId, crowdfund.creator, projectCreatorAmount);
        
        // 转账给开发基金
        (bool successDev, ) = devFundAddress.call{value: devFundAmount}("");
        require(successDev, "Transfer to dev fund failed");
        emit FundsReleased(crowdfundId, devFundAddress, devFundAmount);
        
        // 转账给社区基金
        (bool successCommunity, ) = communityFundAddress.call{value: communityFundAmount}("");
        require(successCommunity, "Transfer to community fund failed");
        emit FundsReleased(crowdfundId, communityFundAddress, communityFundAmount);
    }
    
    /**
     * @dev 众筹失败后投资者申请退款
     * @param crowdfundId 众筹ID
     */
    function claimRefund(uint256 crowdfundId) external nonReentrant {
        Crowdfund storage crowdfund = crowdfunds[crowdfundId];
        require(crowdfund.status == CrowdfundStatus.FAILED, "Crowdfund not failed");
        
        // 获取投资者信息
        InvestorRegistry.Investor memory investor = investorRegistry.getInvestorInfo(crowdfundId, msg.sender);
        require(investor.isRegistered, "Not an investor");
        require(investor.totalInvestment > 0, "No investment to refund");
        
        uint256 refundAmount = investor.totalInvestment;
        
        // 重置投资金额（防止重复退款）
        investorRegistry.registerInvestor(crowdfundId, msg.sender, 0);
        
        // 转账退款
        (bool success, ) = msg.sender.call{value: refundAmount}("");
        require(success, "Refund transfer failed");
        
        emit RefundIssued(crowdfundId, msg.sender, refundAmount);
    }
    
    /**
     * @dev 众筹成功后投资者领取MYB代币
     * @param crowdfundId 众筹ID
     */
    function claimTokens(uint256 crowdfundId) external nonReentrant {
        Crowdfund storage crowdfund = crowdfunds[crowdfundId];
        require(crowdfund.status == CrowdfundStatus.SUCCESSFUL, "Crowdfund not successful");
        require(crowdfund.fundsReleased, "Funds not yet released");
        
        // 获取投资者信息
        InvestorRegistry.Investor memory investor = investorRegistry.getInvestorInfo(crowdfundId, msg.sender);
        require(investor.isRegistered, "Not an investor");
        require(investor.mybTokens > 0, "No tokens to claim");
        
        uint256 tokenAmount = investor.mybTokens;
        
        // 标记代币已领取
        investorRegistry.markTokensClaimed(crowdfundId, msg.sender, tokenAmount);
        
        // 转账MYB代币
        require(mybToken.transfer(msg.sender, tokenAmount), "Token transfer failed");
        
        emit TokensClaimed(crowdfundId, msg.sender, tokenAmount);
    }
    
    /**
     * @dev 获取众筹状态信息
     * @param crowdfundId 众筹ID
     * @return 众筹详情
     */
    function getCrowdfundStatus(uint256 crowdfundId) external view returns (Crowdfund memory) {
        return crowdfunds[crowdfundId];
    }
    
    /**
     * @dev 更新开发基金地址
     * @param newAddress 新地址
     */
    function updateDevFundAddress(address newAddress) external onlyOwner {
        require(newAddress != address(0), "Invalid address");
        devFundAddress = newAddress;
    }
    
    /**
     * @dev 更新社区基金地址
     * @param newAddress 新地址
     */
    function updateCommunityFundAddress(address newAddress) external onlyOwner {
        require(newAddress != address(0), "Invalid address");
        communityFundAddress = newAddress;
    }
    
    /**
     * @dev 暂停合约
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev 恢复合约
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev 获取合约余额
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}