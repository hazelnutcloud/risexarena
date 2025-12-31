// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title ICollateralManager
/// @notice Interface for RISEx collateral management
interface ICollateralManager {
    /// @notice Get the collateral token balance for an account
    /// @param account The account address
    /// @param token The token address
    /// @return balance The signed balance (can be negative due to borrowing)
    function getAccountCollateralTokenBalance(address account, address token) external view returns (int256 balance);
}
