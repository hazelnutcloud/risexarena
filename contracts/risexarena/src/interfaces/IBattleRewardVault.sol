// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IBattleRewardVault
/// @notice Interface for the Battle Reward Vault contract
interface IBattleRewardVault {
    /// @notice Add funds to a battle's prize pool
    /// @param battleId The battle ID
    /// @param amount The amount to add
    function addToPool(uint256 battleId, uint256 amount) external;

    /// @notice Set custom distribution for a battle
    /// @param battleId The battle ID
    /// @param distribution The distribution percentages (scaled by 1e4)
    function setDistribution(uint256 battleId, uint256[] calldata distribution) external;

    /// @notice Distribute rewards to winners
    /// @param battleId The battle ID
    /// @param rankings The final player rankings (best to worst)
    function distributeRewards(uint256 battleId, address[] calldata rankings) external;

    /// @notice Get the prize pool for a battle
    /// @param battleId The battle ID
    /// @return amount The total prize pool amount
    function getPrizePool(uint256 battleId) external view returns (uint256 amount);

    /// @notice Get expected rewards per rank for a battle
    /// @param battleId The battle ID
    /// @return rewards Array of expected rewards per rank
    function getExpectedRewards(uint256 battleId) external view returns (uint256[] memory rewards);
}
