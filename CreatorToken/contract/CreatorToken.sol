// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title CreatorToken (CRT) - 创作者平台的ERC20代币
/// @author
/// @notice 具有治理功能、通缩机制和多角色管理的创作者平台ERC20代币。
/// @dev 实现了治理投票权、销毁机制和收益分享功能。
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract CreatorToken is ERC20, ERC20Permit, ERC20Burnable, ERC20Votes, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");
    
    // 总供应量上限
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 18; // 10亿CRT
    
    // 回购销毁税率 (基点)
    uint256 public burnRateBps = 100; // 1%
    
    // 收益分享接收地址
    address public revenueSharingAddress;

    /// @notice 当初始分配配置完成时触发
    event InitialDistribution(address indexed treasury, uint256 amount);
    
    /// @notice 当回购销毁发生时触发
    event BurnTaxApplied(address indexed from, uint256 burnAmount);
    
    /// @notice 当收益分享地址更新时触发
    event RevenueSharingAddressUpdated(address newAddress);
    
    /// @notice 当销毁税率更新时触发
    event BurnRateUpdated(uint256 newRateBps);

    /// @param name 代币名称
    /// @param symbol 代币符号
    /// @param treasury 初始供应量的接收地址
    /// @param initialSupply 初始铸造供应量 (以wei为单位)
    constructor(
        string memory name,
        string memory symbol,
        address treasury,
        uint256 initialSupply
    ) ERC20(name, symbol) ERC20Permit(name) {
        require(treasury != address(0), "CreatorToken: zero treasury");
        require(initialSupply <= MAX_SUPPLY, "CreatorToken: initial supply exceeds max supply");
        
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        // 默认将铸造者/销毁者角色授予部署者；治理应稍后重新分配
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(BURNER_ROLE, msg.sender);
        _setupRole(TREASURY_ROLE, treasury);
        
        // 设置收益分享地址为财政地址
        revenueSharingAddress = treasury;

        if (initialSupply > 0) {
            _mint(treasury, initialSupply);
            emit InitialDistribution(treasury, initialSupply);
        }
    }
    
    /// @notice 重写_transfer函数以实现交易销毁机制
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        // 如果不是零地址转账且销毁率大于0，应用销毁税
        if (from != address(0) && to != address(0) && burnRateBps > 0) {
            uint256 burnAmount = (amount * burnRateBps) / 10_000;
            uint256 netAmount = amount - burnAmount;
            
            // 销毁部分代币
            _burn(from, burnAmount);
            emit BurnTaxApplied(from, burnAmount);
            
            // 转移剩余代币
            super._transfer(from, to, netAmount);
        } else {
            // 正常转账（铸造或销毁）
            super._transfer(from, to, amount);
        }
    }
    
    /// @notice 更新回购销毁税率
    function setBurnRate(uint256 newRateBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newRateBps <= 500, "CreatorToken: burn rate too high (max 5%)");
        burnRateBps = newRateBps;
        emit BurnRateUpdated(newRateBps);
    }
    
    /// @notice 更新收益分享接收地址
    function setRevenueSharingAddress(address newAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newAddress != address(0), "CreatorToken: zero address");
        revenueSharingAddress = newAddress;
        emit RevenueSharingAddressUpdated(newAddress);
    }
    
    /// @notice 铸造代币给`to`地址。调用者必须拥有MINTER_ROLE角色。
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(to != address(0), "CreatorToken: mint to zero");
        require(totalSupply() + amount <= MAX_SUPPLY, "CreatorToken: exceeds max supply");
        _mint(to, amount);
    }
    
    /// @notice 批量铸造代币给多个地址
    function mintBatch(address[] calldata recipients, uint256[] calldata amounts) external onlyRole(MINTER_ROLE) {
        require(recipients.length == amounts.length, "CreatorToken: arrays length mismatch");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "CreatorToken: mint to zero");
            require(totalSupply() + amounts[i] <= MAX_SUPPLY, "CreatorToken: exceeds max supply");
            _mint(recipients[i], amounts[i]);
        }
    }
    
    // 重写必要的函数以支持ERC20Votes
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }
    
    function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }
    
    function _burn(address from, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._burn(from, amount);
    }

    /// @notice 从调用者地址销毁代币。
    function burn(uint256 amount) public override onlyRole(BURNER_ROLE) {
        super.burn(amount);
    }

    /// @notice 从指定账户销毁代币，需要已授权
    function burnFrom(address account, uint256 amount) public override onlyRole(BURNER_ROLE) {
        super.burnFrom(account, amount);
    }
    
    /// @notice 获取代币最大供应量
    function getMaxSupply() external pure returns (uint256) {
        return MAX_SUPPLY;
    }
    
    /// @notice 重写supportsInterface函数以支持所有实现的接口
    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
