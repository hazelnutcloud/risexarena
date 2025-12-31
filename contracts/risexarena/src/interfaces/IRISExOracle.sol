// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IRISExOracle
/// @notice Interface for the RISEx price oracle
interface IRISExOracle {
    /// @notice Get the mark price for a market
    /// @param marketId The market ID
    /// @return markPrice The current mark price (18 decimals)
    function getMarkPrice(uint256 marketId) external view returns (uint256 markPrice);

    /// @notice Get the index price for a market
    /// @param marketId The market ID
    /// @return indexPrice The current index price (18 decimals)
    function getIndexPrice(uint256 marketId) external view returns (uint256 indexPrice);
}
