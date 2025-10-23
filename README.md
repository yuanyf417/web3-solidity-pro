# Web3 Solidity 项目集

本仓库包含两个独立的基于以太坊的智能合约项目：CreatorToken（创作者奖励平台）和CrowdFund（众筹平台）。

## 项目概述

### CreatorToken

一个基于以太坊的创作者奖励和治理平台，让创作者能够获得粉丝的直接支持，并参与平台治理。

**主要合约：**
- `CreatorRegistry.sol` - 创作者注册和验证系统
- `CreatorToken.sol` - 创作者专属代币
- `Governance.sol` - 去中心化治理系统
- `RevenuePool.sol` - 收益分配池
- `TokenVesting.sol` - 代币线性释放合约

### CrowdFund

一个基于以太坊的众筹平台，允许项目方创建众筹活动，投资者参与投资并获得MYB代币奖励。

**主要合约：**
- `CrowdFundCore.sol` - 众筹核心逻辑
- `MYBToken.sol` - 众筹奖励代币（1 ETH = 10000 MYB）
- `InvestorRegistry.sol` - 投资者信息管理

**特色功能：**
- 支持创建众筹活动，设置目标金额和截止时间
- 最小投资金额为0.01 ETH
- 众筹成功后自动分配资金（70%给项目方，20%给开发基金，10%给社区基金）
- 众筹失败时支持投资者退款

## 项目结构

```
├── CreatorToken/      # 创作者奖励平台
│   ├── contract/      # 智能合约源代码
│   ├── scripts/       # 部署脚本
│   └── test/          # 测试文件
├── CrowdFund/         # 众筹平台
│   ├── contract/      # 智能合约源代码
│   ├── doc/           # 文档（包含前端对接文档）
│   ├── scripts/       # 部署脚本
│   └── test/          # 测试文件
├── prd/               # 产品需求文档
└── README.md          # 仓库说明文档
```

## 开始使用

### 前提条件

- Node.js >= 14.x
- npm >= 6.x

### 项目使用说明

#### CreatorToken

```bash
cd CreatorToken
npm install
npm run compile  # 编译合约
npm test         # 运行测试
```

#### CrowdFund

```bash
cd CrowdFund
npm install
npm run compile  # 编译合约
npm test         # 运行测试
```

## 部署说明

每个项目都有独立的部署脚本和配置文件：

- CreatorToken: `CreatorToken/scripts/deploy.js`
- CrowdFund: `CrowdFund/scripts/deploy.js`

部署前请确保配置了正确的环境变量（可参考各项目下的 `.env.example` 文件）。

## 文档

- CrowdFund前端对接文档：`CrowdFund/doc/前端对接文档.md`
- 更多详细信息请参考各项目的README文件

### 部署合约

#### 本地部署

启动本地开发节点:
```bash
npm run node
```

在另一个终端部署合约:
```bash
npm run deploy
```

或者使用简化的本地部署命令:
```bash
npm run deploy:local
```

#### 测试网部署

**重要：在部署到测试网前，请确保您的钱包有足够的测试代币支付gas费用！**

1. **获取测试代币**:

   - **Sepolia测试网**:
     - [Alchemy Sepolia Faucet](https://sepoliafaucet.com/)
     - [Infura Sepolia Faucet](https://www.infura.io/faucet/sepolia)
     - [Coinbase Wallet Faucet](https://coinbase.com/faucets/ethereum-sepolia-faucet)

   - **Mumbai测试网**:
     - [Polygon Mumbai Faucet](https://faucet.polygon.technology/)
     - [Alchemy Mumbai Faucet](https://mumbaifaucet.com/)

2. **配置环境变量**:

   复制`.env.example`文件为`.env`并填写您的私钥和RPC URL:

   ```bash
   cp .env.example .env
   # 编辑.env文件
   ```

3. **部署到Sepolia测试网**:

   ```bash
   npm run deploy:sepolia
   ```

4. **部署到Mumbai测试网**:

   ```bash
   npm run deploy:mumbai
   ```

### 运行测试覆盖率

```bash
npm run coverage
```

## 智能合约

1. **CreatorToken** - 平台原生代币，支持治理和奖励
2. **CreatorRegistry** - 创作者注册和验证系统
3. **RevenuePool** - 收益池，管理打赏和分配
4. **TokenVesting** - 代币释放计划实现
5. **Governance** - 去中心化治理系统

## 开发说明

### 环境配置

在部署到测试网或主网前，请确保在`hardhat.config.js`中配置了正确的私钥和API密钥:

- INFURA API密钥
- 部署账户的私钥
- Etherscan API密钥 (用于合约验证)

### 添加新合约

1. 在`contract/`目录下创建新的合约文件
2. 运行`npm run compile`编译新合约
3. 在`test/`目录下为新合约创建测试文件
4. 更新`scripts/deploy.js`以包含新合约的部署

## 安全考量

- 所有合约都遵循Solidity安全最佳实践
- 使用OpenZeppelin的安全合约库
- 实现了基于角色的访问控制
- 支持紧急暂停机制

## 许可证

[MIT](LICENSE)