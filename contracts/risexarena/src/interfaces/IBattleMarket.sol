// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IBattleMarket
/// @notice Interface for the Battle Market (prediction market) contract
interface IBattleMarket {
    /// @notice Order side
    enum Side {
        Bid,
        Ask
    }

    /// @notice Create markets for a battle
    /// @param battleId The battle ID
    /// @param players The players in the battle
    function createMarkets(uint256 battleId, address[] calldata players) external;

    /// @notice Resolve markets for a battle
    /// @param battleId The battle ID
    /// @param finalRankings The final player rankings (best to worst)
    function resolveMarkets(uint256 battleId, address[] calldata finalRankings) external;

    /// @notice Mint YES/NO share pairs for an outcome market
    /// @param outcomeId The market identifier
    /// @param amount Number of share pairs to mint
    function mintShares(bytes32 outcomeId, uint256 amount) external;

    /// @notice Place a limit order
    /// @param outcomeId The market identifier
    /// @param isYes Whether buying YES or NO
    /// @param price Price in basis points (0-10000)
    /// @param size Number of shares
    /// @return orderId The order ID
    function placeOrder(bytes32 outcomeId, bool isYes, uint256 price, uint256 size) external returns (uint256 orderId);

    /// @notice Cancel an order
    /// @param outcomeId The market identifier
    /// @param orderId The order ID
    function cancelOrder(bytes32 outcomeId, uint256 orderId) external;

    /// @notice Redeem winning shares
    /// @param outcomeId The market identifier
    function redeemShares(bytes32 outcomeId) external;

    /// @notice Get the outcome ID for a battle/player/rank combination
    /// @param battleId The battle ID
    /// @param player The player address
    /// @param rank The rank (1-indexed)
    /// @return outcomeId The outcome identifier
    function getOutcomeId(uint256 battleId, address player, uint8 rank) external pure returns (bytes32 outcomeId);

    /// @notice Get share balances for a user in a market
    /// @param outcomeId The market identifier
    /// @param user The user address
    /// @return yesShares The YES share balance
    /// @return noShares The NO share balance
    function getShareBalances(bytes32 outcomeId, address user)
        external
        view
        returns (uint256 yesShares, uint256 noShares);
}
