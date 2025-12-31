// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ICollateralManager} from "../../src/interfaces/ICollateralManager.sol";

/// @title MockCollateralManager
/// @notice A mock CollateralManager for testing
contract MockCollateralManager is ICollateralManager {
    mapping(address => mapping(address => int256)) private _balances;

    /// @notice Set balance for testing
    function setBalance(address account, address token, int256 balance) external {
        _balances[account][token] = balance;
    }

    /// @inheritdoc ICollateralManager
    function getAccountCollateralTokenBalance(address account, address token) external view override returns (int256) {
        return _balances[account][token];
    }
}
