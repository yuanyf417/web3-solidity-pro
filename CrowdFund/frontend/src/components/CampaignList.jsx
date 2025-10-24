import React, { useState, useEffect } from 'react';
import { useCrowdfund } from '../hooks/useCrowdfund';
import '../styles/CampaignList.css';

const CampaignList = ({ onSelectCampaign }) => {
  const { getAllCrowdfunds, loading, error } = useCrowdfund();
  const [campaigns, setCampaigns] = useState([]);
  const [isLoading, setIsLoading] = useState(false);

  // 加载众筹活动列表
  const loadCampaigns = async () => {
    setIsLoading(true);
    const data = await getAllCrowdfunds();
    setCampaigns(data);
    setIsLoading(false);
  };

  // 格式化时间
  const formatDeadline = (timestamp) => {
    const date = new Date(parseInt(timestamp) * 1000);
    return date.toLocaleString('zh-CN');
  };

  // 格式化剩余时间
  const formatRemainingTime = (seconds) => {
    if (seconds <= 0) return '已结束';
    
    const days = Math.floor(seconds / (24 * 60 * 60));
    const hours = Math.floor((seconds % (24 * 60 * 60)) / (60 * 60));
    const minutes = Math.floor((seconds % (60 * 60)) / 60);
    
    if (days > 0) {
      return `${days}天 ${hours}小时`;
    } else if (hours > 0) {
      return `${hours}小时 ${minutes}分钟`;
    } else {
      return `${minutes}分钟`;
    }
  };

  useEffect(() => {
    loadCampaigns();
    // 定时刷新列表（每分钟）
    const interval = setInterval(loadCampaigns, 60000);
    return () => clearInterval(interval);
  }, []); // 移除getAllCrowdfunds依赖以避免无限循环

  if (isLoading || loading) {
    return <div className="loading">加载中...</div>;
  }

  if (error) {
    return <div className="error">加载失败: {error}</div>;
  }

  return (
    <div className="campaign-list">
      <h2>众筹活动列表</h2>
      <button className="refresh-btn" onClick={loadCampaigns}>
        刷新列表
      </button>
      
      {campaigns.length === 0 ? (
        <div className="empty-message">暂无众筹活动</div>
      ) : (
        <div className="campaigns-container">
          {campaigns.map((campaign) => (
            <div 
              key={campaign.id} 
              className={`campaign-card ${campaign.isCompleted ? 'completed' : ''}`}
              onClick={() => onSelectCampaign(campaign.id)}
            >
              <div className="campaign-header">
                <h3>{campaign.title}</h3>
                {campaign.isCompleted && <span className="completed-badge">已完成</span>}
              </div>
              
              <p className="campaign-description">{campaign.description.substring(0, 100)}...</p>
              
              <div className="campaign-progress">
                <div className="progress-bar">
                  <div 
                    className="progress-fill" 
                    style={{ width: `${campaign.completionPercentage}%` }}
                  ></div>
                </div>
                <span className="progress-text">{campaign.completionPercentage}%</span>
              </div>
              
              <div className="campaign-stats">
                <div className="stat-item">
                  <span className="stat-label">已筹资金:</span>
                  <span className="stat-value">{campaign.currentAmount} ETH</span>
                </div>
                <div className="stat-item">
                  <span className="stat-label">目标资金:</span>
                  <span className="stat-value">{campaign.goalAmount} ETH</span>
                </div>
              </div>
              
              <div className="campaign-footer">
                <span className="deadline">
                  剩余时间: {formatRemainingTime(campaign.remainingTime)}
                </span>
                <button className="view-detail-btn">查看详情</button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default CampaignList;