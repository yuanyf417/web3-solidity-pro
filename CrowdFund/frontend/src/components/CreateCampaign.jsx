import React, { useState } from 'react';
import { useCrowdfund } from '../hooks/useCrowdfund';
import { useWeb3 } from '../utils/Web3Context';
import '../styles/CreateCampaign.css';

const CreateCampaign = ({ onSuccess }) => {
  const { createCrowdfund, loading, error, successMessage } = useCrowdfund();
  const { isConnected } = useWeb3();
  
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    goalAmount: '',
    deadlineDays: ''
  });

  // 处理表单输入变化
  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: value
    }));
  };

  // 处理表单提交
  const handleSubmit = async (e) => {
    e.preventDefault();
    
    // 表单验证
    if (!formData.title.trim()) {
      alert('请输入众筹标题');
      return;
    }
    
    if (!formData.description.trim()) {
      alert('请输入众筹描述');
      return;
    }
    
    const goalAmount = parseFloat(formData.goalAmount);
    if (isNaN(goalAmount) || goalAmount <= 0) {
      alert('请输入有效的目标金额');
      return;
    }
    
    const deadlineDays = parseInt(formData.deadlineDays);
    if (isNaN(deadlineDays) || deadlineDays <= 0 || deadlineDays > 365) {
      alert('请输入有效的截止天数（1-365天）');
      return;
    }
    
    // 创建众筹活动
    const campaignId = await createCrowdfund(
      formData.title,
      formData.description,
      goalAmount,
      deadlineDays
    );
    
    // 如果创建成功，重置表单并返回列表页
    if (campaignId !== null) {
      setFormData({
        title: '',
        description: '',
        goalAmount: '',
        deadlineDays: ''
      });
      
      if (onSuccess) {
        setTimeout(() => {
          onSuccess(campaignId);
        }, 1000);
      }
    }
  };

  return (
    <div className="create-campaign">
      <h2>创建众筹活动</h2>
      
      {!isConnected ? (
        <div className="connect-prompt">
          <p>请先连接您的钱包</p>
        </div>
      ) : (
        <form onSubmit={handleSubmit} className="create-form">
          <div className="form-group">
            <label htmlFor="title">众筹标题 *</label>
            <input
              type="text"
              id="title"
              name="title"
              value={formData.title}
              onChange={handleChange}
              placeholder="请输入吸引人的标题"
              maxLength={100}
              required
            />
          </div>
          
          <div className="form-group">
            <label htmlFor="description">众筹描述 *</label>
            <textarea
              id="description"
              name="description"
              value={formData.description}
              onChange={handleChange}
              placeholder="详细描述您的项目..."
              rows={6}
              maxLength={1000}
              required
            />
            <div className="char-count">{formData.description.length}/1000</div>
          </div>
          
          <div className="form-row">
            <div className="form-group">
              <label htmlFor="goalAmount">目标金额 (ETH) *</label>
              <input
                type="number"
                id="goalAmount"
                name="goalAmount"
                value={formData.goalAmount}
                onChange={handleChange}
                placeholder="0.0"
                step="0.01"
                min="0.01"
                required
              />
            </div>
            
            <div className="form-group">
              <label htmlFor="deadlineDays">众筹期限 (天) *</label>
              <input
                type="number"
                id="deadlineDays"
                name="deadlineDays"
                value={formData.deadlineDays}
                onChange={handleChange}
                placeholder="天数"
                min="1"
                max="365"
                required
              />
            </div>
          </div>
          
          <div className="form-tips">
            <h4>创建提示</h4>
            <ul>
              <li>确保您的项目描述清晰准确</li>
              <li>设置合理的目标金额和时间期限</li>
              <li>一旦创建，部分信息将无法修改</li>
              <li>您将成为该众筹活动的管理员</li>
            </ul>
          </div>
          
          <button 
            type="submit" 
            className="submit-btn"
            disabled={loading}
          >
            {loading ? '创建中...' : '创建众筹活动'}
          </button>
        </form>
      )}
      
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

export default CreateCampaign;