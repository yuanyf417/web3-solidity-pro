import React, { useEffect } from 'react';
import { useToken } from '../hooks/useToken';
import { useWeb3 } from '../utils/Web3Context';
import '../styles/TokenInfo.css';

const TokenInfo = () => {
  const { tokenBalance, exchangeRate, fetchTokenBalance } = useToken();
  const { isConnected } = useWeb3();

  // 定时刷新余额
  useEffect(() => {
    if (isConnected) {
      fetchTokenBalance();
      const interval = setInterval(fetchTokenBalance, 60000); // 每分钟刷新
      return () => clearInterval(interval);
    }
  }, [isConnected, fetchTokenBalance]);

  if (!isConnected) {
    return null;
  }

  return (
    <div className="token-info">
      <div className="token-balance">
        <span className="balance-label">MYB余额</span>
        <span className="balance-value">{parseFloat(tokenBalance).toFixed(2)}</span>
      </div>
      <div className="exchange-rate">
        <span className="rate-label">兑换率</span>
        <span className="rate-value">1 ETH = {exchangeRate.toLocaleString()} MYB</span>
      </div>
    </div>
  );
};

export default TokenInfo;