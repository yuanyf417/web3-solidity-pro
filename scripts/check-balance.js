// 检查测试网账户余额脚本
const hre = require('hardhat');
const { ethers } = require('hardhat');

async function main() {
  // 获取部署者账户
  const [deployer] = await ethers.getSigners();
  const deployerAddress = deployer.address;
  
  // 获取当前网络
  const network = hre.network.name;
  
  console.log(`检查账户余额 - 网络: ${network}`);
  console.log(`账户地址: ${deployerAddress}`);
  
  try {
    // 获取ETH余额
    const balance = await ethers.provider.getBalance(deployerAddress);
    const balanceInEth = ethers.utils.formatEther(balance);
    
    console.log(`\nETH余额: ${balanceInEth} ETH`);
    
    // 提供部署所需的大致估计
    const estimatedDeployCostInEth = 0.01; // 估计部署所有合约需要0.01 ETH
    const hasEnoughBalance = parseFloat(balanceInEth) >= estimatedDeployCostInEth;
    
    console.log(`\n部署估计成本: ~${estimatedDeployCostInEth} ETH`);
    console.log(`是否有足够余额: ${hasEnoughBalance ? '✓ 足够' : '✗ 不足'}`);
    
    if (!hasEnoughBalance) {
      console.log(`\n请通过以下途径获取测试网ETH:`);
      if (network === 'sepolia') {
        console.log(`- Alchemy Sepolia Faucet: https://sepoliafaucet.com/`);
        console.log(`- Infura Sepolia Faucet: https://www.infura.io/faucet/sepolia`);
        console.log(`- Coinbase Wallet Faucet: https://coinbase.com/faucets/ethereum-sepolia-faucet`);
      } else if (network === 'mumbai') {
        console.log(`- Polygon Mumbai Faucet: https://faucet.polygon.technology/`);
        console.log(`- Alchemy Mumbai Faucet: https://mumbaifaucet.com/`);
      }
    }
  } catch (error) {
    console.error('获取余额时出错:', error.message);
  }
}

// 执行主函数
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });