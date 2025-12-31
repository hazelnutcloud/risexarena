// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IBattleRewardVault} from "./interfaces/IBattleRewardVault.sol";
import {IBattleManager} from "./interfaces/IBattleManager.sol";

/// @title BattleRewardVault
/// @notice Manages prize pools funded by prediction market fees and distributes rewards to traders
contract BattleRewardVault is IBattleRewardVault, Ownable {
    // ═══════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ═══════════════════════════════════════════════════════════════════════════

    error ZeroAddress();
    error AlreadyDistributed();
    error InvalidDistribution();
    error NotBattleManager();
    error NotBattleMarket();
    error NotBattleInitiator();
    error BattleNotOpen();

    // ═══════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════════════════

    event PoolFunded(uint256 indexed battleId, uint256 amount, uint256 newTotal);
    event DistributionSet(uint256 indexed battleId, uint256[] distribution);
    event RewardDistributed(uint256 indexed battleId, address indexed player, uint8 rank, uint256 amount);
    event PrizePoolDistributed(uint256 indexed battleId, uint256 totalAmount);
    event BattleManagerSet(address indexed battleManager);
    event BattleMarketSet(address indexed battleMarket);

    // ═══════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ═══════════════════════════════════════════════════════════════════════════

    struct PrizePool {
        uint256 totalAmount;
        uint256[] distribution; // Percentage per rank (scaled by 1e4)
        bool distributed;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice USDC token address
    address public immutable usdc;

    /// @notice Battle manager contract
    IBattleManager public battleManager;

    /// @notice Battle market contract
    address public battleMarket;

    /// @notice Prize pools per battle
    mapping(uint256 => PrizePool) public prizePools;

    /// @notice Default distributions by player count
    /// @dev 2 players: [7000, 3000] = 70%/30%
    /// @dev 3 players: [5000, 3000, 2000] = 50%/30%/20%
    /// @dev 4 players: [4000, 3000, 2000, 1000] = 40%/30%/20%/10%
    mapping(uint8 => uint256[]) public defaultDistributions;

    // ═══════════════════════════════════════════════════════════════════════════
    // MODIFIERS
    // ═══════════════════════════════════════════════════════════════════════════

    modifier onlyBattleManager() {
        if (msg.sender != address(battleManager)) revert NotBattleManager();
        _;
    }

    modifier onlyBattleMarket() {
        if (msg.sender != battleMarket) revert NotBattleMarket();
        _;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════════════

    constructor(address usdc_) {
        if (usdc_ == address(0)) revert ZeroAddress();
        usdc = usdc_;
        _initializeOwner(msg.sender);

        // Set default distributions
        uint256[] memory dist2 = new uint256[](2);
        dist2[0] = 7000;
        dist2[1] = 3000;
        defaultDistributions[2] = dist2;

        uint256[] memory dist3 = new uint256[](3);
        dist3[0] = 5000;
        dist3[1] = 3000;
        dist3[2] = 2000;
        defaultDistributions[3] = dist3;

        uint256[] memory dist4 = new uint256[](4);
        dist4[0] = 4000;
        dist4[1] = 3000;
        dist4[2] = 2000;
        dist4[3] = 1000;
        defaultDistributions[4] = dist4;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Set the battle manager contract
    /// @param battleManager_ The battle manager address
    function setBattleManager(address battleManager_) external onlyOwner {
        if (battleManager_ == address(0)) revert ZeroAddress();
        battleManager = IBattleManager(battleManager_);
        emit BattleManagerSet(battleManager_);
    }

    /// @notice Set the battle market contract
    /// @param battleMarket_ The battle market address
    function setBattleMarket(address battleMarket_) external onlyOwner {
        if (battleMarket_ == address(0)) revert ZeroAddress();
        battleMarket = battleMarket_;
        emit BattleMarketSet(battleMarket_);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // EXTERNAL FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IBattleRewardVault
    function addToPool(uint256 battleId, uint256 amount) external onlyBattleMarket {
        PrizePool storage pool = prizePools[battleId];
        pool.totalAmount += amount;
        emit PoolFunded(battleId, amount, pool.totalAmount);
    }

    /// @inheritdoc IBattleRewardVault
    function setDistribution(uint256 battleId, uint256[] calldata distribution) external {
        // Only battle initiator can set custom distribution before battle starts
        if (battleManager.getBattleInitiator(battleId) != msg.sender) {
            revert NotBattleInitiator();
        }
        if (battleManager.getBattleStatus(battleId) != IBattleManager.BattleStatus.Open) {
            revert BattleNotOpen();
        }

        // Validate distribution sums to 10000 (100%)
        uint256 total;
        for (uint256 i = 0; i < distribution.length; i++) {
            total += distribution[i];
        }
        if (total != 10000) revert InvalidDistribution();

        prizePools[battleId].distribution = distribution;
        emit DistributionSet(battleId, distribution);
    }

    /// @inheritdoc IBattleRewardVault
    function distributeRewards(uint256 battleId, address[] calldata rankings) external onlyBattleManager {
        PrizePool storage pool = prizePools[battleId];
        if (pool.distributed) revert AlreadyDistributed();

        uint256[] memory distribution =
            pool.distribution.length > 0 ? pool.distribution : defaultDistributions[uint8(rankings.length)];

        for (uint256 i = 0; i < rankings.length; i++) {
            uint256 reward = (pool.totalAmount * distribution[i]) / 10000;
            if (reward > 0) {
                SafeTransferLib.safeTransfer(usdc, rankings[i], reward);
                // Rank is safe to cast as rankings.length <= 4 (MAX_PLAYERS)
                // forge-lint: disable-next-line(unsafe-typecast)
                emit RewardDistributed(battleId, rankings[i], uint8(i + 1), reward);
            }
        }

        pool.distributed = true;
        emit PrizePoolDistributed(battleId, pool.totalAmount);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IBattleRewardVault
    function getPrizePool(uint256 battleId) external view returns (uint256) {
        return prizePools[battleId].totalAmount;
    }

    /// @inheritdoc IBattleRewardVault
    function getExpectedRewards(uint256 battleId) external view returns (uint256[] memory rewards) {
        PrizePool storage pool = prizePools[battleId];

        // Determine player count from battle
        address[] memory players = battleManager.getBattlePlayers(battleId);
        uint8 playerCount = uint8(players.length);

        uint256[] memory distribution =
            pool.distribution.length > 0 ? pool.distribution : defaultDistributions[playerCount];

        rewards = new uint256[](distribution.length);
        for (uint256 i = 0; i < distribution.length; i++) {
            rewards[i] = (pool.totalAmount * distribution[i]) / 10000;
        }
    }

    /// @notice Get distribution for a battle
    /// @param battleId The battle ID
    /// @return distribution The distribution array
    function getDistribution(uint256 battleId) external view returns (uint256[] memory) {
        PrizePool storage pool = prizePools[battleId];
        if (pool.distribution.length > 0) {
            return pool.distribution;
        }

        // Return default distribution for player count
        address[] memory players = battleManager.getBattlePlayers(battleId);
        return defaultDistributions[uint8(players.length)];
    }

    /// @notice Check if rewards have been distributed for a battle
    /// @param battleId The battle ID
    /// @return distributed Whether rewards have been distributed
    function isDistributed(uint256 battleId) external view returns (bool) {
        return prizePools[battleId].distributed;
    }
}
