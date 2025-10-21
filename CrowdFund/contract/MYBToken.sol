// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MYBToken - CrowdFund项目专属代币
 * @dev ERC-20标准代币，用于去中心化众筹平台
 */
contract MYBToken is ERC20, Ownable {
    // 代币精度
    uint8 private constant _DECIMALS = 18;
    // 代币总量：100,000 MYB
    uint256 private constant _INITIAL_SUPPLY = 100_000 * (10 ** uint256(_DECIMALS));
    
    // 兑换比例：1 ETH = 100 MYB
    uint256 public exchangeRate = 100;
    
    /**
     * @dev 构造函数
     */
    constructor() ERC20("CrowdFund Token", "MYB") {
        // 铸造初始供应量给合约部署者
        _mint(msg.sender, _INITIAL_SUPPLY);
    }
    
    /**
     * @dev 获取代币精度
     */
    function decimals() public pure override returns (uint8) {
        return _DECIMALS;
    }
    
    /**
     * @dev 调整ETH兑换MYB的比例（仅所有者可调用）
     * @param newRate 新的兑换比例
     */
    function setExchangeRate(uint256 newRate) external onlyOwner {
        require(newRate > 0, "Exchange rate must be greater than 0");
        exchangeRate = newRate;
    }
    
    /**
     * @dev 铸造额外代币（仅所有者可调用）
     * @param to 接收地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    /**
     * @dev 销毁代币（仅所有者可调用）
     * @param amount 销毁数量
     */
    function burn(uint256 amount) external onlyOwner {
        _burn(msg.sender, amount);
    }
}