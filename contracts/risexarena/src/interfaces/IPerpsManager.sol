// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IPerpsManager
/// @notice Interface for the RISEx perpetuals manager
interface IPerpsManager {
    /// @notice Position struct representing a trader's position in a market
    struct Position {
        int128 size; // Positive for long, negative for short
        int128 quoteAmount; // Negative for longs (cost basis), positive for shorts
    }

    /// @notice Get a trader's position in a specific market
    /// @param marketId The market ID
    /// @param account The trader's address
    /// @return position The position struct
    function getPosition(uint256 marketId, address account) external view returns (Position memory position);

    /// @notice Get the bitmap of active markets for an account
    /// @param account The trader's address
    /// @return bitmaps Array of bitmaps indicating active markets
    function getActiveMarkets(address account) external view returns (uint256[] memory bitmaps);
}
