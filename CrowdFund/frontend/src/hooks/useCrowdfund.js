import { useState } from 'react';
import { useWeb3 } from '../utils/Web3Context';
import { ethers } from 'ethers';

export const useCrowdfund = () => {
  const { crowdfundCoreContract, investorRegistryContract, account, useMockData, checkNetwork } = useWeb3();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [successMessage, setSuccessMessage] = useState(null);
  
  // 模拟数据
  const mockCampaigns = [
    {
      id: '0',
      title: '区块链游戏开发项目',
      description: '我们正在开发一款革命性的区块链游戏，融合DeFi和NFT元素',
      creator: '0x742d35Cc6634C0532925a3b844Bc454e4438f44e',
      goalAmount: '50.0',
      currentAmount: '23.5',
      deadline: (Math.floor(Date.now() / 1000) + 7 * 24 * 60 * 60).toString(), // 7天后
      isCompleted: false,
      remainingTime: 7 * 24 * 60 * 60,
      completionPercentage: 47
    },
    {
      id: '1', 
      title: '去中心化存储解决方案',
      description: '构建一个安全、高效、低成本的去中心化云存储系统',
      creator: '0x88a5c2d9919e46f883eb62f7b8dd9d0cc45bc290',
      goalAmount: '100.0',
      currentAmount: '100.0',
      deadline: (Math.floor(Date.now() / 1000) - 24 * 60 * 60).toString(), // 1天前
      isCompleted: true,
      remainingTime: 0,
      completionPercentage: 100
    },
    {
      id: '2',
      title: '环保数据上链项目',
      description: '将全球环保数据上链，建立透明可信的环境监测系统',
      creator: '0x932a71e8230108f421623f9746c712936f6d6e7b',
      goalAmount: '30.0',
      currentAmount: '12.75',
      deadline: (Math.floor(Date.now() / 1000) + 3 * 24 * 60 * 60).toString(), // 3天后
      isCompleted: false,
      remainingTime: 3 * 24 * 60 * 60,
      completionPercentage: 42
    }
  ];

  // 创建众筹活动
  const createCrowdfund = async (title, description, goalAmount, deadlineDays) => {
    if (!account) {
      setError('钱包未连接');
      return null;
    }

    try {
      setLoading(true);
      setError(null);
      setSuccessMessage(null);

      // 如果不是模拟模式，先检查网络
      if (!useMockData) {
        const isCorrectNetwork = await checkNetwork();
        if (!isCorrectNetwork) {
          throw new Error('请确保连接到Sepolia测试网');
        }
      }

      if (useMockData) {
        // 模拟创建众筹活动
        await new Promise(resolve => setTimeout(resolve, 1000)); // 模拟网络延迟
        const newId = mockCampaigns.length.toString();
        const deadline = Math.floor(Date.now() / 1000) + (deadlineDays * 24 * 60 * 60);
        
        // 添加新的众筹活动到模拟数据中，保存用户输入的目标金额
        const newCampaign = {
          id: newId,
          title: title,
          description: description,
          creator: account,
          goalAmount: goalAmount.toString(),
          currentAmount: '0.0',
          deadline: deadline.toString(),
          isCompleted: false,
          remainingTime: deadline - Math.floor(Date.now() / 1000),
          completionPercentage: 0
        };
        
        mockCampaigns.push(newCampaign);
        setSuccessMessage(`众筹活动创建成功！ID: ${newId}`);
        return newId;
      } else if (crowdfundCoreContract) {
        // 计算截止时间戳（当前时间 + 天数）
        const deadline = Math.floor(Date.now() / 1000) + (deadlineDays * 24 * 60 * 60);
        
        // 将目标金额转换为wei
        const goalAmountWei = ethers.parseEther(goalAmount.toString());
        
        // 调用合约创建众筹活动 - 注意：合约只接受3个参数，将description合并到title中
        const projectName = `${title} - ${description.substring(0, 50)}${description.length > 50 ? '...' : ''}`;
        const tx = await crowdfundCoreContract.createCrowdfund(
          projectName, // 合并标题和简短描述
          goalAmountWei,
          deadline
        );
        
        // 等待交易确认
        await tx.wait();
        
        // 获取创建的众筹ID - 使用正确的合约方法名并正确处理BigInt
        const receipt = await crowdfundCoreContract.crowdfundCounter();
        const campaignId = (receipt - BigInt(1)).toString();
        
        setSuccessMessage(`众筹活动创建成功！ID: ${campaignId}`);
        return campaignId;
      }
    } catch (err) {
      // 处理不同类型的错误
      let errorMessage = '创建众筹失败';
      if (err.code === 'CALL_EXCEPTION' && err.message.includes('missing revert data')) {
        errorMessage = '创建众筹失败: 合约调用错误，请检查网络连接和合约地址';
      } else if (err.code === 'BAD_DATA') {
        errorMessage = '创建众筹失败: 数据解析错误';
      } else if (err.message) {
        errorMessage = `创建众筹失败: ${err.message}`;
      }
      
      setError(errorMessage);
      console.error('创建众筹错误:', err);
      return null;
    } finally {
      setLoading(false);
    }
  };

  // 投资众筹活动
  const invest = async (campaignId, amount) => {
    if (!account) {
      setError('钱包未连接');
      return false;
    }

    try {
      setLoading(true);
      setError(null);
      setSuccessMessage(null);

      if (useMockData) {
        // 模拟投资
        await new Promise(resolve => setTimeout(resolve, 1000));
        setSuccessMessage(`投资成功！金额: ${amount} ETH`);
        return true;
      } else if (crowdfundCoreContract) {
        // 将投资金额转换为wei
        const amountWei = ethers.parseEther(amount.toString());
        
        // 调用合约进行投资
        const tx = await crowdfundCoreContract.invest(campaignId, {
          value: amountWei
        });
        
        // 等待交易确认
        await tx.wait();
        
        setSuccessMessage(`投资成功！金额: ${amount} ETH`);
        return true;
      }
    } catch (err) {
      // 处理不同类型的错误
      let errorMessage = '投资失败';
      if (err.code === 'CALL_EXCEPTION' && err.message.includes('Ownable: caller is not the owner')) {
        errorMessage = '很抱歉，您不能投资自己发起的众筹项目';
      } else if (err.code === 'CALL_EXCEPTION' && err.message.includes('missing revert data')) {
        errorMessage = '投资失败: 合约调用错误，请检查网络连接和合约地址';
      } else if (err.message) {
        errorMessage = `投资失败: ${err.message}`;
      }
      
      setError(errorMessage);
      console.error('投资错误:', err);
      return false;
    } finally {
      setLoading(false);
    }
  };

  // 获取众筹活动详情
  const getCrowdfund = async (campaignId) => {
    try {
      setError(null);
      
      if (useMockData) {
        // 返回模拟数据
        const campaign = mockCampaigns.find(c => c.id === campaignId.toString());
        if (campaign) {
          // 更新剩余时间
          const updatedCampaign = {
            ...campaign,
            remainingTime: Math.max(0, parseInt(campaign.deadline) - Math.floor(Date.now() / 1000))
          };
          return updatedCampaign;
        }
        return null;
      } else if (crowdfundCoreContract) {
        // 调用合约获取众筹详情 - 使用正确的函数名
        const campaign = await crowdfundCoreContract.getCrowdfundStatus(campaignId);
        
        // 转换数据格式
        const formattedCampaign = {
          id: campaign.id.toString(),
          title: campaign.projectName, // 使用projectName作为title
          description: '', // 合约中没有description字段，保持为空
          creator: campaign.creator,
          goalAmount: ethers.formatEther(campaign.targetAmount), // 使用targetAmount作为goalAmount
          currentAmount: ethers.formatEther(campaign.currentAmount),
          deadline: campaign.deadline.toString(),
          isCompleted: campaign.status >= 2, // 状态>=2表示已完成（SUCCESSFUL、FAILED、REFUNDED）
          // 计算剩余时间
          remainingTime: Math.max(0, parseInt(campaign.deadline) - Math.floor(Date.now() / 1000)),
          // 计算完成百分比
          completionPercentage: Math.min(
            100, 
            Math.round((parseFloat(ethers.formatEther(campaign.currentAmount)) / parseFloat(ethers.formatEther(campaign.targetAmount))) * 100)
          )
        };
        
        return formattedCampaign;
      }
    } catch (err) {
      console.error('获取众筹详情错误:', err);
      // 在模拟模式下不显示错误
      if (!useMockData) {
        setError(`获取众筹详情失败: ${err.message}`);
      }
      return null;
    }
  };

  // 获取所有众筹活动
  const getAllCrowdfunds = async () => {
    try {
      setError(null);
      
      if (useMockData) {
        // 返回模拟数据，更新剩余时间
        return mockCampaigns.map(campaign => ({
          ...campaign,
          remainingTime: Math.max(0, parseInt(campaign.deadline) - Math.floor(Date.now() / 1000))
        }));
      } else if (crowdfundCoreContract) {
        // 获取众筹活动总数 - 使用正确的合约方法名
        const count = await crowdfundCoreContract.crowdfundCounter();
        const campaigns = [];
        
        // 遍历获取每个众筹活动的详情
        for (let i = 0; i < count; i++) {
          try {
            const campaign = await getCrowdfund(i);
            if (campaign) {
              campaigns.push(campaign);
            }
          } catch (err) {
            console.error(`获取众筹ID ${i} 失败:`, err);
          }
        }
        
        return campaigns;
      }
      return [];
    } catch (err) {
      console.error('获取众筹列表错误:', err);
      // 在模拟模式下不显示错误
      if (!useMockData) {
        setError(`获取众筹列表失败: ${err.message}`);
      }
      return [];
    }
  };

  // 获取用户在特定众筹活动中的投资金额
  const getUserInvestment = async (campaignId) => {
    if (!account) {
      return '0';
    }

    try {
      setError(null);
      
      if (useMockData) {
        // 返回模拟投资金额
        const mockInvestments = {
          '0': '5.2',
          '1': '10.0',
          '2': '3.75'
        };
        return mockInvestments[campaignId.toString()] || '0';
      } else if (investorRegistryContract) {
        const investorInfo = await investorRegistryContract.getInvestorInfo(campaignId, account);
        return ethers.formatEther(investorInfo.totalInvestment);
      }
      return '0';
    } catch (err) {
      console.error('获取投资金额错误:', err);
      if (!useMockData) {
        setError(`获取投资金额失败: ${err.message}`);
      }
      return '0';
    }
  };

  // 释放资金（仅众筹创建者可调用）
  const releaseFunds = async (campaignId) => {
    if (!account) {
      setError('钱包未连接');
      return false;
    }

    try {
      setLoading(true);
      setError(null);
      setSuccessMessage(null);
      
      if (useMockData) {
        // 模拟释放资金
        await new Promise(resolve => setTimeout(resolve, 1000));
        setSuccessMessage('资金释放成功！');
        return true;
      } else if (crowdfundCoreContract) {
        const tx = await crowdfundCoreContract.releaseFunds(campaignId);
        await tx.wait();
        
        setSuccessMessage('资金释放成功！');
        return true;
      }
    } catch (err) {
      setError(`资金释放失败: ${err.message}`);
      console.error('资金释放错误:', err);
      return false;
    } finally {
      setLoading(false);
    }
  };

  // 申请退款
  const claimRefund = async (campaignId) => {
    if (!account) {
      setError('钱包未连接');
      return false;
    }

    try {
      setLoading(true);
      setError(null);
      setSuccessMessage(null);
      
      if (useMockData) {
        // 模拟申请退款
        await new Promise(resolve => setTimeout(resolve, 1000));
        setSuccessMessage('退款申请成功！');
        return true;
      } else if (crowdfundCoreContract) {
        const tx = await crowdfundCoreContract.claimRefund(campaignId);
        await tx.wait();
        
        setSuccessMessage('退款申请成功！');
        return true;
      }
    } catch (err) {
      setError(`退款申请失败: ${err.message}`);
      console.error('退款申请错误:', err);
      return false;
    } finally {
      setLoading(false);
    }
  };

  // 清除消息
  const clearMessages = () => {
    setError(null);
    setSuccessMessage(null);
  };

  return {
    loading,
    error,
    successMessage,
    createCrowdfund,
    invest,
    getCrowdfund,
    getAllCrowdfunds,
    getUserInvestment,
    releaseFunds,
    claimRefund,
    clearMessages
  };
};