// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title RevenuePool - 处理创作者的打赏/捐款和提款
/// @notice 支持ETH和ERC20代币打赏，具有多级费用结构和灵活的收益分配机制，包含验证级别折扣系统。
/// @dev 与CreatorRegistry和TokenVesting集成，支持收益分享、定期分配和基于验证级别的费用折扣。
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface ICreatorRegistry {
    function isActive(address creatorAddr) external view returns (bool);
    function getVerificationLevel(address creatorAddr) external view returns (uint8);
    function updateTipStats(address creatorAddr, uint256 amount) external;
}

interface ITokenVesting {
    function createVestingSchedule(
        address beneficiary,
        uint8 allocationType,
        uint256 amount,
        uint256 start,
        uint256 cliff,
        uint256 end
    ) external;
}

contract RevenuePool is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // 代币地址 => 用户 => 金额
    // token == address(0) 表示ETH
    mapping(address => mapping(address => uint256)) public pendingWithdrawals;

    // 平台费用结构
    struct FeeStructure {
        uint256 platformFeeBps;      // 平台费用 (基点)
        uint256 treasuryFeeBps;      // 财政费用 (基点)
        uint256 communityFeeBps;     // 社区发展费用 (基点)
    }
    
    FeeStructure public feeStructure;
    address public platformFeeRecipient;
    address public treasury;
    address public communityFund;
    
    // 定期分配设置
    bool public autoVestingEnabled = false;
    ITokenVesting public tokenVesting;
    uint8 public defaultAllocationType = 3; // 默认ECOSYSTEM
    uint256 public vestingStartDelay = 0;   // 开始延迟 (秒)
    uint256 public vestingCliff = 30 days;  // 悬崖期 (30天)
    uint256 public vestingDuration = 365 days; // 总释放期 (365天)
    
    // 验证级别折扣
    struct VerificationDiscount {
        uint256 basicDiscountBps;     // 基础验证折扣 (基点)
        uint256 intermediateDiscountBps; // 中级验证折扣 (基点)
        uint256 advancedDiscountBps;  // 高级验证折扣 (基点)
    }
    
    VerificationDiscount public verificationDiscount;
    
    // 打赏金额限制
    uint256 public minTipAmount = 1 wei;  // 最小打赏金额
    uint256 public maxTipAmountPerTx = 10 ether; // 每笔交易最大打赏金额
    
    // 定期分配配置
    uint256 public regularDistributionInterval = 1 weeks; // 定期分配间隔
    uint256 public lastDistributionTimestamp; // 上次分配时间戳

    ICreatorRegistry public registry;
    address public owner;

    event TipReceived(address indexed payer, address indexed creator, address indexed token, uint256 amount, uint256 platformFee, uint256 treasuryFee, uint256 communityFee, uint256 discount);
    event Withdrawn(address indexed token, address indexed to, uint256 amount);
    event FeeStructureUpdated(FeeStructure newStructure);
    event FeeRecipientsUpdated(address platform, address treasury, address community);
    event VestingSettingsUpdated(bool enabled, uint8 allocationType, uint256 startDelay, uint256 cliff, uint256 duration);
    event OwnerTransferred(address indexed oldOwner, address indexed newOwner);
    event TokensVested(address indexed recipient, uint256 amount, uint8 allocationType);
    event VerificationDiscountUpdated(VerificationDiscount oldDiscount, VerificationDiscount newDiscount);
    event RegularDistributionExecuted(uint256 timestamp, uint256 totalAmount);
    event TipLimitsUpdated(uint256 oldMinAmount, uint256 newMinAmount, uint256 oldMaxAmount, uint256 newMaxAmount);

    modifier onlyOwner() {
        require(msg.sender == owner, "RevenuePool: not owner");
        _;
    }

    constructor(
        address registryAddr,
        address _platformFeeRecipient,
        address _treasury,
        address _communityFund,
        uint256 _platformFeeBps,
        uint256 _treasuryFeeBps,
        uint256 _communityFeeBps
    ) {
        require(registryAddr != address(0), "RevenuePool: registry zero");
        require(_platformFeeBps + _treasuryFeeBps + _communityFeeBps <= 3000, "RevenuePool: total fees exceed 30%");
        
        registry = ICreatorRegistry(registryAddr);
        platformFeeRecipient = _platformFeeRecipient;
        treasury = _treasury;
        communityFund = _communityFund;
        
        feeStructure = FeeStructure({
            platformFeeBps: _platformFeeBps,
            treasuryFeeBps: _treasuryFeeBps,
            communityFeeBps: _communityFeeBps
        });
        
        // 设置默认验证级别折扣
        verificationDiscount = VerificationDiscount({
            basicDiscountBps: 100,     // 1%折扣
            intermediateDiscountBps: 250, // 2.5%折扣
            advancedDiscountBps: 500   // 5%折扣
        });
        
        owner = msg.sender;
        lastDistributionTimestamp = block.timestamp;
        
        // 移除暂停功能
    }
    
    // 暂停相关功能已移除
    
    /// @notice 设置代币分配合约地址
    function setTokenVesting(address vestingAddr) external onlyOwner {
        require(vestingAddr != address(0), "RevenuePool: zero address");
        tokenVesting = ITokenVesting(vestingAddr);
    }
    
    /// @notice 更新定期分配设置
    function updateVestingSettings(
        bool enabled,
        uint8 allocationType,
        uint256 startDelay,
        uint256 cliff,
        uint256 duration
    ) external onlyOwner {
        autoVestingEnabled = enabled;
        defaultAllocationType = allocationType;
        vestingStartDelay = startDelay;
        vestingCliff = cliff;
        vestingDuration = duration;
        
        emit VestingSettingsUpdated(enabled, allocationType, startDelay, cliff, duration);
    }
    
    /// @notice 更新费用接收地址
    function updateFeeRecipients(address platform, address _treasury, address community) external onlyOwner {
        platformFeeRecipient = platform;
        treasury = _treasury;
        communityFund = community;
        
        emit FeeRecipientsUpdated(platform, _treasury, community);
    }

    /// @notice 用ETH向创作者打赏 (msg.value)
    /// @param creator 接收打赏的创作者地址 (必须在注册表中处于活跃状态)
    function tipCreatorETH(address creator) external payable nonReentrant {
        require(msg.value >= minTipAmount, "RevenuePool: amount below minimum");
        require(msg.value <= maxTipAmountPerTx, "RevenuePool: amount exceeds maximum");
        require(registry.isActive(creator), "RevenuePool: creator not active");
        
        // 获取创作者验证级别以计算折扣
        uint8 verificationLevel = registry.getVerificationLevel(creator);
        uint256 discountBps = getDiscountByLevel(verificationLevel);
        
        // 计算折扣金额
        uint256 discountAmount = (msg.value * discountBps) / 10000;
        uint256 effectiveAmount = msg.value - discountAmount;

        // 计算各级费用 (基于折扣后金额)
        (uint256 platformFee, uint256 treasuryFee, uint256 communityFee) = _calculateFees(effectiveAmount);
        uint256 net = effectiveAmount - platformFee - treasuryFee - communityFee;
        
        // 更新创作者打赏统计和声誉
        registry.updateTipStats(creator, msg.value);

        // 分配费用
        if (platformFee > 0 && platformFeeRecipient != address(0)) {
            pendingWithdrawals[address(0)][platformFeeRecipient] += platformFee;
        }
        
        if (treasuryFee > 0 && treasury != address(0)) {
            pendingWithdrawals[address(0)][treasury] += treasuryFee;
        }
        
        if (communityFee > 0 && communityFund != address(0)) {
            // 如果启用了自动分配合约，则将社区费用分配到定期释放计划
            if (autoVestingEnabled && address(tokenVesting) != address(0)) {
                // 这里应该是社区代币，但由于是ETH，我们先累积到社区基金
                pendingWithdrawals[address(0)][communityFund] += communityFee;
            } else {
                pendingWithdrawals[address(0)][communityFund] += communityFee;
            }
        }

        // 计入创作者的待领取ETH余额
        pendingWithdrawals[address(0)][creator] += net;

        emit TipReceived(msg.sender, creator, address(0), msg.value, platformFee, treasuryFee, communityFee, discountAmount);
    }

    /// @notice 用ERC20代币向创作者打赏
    /// @param token ERC20代币地址
    /// @param creator 接收打赏的创作者地址 (必须处于活跃状态)
    /// @param amount 打赏的代币数量 (调用者必须已授权)
    function tipCreatorERC20(address token, address creator, uint256 amount) external nonReentrant {
        require(token != address(0), "RevenuePool: token zero");
        require(amount >= minTipAmount, "RevenuePool: amount below minimum");
        require(amount <= maxTipAmountPerTx, "RevenuePool: amount exceeds maximum");
        require(registry.isActive(creator), "RevenuePool: creator not active");

        // 从付款人转移代币到此合约
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        // 获取创作者验证级别以计算折扣
        uint8 verificationLevel = registry.getVerificationLevel(creator);
        uint256 discountBps = getDiscountByLevel(verificationLevel);
        
        // 计算折扣金额
        uint256 discountAmount = (amount * discountBps) / 10000;
        uint256 effectiveAmount = amount - discountAmount;

        // 计算各级费用 (基于折扣后金额)
        (uint256 platformFee, uint256 treasuryFee, uint256 communityFee) = _calculateFees(effectiveAmount);
        uint256 net = effectiveAmount - platformFee - treasuryFee - communityFee;
        
        // 更新创作者打赏统计和声誉
        registry.updateTipStats(creator, amount);

        // 分配费用
        if (platformFee > 0 && platformFeeRecipient != address(0)) {
            pendingWithdrawals[token][platformFeeRecipient] += platformFee;
        }
        
        if (treasuryFee > 0 && treasury != address(0)) {
            pendingWithdrawals[token][treasury] += treasuryFee;
        }
        
        if (communityFee > 0 && communityFund != address(0)) {
            // 如果启用了自动分配合约，则将社区费用分配到定期释放计划
            if (autoVestingEnabled && address(tokenVesting) != address(0)) {
                // 直接调用分配合约创建释放计划
                _createVestingSchedule(communityFund, communityFee);
            } else {
                pendingWithdrawals[token][communityFund] += communityFee;
            }
        }

        pendingWithdrawals[token][creator] += net;

        emit TipReceived(msg.sender, creator, token, amount, platformFee, treasuryFee, communityFee, discountAmount);
    }
    
    /// @notice 批量向多个创作者打赏ERC20代币
    function batchTipCreatorERC20(
        address token,
        address[] calldata creators,
        uint256[] calldata amounts
    ) external nonReentrant {
        require(token != address(0), "RevenuePool: token zero");
        require(creators.length == amounts.length, "RevenuePool: arrays length mismatch");
        require(creators.length <= 100, "RevenuePool: too many creators"); // 防止gas超限
        
        uint256 totalAmount = 0;
        
        // 验证并计算总金额
        for (uint256 i = 0; i < creators.length; i++) {
            require(creators[i] != address(0), "RevenuePool: zero creator");
            require(amounts[i] >= minTipAmount, "RevenuePool: amount below minimum");
            require(amounts[i] <= maxTipAmountPerTx, "RevenuePool: amount exceeds maximum");
            require(registry.isActive(creators[i]), "RevenuePool: creator not active");
            totalAmount += amounts[i];
        }
        
        // 从付款人转移代币到此合约
        IERC20(token).safeTransferFrom(msg.sender, address(this), totalAmount);
        
        // 处理每个打赏
        for (uint256 i = 0; i < creators.length; i++) {
            // 获取创作者验证级别以计算折扣
            uint8 verificationLevel = registry.getVerificationLevel(creators[i]);
            uint256 discountBps = getDiscountByLevel(verificationLevel);
            
            // 计算折扣金额
            uint256 discountAmount = (amounts[i] * discountBps) / 10000;
            uint256 effectiveAmount = amounts[i] - discountAmount;
            
            (uint256 platformFee, uint256 treasuryFee, uint256 communityFee) = _calculateFees(effectiveAmount);
            uint256 net = effectiveAmount - platformFee - treasuryFee - communityFee;
            
            // 分配费用... (简化版)
            if (platformFee > 0) pendingWithdrawals[token][platformFeeRecipient] += platformFee;
            if (treasuryFee > 0) pendingWithdrawals[token][treasury] += treasuryFee;
            if (communityFee > 0) {
                if (autoVestingEnabled && address(tokenVesting) != address(0)) {
                    _createVestingSchedule(communityFund, communityFee);
                } else {
                    pendingWithdrawals[token][communityFund] += communityFee;
                }
            }
            
            pendingWithdrawals[token][creators[i]] += net;
            
            // 更新创作者打赏统计和声誉
            registry.updateTipStats(creators[i], amounts[i]);
            
            emit TipReceived(msg.sender, creators[i], token, amounts[i], platformFee, treasuryFee, communityFee, discountAmount);
        }
    }
    
    /// @dev 创建代币释放计划的辅助函数
    function _createVestingSchedule(address recipient, uint256 amount) internal {
        uint256 start = block.timestamp + vestingStartDelay;
        uint256 cliff = start + vestingCliff;
        uint256 end = start + vestingDuration;
        
        try tokenVesting.createVestingSchedule(
            recipient,
            defaultAllocationType,
            amount,
            start,
            cliff,
            end
        ) {
            emit TokensVested(recipient, amount, defaultAllocationType);
        } catch {
            // 如果创建失败，回退到普通余额
            address token = address(tokenVesting); // 这里假设tokenVesting知道代币地址，实际实现中可能需要调整
            pendingWithdrawals[token][recipient] += amount;
        }
    }

    /// @notice 创作者(或接收者)提取其代币的待领取余额 (ETH使用address(0))
    function withdraw(address token) external nonReentrant {
        uint256 amount = pendingWithdrawals[token][msg.sender];
        require(amount > 0, "RevenuePool: no funds");

        pendingWithdrawals[token][msg.sender] = 0;

        if (token == address(0)) {
            // ETH提款
            (bool ok, ) = payable(msg.sender).call{value: amount}("");
            require(ok, "RevenuePool: ETH send failed");
        } else {
            IERC20(token).safeTransfer(msg.sender, amount);
        }

        emit Withdrawn(token, msg.sender, amount);
    }
    
    /// @notice 提取指定金额的待领取余额
    function withdrawPartial(address token, uint256 amount) external nonReentrant {
        require(pendingWithdrawals[token][msg.sender] >= amount, "RevenuePool: insufficient balance");
        require(amount > 0, "RevenuePool: zero amount");

        pendingWithdrawals[token][msg.sender] -= amount;

        if (token == address(0)) {
            (bool ok, ) = payable(msg.sender).call{value: amount}("");
            require(ok, "RevenuePool: ETH send failed");
        } else {
            IERC20(token).safeTransfer(msg.sender, amount);
        }

        emit Withdrawn(token, msg.sender, amount);
    }

    /// @notice 所有者可以提取指定接收者的累积费用或余额 (代币或ETH)
    function withdrawOnBehalf(address token, address recipient, address to) external nonReentrant onlyOwner {
        require(to != address(0), "RevenuePool: to zero");
        uint256 amount = pendingWithdrawals[token][recipient];
        require(amount > 0, "RevenuePool: no funds");
        pendingWithdrawals[token][recipient] = 0;

        if (token == address(0)) {
            (bool ok, ) = payable(to).call{value: amount}("");
            require(ok, "RevenuePool: ETH send failed");
        } else {
            IERC20(token).safeTransfer(to, amount);
        }

        emit Withdrawn(token, to, amount);
    }

    /// @notice 更新费用结构 (仅所有者)
    function updateFeeStructure(
        uint256 platformFeeBps,
        uint256 treasuryFeeBps,
        uint256 communityFeeBps
    ) external onlyOwner {
        require(platformFeeBps + treasuryFeeBps + communityFeeBps <= 3000, "RevenuePool: total fees exceed 30%");
        
        feeStructure.platformFeeBps = platformFeeBps;
        feeStructure.treasuryFeeBps = treasuryFeeBps;
        feeStructure.communityFeeBps = communityFeeBps;
        
        emit FeeStructureUpdated(feeStructure);
    }

    /// @notice 设置所有者 (转移所有权)
    function transferOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "RevenuePool: zero owner");
        emit OwnerTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @dev 计算多级费用的辅助函数
    function _calculateFees(uint256 amount) internal view returns (uint256, uint256, uint256) {
        uint256 platformFee = 0;
        uint256 treasuryFee = 0;
        uint256 communityFee = 0;
        
        if (feeStructure.platformFeeBps > 0 && platformFeeRecipient != address(0)) {
            platformFee = (amount * feeStructure.platformFeeBps) / 10_000;
        }
        
        if (feeStructure.treasuryFeeBps > 0 && treasury != address(0)) {
            treasuryFee = (amount * feeStructure.treasuryFeeBps) / 10_000;
        }
        
        if (feeStructure.communityFeeBps > 0 && communityFund != address(0)) {
            communityFee = (amount * feeStructure.communityFeeBps) / 10_000;
        }
        
        return (platformFee, treasuryFee, communityFee);
    }

    /// @notice 查询指定用户在特定代币上的待领取余额
    function getPendingWithdrawal(address token, address user) external view returns (uint256) {
        return pendingWithdrawals[token][user];
    }
    
    /// @notice 获取当前合约的ETH余额
    function getEthBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /// @notice 获取当前合约在特定代币上的余额
    function getTokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
    
    /// @notice 设置打赏金额限制
    function setTipLimits(uint256 _minTipAmount, uint256 _maxTipAmountPerTx) external onlyOwner {
        require(_minTipAmount <= _maxTipAmountPerTx, "RevenuePool: invalid limits");
        require(_minTipAmount >= 1 wei, "RevenuePool: min tip too low");
        
        uint256 oldMin = minTipAmount;
        uint256 oldMax = maxTipAmountPerTx;
        
        minTipAmount = _minTipAmount;
        maxTipAmountPerTx = _maxTipAmountPerTx;
        
        emit TipLimitsUpdated(oldMin, _minTipAmount, oldMax, _maxTipAmountPerTx);
    }
    
    /// @notice 更新验证级别折扣
    function setVerificationDiscount(
        uint256 basicDiscountBps,
        uint256 intermediateDiscountBps,
        uint256 advancedDiscountBps
    ) external onlyOwner {
        // 确保折扣不超过20%
        require(
            basicDiscountBps <= 2000 && 
            intermediateDiscountBps <= 2000 && 
            advancedDiscountBps <= 2000,
            "RevenuePool: discount too high"
        );
        
        // 确保折扣级别递增
        require(
            basicDiscountBps <= intermediateDiscountBps && 
            intermediateDiscountBps <= advancedDiscountBps,
            "RevenuePool: invalid discount progression"
        );
        
        VerificationDiscount memory oldDiscount = verificationDiscount;
        
        verificationDiscount = VerificationDiscount({
            basicDiscountBps: basicDiscountBps,
            intermediateDiscountBps: intermediateDiscountBps,
            advancedDiscountBps: advancedDiscountBps
        });
        
        emit VerificationDiscountUpdated(oldDiscount, verificationDiscount);
    }
    
    /// @notice 执行定期分配（例如平台奖励）
    function executeRegularDistribution() external onlyOwner {
        require(
            block.timestamp >= lastDistributionTimestamp + regularDistributionInterval,
            "RevenuePool: distribution interval not passed"
        );
        
        // 更新最后分配时间戳
        lastDistributionTimestamp = block.timestamp;
        
        // 这里可以实现定期分配逻辑，例如向高声誉创作者发放额外奖励
        // 这需要获取所有活跃创作者并根据声誉进行排序
        
        emit RegularDistributionExecuted(block.timestamp, 0); // 0 表示本次分配金额
    }
    
    /// @dev 根据验证级别获取折扣率
    function getDiscountByLevel(uint8 level) internal view returns (uint256) {
        if (level == 1) { // BASIC
            return verificationDiscount.basicDiscountBps;
        } else if (level == 2) { // INTERMEDIATE
            return verificationDiscount.intermediateDiscountBps;
        } else if (level == 3) { // ADVANCED
            return verificationDiscount.advancedDiscountBps;
        }
        return 0;
    }
    
    /// @notice 设置定期分配间隔
    function setDistributionInterval(uint256 interval) external onlyOwner {
        // 1年 = 365天
        require(interval >= 1 days && interval <= 365 days, "RevenuePool: invalid interval");
        regularDistributionInterval = interval;
    }
    
    // 允许合约直接接收ETH (不推荐用于打赏)
    receive() external payable {}
    
    // 确保合约能接收合约调用回退
    fallback() external payable {}
}
