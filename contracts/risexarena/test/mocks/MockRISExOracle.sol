// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IRISExOracle} from "../../src/interfaces/IRISExOracle.sol";

/// @title MockRISExOracle
/// @notice A mock RISEx Oracle for testing
contract MockRISExOracle is IRISExOracle {
    mapping(uint256 => uint256) private _markPrices;
    mapping(uint256 => uint256) private _indexPrices;

    /// @notice Set mark price for testing
    function setMarkPrice(uint256 marketId, uint256 price) external {
        _markPrices[marketId] = price;
    }

    /// @notice Set index price for testing
    function setIndexPrice(uint256 marketId, uint256 price) external {
        _indexPrices[marketId] = price;
    }

    /// @inheritdoc IRISExOracle
    function getMarkPrice(uint256 marketId) external view override returns (uint256) {
        return _markPrices[marketId];
    }

    /// @inheritdoc IRISExOracle
    function getIndexPrice(uint256 marketId) external view override returns (uint256) {
        return _indexPrices[marketId];
    }
}
