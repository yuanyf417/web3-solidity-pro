// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title InvestorRegistry - 投资者信息管理合约
 * @dev 记录众筹参与者的信息和投资金额
 */
contract InvestorRegistry is Ownable, Pausable {
    // 投资者结构
    struct Investor {
        bool isRegistered;
        uint256 totalInvestment; // 总投资金额（以ETH为单位，精度18）
        uint256 mybTokens;       // 获得的MYB代币数量
        uint256 lastUpdateTime;  // 最后更新时间
    }
    
    // 众筹ID到投资者地址的映射
    mapping(uint256 => mapping(address => Investor)) public investors;
    
    // 众筹ID到投资者地址列表的映射
    mapping(uint256 => address[]) public crowdfundInvestors;
    
    // 众筹ID到投资者数量的映射
    mapping(uint256 => uint256) public investorCount;
    
    // 事件定义
    event InvestorRegistered(uint256 indexed crowdfundId, address indexed investor, uint256 investment);
    event InvestmentUpdated(uint256 indexed crowdfundId, address indexed investor, uint256 newTotal);
    event TokensClaimed(uint256 indexed crowdfundId, address indexed investor, uint256 amount);
    
    /**
     * @dev 注册投资者
     * @param crowdfundId 众筹ID
     * @param investor 投资者地址
     * @param investment 投资金额
     */
    function registerInvestor(uint256 crowdfundId, address investor, uint256 investment) external onlyOwner whenNotPaused {
        require(investor != address(0), "Invalid investor address");
        require(investment > 0, "Investment must be greater than 0");
        
        Investor storage user = investors[crowdfundId][investor];
        
        // 如果是新投资者，添加到列表中
        if (!user.isRegistered) {
            user.isRegistered = true;
            crowdfundInvestors[crowdfundId].push(investor);
            investorCount[crowdfundId]++;
            emit InvestorRegistered(crowdfundId, investor, investment);
        } else {
            emit InvestmentUpdated(crowdfundId, investor, user.totalInvestment + investment);
        }
        
        // 更新投资金额
        user.totalInvestment += investment;
        user.lastUpdateTime = block.timestamp;
    }
    
    /**
     * @dev 设置投资者的代币数量
     * @param crowdfundId 众筹ID
     * @param investor 投资者地址
     * @param tokenAmount 代币数量
     */
    function setInvestorTokens(uint256 crowdfundId, address investor, uint256 tokenAmount) external onlyOwner {
        require(investors[crowdfundId][investor].isRegistered, "Investor not registered");
        investors[crowdfundId][investor].mybTokens = tokenAmount;
    }
    
    /**
     * @dev 标记代币已领取
     * @param crowdfundId 众筹ID
     * @param investor 投资者地址
     * @param amount 领取数量
     */
    function markTokensClaimed(uint256 crowdfundId, address investor, uint256 amount) external onlyOwner {
        Investor storage user = investors[crowdfundId][investor];
        require(user.isRegistered, "Investor not registered");
        require(user.mybTokens >= amount, "Insufficient tokens");
        
        user.mybTokens -= amount;
        emit TokensClaimed(crowdfundId, investor, amount);
    }
    
    /**
     * @dev 获取投资者信息
     * @param crowdfundId 众筹ID
     * @param investor 投资者地址
     * @return 投资者结构信息
     */
    function getInvestorInfo(uint256 crowdfundId, address investor) external view returns (Investor memory) {
        return investors[crowdfundId][investor];
    }
    
    /**
     * @dev 获取某个众筹的所有投资者
     * @param crowdfundId 众筹ID
     * @return 投资者地址数组
     */
    function getCrowdfundInvestors(uint256 crowdfundId) external view returns (address[] memory) {
        return crowdfundInvestors[crowdfundId];
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
}