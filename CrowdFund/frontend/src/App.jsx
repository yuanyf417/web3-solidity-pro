import React, { useState } from 'react';
import { Web3Provider } from './utils/Web3Context';
import WalletConnect from './components/WalletConnect';
import CampaignList from './components/CampaignList';
import CampaignDetail from './components/CampaignDetail';
import CreateCampaign from './components/CreateCampaign';
import TokenInfo from './components/TokenInfo';
import './App.css';

function App() {
  const [currentView, setCurrentView] = useState('list'); // list, detail, create
  const [selectedCampaignId, setSelectedCampaignId] = useState(null);

  // 处理选择众筹活动
  const handleSelectCampaign = (campaignId) => {
    setSelectedCampaignId(campaignId);
    setCurrentView('detail');
  };

  // 处理返回列表
  const handleBackToList = () => {
    setCurrentView('list');
    setSelectedCampaignId(null);
  };

  // 处理创建成功
  const handleCreateSuccess = (campaignId) => {
    handleSelectCampaign(campaignId);
  };

  // 渲染主内容
  const renderMainContent = () => {
    switch (currentView) {
      case 'detail':
        return (
          <CampaignDetail 
            campaignId={selectedCampaignId} 
            onBack={handleBackToList} 
          />
        );
      case 'create':
        return (
          <CreateCampaign 
            onSuccess={handleCreateSuccess}
          />
        );
      case 'list':
      default:
        return (
          <div className="dashboard">
            <div className="dashboard-header">
              <h1>众筹活动</h1>
              <button 
                className="create-btn"
                onClick={() => setCurrentView('create')}
              >
                创建众筹
              </button>
            </div>
            <div className="dashboard-content">
              <div className="main-content">
                <CampaignList onSelectCampaign={handleSelectCampaign} />
              </div>
              <div className="sidebar">
                <TokenInfo />
              </div>
            </div>
          </div>
        );
    }
  };

  return (
    <Web3Provider>
      <div className="app">
        <header className="header">
          <div className="logo">
            <h1>CrowdFund</h1>
          </div>
          <WalletConnect />
        </header>
        
        <main className="main">
          {renderMainContent()}
        </main>
        
        <footer className="footer">
          <p>&copy; 2024 CrowdFund - 基于以太坊的去中心化众筹平台</p>
        </footer>
      </div>
    </Web3Provider>
  );
}

export default App
