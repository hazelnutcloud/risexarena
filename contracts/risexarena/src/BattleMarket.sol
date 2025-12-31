// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {LibBitmap} from "solady/utils/LibBitmap.sol";
import {IBattleMarket} from "./interfaces/IBattleMarket.sol";
import {IBattleRewardVault} from "./interfaces/IBattleRewardVault.sol";

/// @title BattleMarket
/// @notice Implements Polymarket-style YES/NO prediction markets for battle outcomes
/// @dev Uses a CLOB orderbook with unified ticks for efficient order matching
contract BattleMarket is IBattleMarket, Ownable {
    using LibBitmap for LibBitmap.Bitmap;

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Basis points denominator (10000 = 100%)
    uint256 public constant BPS = 10000;

    /// @notice Share price in USDC (1 USDC = 1e6)
    uint256 public constant SHARE_PRICE = 1e6;

    /// @notice Not found sentinel value
    uint256 internal constant NOT_FOUND = type(uint256).max;

    // ═══════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ═══════════════════════════════════════════════════════════════════════════

    error ZeroAddress();
    error InvalidPrice();
    error PriceTooHigh();
    error InvalidSize();
    error MarketAlreadyResolved();
    error MarketNotResolved();
    error MarketNotActive();
    error InsufficientShares();
    error NotBattleManager();
    error OrderNotFound();
    error NotOrderMaker();
    error MarketsAlreadyCreated();

    // ═══════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════════════════

    event MarketsCreated(uint256 indexed battleId, bytes32[] outcomeIds);
    event SharesMinted(bytes32 indexed outcomeId, address indexed minter, uint256 amount, uint256 fee);
    event OrderPlaced(
        bytes32 indexed outcomeId, uint256 indexed orderId, address maker, bool isYes, uint256 price, uint256 size
    );
    event OrderMatched(bytes32 indexed outcomeId, uint256 makerOrderId, address taker, uint256 size, uint256 price);
    event OrderCancelled(bytes32 indexed outcomeId, uint256 indexed orderId);
    event MarketResolved(bytes32 indexed outcomeId, bool outcome);
    event SharesRedeemed(bytes32 indexed outcomeId, address indexed redeemer, uint256 amount, uint256 payout);

    // ═══════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ═══════════════════════════════════════════════════════════════════════════

    struct OutcomeMarket {
        uint256 battleId;
        address player; // The player this market is about
        uint8 rank; // The rank being predicted (1-4)
        uint256 yesShares; // Total YES shares minted
        uint256 noShares; // Total NO shares minted
        bool resolved;
        bool outcome; // true if player finished at this rank
        bool active;
    }

    struct LimitOrder {
        address maker;
        uint256 price; // Price in BPS
        uint256 size;
        uint256 filled;
        bool isYes; // true = YES order, false = NO order
        bool isBid; // true = buying, false = selling
        bool active;
    }

    struct PriceLevel {
        uint256[] orderIds;
        uint256 totalSize;
        uint256 nextOrderIndex; // For FIFO processing
    }

    struct MarketState {
        OutcomeMarket market;
        // Order storage
        mapping(uint256 => LimitOrder) orders;
        uint256 nextOrderId;
        // Orderbook: price -> price level
        mapping(uint256 => PriceLevel) yesBidLevels;
        mapping(uint256 => PriceLevel) yesAskLevels;
        mapping(uint256 => PriceLevel) noBidLevels;
        mapping(uint256 => PriceLevel) noAskLevels;
        // Bitmaps for active price levels
        LibBitmap.Bitmap yesBidTicks;
        LibBitmap.Bitmap yesAskTicks;
        LibBitmap.Bitmap noBidTicks;
        LibBitmap.Bitmap noAskTicks;
        // Share balances
        mapping(address => uint256) yesBalances;
        mapping(address => uint256) noBalances;
    }

    /// @dev Helper struct to reduce stack depth in market buy
    struct BuyContext {
        bytes32 outcomeId;
        bool isYes;
        uint256 maxSize;
        uint256 maxPrice;
        uint256 remaining;
        uint256 totalCost;
        uint256 filled;
    }

    /// @dev Helper struct to reduce stack depth in market sell
    struct SellContext {
        bytes32 outcomeId;
        bool isYes;
        uint256 size;
        uint256 minPrice;
        uint256 remaining;
        uint256 totalProceeds;
        uint256 filled;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice USDC token address
    address public immutable usdc;

    /// @notice Mint fee in basis points
    uint256 public mintFeeBps;

    /// @notice Reward vault for fees
    IBattleRewardVault public rewardVault;

    /// @notice Battle manager contract
    address public battleManager;

    /// @notice Market state per outcome ID
    mapping(bytes32 => MarketState) internal _markets;

    /// @notice Track if markets are created for a battle
    mapping(uint256 => bool) public marketsCreated;

    // ═══════════════════════════════════════════════════════════════════════════
    // MODIFIERS
    // ═══════════════════════════════════════════════════════════════════════════

    modifier onlyBattleManager() {
        if (msg.sender != battleManager) revert NotBattleManager();
        _;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════════════

    constructor(address usdc_, address rewardVault_, uint256 mintFeeBps_) {
        if (usdc_ == address(0) || rewardVault_ == address(0)) revert ZeroAddress();
        usdc = usdc_;
        rewardVault = IBattleRewardVault(rewardVault_);
        mintFeeBps = mintFeeBps_;
        _initializeOwner(msg.sender);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Set the battle manager
    /// @param battleManager_ The battle manager address
    function setBattleManager(address battleManager_) external onlyOwner {
        if (battleManager_ == address(0)) revert ZeroAddress();
        battleManager = battleManager_;
    }

    /// @notice Set the mint fee
    /// @param mintFeeBps_ The mint fee in basis points
    function setMintFee(uint256 mintFeeBps_) external onlyOwner {
        mintFeeBps = mintFeeBps_;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MARKET CREATION & RESOLUTION
    // ═══════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IBattleMarket
    function createMarkets(uint256 battleId, address[] calldata players) external onlyBattleManager {
        if (marketsCreated[battleId]) revert MarketsAlreadyCreated();

        uint256 numPlayers = players.length;
        bytes32[] memory outcomeIds = new bytes32[](numPlayers * numPlayers);
        uint256 idx = 0;

        // Create N * N markets (N players x N ranks)
        for (uint8 rank = 1; rank <= numPlayers; rank++) {
            for (uint256 i = 0; i < numPlayers; i++) {
                bytes32 outcomeId = getOutcomeId(battleId, players[i], rank);
                outcomeIds[idx++] = outcomeId;

                MarketState storage state = _markets[outcomeId];
                state.market = OutcomeMarket({
                    battleId: battleId,
                    player: players[i],
                    rank: rank,
                    yesShares: 0,
                    noShares: 0,
                    resolved: false,
                    outcome: false,
                    active: true
                });
            }
        }

        marketsCreated[battleId] = true;
        emit MarketsCreated(battleId, outcomeIds);
    }

    /// @inheritdoc IBattleMarket
    function resolveMarkets(uint256 battleId, address[] calldata finalRankings) external onlyBattleManager {
        uint256 numPlayers = finalRankings.length;

        for (uint8 rank = 1; rank <= numPlayers; rank++) {
            for (uint256 i = 0; i < numPlayers; i++) {
                address player = finalRankings[i];
                bytes32 outcomeId = getOutcomeId(battleId, player, rank);
                MarketState storage state = _markets[outcomeId];

                // finalRankings[0] is 1st place, finalRankings[1] is 2nd place, etc.
                bool playerWon = (i == rank - 1);

                state.market.resolved = true;
                state.market.outcome = playerWon;

                emit MarketResolved(outcomeId, playerWon);
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // SHARE MINTING
    // ═══════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IBattleMarket
    function mintShares(bytes32 outcomeId, uint256 amount) external {
        if (amount == 0) revert InvalidSize();

        MarketState storage state = _markets[outcomeId];
        if (!state.market.active) revert MarketNotActive();
        if (state.market.resolved) revert MarketAlreadyResolved();

        uint256 cost = amount * SHARE_PRICE;
        uint256 fee = (cost * mintFeeBps) / BPS;

        // Transfer cost + fee from user
        SafeTransferLib.safeTransferFrom(usdc, msg.sender, address(this), cost + fee);

        // Send fee to reward vault for trader prize pool
        if (fee > 0) {
            SafeTransferLib.safeTransfer(usdc, address(rewardVault), fee);
            rewardVault.addToPool(state.market.battleId, fee);
        }

        // Mint share pairs
        state.market.yesShares += amount;
        state.market.noShares += amount;
        state.yesBalances[msg.sender] += amount;
        state.noBalances[msg.sender] += amount;

        emit SharesMinted(outcomeId, msg.sender, amount, fee);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ORDER PLACEMENT
    // ═══════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IBattleMarket
    function placeOrder(bytes32 outcomeId, bool isYes, uint256 price, uint256 size) external returns (uint256 orderId) {
        if (price == 0) revert InvalidPrice();
        if (price >= BPS) revert PriceTooHigh();
        if (size == 0) revert InvalidSize();

        MarketState storage state = _markets[outcomeId];
        if (!state.market.active) revert MarketNotActive();
        if (state.market.resolved) revert MarketAlreadyResolved();

        uint256 collateralRequired = (size * price * SHARE_PRICE) / BPS;
        SafeTransferLib.safeTransferFrom(usdc, msg.sender, address(this), collateralRequired);

        orderId = state.nextOrderId++;
        state.orders[orderId] = LimitOrder({
            maker: msg.sender, price: price, size: size, filled: 0, isYes: isYes, isBid: true, active: true
        });

        _addToBidBook(state, isYes, price, orderId, size);
        emit OrderPlaced(outcomeId, orderId, msg.sender, isYes, price, size);
    }

    /// @notice Place a sell order (selling existing shares)
    function placeSellOrder(bytes32 outcomeId, bool isYes, uint256 price, uint256 size)
        external
        returns (uint256 orderId)
    {
        if (price == 0) revert InvalidPrice();
        if (price >= BPS) revert PriceTooHigh();
        if (size == 0) revert InvalidSize();

        MarketState storage state = _markets[outcomeId];
        if (!state.market.active) revert MarketNotActive();
        if (state.market.resolved) revert MarketAlreadyResolved();

        // Deduct shares from seller
        if (isYes) {
            if (state.yesBalances[msg.sender] < size) revert InsufficientShares();
            state.yesBalances[msg.sender] -= size;
        } else {
            if (state.noBalances[msg.sender] < size) revert InsufficientShares();
            state.noBalances[msg.sender] -= size;
        }

        orderId = state.nextOrderId++;
        state.orders[orderId] = LimitOrder({
            maker: msg.sender, price: price, size: size, filled: 0, isYes: isYes, isBid: false, active: true
        });

        _addToAskBook(state, isYes, price, orderId, size);
        emit OrderPlaced(outcomeId, orderId, msg.sender, isYes, price, size);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ORDER CANCELLATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IBattleMarket
    function cancelOrder(bytes32 outcomeId, uint256 orderId) external {
        MarketState storage state = _markets[outcomeId];
        LimitOrder storage order = state.orders[orderId];

        if (!order.active) revert OrderNotFound();
        if (order.maker != msg.sender) revert NotOrderMaker();

        uint256 remainingSize = order.size - order.filled;
        order.active = false;

        if (order.isBid) {
            uint256 refund = (remainingSize * order.price * SHARE_PRICE) / BPS;
            SafeTransferLib.safeTransfer(usdc, order.maker, refund);
        } else {
            if (order.isYes) {
                state.yesBalances[msg.sender] += remainingSize;
            } else {
                state.noBalances[msg.sender] += remainingSize;
            }
        }

        emit OrderCancelled(outcomeId, orderId);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MARKET ORDERS
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Execute a market buy order
    function marketBuy(bytes32 outcomeId, bool isYes, uint256 maxSize, uint256 maxPrice)
        external
        returns (uint256 filled)
    {
        if (maxSize == 0) revert InvalidSize();
        if (maxPrice == 0 || maxPrice >= BPS) revert InvalidPrice();

        MarketState storage state = _markets[outcomeId];
        if (!state.market.active) revert MarketNotActive();
        if (state.market.resolved) revert MarketAlreadyResolved();

        BuyContext memory ctx = BuyContext({
            outcomeId: outcomeId,
            isYes: isYes,
            maxSize: maxSize,
            maxPrice: maxPrice,
            remaining: maxSize,
            totalCost: 0,
            filled: 0
        });

        _executeMarketBuy(state, ctx);
        filled = ctx.filled;

        if (ctx.totalCost > 0) {
            SafeTransferLib.safeTransferFrom(usdc, msg.sender, address(this), ctx.totalCost);
        }

        if (isYes) {
            state.yesBalances[msg.sender] += filled;
        } else {
            state.noBalances[msg.sender] += filled;
        }
    }

    /// @notice Execute a market sell order
    function marketSell(bytes32 outcomeId, bool isYes, uint256 size, uint256 minPrice)
        external
        returns (uint256 filled)
    {
        if (size == 0) revert InvalidSize();

        MarketState storage state = _markets[outcomeId];
        if (!state.market.active) revert MarketNotActive();
        if (state.market.resolved) revert MarketAlreadyResolved();

        uint256 userBalance = isYes ? state.yesBalances[msg.sender] : state.noBalances[msg.sender];
        if (userBalance < size) revert InsufficientShares();

        SellContext memory ctx = SellContext({
            outcomeId: outcomeId,
            isYes: isYes,
            size: size,
            minPrice: minPrice,
            remaining: size,
            totalProceeds: 0,
            filled: 0
        });

        _executeMarketSell(state, ctx);
        filled = ctx.filled;

        if (isYes) {
            state.yesBalances[msg.sender] -= filled;
        } else {
            state.noBalances[msg.sender] -= filled;
        }

        if (ctx.totalProceeds > 0) {
            SafeTransferLib.safeTransfer(usdc, msg.sender, ctx.totalProceeds);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // REDEMPTION
    // ═══════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IBattleMarket
    function redeemShares(bytes32 outcomeId) external {
        MarketState storage state = _markets[outcomeId];
        if (!state.market.active) revert MarketNotActive();
        if (!state.market.resolved) revert MarketNotResolved();

        uint256 shares;
        if (state.market.outcome) {
            shares = state.yesBalances[msg.sender];
            state.yesBalances[msg.sender] = 0;
        } else {
            shares = state.noBalances[msg.sender];
            state.noBalances[msg.sender] = 0;
        }

        if (shares == 0) revert InsufficientShares();

        uint256 payout = shares * SHARE_PRICE;
        SafeTransferLib.safeTransfer(usdc, msg.sender, payout);

        emit SharesRedeemed(outcomeId, msg.sender, shares, payout);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IBattleMarket
    function getOutcomeId(uint256 battleId, address player, uint8 rank) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(battleId, player, rank));
    }

    /// @inheritdoc IBattleMarket
    function getShareBalances(bytes32 outcomeId, address user)
        external
        view
        returns (uint256 yesShares, uint256 noShares)
    {
        MarketState storage state = _markets[outcomeId];
        yesShares = state.yesBalances[user];
        noShares = state.noBalances[user];
    }

    /// @notice Get market info
    function getMarket(bytes32 outcomeId) external view returns (OutcomeMarket memory) {
        return _markets[outcomeId].market;
    }

    /// @notice Get order info
    function getOrder(bytes32 outcomeId, uint256 orderId) external view returns (LimitOrder memory) {
        return _markets[outcomeId].orders[orderId];
    }

    /// @notice Get best bid price for an outcome
    function getBestBid(bytes32 outcomeId, bool isYes) external view returns (uint256 price) {
        MarketState storage state = _markets[outcomeId];
        LibBitmap.Bitmap storage ticks = isYes ? state.yesBidTicks : state.noBidTicks;
        price = ticks.findLastSet(BPS);
        if (price == NOT_FOUND) price = 0;
    }

    /// @notice Get best ask price for an outcome
    function getBestAsk(bytes32 outcomeId, bool isYes) external view returns (uint256 price) {
        MarketState storage state = _markets[outcomeId];
        LibBitmap.Bitmap storage ticks = isYes ? state.yesAskTicks : state.noAskTicks;
        uint256 invertedPrice = ticks.findLastSet(BPS);
        if (invertedPrice == NOT_FOUND) {
            price = BPS;
        } else {
            price = BPS - invertedPrice;
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    function _addToBidBook(MarketState storage state, bool isYes, uint256 price, uint256 orderId, uint256 size)
        internal
    {
        PriceLevel storage level;
        LibBitmap.Bitmap storage ticks;

        if (isYes) {
            level = state.yesBidLevels[price];
            ticks = state.yesBidTicks;
        } else {
            level = state.noBidLevels[price];
            ticks = state.noBidTicks;
        }

        level.orderIds.push(orderId);
        level.totalSize += size;
        ticks.set(price);
    }

    function _addToAskBook(MarketState storage state, bool isYes, uint256 price, uint256 orderId, uint256 size)
        internal
    {
        uint256 invertedPrice = BPS - price;
        PriceLevel storage level;
        LibBitmap.Bitmap storage ticks;

        if (isYes) {
            level = state.yesAskLevels[invertedPrice];
            ticks = state.yesAskTicks;
        } else {
            level = state.noAskLevels[invertedPrice];
            ticks = state.noAskTicks;
        }

        level.orderIds.push(orderId);
        level.totalSize += size;
        ticks.set(invertedPrice);
    }

    function _executeMarketBuy(MarketState storage state, BuyContext memory ctx) internal {
        LibBitmap.Bitmap storage askTicks = ctx.isYes ? state.yesAskTicks : state.noAskTicks;
        uint256 invertedPrice = askTicks.findLastSet(BPS);

        while (invertedPrice != NOT_FOUND && ctx.remaining > 0) {
            uint256 actualPrice = BPS - invertedPrice;
            if (actualPrice > ctx.maxPrice) break;

            PriceLevel storage level = ctx.isYes ? state.yesAskLevels[invertedPrice] : state.noAskLevels[invertedPrice];

            _fillOrdersAtLevel(state, level, ctx, actualPrice, true);

            if (level.nextOrderIndex >= level.orderIds.length) {
                askTicks.unset(invertedPrice);
            }

            if (invertedPrice > 0) {
                invertedPrice = askTicks.findLastSet(invertedPrice - 1);
            } else {
                break;
            }
        }
    }

    function _executeMarketSell(MarketState storage state, SellContext memory ctx) internal {
        LibBitmap.Bitmap storage bidTicks = ctx.isYes ? state.yesBidTicks : state.noBidTicks;
        uint256 price = bidTicks.findLastSet(BPS);

        while (price != NOT_FOUND && ctx.remaining > 0 && price >= ctx.minPrice) {
            PriceLevel storage level = ctx.isYes ? state.yesBidLevels[price] : state.noBidLevels[price];

            _fillSellOrdersAtLevel(state, level, ctx, price);

            if (level.nextOrderIndex >= level.orderIds.length) {
                bidTicks.unset(price);
            }

            if (price > 0) {
                price = bidTicks.findLastSet(price - 1);
            } else {
                break;
            }
        }
    }

    function _fillOrdersAtLevel(
        MarketState storage state,
        PriceLevel storage level,
        BuyContext memory ctx,
        uint256 price,
        bool /* isBuy */
    ) internal {
        while (level.nextOrderIndex < level.orderIds.length && ctx.remaining > 0) {
            uint256 orderId = level.orderIds[level.nextOrderIndex];
            LimitOrder storage order = state.orders[orderId];

            if (!order.active) {
                level.nextOrderIndex++;
                continue;
            }

            uint256 available = order.size - order.filled;
            uint256 fillAmount = ctx.remaining < available ? ctx.remaining : available;

            order.filled += fillAmount;
            ctx.remaining -= fillAmount;
            ctx.filled += fillAmount;

            uint256 cost = (fillAmount * price * SHARE_PRICE) / BPS;
            ctx.totalCost += cost;

            SafeTransferLib.safeTransfer(usdc, order.maker, cost);
            emit OrderMatched(ctx.outcomeId, orderId, msg.sender, fillAmount, price);

            if (order.filled == order.size) {
                order.active = false;
                level.nextOrderIndex++;
            }
        }
    }

    function _fillSellOrdersAtLevel(
        MarketState storage state,
        PriceLevel storage level,
        SellContext memory ctx,
        uint256 price
    ) internal {
        while (level.nextOrderIndex < level.orderIds.length && ctx.remaining > 0) {
            uint256 orderId = level.orderIds[level.nextOrderIndex];
            LimitOrder storage order = state.orders[orderId];

            if (!order.active) {
                level.nextOrderIndex++;
                continue;
            }

            uint256 available = order.size - order.filled;
            uint256 fillAmount = ctx.remaining < available ? ctx.remaining : available;

            order.filled += fillAmount;
            ctx.remaining -= fillAmount;
            ctx.filled += fillAmount;

            uint256 proceeds = (fillAmount * price * SHARE_PRICE) / BPS;
            ctx.totalProceeds += proceeds;

            // Credit shares to buyer
            if (ctx.isYes) {
                state.yesBalances[order.maker] += fillAmount;
            } else {
                state.noBalances[order.maker] += fillAmount;
            }

            emit OrderMatched(ctx.outcomeId, orderId, msg.sender, fillAmount, price);

            if (order.filled == order.size) {
                order.active = false;
                level.nextOrderIndex++;
            }
        }
    }
}
