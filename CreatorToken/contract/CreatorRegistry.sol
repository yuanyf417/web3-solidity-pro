// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title CreatorRegistry - 创作者验证与注册表
/// @notice 平台的创作者注册表，提供多级验证、元数据管理和声誉系统。
/// @dev 实现了多角色管理、链上身份验证和创作者声誉追踪。
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract CreatorRegistry is AccessControl {
    using ECDSA for bytes32;
    using Strings for uint256;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE"); // 验证者角色
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE"); // 版主角色

    // 创作者身份验证级别
    enum VerificationLevel {
        NONE,        // 未验证
        BASIC,       // 基础验证（邮箱/社交媒体）
        INTERMEDIATE,// 中级验证（KYC）
        ADVANCED     // 高级验证（机构认证）
    }
    
    // 创作者状态
    enum CreatorStatus {
        PENDING,     // 待审核
        ACTIVE,      // 活跃
        SUSPENDED,   // 暂停
        REJECTED     // 拒绝
    }
    
    struct Creator {
        address owner;           // 创作者钱包地址
        address[] managers;      // 管理员地址列表
        string metadataURI;      // 链上元数据指针 (IPFS/Arweave)
        VerificationLevel verificationLevel; // 验证级别
        CreatorStatus status;    // 创作者状态
        uint256 registeredAt;    // 注册时间
        uint256 reputation;      // 声誉分数
        uint256 tipCount;        // 收到的打赏次数
        uint256 totalTips;       // 收到的打赏总额（以最小单位计）
        address[] collaborators; // 协作者地址列表
    }

    // 映射 创作者地址 => Creator
    mapping(address => Creator) private _creators;
    // 已注册创作者列表 (用于简单枚举)
    address[] private _creatorList;
    // 地址 => 是否为某创作者的管理员
    mapping(address => address) private _creatorManagers; // 管理员地址 => 所属创作者地址
    // 验证者签名过期时间 (秒)
    uint256 public signatureExpiryTime = 86400; // 24小时
    // 声誉系数 (用于计算)
    uint256 public reputationFactor = 100;
    
    // 事件定义
    event CreatorRegistered(address indexed creator, string metadataURI, uint256 timestamp);
    event CreatorStatusChanged(address indexed creator, CreatorStatus oldStatus, CreatorStatus newStatus);
    event CreatorMetadataUpdated(address indexed creator, string newMetadataURI);
    event VerificationLevelUpdated(address indexed creator, VerificationLevel level);
    event ManagerAdded(address indexed creator, address indexed manager);
    event ManagerRemoved(address indexed creator, address indexed manager);
    event CollaboratorAdded(address indexed creator, address indexed collaborator);
    event CollaboratorRemoved(address indexed creator, address indexed collaborator);
    event CreatorRemoved(address indexed creator);
    event ReputationUpdated(address indexed creator, uint256 oldValue, uint256 newValue);
    event TipStatsUpdated(address indexed creator, uint256 newTipCount, uint256 newTotalTips);
    event SignatureExpiryTimeUpdated(uint256 newTime);
    event ReputationFactorUpdated(uint256 newFactor);

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "CreatorRegistry: not admin");
        _;
    }

    constructor(address admin) {
        require(admin != address(0), "CreatorRegistry: admin zero");
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, admin);
        _setupRole(VERIFIER_ROLE, admin); // 默认将验证者角色授予管理员
        _setupRole(MODERATOR_ROLE, admin); // 默认将版主角色授予管理员
    }
    
    /// @notice 验证签名以允许离线验证后注册
    function verifyRegistrationSignature(
        address creatorAddr,
        string calldata metadataURI,
        uint256 timestamp,
        bytes calldata signature
    ) external view returns (bool) {
        require(block.timestamp <= timestamp + signatureExpiryTime, "CreatorRegistry: signature expired");
        
        bytes32 messageHash = keccak256(
            abi.encodePacked("RegisterCreator", creatorAddr, metadataURI, timestamp)
        );
        
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        address signer = ethSignedMessageHash.recover(signature);
        
        return hasRole(VERIFIER_ROLE, signer);
    }

    /// @notice 将调用者注册为带有元数据URI的创作者
    /// @param metadataURI 指向创作者元数据的指针 (例如 IPFS)
    function registerCreator(string calldata metadataURI) external {
        _registerCreatorInternal(msg.sender, metadataURI);
    }
    
    /// @notice 通过验证者签名批量注册创作者
    /// @param creators 创作者地址列表
    /// @param metadataURIs 元数据URI列表
    /// @param timestamps 时间戳列表
    /// @param signatures 验证者签名列表
    function batchRegisterCreators(
        address[] calldata creators,
        string[] calldata metadataURIs,
        uint256[] calldata timestamps,
        bytes[] calldata signatures
    ) external onlyRole(VERIFIER_ROLE) {
        require(
            creators.length == metadataURIs.length &&
            creators.length == timestamps.length &&
            creators.length == signatures.length,
            "CreatorRegistry: arrays length mismatch"
        );
        
        for (uint256 i = 0; i < creators.length; i++) {
            // 验证签名
            bytes32 messageHash = keccak256(
                abi.encodePacked("RegisterCreator", creators[i], metadataURIs[i], timestamps[i])
            );
            bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
            address signer = ethSignedMessageHash.recover(signatures[i]);
            
            require(hasRole(VERIFIER_ROLE, signer), "CreatorRegistry: invalid signature");
            require(block.timestamp <= timestamps[i] + signatureExpiryTime, "CreatorRegistry: signature expired");
            
            _registerCreatorInternal(creators[i], metadataURIs[i]);
        }
    }
    
    /// @dev 内部注册创作者的辅助函数
    function _registerCreatorInternal(address creator, string calldata metadataURI) internal {
        require(!_exists(creator), "CreatorRegistry: already registered");

        _creators[creator] = Creator({
            owner: creator,
            managers: new address[](0),
            metadataURI: metadataURI,
            verificationLevel: VerificationLevel.NONE,
            status: CreatorStatus.PENDING,
            registeredAt: block.timestamp,
            reputation: 0,
            tipCount: 0,
            totalTips: 0,
            collaborators: new address[](0)
        });
        
        _creatorList.push(creator);
        emit CreatorRegistered(creator, metadataURI, block.timestamp);
    }

    /// @notice 管理员或验证者批准创作者
    function approveCreator(address creatorAddr) external {
        require(hasRole(ADMIN_ROLE, msg.sender) || hasRole(VERIFIER_ROLE, msg.sender), "CreatorRegistry: not authorized");
        require(_exists(creatorAddr), "CreatorRegistry: not registered");
        
        Creator storage c = _creators[creatorAddr];
        CreatorStatus oldStatus = c.status;
        c.status = CreatorStatus.ACTIVE;
        
        emit CreatorStatusChanged(creatorAddr, oldStatus, CreatorStatus.ACTIVE);
    }

    /// @notice 管理员或版主设置创作者状态
    function setCreatorStatus(address creatorAddr, CreatorStatus status) external {
        require(hasRole(ADMIN_ROLE, msg.sender) || hasRole(MODERATOR_ROLE, msg.sender), "CreatorRegistry: not authorized");
        require(_exists(creatorAddr), "CreatorRegistry: not registered");
        
        Creator storage c = _creators[creatorAddr];
        CreatorStatus oldStatus = c.status;
        c.status = status;
        
        emit CreatorStatusChanged(creatorAddr, oldStatus, status);
    }
    
    /// @notice 设置创作者的验证级别
    function setVerificationLevel(address creatorAddr, VerificationLevel level) external onlyRole(VERIFIER_ROLE) {
        require(_exists(creatorAddr), "CreatorRegistry: not registered");
        
        Creator storage c = _creators[creatorAddr];
        c.verificationLevel = level;
        
        emit VerificationLevelUpdated(creatorAddr, level);
    }

    /// @notice 更新自己的元数据 (创作者或其管理员可以更新元数据)
    function updateMetadata(string calldata metadataURI) external {
        address creatorAddr = msg.sender;
        // 检查是否是创作者本人或其管理员
        if (_creatorManagers[msg.sender] != address(0)) {
            creatorAddr = _creatorManagers[msg.sender];
        }
        
        require(_exists(creatorAddr), "CreatorRegistry: not registered");
        Creator storage c = _creators[creatorAddr];
        
        // 确认调用者权限
        bool isOwner = (msg.sender == c.owner);
        bool isManager = false;
        for (uint256 i = 0; i < c.managers.length; i++) {
            if (c.managers[i] == msg.sender) {
                isManager = true;
                break;
            }
        }
        
        require(isOwner || isManager, "CreatorRegistry: not authorized");
        
        c.metadataURI = metadataURI;
        emit CreatorMetadataUpdated(creatorAddr, metadataURI);
    }
    
    /// @notice 添加创作者管理员
    function addManager(address creatorAddr, address manager) external {
        require(_exists(creatorAddr), "CreatorRegistry: not registered");
        Creator storage c = _creators[creatorAddr];
        
        // 只有创作者本人或管理员可以添加新管理员
        require(msg.sender == c.owner, "CreatorRegistry: only owner");
        require(manager != address(0), "CreatorRegistry: zero address");
        require(manager != creatorAddr, "CreatorRegistry: cannot add self");
        
        // 检查是否已存在
        for (uint256 i = 0; i < c.managers.length; i++) {
            require(c.managers[i] != manager, "CreatorRegistry: already a manager");
        }
        
        c.managers.push(manager);
        _creatorManagers[manager] = creatorAddr;
        
        emit ManagerAdded(creatorAddr, manager);
    }
    
    /// @notice 移除创作者管理员
    function removeManager(address creatorAddr, address manager) external {
        require(_exists(creatorAddr), "CreatorRegistry: not registered");
        Creator storage c = _creators[creatorAddr];
        
        // 只有创作者本人可以移除管理员
        require(msg.sender == c.owner, "CreatorRegistry: only owner");
        
        for (uint256 i = 0; i < c.managers.length; i++) {
            if (c.managers[i] == manager) {
                // 删除并重组数组
                c.managers[i] = c.managers[c.managers.length - 1];
                c.managers.pop();
                delete _creatorManagers[manager];
                
                emit ManagerRemoved(creatorAddr, manager);
                break;
            }
        }
    }
    
    /// @notice 添加协作者
    function addCollaborator(address collaborator) external {
        address creatorAddr = msg.sender;
        // 检查是否是创作者本人或其管理员
        if (_creatorManagers[msg.sender] != address(0)) {
            creatorAddr = _creatorManagers[msg.sender];
        }
        
        require(_exists(creatorAddr), "CreatorRegistry: not registered");
        Creator storage c = _creators[creatorAddr];
        
        // 确认调用者权限
        bool isOwner = (msg.sender == c.owner);
        bool isManager = false;
        for (uint256 i = 0; i < c.managers.length; i++) {
            if (c.managers[i] == msg.sender) {
                isManager = true;
                break;
            }
        }
        
        require(isOwner || isManager, "CreatorRegistry: not authorized");
        require(collaborator != address(0), "CreatorRegistry: zero address");
        
        // 检查是否已存在
        for (uint256 i = 0; i < c.collaborators.length; i++) {
            require(c.collaborators[i] != collaborator, "CreatorRegistry: already a collaborator");
        }
        
        c.collaborators.push(collaborator);
        emit CollaboratorAdded(creatorAddr, collaborator);
    }
    
    /// @notice 移除协作者
    function removeCollaborator(address collaborator) external {
        address creatorAddr = msg.sender;
        // 检查是否是创作者本人或其管理员
        if (_creatorManagers[msg.sender] != address(0)) {
            creatorAddr = _creatorManagers[msg.sender];
        }
        
        require(_exists(creatorAddr), "CreatorRegistry: not registered");
        Creator storage c = _creators[creatorAddr];
        
        // 确认调用者权限
        bool isOwner = (msg.sender == c.owner);
        bool isManager = false;
        for (uint256 i = 0; i < c.managers.length; i++) {
            if (c.managers[i] == msg.sender) {
                isManager = true;
                break;
            }
        }
        
        require(isOwner || isManager, "CreatorRegistry: not authorized");
        
        for (uint256 i = 0; i < c.collaborators.length; i++) {
            if (c.collaborators[i] == collaborator) {
                // 删除并重组数组
                c.collaborators[i] = c.collaborators[c.collaborators.length - 1];
                c.collaborators.pop();
                
                emit CollaboratorRemoved(creatorAddr, collaborator);
                break;
            }
        }
    }
    
    /// @notice 更新创作者声誉分数
    function updateReputation(address creatorAddr, uint256 delta) external {
        require(_exists(creatorAddr), "CreatorRegistry: not registered");
        // 只有授权合约（如RevenuePool）可以更新声誉
        // 在实际实现中应使用更严格的权限控制
        
        Creator storage c = _creators[creatorAddr];
        uint256 oldValue = c.reputation;
        
        if (delta > 0) {
            c.reputation = oldValue + delta;
        } else {
            // 如果delta是负数，将reputation设为0
            c.reputation = 0;
        }
        
        emit ReputationUpdated(creatorAddr, oldValue, c.reputation);
    }
    
    /// @notice 更新创作者打赏统计
    function updateTipStats(address creatorAddr, uint256 tipAmount) external {
        require(_exists(creatorAddr), "CreatorRegistry: not registered");
        // 只有授权合约可以更新
        
        Creator storage c = _creators[creatorAddr];
        c.tipCount += 1;
        c.totalTips += tipAmount;
        
        // 基于打赏更新声誉
        uint256 reputationDelta = tipAmount / reputationFactor;
        uint256 oldValue = c.reputation;
        c.reputation = oldValue + reputationDelta;
        
        emit TipStatsUpdated(creatorAddr, c.tipCount, c.totalTips);
        emit ReputationUpdated(creatorAddr, oldValue, c.reputation);
    }
    
    /// @notice 更新签名过期时间
    function setSignatureExpiryTime(uint256 newTime) external onlyRole(ADMIN_ROLE) {
        signatureExpiryTime = newTime;
        emit SignatureExpiryTimeUpdated(newTime);
    }
    
    /// @notice 更新声誉系数
    function setReputationFactor(uint256 newFactor) external onlyRole(ADMIN_ROLE) {
        require(newFactor > 0, "CreatorRegistry: factor must be positive");
        reputationFactor = newFactor;
        emit ReputationFactorUpdated(newFactor);
    }

    /// @notice 获取创作者基本信息
    function getCreator(address creatorAddr) external view returns (
        address owner,
        string memory metadataURI,
        VerificationLevel verificationLevel,
        CreatorStatus status,
        uint256 registeredAt,
        uint256 reputation
    ) {
        require(_exists(creatorAddr), "CreatorRegistry: not registered");
        Creator storage c = _creators[creatorAddr];
        
        return (
            c.owner,
            c.metadataURI,
            c.verificationLevel,
            c.status,
            c.registeredAt,
            c.reputation
        );
    }
    
    /// @notice 获取创作者统计信息
    function getCreatorStats(address creatorAddr) external view returns (
        uint256 tipCount,
        uint256 totalTips,
        uint256 managerCount,
        uint256 collaboratorCount
    ) {
        require(_exists(creatorAddr), "CreatorRegistry: not registered");
        Creator storage c = _creators[creatorAddr];
        
        return (
            c.tipCount,
            c.totalTips,
            c.managers.length,
            c.collaborators.length
        );
    }
    
    /// @notice 获取创作者管理员列表
    function getCreatorManagers(address creatorAddr) external view returns (address[] memory) {
        require(_exists(creatorAddr), "CreatorRegistry: not registered");
        return _creators[creatorAddr].managers;
    }
    
    /// @notice 获取创作者协作者列表
    function getCreatorCollaborators(address creatorAddr) external view returns (address[] memory) {
        require(_exists(creatorAddr), "CreatorRegistry: not registered");
        return _creators[creatorAddr].collaborators;
    }
    
    /// @notice 检查地址是否是某创作者的管理员
    function isCreatorManager(address addr) external view returns (address, bool) {
        address creatorAddr = _creatorManagers[addr];
        return (creatorAddr, creatorAddr != address(0));
    }

    /// @notice 返回地址是否已注册
    function isRegistered(address creatorAddr) external view returns (bool) {
        return _exists(creatorAddr);
    }

    /// @notice 返回地址是否处于活跃状态 (已批准)
    function isActive(address creatorAddr) external view returns (bool) {
        return _exists(creatorAddr) && _creators[creatorAddr].status == CreatorStatus.ACTIVE;
    }
    
    /// @notice 获取创作者验证级别
    function getVerificationLevel(address creatorAddr) external view returns (VerificationLevel) {
        require(_exists(creatorAddr), "CreatorRegistry: not registered");
        return _creators[creatorAddr].verificationLevel;
    }
    
    /// @notice 获取创作者状态
    function getCreatorStatus(address creatorAddr) external view returns (CreatorStatus) {
        require(_exists(creatorAddr), "CreatorRegistry: not registered");
        return _creators[creatorAddr].status;
    }

    /// @notice 返回已注册创作者的总数
    function totalCreators() external view returns (uint256) {
        return _creatorList.length;
    }

    /// @notice 通过索引返回创作者地址 (从0开始)
    function creatorByIndex(uint256 index) external view returns (address) {
        require(index < _creatorList.length, "CreatorRegistry: index OOB");
        return _creatorList[index];
    }

    /// @notice 批量获取创作者信息（分页）
    function getCreators(uint256 startIndex, uint256 count) external view returns (address[] memory) {
        require(startIndex < _creatorList.length, "CreatorRegistry: start index out of bounds");
        
        uint256 endIndex = startIndex + count;
        if (endIndex > _creatorList.length) {
            endIndex = _creatorList.length;
        }
        
        address[] memory result = new address[](endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = _creatorList[i];
        }
        
        return result;
    }
    
    /// @notice 管理员可以移除创作者记录 (如有需要)
    function removeCreator(address creatorAddr) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "CreatorRegistry: not admin");
        require(_exists(creatorAddr), "CreatorRegistry: not registered");
        
        Creator storage c = _creators[creatorAddr];
        
        // 清理管理员映射
        for (uint256 i = 0; i < c.managers.length; i++) {
            delete _creatorManagers[c.managers[i]];
        }
        
        delete _creators[creatorAddr];
        
        // 从数组中移除 (时间复杂度O(n))
        for (uint256 i = 0; i < _creatorList.length; i++) {
            if (_creatorList[i] == creatorAddr) {
                _creatorList[i] = _creatorList[_creatorList.length - 1];
                _creatorList.pop();
                break;
            }
        }
        
        emit CreatorRemoved(creatorAddr);
    }

    /// @dev 检查创作者是否已注册
    function _exists(address creatorAddr) internal view returns (bool) {
        return _creators[creatorAddr].owner != address(0);
    }
}
