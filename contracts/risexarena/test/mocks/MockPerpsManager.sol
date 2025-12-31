// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPerpsManager} from "../../src/interfaces/IPerpsManager.sol";

/// @title MockPerpsManager
/// @notice A mock PerpsManager for testing
contract MockPerpsManager is IPerpsManager {
    mapping(uint256 => mapping(address => Position)) private _positions;
    mapping(address => uint256[]) private _activeMarketBitmaps;

    /// @notice Set a position for testing
    function setPosition(uint256 marketId, address account, int128 size, int128 quoteAmount) external {
        _positions[marketId][account] = Position({size: size, quoteAmount: quoteAmount});

        // Update active markets bitmap
        uint256 bucketIndex = marketId >> 8;
        uint256 bitIndex = marketId & 0xff;

        // Ensure array is large enough
        while (_activeMarketBitmaps[account].length <= bucketIndex) {
            _activeMarketBitmaps[account].push(0);
        }

        // Set the bit
        _activeMarketBitmaps[account][bucketIndex] |= (1 << bitIndex);
    }

    /// @notice Clear active markets for an account
    function clearActiveMarkets(address account) external {
        delete _activeMarketBitmaps[account];
    }

    /// @inheritdoc IPerpsManager
    function getPosition(uint256 marketId, address account) external view override returns (Position memory) {
        return _positions[marketId][account];
    }

    /// @inheritdoc IPerpsManager
    function getActiveMarkets(address account) external view override returns (uint256[] memory) {
        return _activeMarketBitmaps[account];
    }
}
