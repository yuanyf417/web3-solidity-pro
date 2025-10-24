import { useState, useEffect } from 'react';
import { useWeb3 } from '../utils/Web3Context';
import { ethers } from 'ethers';

export const useToken = () => {
  const { mybTokenContract, account } = useWeb3();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [successMessage, setSuccessMessage] = useState(null);
  const [tokenBalance, setTokenBalance] = useState('0');
  const [exchangeRate, setExchangeRate] = useState(10000); // 默认1 ETH = 10000 MYB

  // 获取代币余额
  const fetchTokenBalance = async () => {
    if (!mybTokenContract || !account) {
      setTokenBalance('0');
      return;
    }

    try {
      setError(null);
      const balance = await mybTokenContract.balanceOf(account);
      // MYB代币精度为18位，需要转换
      setTokenBalance(ethers.formatUnits(balance, 18));
    } catch (err) {
      setError(`获取余额失败: ${err.message}`);
      console.error('获取余额错误:', err);
      setTokenBalance('0');
    }
  };

  // 获取兑换率
  const fetchExchangeRate = async () => {
    if (!mybTokenContract) {
      return;
    }

    try {
      setError(null);
      const rate = await mybTokenContract.exchangeRate();
      // 在ethers.js v6中，使用toString()转换BigNumber为字符串，再转换为数字
      setExchangeRate(Number(rate.toString()));
    } catch (err) {
      console.error('获取兑换率失败，使用默认值:', err);
      // 保持默认值10000
    }
  };

  // 转账代币
  const transferTokens = async (recipient, amount) => {
    if (!mybTokenContract || !account) {
      setError('钱包未连接');
      return false;
    }

    try {
      setLoading(true);
      setError(null);
      setSuccessMessage(null);

      // 将金额转换为wei单位（18位精度）
      const amountWei = ethers.parseUnits(amount.toString(), 18);
      
      // 调用合约转账
      const tx = await mybTokenContract.transfer(recipient, amountWei);
      
      // 等待交易确认
      await tx.wait();
      
      setSuccessMessage(`转账成功！金额: ${amount} MYB`);
      // 更新余额
      fetchTokenBalance();
      return true;
    } catch (err) {
      setError(`转账失败: ${err.message}`);
      console.error('转账错误:', err);
      return false;
    } finally {
      setLoading(false);
    }
  };

  // ETH转换为MYB
  const ethToMyb = (ethAmount) => {
    return (parseFloat(ethAmount) * exchangeRate).toFixed(2);
  };

  // MYB转换为ETH
  const mybToEth = (mybAmount) => {
    return (parseFloat(mybAmount) / exchangeRate).toFixed(6);
  };

  // 清除消息
  const clearMessages = () => {
    setError(null);
    setSuccessMessage(null);
  };

  // 当账户或合约变化时，自动获取余额和兑换率
  useEffect(() => {
    fetchTokenBalance();
    fetchExchangeRate();
  }, [account, mybTokenContract]);

  return {
    loading,
    error,
    successMessage,
    tokenBalance,
    exchangeRate,
    fetchTokenBalance,
    transferTokens,
    ethToMyb,
    mybToEth,
    clearMessages
  };
};