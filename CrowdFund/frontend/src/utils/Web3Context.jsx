import React, { createContext, useContext, useState, useEffect } from 'react';
import { ethers } from 'ethers';

// 合约ABI (简化版，实际使用时应该从编译后的文件中导入)
const CROWDFUND_CORE_ABI = [
  // 创建众筹活动
  'function createCrowdfund(string memory projectName, uint256 targetAmount, uint256 deadline) external',
  // 投资
  'function invest(uint256 _campaignId) external payable',
  // 获取众筹活动详情 - 修改为与合约实际实现匹配
  'function getCrowdfundStatus(uint256 crowdfundId) external view returns (tuple(uint256 id, string projectName, address creator, uint256 targetAmount, uint256 currentAmount, uint256 deadline, uint256 mybPerEth, uint8 status, uint256 createdAt, bool fundsReleased))',
  // 获取众筹活动总数 - 修改为与合约实际实现匹配
  'function crowdfundCounter() external view returns (uint256)',
  // 释放资金
  'function releaseFunds(uint256 _campaignId) external',
  // 申请退款
  'function claimRefund(uint256 _campaignId) external',
  // 事件
  'event CrowdfundCreated(uint256 indexed crowdfundId, string projectName, address creator, uint256 targetAmount, uint256 deadline)',
  'event InvestmentReceived(uint256 indexed crowdfundId, address indexed investor, uint256 amount, uint256 mybTokens)',
  'event CrowdfundSuccessful(uint256 indexed crowdfundId, uint256 totalAmount)',
  'event CrowdfundFailed(uint256 indexed crowdfundId)',
  'event FundsReleased(uint256 indexed crowdfundId, address indexed recipient, uint256 amount)'
];

const MYB_TOKEN_ABI = [
  // 获取余额
  'function balanceOf(address account) external view returns (uint256)',
  // 转账
  'function transfer(address to, uint256 amount) external returns (bool)',
  // 获取兑换率
  'function exchangeRate() external view returns (uint256)'
];

// InvestorRegistry合约ABI
const INVESTOR_REGISTRY_ABI = [
  // 获取投资者信息
  'function getInvestorInfo(uint256 crowdfundId, address investor) external view returns (tuple(bool isRegistered, uint256 totalInvestment, uint256 mybTokens, uint256 lastUpdateTime))'
];

// Sepolia测试网合约地址（已部署）
const CROWDFUND_CORE_ADDRESS = '0xEd981954E1Ff757b1da132F7475B8E8891a1dbE2'; // Sepolia测试网地址
const MYB_TOKEN_ADDRESS = '0x4a042653398eF0e1D4A44E991ddCf639F4c3b024'; // Sepolia测试网地址
const INVESTOR_REGISTRY_ADDRESS = '0x8387e0c6072D50D6D57D8EFAE10A4afC5d4665D4'; // InvestorRegistry合约地址（需要替换为实际部署地址）

// Sepolia测试网Chain ID
const SEPOLIA_CHAIN_ID = '0xaa36a7'; // 十六进制表示的11155111

// 模拟数据模式标志
const USE_MOCK_DATA = false; // 使用模拟数据以避免合约权限问题

// 创建Context
const Web3Context = createContext();

