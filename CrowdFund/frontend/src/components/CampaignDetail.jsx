import React, { useState, useEffect } from 'react';
import { useCrowdfund } from '../hooks/useCrowdfund';
import { useWeb3 } from '../utils/Web3Context';
import { useToken } from '../hooks/useToken';
import '../styles/CampaignDetail.css';

const CampaignDetail = ({ campaignId, onBack }) => {
  const { 
    getCrowdfund, 
    invest, 
    releaseFunds, 
    claimRefund,
    getUserInvestment,
    loading,
    error,
    successMessage
  } = useCrowdfund();
  const { account } = useWeb3();
  const { ethToMyb } = useToken();
  
  const [campaign, setCampaign] = useState(null);
  const [investmentAmount, setInvestmentAmount] = useState('');
  const [userInvestment, setUserInvestment] = useState('0');
  const [isLoading, setIsLoading] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);

  // 加载众筹活动详情
  const loadCampaignDetail = async () => {
    if (!campaignId) return;
    
    setIsLoading(true);
    const data = await getCrowdfund(campaignId);
    setCampaign(data);
    
    // 获取用户投资金额
    if (account) {
      const investment = await getUserInvestment(campaignId);
      setUserInvestment(investment);
    }
    
    setIsLoading(false);
  };

  // 处理投资
  const handleInvest = async () => {
    if (!investmentAmount || isNaN(parseFloat(investmentAmount)) || parseFloat(investmentAmount) <= 0) {
      alert('请输入有效的投资金额');
      return;
    }

    setActionLoading(true);
    const success = await invest(campaignId, parseFloat(investmentAmount));
    if (success) {
      setInvestmentAmount('');
      loadCampaignDetail(); // 重新加载详情
    }
    setActionLoading(false);
  };

  // 处理释放资金
  const handleReleaseFunds = async () => {
    if (!window.confirm('确定要释放资金吗？')) return;
    
    setActionLoading(true);
    const success = await releaseFunds(campaignId);
    if (success) {
      loadCampaignDetail(); // 重新加载详情
    }
    setActionLoading(false);
  };

  // 处理申请退款
  const handleClaimRefund = async () => {
    if (!window.confirm('确定要申请退款吗？')) return;
    
    setActionLoading(true);
    const success = await claimRefund(campaignId);
    if (success) {
      loadCampaignDetail(); // 重新加载详情
    }
    setActionLoading(false);
  };

  // 格式化截止时间
  const formatDeadline = (timestamp) => {
    if (!timestamp) return '';
    const date = new Date(parseInt(timestamp) * 1000);
    return date.toLocaleString('zh-CN');
  };

  // 格式化地址
  const formatAddress = (addr) => {
    if (!addr) return '';
    return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
  };

  useEffect(() => {
    loadCampaignDetail();
    // 定时刷新（每分钟）
    const interval = setInterval(loadCampaignDetail, 60000);
    return () => clearInterval(interval);
  }, [campaignId, account]);

  if (isLoading || loading) {
    return <div className="loading">加载中...</div>;
  }

  if (!campaign) {
    return <div className="error">未找到众筹活动</div>;
  }

  // 判断当前用户是否是创建者
  const isCreator = account === campaign.creator;
  
  // 判断是否已过期
  const isExpired = parseInt(campaign.deadline) < Math.floor(Date.now() / 1000);
  
  // 判断是否可以申请退款（未达成目标且已过期）
  const canClaimRefund = isExpired && 
                        parseFloat(campaign.currentAmount) < parseFloat(campaign.goalAmount) && 
                        parseFloat(userInvestment) > 0;
  
  // 判断是否可以释放资金（已达成目标且未完成）
  const canReleaseFunds = !campaign.isCompleted && 
                         parseFloat(campaign.currentAmount) >= parseFloat(campaign.goalAmount);

  return (
    <div className="campaign-detail">
      <button className="back-btn" onClick={onBack}>← 返回列表</button>
      
      <div className="detail-card">
        <h1>{campaign.title}</h1>
        <p className="description">{campaign.description}</p>
        
        <div className="campaign-meta">
          <div className="meta-item">
            <span className="meta-label">创建者:</span>
            <span className="meta-value">{formatAddress(campaign.creator)}</span>
          </div>
          <div className="meta-item">
            <span className="meta-label">截止时间:</span>
            <span className="meta-value">{formatDeadline(campaign.deadline)}</span>
          </div>
          {campaign.isCompleted && (
            <div className="status-badge completed">众筹已完成</div>
          )}
        </div>

        <div className="funding-info">
          <div className="amount-display">
            <div className="current-amount">
              <span className="amount-label">已筹资金</span>
              <span className="amount-value">{campaign.currentAmount} ETH</span>
              <span className="myb-value">({ethToMyb(campaign.currentAmount)} MYB)</span>
            </div>
            <div className="goal-amount">
              <span className="amount-label">目标资金</span>
              <span className="amount-value">{campaign.goalAmount} ETH</span>
              <span className="myb-value">({ethToMyb(campaign.goalAmount)} MYB)</span>
            </div>
          </div>
          
          <div className="progress-container">
            <div className="progress-bar">
              <div 
                className="progress-fill" 
                style={{ width: `${campaign.completionPercentage}%` }}
              ></div>
            </div>
            <span className="progress-text">{campaign.completionPercentage}%</span>
          </div>
        </div>

        {/* 投资表单 */}
        {!campaign.isCompleted && !isExpired && (
          <div className="investment-form">
            <h3>参与投资</h3>
            <div className="form-group">
              <input
                type="number"
                step="0.01"
                min="0.01"
                value={investmentAmount}
                onChange={(e) => setInvestmentAmount(e.target.value)}
                placeholder="输入投资金额 (ETH)"
              />
              <button 
                onClick={handleInvest}
                disabled={actionLoading || !investmentAmount}
              >
                {actionLoading ? '处理中...' : '立即投资'}
              </button>
            </div>
            <p className="min-investment">最低投资金额: 0.01 ETH</p>
          </div>
        )}

        {/* 用户投资信息 */}
        {account && parseFloat(userInvestment) > 0 && (
          <div className="user-investment">
            <p>您已投资: <strong>{userInvestment} ETH</strong></p>
          </div>
        )}

        {/* 操作按钮区 */}
        <div className="action-buttons">
          {/* 释放资金按钮（仅创建者可见） */}
          {isCreator && canReleaseFunds && (
            <button 
              className="primary-btn"
              onClick={handleReleaseFunds}
              disabled={actionLoading}
            >
              {actionLoading ? '处理中...' : '释放资金'}
            </button>
          )}
          
          {/* 申请退款按钮 */}
          {canClaimRefund && (
            <button 
              className="secondary-btn"
              onClick={handleClaimRefund}
              disabled={actionLoading}
            >
              {actionLoading ? '处理中...' : '申请退款'}
            </button>
          )}
          
          {/* 已过期提示 */}
          {isExpired && !campaign.isCompleted && parseFloat(campaign.currentAmount) < parseFloat(campaign.goalAmount) && (
            <p className="expired-message">众筹已过期且未达成目标，投资者可申请退款</p>
          )}
        </div>
      </div>

      {/* 消息提示 */}
      {error && (
        <div className="message error-message">{error}</div>
      )}
      {successMessage && (
        <div className="message success-message">{successMessage}</div>
      )}
    </div>
  );
};

export default CampaignDetail;