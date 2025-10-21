// test/crowdfund.test.js
const { expect } = require("chai");

describe("CrowdFund 合约测试", function () {
  let mybToken, investorRegistry, crowdfundCore;
  let owner, creator, investor1, investor2;
  let initialSupply;
  
  before(async function () {
    [owner, creator, investor1, investor2] = await ethers.getSigners();
    
    // 部署MYBToken合约
    const MYBToken = await ethers.getContractFactory("MYBToken");
    mybToken = await MYBToken.deploy();
    await mybToken.deployed();
    
    // 部署InvestorRegistry合约
    const InvestorRegistry = await ethers.getContractFactory("InvestorRegistry");
    investorRegistry = await InvestorRegistry.deploy();
    await investorRegistry.deployed();
    
    // 部署CrowdFundCore合约
    const CrowdFundCore = await ethers.getContractFactory("CrowdFundCore");
    crowdfundCore = await CrowdFundCore.deploy(
      mybToken.address,
      investorRegistry.address,
      owner.address,
      owner.address
    );
    await crowdfundCore.deployed();
    
    // 转移部分代币给CrowdFundCore
    initialSupply = await mybToken.totalSupply();
    const investorAllocation = initialSupply.mul(70).div(100); // 70%
    await mybToken.transfer(crowdfundCore.address, investorAllocation);
  });
  
  describe("基本功能测试", function () {
    it("应该正确部署所有合约", async function () {
      expect(await mybToken.name()).to.equal("CrowdFund Token");
      expect(await mybToken.symbol()).to.equal("MYB");
      expect(await investorRegistry.owner()).to.equal(owner.address);
      expect(await crowdfundCore.owner()).to.equal(owner.address);
    });
    
    it("应该正确创建众筹活动", async function () {
      const projectName = "测试项目";
      const targetAmount = ethers.utils.parseEther("10"); // 目标10 ETH
      const deadline = Math.floor(Date.now() / 1000) + 86400; // 24小时后
      
      await expect(crowdfundCore.connect(creator).createCrowdfund(
        projectName, targetAmount, deadline
      )).to.emit(crowdfundCore, "CrowdfundCreated");
      
      const crowdfund = await crowdfundCore.getCrowdfundStatus(1);
      expect(crowdfund.projectName).to.equal(projectName);
      expect(crowdfund.creator).to.equal(creator.address);
      expect(crowdfund.targetAmount).to.equal(targetAmount);
    });
    
    it("应该正确处理投资", async function () {
      const investmentAmount = ethers.utils.parseEther("5"); // 投资5 ETH
      
      await expect(crowdfundCore.connect(investor1).invest(1, {
        value: investmentAmount
      })).to.emit(crowdfundCore, "InvestmentReceived");
      
      const crowdfund = await crowdfundCore.getCrowdfundStatus(1);
      expect(crowdfund.currentAmount).to.equal(investmentAmount);
      
      // 检查投资者注册
      const investorInfo = await investorRegistry.getInvestorInfo(1, investor1.address);
      expect(investorInfo.isRegistered).to.be.true;
      expect(investorInfo.totalInvestment).to.equal(investmentAmount);
    });
  });
  
  describe("众筹流程测试", function () {
    it("应该在达到目标时自动标记为成功", async function () {
      // 第一次投资已经投了5 ETH，再投6 ETH达到并超过目标10 ETH
      const additionalInvestment = ethers.utils.parseEther("6");
      
      await expect(crowdfundCore.connect(investor2).invest(1, {
        value: additionalInvestment
      })).to.emit(crowdfundCore, "CrowdfundSuccessful");
      
      const crowdfund = await crowdfundCore.getCrowdfundStatus(1);
      expect(crowdfund.status).to.equal(3); // SUCCESSFUL = 3
    });
    
    it("应该能够释放资金", async function () {
      const ownerInitialBalance = await owner.getBalance();
      const creatorInitialBalance = await creator.getBalance();
      const contractBalance = await crowdfundCore.getContractBalance();
      
      await crowdfundCore.releaseFunds(1);
      
      const crowdfund = await crowdfundCore.getCrowdfundStatus(1);
      expect(crowdfund.fundsReleased).to.be.true;
      
      // 验证合约余额已减少
      expect(await crowdfundCore.getContractBalance()).to.equal(0);
    });
    
    it("投资者应该能够领取MYB代币", async function () {
      // 获取投资者应得的代币数量
      const investor1Info = await investorRegistry.getInvestorInfo(1, investor1.address);
      const tokensToClaim = investor1Info.mybTokens;
      
      // 领取代币
      await expect(crowdfundCore.connect(investor1).claimTokens(1))
        .to.emit(crowdfundCore, "TokensClaimed");
      
      // 验证代币余额增加
      expect(await mybToken.balanceOf(investor1.address)).to.equal(tokensToClaim);
      
      // 验证已领取标记
      const updatedInfo = await investorRegistry.getInvestorInfo(1, investor1.address);
      expect(updatedInfo.mybTokens).to.equal(0);
    });
  });
  
  describe("安全机制测试", function () {
    it("应该防止非所有者释放资金", async function () {
      // 创建一个新的众筹活动用于测试
      const projectName = "安全测试项目";
      const targetAmount = ethers.utils.parseEther("1");
      const deadline = Math.floor(Date.now() / 1000) + 3600; // 1小时后
      
      await crowdfundCore.connect(creator).createCrowdfund(
        projectName, targetAmount, deadline
      );
      
      // 投资并达到目标
      await crowdfundCore.connect(investor1).invest(2, {
        value: targetAmount
      });
      
      // 非所有者尝试释放资金
      await expect(
        crowdfundCore.connect(creator).releaseFunds(2)
      ).to.be.reverted;
    });
    
    it("应该在暂停状态下禁止操作", async function () {
      // 暂停合约
      await crowdfundCore.pause();
      
      // 尝试创建众筹活动
      const projectName = "暂停测试项目";
      const targetAmount = ethers.utils.parseEther("1");
      const deadline = Math.floor(Date.now() / 1000) + 3600;
      
      await expect(
        crowdfundCore.connect(creator).createCrowdfund(
          projectName, targetAmount, deadline
        )
      ).to.be.reverted;
      
      // 恢复合约
      await crowdfundCore.unpause();
    });
  });
});