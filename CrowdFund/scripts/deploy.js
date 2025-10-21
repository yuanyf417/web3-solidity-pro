// scripts/deploy-crowdfund.js
const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  
  console.log("部署合约使用的账户:", deployer.address);
  console.log("账户余额:", (await deployer.getBalance()).toString());
  
  // 部署MYBToken合约
  console.log("\n部署MYBToken合约...");
  const MYBToken = await hre.ethers.getContractFactory("MYBToken");
  const mybToken = await MYBToken.deploy();
  
  await mybToken.deployed();
  console.log("MYBToken合约地址:", mybToken.address);
  
  // 部署InvestorRegistry合约
  console.log("\n部署InvestorRegistry合约...");
  const InvestorRegistry = await hre.ethers.getContractFactory("InvestorRegistry");
  const investorRegistry = await InvestorRegistry.deploy();
  
  await investorRegistry.deployed();
  console.log("InvestorRegistry合约地址:", investorRegistry.address);
  
  // 为开发基金和社区基金使用部署者地址（实际项目中应该使用多签钱包）
  const devFundAddress = deployer.address;
  const communityFundAddress = deployer.address;
  
  // 部署CrowdFundCore合约
  console.log("\n部署CrowdFundCore合约...");
  const CrowdFundCore = await hre.ethers.getContractFactory("CrowdFundCore");
  const crowdfundCore = await CrowdFundCore.deploy(
    mybToken.address,
    investorRegistry.address,
    devFundAddress,
    communityFundAddress
  );
  
  await crowdfundCore.deployed();
  console.log("CrowdFundCore合约地址:", crowdfundCore.address);
  
  // 授权CrowdFundCore合约使用MYBToken（转移部分代币给CrowdFundCore用于分配）
  console.log("\n授权CrowdFundCore使用MYBToken...");
  
  // 计算授权数量（总供应量的70%用于众筹投资者）
  const totalSupply = await mybToken.totalSupply();
  const investorAllocation = totalSupply.mul(70).div(100); // 70%用于投资者
  
  await mybToken.transfer(crowdfundCore.address, investorAllocation);
  console.log(`已转移 ${ethers.utils.formatEther(investorAllocation)} MYB 到CrowdFundCore合约`);
  
  console.log("\n部署完成！合约信息摘要:");
  console.log("1. MYBToken: 合约地址 =", mybToken.address);
  console.log("2. InvestorRegistry: 合约地址 =", investorRegistry.address);
  console.log("3. CrowdFundCore: 合约地址 =", crowdfundCore.address);
  console.log("4. 开发基金地址 =", devFundAddress);
  console.log("5. 社区基金地址 =", communityFundAddress);
}

// 运行部署函数
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });