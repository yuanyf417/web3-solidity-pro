// 部署脚本 - 部署CreatorToken生态系统合约

const hre = require('hardhat');
const { ethers } = require('hardhat');

async function main() {
  console.log('开始部署CreatorToken生态系统合约...');

  // 部署CreatorToken合约
  console.log('部署CreatorToken合约...');
  const CreatorToken = await ethers.getContractFactory('CreatorToken');
  const [deployer] = await ethers.getSigners();
  const creatorToken = await CreatorToken.deploy(
    'CreatorToken',
    'CTK',
    deployer.address,
    ethers.utils.parseEther('1000000')
  );
  await creatorToken.deployed();
  console.log('CreatorToken合约部署成功: ', creatorToken.address);

  // 部署CreatorRegistry合约
  console.log('部署CreatorRegistry合约...');
  const CreatorRegistry = await ethers.getContractFactory('CreatorRegistry');
  const creatorRegistry = await CreatorRegistry.deploy(deployer.address);
  await creatorRegistry.deployed();
  console.log('CreatorRegistry合约部署成功: ', creatorRegistry.address);

  // 部署TokenVesting合约
  console.log('部署TokenVesting合约...');
  const TokenVesting = await ethers.getContractFactory('TokenVesting');
  const tokenVesting = await TokenVesting.deploy(creatorToken.address);
  await tokenVesting.deployed();
  console.log('TokenVesting合约部署成功: ', tokenVesting.address);

  // 部署RevenuePool合约
  console.log('部署RevenuePool合约...');
  const RevenuePool = await ethers.getContractFactory('RevenuePool');
  const revenuePool = await RevenuePool.deploy(
    creatorRegistry.address, // registryAddr
    deployer.address, // _platformFeeRecipient
    deployer.address, // _treasury
    deployer.address, // _communityFund
    500, // _platformFeeBps (5%)
    200, // _treasuryFeeBps (2%)
    100  // _communityFeeBps (1%)
  );
  await revenuePool.deployed();
  console.log('RevenuePool合约部署成功: ', revenuePool.address);

  // 部署Governance合约
  console.log('部署Governance合约...');
  const Governance = await ethers.getContractFactory('Governance');
  const governance = await Governance.deploy(
    creatorToken.address,
    1,
    172800, // 2天
    86400,  // 1天
    432000  // 5天
  );
  await governance.deployed();
  console.log('Governance合约部署成功: ', governance.address);

  // 设置角色和权限
  console.log('配置角色和权限...');
  // deployer已在前面定义
  
  // 为RevenuePool设置MINTER_ROLE
  await creatorToken.grantRole(
    await creatorToken.MINTER_ROLE(),
    revenuePool.address
  );
  
  // 为Governance设置TREASURY_ROLE
  await creatorToken.grantRole(
    await creatorToken.TREASURY_ROLE(),
    governance.address
  );

  console.log('\n部署完成！');
  console.log('\n合约地址总结:');
  console.log('CreatorToken:', creatorToken.address);
  console.log('CreatorRegistry:', creatorRegistry.address);
  console.log('TokenVesting:', tokenVesting.address);
  console.log('RevenuePool:', revenuePool.address);
  console.log('Governance:', governance.address);
}

// 执行主函数
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });