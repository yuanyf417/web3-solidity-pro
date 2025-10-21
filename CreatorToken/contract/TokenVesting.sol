// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title TokenVesting - 代币分配和线性释放合约
/// @notice 管理CreatorToken的线性释放和分配计划
/// @dev 支持多种分配计划和不同的释放时间表
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TokenVesting is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // 分配类型
    enum AllocationType {
        TEAM,         // 团队
        INVESTORS,    // 投资者
        COMMUNITY,    // 社区发展
        ECOSYSTEM,    // 生态系统
        TREASURY      // 国库
    }

    // 释放计划结构
    struct VestingSchedule {
        // 受益方地址
        address beneficiary;
        // 分配类型
        AllocationType allocationType;
        // 总分配数量
        uint256 totalAmount;
        // 已释放数量
        uint256 released;
        // 开始时间
        uint256 start;
        // 悬崖时间 (必须达到此时间才能首次领取)
        uint256 cliff;
        // 结束时间 (释放完成)
        uint256 end;
        // 释放比例 (基于1e18)
        uint256 percent;
    }

    // 代币合约
    IERC20 public token;
    // 时间表ID计数器
    uint256 public scheduleCount;
    // 时间表映射
    mapping(uint256 => VestingSchedule) public vestingSchedules;
    // 地址 => 时间表ID列表
    mapping(address => uint256[]) public beneficiarySchedules;
    // 总分配数量
    mapping(AllocationType => uint256) public totalAllocations;

    // 事件
    event ScheduleCreated(uint256 indexed scheduleId, address beneficiary, AllocationType allocationType, uint256 amount);
    event TokensReleased(uint256 indexed scheduleId, address beneficiary, uint256 amount);

    constructor(address _token) {
        require(_token != address(0), "TokenVesting: token address cannot be zero");
        token = IERC20(_token);
    }

    /// @notice 创建新的代币释放计划
    /// @param beneficiary 受益方地址
    /// @param allocationType 分配类型
    /// @param amount 代币数量
    /// @param start 开始时间
    /// @param cliff 悬崖时间
    /// @param end 结束时间
    function createVestingSchedule(
        address beneficiary,
        AllocationType allocationType,
        uint256 amount,
        uint256 start,
        uint256 cliff,
        uint256 end
    ) public onlyOwner {
        require(beneficiary != address(0), "TokenVesting: beneficiary is the zero address");
        require(amount > 0, "TokenVesting: amount is 0");
        require(cliff >= start, "TokenVesting: cliff is before start");
        require(end > cliff, "TokenVesting: end is before cliff");

        scheduleCount += 1;
        VestingSchedule storage schedule = vestingSchedules[scheduleCount];
        schedule.beneficiary = beneficiary;
        schedule.allocationType = allocationType;
        schedule.totalAmount = amount;
        schedule.released = 0;
        schedule.start = start;
        schedule.cliff = cliff;
        schedule.end = end;

        // 将此时间表添加到受益人的列表中
        beneficiarySchedules[beneficiary].push(scheduleCount);
        // 更新总分配
        totalAllocations[allocationType] = totalAllocations[allocationType].add(amount);

        emit ScheduleCreated(scheduleCount, beneficiary, allocationType, amount);
    }

    /// @notice 批量创建代币释放计划
    function createBatchVestingSchedules(
        address[] calldata beneficiaries,
        AllocationType[] calldata allocationTypes,
        uint256[] calldata amounts,
        uint256[] calldata starts,
        uint256[] calldata cliffs,
        uint256[] calldata ends
    ) external onlyOwner {
        require(
            beneficiaries.length == allocationTypes.length &&
            beneficiaries.length == amounts.length &&
            beneficiaries.length == starts.length &&
            beneficiaries.length == cliffs.length &&
            beneficiaries.length == ends.length,
            "TokenVesting: arrays length mismatch"
        );

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            createVestingSchedule(
                beneficiaries[i],
                allocationTypes[i],
                amounts[i],
                starts[i],
                cliffs[i],
                ends[i]
            );
        }
    }

    /// @notice 计算应释放的代币数量
    /// @param scheduleId 时间表ID
    function releasableAmount(uint256 scheduleId) public view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[scheduleId];
        require(schedule.beneficiary != address(0), "TokenVesting: invalid schedule id");

        uint256 currentBalance = _calculateReleaseAmount(schedule);
        uint256 unreleased = currentBalance.sub(schedule.released);

        return unreleased;
    }

    /// @notice 释放代币给受益方
    /// @param scheduleId 时间表ID
    function release(uint256 scheduleId) external {
        VestingSchedule storage schedule = vestingSchedules[scheduleId];
        require(msg.sender == schedule.beneficiary || msg.sender == owner(), "TokenVesting: not authorized");
        require(schedule.beneficiary != address(0), "TokenVesting: invalid schedule id");

        uint256 amount = releasableAmount(scheduleId);
        require(amount > 0, "TokenVesting: no tokens are due");

        schedule.released = schedule.released.add(amount);
        token.safeTransfer(schedule.beneficiary, amount);

        emit TokensReleased(scheduleId, schedule.beneficiary, amount);
    }

    /// @notice 为受益方释放所有可释放的代币
    function releaseAll(address beneficiary) external {
        require(msg.sender == beneficiary || msg.sender == owner(), "TokenVesting: not authorized");
        uint256[] storage schedules = beneficiarySchedules[beneficiary];

        for (uint256 i = 0; i < schedules.length; i++) {
            uint256 amount = releasableAmount(schedules[i]);
            if (amount > 0) {
                VestingSchedule storage schedule = vestingSchedules[schedules[i]];
                schedule.released = schedule.released.add(amount);
                token.safeTransfer(schedule.beneficiary, amount);
                emit TokensReleased(schedules[i], schedule.beneficiary, amount);
            }
        }
    }

    /// @notice 获取地址的所有时间表ID
    function getBeneficiarySchedules(address beneficiary) external view returns (uint256[] memory) {
        return beneficiarySchedules[beneficiary];
    }

    /// @dev 计算根据时间表应释放的代币数量
    function _calculateReleaseAmount(VestingSchedule storage schedule) internal view returns (uint256) {
        uint256 currentTime = block.timestamp;

        // 如果当前时间在悬崖之前，没有代币可释放
        if (currentTime < schedule.cliff) {
            return 0;
        }
        // 如果当前时间在结束时间之后，所有代币都可释放
        else if (currentTime >= schedule.end) {
            return schedule.totalAmount;
        }
        // 否则，按比例释放
        else {
            return schedule.totalAmount.mul(currentTime.sub(schedule.start)).div(schedule.end.sub(schedule.start));
        }
    }
}