// Context Provider组件
export const Web3Provider = ({ children }) => {
  const [provider, setProvider] = useState(null);
  const [signer, setSigner] = useState(null);
  const [account, setAccount] = useState(null);
  const [crowdfundCoreContract, setCrowdfundCoreContract] = useState(null);
  const [mybTokenContract, setMybTokenContract] = useState(null);
  const [investorRegistryContract, setInvestorRegistryContract] = useState(null);
  const [isConnected, setIsConnected] = useState(false);
  const [useMockData, setUseMockData] = useState(USE_MOCK_DATA);
  const [error, setError] = useState(null);

  // 连接钱包
  const connectWallet = async () => {
    try {
      if (!window.ethereum) {
        throw new Error('MetaMask 未安装');
      }

      // 检查网络是否为Sepolia测试网
      const chainId = await window.ethereum.request({ method: 'eth_chainId' });
      if (chainId !== SEPOLIA_CHAIN_ID) {
        // 尝试切换到Sepolia测试网
        try {
          await window.ethereum.request({
            method: 'wallet_switchEthereumChain',
            params: [{ chainId: SEPOLIA_CHAIN_ID }]
          });
        } catch (switchError) {
          // 用户拒绝切换或没有添加Sepolia网络
          throw new Error('请切换到Sepolia测试网再连接钱包');
        }
      }

      // 请求账户访问权限
      const accounts = await window.ethereum.request({
        method: 'eth_requestAccounts'
      });
      
      // 创建provider和signer
      const newProvider = new ethers.BrowserProvider(window.ethereum);
      const newSigner = await newProvider.getSigner();
      
      // 创建合约实例
      const newCrowdfundCoreContract = new ethers.Contract(
        CROWDFUND_CORE_ADDRESS, 
        CROWDFUND_CORE_ABI, 
        newSigner
      );
      
      const newMybTokenContract = new ethers.Contract(
        MYB_TOKEN_ADDRESS, 
        MYB_TOKEN_ABI, 
        newSigner
      );

      const newInvestorRegistryContract = new ethers.Contract(
        INVESTOR_REGISTRY_ADDRESS, 
        INVESTOR_REGISTRY_ABI, 
        newSigner
      );

      setProvider(newProvider);
      setSigner(newSigner);
      setAccount(accounts[0]);
      setCrowdfundCoreContract(newCrowdfundCoreContract);
      setMybTokenContract(newMybTokenContract);
      setInvestorRegistryContract(newInvestorRegistryContract);
      setIsConnected(true);
      setError(null);
      
      // 记录连接状态到本地存储
      try {
        localStorage.setItem('walletConnected', 'true');
        localStorage.setItem('lastConnectedAccount', accounts[0]);
      } catch (storageError) {
        console.log('无法保存连接状态到本地存储:', storageError);
      }

      // 监听账户变化
      window.ethereum.on('accountsChanged', handleAccountsChanged);
      // 监听链变化
      window.ethereum.on('chainChanged', handleChainChanged);
    } catch (err) {
      setError(err.message);
      console.error('连接钱包失败:', err);
    }
  };

  // 处理账户变化
  const handleAccountsChanged = (accounts) => {
    if (accounts.length > 0) {
      setAccount(accounts[0]);
      // 重新检查网络
      checkNetwork();
    } else {
      // 用户断开了钱包连接
      resetWeb3State();
    }
  };
  
  // 检查当前网络
  const checkNetwork = async () => {
    try {
      if (window.ethereum) {
        const chainId = await window.ethereum.request({ method: 'eth_chainId' });
        if (chainId !== SEPOLIA_CHAIN_ID) {
          setError('请切换到Sepolia测试网以连接合约');
          return false;
        } else {
          setError(null);
          return true;
        }
      }
      return false;
    } catch (err) {
      console.error('检查网络失败:', err);
      setError('网络检查失败');
      return false;
    }
  };

  // 处理链变化
  const handleChainChanged = () => {
    // 链变化时刷新页面
    window.location.reload();
  };

  // 重置Web3状态
  const resetWeb3State = () => {
    setProvider(null);
    setSigner(null);
    setAccount(null);
    setCrowdfundCoreContract(null);
    setMybTokenContract(null);
    setInvestorRegistryContract(null);
    setIsConnected(false);
  };

  // 完全断开连接
  const disconnectWallet = async () => {
    try {
      // 立即重置Web3状态，避免UI显示延迟
      resetWeb3State();
      
      // 清除本地存储中的连接状态（最重要的一步）
      try {
        localStorage.removeItem('walletConnected');
        localStorage.removeItem('lastConnectedAccount');
      } catch (storageError) {
        console.log('无法清除本地存储:', storageError);
      }
      
      // 移除事件监听器
      if (window.ethereum) {
        window.ethereum.removeListener('accountsChanged', handleAccountsChanged);
        window.ethereum.removeListener('chainChanged', handleChainChanged);
        
        // 尝试使用 experimental_disconnect（如果可用）
        if (window.ethereum.experimental_disconnect) {
          try {
            await window.ethereum.experimental_disconnect();
          } catch (disconnectError) {
            console.log('experimental_disconnect 不可用或失败:', disconnectError);
          }
        }
        
        // 尝试使用wallet_revokePermissions（如果可用）
        try {
          await window.ethereum.request({
            method: 'wallet_revokePermissions',
            params: [{ eth_accounts: {} }]
          });
        } catch (revokeError) {
          console.log('wallet_revokePermissions 不可用或失败:', revokeError);
          
          // 如果wallet_revokePermissions不可用，尝试使用wallet_requestPermissions
          try {
            await window.ethereum.request({
              method: 'wallet_requestPermissions',
              params: []
            });
          } catch (permError) {
            console.log('钱包权限管理失败:', permError);
          }
        }
      }
      
      // 添加一个短暂延迟，确保所有断开操作完成
      await new Promise(resolve => setTimeout(resolve, 300));
      
    } catch (err) {
      console.error('完全断开连接时出错:', err);
      // 即使出错也要确保状态被重置
      resetWeb3State();
    }
  };

  // 检查钱包是否已连接
  useEffect(() => {
    const checkConnection = async () => {
      if (window.ethereum) {
        try {
          // 首先检查本地存储中的连接状态标志
          const walletConnectedFlag = localStorage.getItem('walletConnected');
          
          // 只有当本地存储中明确标记为已连接时，才尝试自动连接
          if (walletConnectedFlag === 'true') {
            const accounts = await window.ethereum.request({
              method: 'eth_accounts'
            });
            
            if (accounts.length > 0) {
              connectWallet();
            }
          }
        } catch (err) {
          console.error('检查连接失败:', err);
        }
      }
    };

    checkConnection();

    // 组件卸载时清理事件监听器
    return () => {
      if (window.ethereum) {
        window.ethereum.removeListener('accountsChanged', handleAccountsChanged);
        window.ethereum.removeListener('chainChanged', handleChainChanged);
      }
    };
  }, []);

  const value = {
    provider,
    signer,
    account,
    crowdfundCoreContract,
    mybTokenContract,
    investorRegistryContract,
    isConnected,
    error,
    useMockData,
    connectWallet,
    disconnectWallet,
    checkNetwork // 添加网络检查函数到context中
  };

  return (
    <Web3Context.Provider value={value}>
      {children}
    </Web3Context.Provider>
  );
};

// 自定义Hook
export const useWeb3 = () => {
  const context = useContext(Web3Context);
  if (!context) {
    throw new Error('useWeb3 must be used within a Web3Provider');
  }
  return context;
};