// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IBattleManager
/// @notice Interface for the Battle Manager contract
interface IBattleManager {
    /// @notice Win condition types for battles
    enum WinCondition {
        TimeBased, // Highest PnL at end of duration wins
        PnLTarget // First to reach PnL target wins
    }

    /// @notice Battle status states
    enum BattleStatus {
        Open, // Accepting join requests
        Active, // Battle in progress
        Settled, // Battle completed, rewards distributed
        Cancelled // Battle cancelled (not enough players, etc.)
    }

    /// @notice Configuration for a battle
    struct BattleConfig {
        uint8 maxPlayers; // Maximum players (2-4)
        WinCondition winCondition; // TimeBased or PnLTarget
        uint256 duration; // Battle duration (for TimeBased)
        int256 pnlTarget; // Target PnL percentage (for PnLTarget), scaled by 1e18
        uint256 minEquity; // Minimum equity required to join
        uint256[] allowedMarkets; // RISEx market IDs allowed for trading
    }

    /// @notice Create a new battle
    /// @param config The battle configuration
    /// @return battleId The ID of the created battle
    function createBattle(BattleConfig calldata config) external returns (uint256 battleId);

    /// @notice Request to join an open battle
    /// @param battleId The battle to join
    function requestJoin(uint256 battleId) external;

    /// @notice Approve a join request (initiator only)
    /// @param battleId The battle ID
    /// @param player The player to approve
    function approveJoinRequest(uint256 battleId, address player) external;

    /// @notice Start a battle (initiator only)
    /// @param battleId The battle to start
    function startBattle(uint256 battleId) external;

    /// @notice Claim a PnL target win
    /// @param battleId The battle ID
    /// @param winner The player who reached the target
    function claimPnLTargetWin(uint256 battleId, address winner) external;

    /// @notice Settle a time-based battle
    /// @param battleId The battle to settle
    function settleBattle(uint256 battleId) external;

    /// @notice Get a player's current PnL in a battle
    /// @param battleId The battle ID
    /// @param player The player address
    /// @return pnlPercentage The PnL percentage (scaled by 1e18)
    function getPlayerPnL(uint256 battleId, address player) external view returns (int256 pnlPercentage);

    /// @notice Get current rankings for a battle
    /// @param battleId The battle ID
    /// @return rankings Ordered array of player addresses (best to worst)
    function getCurrentRankings(uint256 battleId) external view returns (address[] memory rankings);

    /// @notice Get battle players
    /// @param battleId The battle ID
    /// @return players Array of player addresses
    function getBattlePlayers(uint256 battleId) external view returns (address[] memory players);

    /// @notice Get battle initiator
    /// @param battleId The battle ID
    /// @return initiator The initiator address
    function getBattleInitiator(uint256 battleId) external view returns (address initiator);

    /// @notice Get battle status
    /// @param battleId The battle ID
    /// @return status The battle status
    function getBattleStatus(uint256 battleId) external view returns (BattleStatus status);
}
