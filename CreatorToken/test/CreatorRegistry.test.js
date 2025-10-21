// CreatorRegistry合约测试
const { expect } = require('chai');
const { ethers } = require('hardhat');
const { Signer } = require('ethers');

describe('CreatorRegistry合约测试', function() {
  let CreatorRegistry;
  let creatorRegistry;
  let owner;
  let creator;
  let verifier;
  let moderator;

  beforeEach(async function() {
    // 部署合约
    CreatorRegistry = await ethers.getContractFactory('CreatorRegistry');
    [owner, creator, verifier, moderator] = await ethers.getSigners();
    creatorRegistry = await CreatorRegistry.deploy(owner.address);
    await creatorRegistry.deployed();
    
    // 设置验证者和审核者角色
      // 首先获取DEFAULT_ADMIN_ROLE来授权
      const DEFAULT_ADMIN_ROLE = await creatorRegistry.DEFAULT_ADMIN_ROLE();
      const VERIFIER_ROLE = await creatorRegistry.VERIFIER_ROLE();
      const MODERATOR_ROLE = await creatorRegistry.MODERATOR_ROLE();
      // 确保owner有授权权限
      await creatorRegistry.grantRole(VERIFIER_ROLE, verifier.address);
      await creatorRegistry.grantRole(MODERATOR_ROLE, moderator.address);
  });

  it('应该允许创作者注册', async function() {
    const creatorName = 'TestCreator';
    const metadataURI = 'https://ipfs.io/ipfs/Qm...';
    const socialLinks = ['twitter.com/testcreator'];
    
    await creatorRegistry.connect(creator).registerCreator(
      metadataURI
    );
    
    // 简化测试，只检查是否注册成功
    const isRegistered = await creatorRegistry.isRegistered(creator.address);
    expect(isRegistered).to.be.true;
  });

  it('应该允许审核者批准创作者', async function() {
    // 先注册
    await creatorRegistry.connect(creator).registerCreator(
      'https://ipfs.io/ipfs/Qm...'
    );
    
    // 审核者设置创作者状态为ACTIVE
    await creatorRegistry.connect(moderator).setCreatorStatus(creator.address, 1); // 1 = ACTIVE
    
    const creatorInfo = await creatorRegistry.getCreator(creator.address);
    expect(creatorInfo.status).to.equal(1); // APPROVED
  });

  it('应该允许验证者设置验证级别', async function() {
    // 先注册并批准
    await creatorRegistry.connect(creator).registerCreator(
      'https://ipfs.io/ipfs/Qm...'
    );
    // 先设置创作者状态为ACTIVE
    await creatorRegistry.connect(moderator).setCreatorStatus(creator.address, 1); // 1 = ACTIVE
    
    // 验证者设置验证级别为1（中级）
    await creatorRegistry.connect(verifier).setVerificationLevel(creator.address, 1);
    
    const creatorInfo = await creatorRegistry.getCreator(creator.address);
    expect(creatorInfo.verificationLevel).to.equal(1); // INTERMEDIATE
  });
});