import React from 'react';
import { useWeb3 } from '../utils/Web3Context';
import '../styles/WalletConnect.css';

const WalletConnect = () => {
  const { account, isConnected, connectWallet, disconnectWallet } = useWeb3();

  // 格式化地址显示（只显示前6位和后4位）
  const formatAddress = (addr) => {
    if (!addr) return '';
    return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
  };

  return (
    <div className="wallet-connect">
      {isConnected ? (
        <div className="wallet-info">
          <span className="wallet-address">
            {formatAddress(account)}
          </span>
          <button 
            className="disconnect-btn"
            onClick={disconnectWallet}
          >
            断开连接
          </button>
        </div>
      ) : (
        <button 
          className="connect-btn"
          onClick={connectWallet}
        >
          连接钱包
        </button>
      )}
    </div>
  );
};

export default WalletConnect;