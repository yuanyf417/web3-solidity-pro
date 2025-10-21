# CreatorToken生态系统

一个基于以太坊的创作者奖励和治理平台，让创作者能够获得粉丝的直接支持，并参与平台治理。

## 功能特点

- **创作者注册与验证** - 创作者可以在平台注册并获得不同级别的验证
- **多种打赏方式** - 支持ETH和ERC20代币打赏
- **透明的收益分配** - 清晰的费用结构和收益计算
- **代币释放计划** - 支持线性释放的代币分配
- **去中心化治理** - 基于代币的提案和投票系统

## 项目结构

```
├── contract/          # 智能合约源代码
├── scripts/           # 部署脚本
├── test/              # 测试文件
├── artifacts/         # 编译后的合约字节码和ABI
├── cache/             # Hardhat缓存文件
├── package.json       # 项目依赖和脚本
├── hardhat.config.js  # Hardhat配置
└── README.md          # 项目说明文档
```

## 开始使用

### 前提条件

- Node.js >= 14.x
- npm >= 6.x

### 安装依赖

```bash
npm install
```

### 编译合约

```bash
npm run compile
```

### 运行测试

```bash
npm test
```

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