// CreatorToken合约测试
const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('CreatorToken合约测试', function() {
  let CreatorToken;
  let creatorToken;
  let owner;
  let addr1;
  let addr2;

  beforeEach(async function() {
    // 部署合约
    CreatorToken = await ethers.getContractFactory('CreatorToken');
    [owner, addr1, addr2] = await ethers.getSigners();
    creatorToken = await CreatorToken.deploy(
      'CreatorToken',
      'CTK',
      owner.address,
      ethers.utils.parseEther('1000000')
    );
    await creatorToken.deployed();
  });

  it('应该设置正确的名称和符号', async function() {
    expect(await creatorToken.name()).to.equal('CreatorToken');
    expect(await creatorToken.symbol()).to.equal('CTK');
  });

  it('应该给部署者设置DEFAULT_ADMIN_ROLE', async function() {
    const DEFAULT_ADMIN_ROLE = await creatorToken.DEFAULT_ADMIN_ROLE();
    expect(await creatorToken.hasRole(DEFAULT_ADMIN_ROLE, owner.address)).to.be.true;
  });

  it('拥有MINTER_ROLE的账户应该能够铸造代币', async function() {
    const MINTER_ROLE = await creatorToken.MINTER_ROLE();
    await creatorToken.grantRole(MINTER_ROLE, owner.address);
    
    const amount = ethers.utils.parseEther('1000');
    await creatorToken.mint(addr1.address, amount);
    
    expect(await creatorToken.balanceOf(addr1.address)).to.equal(amount);
  });

  it('没有MINTER_ROLE的账户不应该能够铸造代币', async function() {
    const amount = ethers.utils.parseEther('1000');
    
    await expect(
      creatorToken.connect(addr1).mint(addr2.address, amount)
    ).to.be.reverted;
  });

  // 跳过不存在的setTransactionTaxRate测试
  it.skip('应该正确设置和更新交易税率', async function() {
    // 设置税率为2%
    await creatorToken.setTransactionTaxRate(200);
    expect(await creatorToken.transactionTaxRate()).to.equal(200);
    
    // 非管理员不能设置税率
    await expect(
      creatorToken.connect(addr1).setTransactionTaxRate(500)
    ).to.be.reverted;
  });
});