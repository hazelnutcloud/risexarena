// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {BattleMarket} from "../src/BattleMarket.sol";
import {BattleRewardVault} from "../src/BattleRewardVault.sol";
import {IBattleManager} from "../src/interfaces/IBattleManager.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

/// @dev Mock BattleManager for isolated BattleMarket testing
contract MockBattleManager {
    mapping(uint256 => address) public initiators;
    mapping(uint256 => IBattleManager.BattleStatus) public statuses;
    mapping(uint256 => address[]) public players;

    function setBattleInitiator(uint256 battleId, address initiator) external {
        initiators[battleId] = initiator;
    }

    function setBattleStatus(uint256 battleId, IBattleManager.BattleStatus status) external {
        statuses[battleId] = status;
    }

    function setBattlePlayers(uint256 battleId, address[] calldata _players) external {
        players[battleId] = _players;
    }

    function getBattleInitiator(uint256 battleId) external view returns (address) {
        return initiators[battleId];
    }

    function getBattleStatus(uint256 battleId) external view returns (IBattleManager.BattleStatus) {
        return statuses[battleId];
    }

    function getBattlePlayers(uint256 battleId) external view returns (address[] memory) {
        return players[battleId];
    }
}

contract BattleMarketTest is Test {
    BattleMarket public battleMarket;
    BattleRewardVault public rewardVault;
    MockERC20 public usdc;
    MockBattleManager public mockBattleManager;

    address public owner = address(this);
    address public player1 = address(0x1);
    address public player2 = address(0x2);
    address public bettor1 = address(0x10);
    address public bettor2 = address(0x20);

    uint256 public constant INITIAL_BALANCE = 10000e6;
    uint256 public constant MINT_FEE_BPS = 100; // 1%

    function setUp() public {
        usdc = new MockERC20("USD Coin", "USDC", 6);
        rewardVault = new BattleRewardVault(address(usdc));
        battleMarket = new BattleMarket(address(usdc), address(rewardVault), MINT_FEE_BPS);
        mockBattleManager = new MockBattleManager();

        // Configure
        battleMarket.setBattleManager(address(mockBattleManager));
        rewardVault.setBattleManager(address(mockBattleManager));
        rewardVault.setBattleMarket(address(battleMarket));

        // Fund accounts
        _fundAccount(bettor1);
        _fundAccount(bettor2);
    }

    function _fundAccount(address account) internal {
        usdc.mint(account, INITIAL_BALANCE);
        vm.prank(account);
        usdc.approve(address(battleMarket), type(uint256).max);
    }

    function _createMarkets() internal returns (uint256 battleId, bytes32 p1Rank1, bytes32 p2Rank1) {
        battleId = 0;
        address[] memory players = new address[](2);
        players[0] = player1;
        players[1] = player2;

        mockBattleManager.setBattlePlayers(battleId, players);

        vm.prank(address(mockBattleManager));
        battleMarket.createMarkets(battleId, players);

        p1Rank1 = battleMarket.getOutcomeId(battleId, player1, 1);
        p2Rank1 = battleMarket.getOutcomeId(battleId, player2, 1);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MARKET CREATION TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_createMarkets_success() public {
        (uint256 battleId,,) = _createMarkets();

        assertTrue(battleMarket.marketsCreated(battleId));

        // Verify markets were created for all player/rank combinations
        bytes32 p1r1 = battleMarket.getOutcomeId(battleId, player1, 1);
        bytes32 p1r2 = battleMarket.getOutcomeId(battleId, player1, 2);
        bytes32 p2r1 = battleMarket.getOutcomeId(battleId, player2, 1);
        bytes32 p2r2 = battleMarket.getOutcomeId(battleId, player2, 2);

        BattleMarket.OutcomeMarket memory market = battleMarket.getMarket(p1r1);
        assertTrue(market.active);
        assertEq(market.player, player1);
        assertEq(market.rank, 1);
    }

    function test_createMarkets_revertNotBattleManager() public {
        address[] memory players = new address[](2);
        players[0] = player1;
        players[1] = player2;

        vm.expectRevert(BattleMarket.NotBattleManager.selector);
        battleMarket.createMarkets(0, players);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // SHARE MINTING TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_mintShares_success() public {
        (, bytes32 p1Rank1,) = _createMarkets();

        uint256 amount = 100;
        uint256 expectedCost = amount * 1e6; // 100 USDC
        uint256 expectedFee = (expectedCost * MINT_FEE_BPS) / 10000;

        uint256 balanceBefore = usdc.balanceOf(bettor1);

        vm.prank(bettor1);
        battleMarket.mintShares(p1Rank1, amount);

        // Check balances
        (uint256 yesShares, uint256 noShares) = battleMarket.getShareBalances(p1Rank1, bettor1);
        assertEq(yesShares, amount);
        assertEq(noShares, amount);

        // Check cost deducted
        assertEq(usdc.balanceOf(bettor1), balanceBefore - expectedCost - expectedFee);

        // Check fee went to reward vault
        assertEq(rewardVault.getPrizePool(0), expectedFee);
    }

    function test_mintShares_revertMarketNotActive() public {
        bytes32 fakeOutcomeId = keccak256("fake");

        vm.prank(bettor1);
        vm.expectRevert(BattleMarket.MarketNotActive.selector);
        battleMarket.mintShares(fakeOutcomeId, 100);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ORDER PLACEMENT TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_placeOrder_bid() public {
        (, bytes32 p1Rank1,) = _createMarkets();

        uint256 price = 6000; // 60%
        uint256 size = 100;
        uint256 collateral = (size * price * 1e6) / 10000; // 60 USDC

        uint256 balanceBefore = usdc.balanceOf(bettor1);

        vm.prank(bettor1);
        uint256 orderId = battleMarket.placeOrder(p1Rank1, true, price, size);

        assertEq(orderId, 0);
        assertEq(usdc.balanceOf(bettor1), balanceBefore - collateral);

        BattleMarket.LimitOrder memory order = battleMarket.getOrder(p1Rank1, orderId);
        assertEq(order.maker, bettor1);
        assertEq(order.price, price);
        assertEq(order.size, size);
        assertTrue(order.isYes);
        assertTrue(order.isBid);
        assertTrue(order.active);
    }

    function test_placeSellOrder() public {
        (, bytes32 p1Rank1,) = _createMarkets();

        // First mint some shares
        vm.prank(bettor1);
        battleMarket.mintShares(p1Rank1, 100);

        // Place sell order
        uint256 price = 7000; // 70%
        uint256 size = 50;

        vm.prank(bettor1);
        uint256 orderId = battleMarket.placeSellOrder(p1Rank1, true, price, size);

        BattleMarket.LimitOrder memory order = battleMarket.getOrder(p1Rank1, orderId);
        assertEq(order.maker, bettor1);
        assertFalse(order.isBid);

        // Shares should be locked (deducted from balance)
        (uint256 yesShares,) = battleMarket.getShareBalances(p1Rank1, bettor1);
        assertEq(yesShares, 50); // 100 - 50 locked
    }

    function test_placeSellOrder_revertInsufficientShares() public {
        (, bytes32 p1Rank1,) = _createMarkets();

        vm.prank(bettor1);
        vm.expectRevert(BattleMarket.InsufficientShares.selector);
        battleMarket.placeSellOrder(p1Rank1, true, 7000, 100);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ORDER CANCELLATION TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_cancelOrder_bid() public {
        (, bytes32 p1Rank1,) = _createMarkets();

        uint256 price = 6000;
        uint256 size = 100;
        uint256 collateral = (size * price * 1e6) / 10000;

        vm.prank(bettor1);
        uint256 orderId = battleMarket.placeOrder(p1Rank1, true, price, size);

        uint256 balanceBefore = usdc.balanceOf(bettor1);

        vm.prank(bettor1);
        battleMarket.cancelOrder(p1Rank1, orderId);

        // Collateral should be refunded
        assertEq(usdc.balanceOf(bettor1), balanceBefore + collateral);

        // Order should be inactive
        BattleMarket.LimitOrder memory order = battleMarket.getOrder(p1Rank1, orderId);
        assertFalse(order.active);
    }

    function test_cancelOrder_ask() public {
        (, bytes32 p1Rank1,) = _createMarkets();

        vm.prank(bettor1);
        battleMarket.mintShares(p1Rank1, 100);

        vm.prank(bettor1);
        uint256 orderId = battleMarket.placeSellOrder(p1Rank1, true, 7000, 50);

        vm.prank(bettor1);
        battleMarket.cancelOrder(p1Rank1, orderId);

        // Shares should be returned
        (uint256 yesShares,) = battleMarket.getShareBalances(p1Rank1, bettor1);
        assertEq(yesShares, 100);
    }

    function test_cancelOrder_revertNotOrderMaker() public {
        (, bytes32 p1Rank1,) = _createMarkets();

        vm.prank(bettor1);
        uint256 orderId = battleMarket.placeOrder(p1Rank1, true, 6000, 100);

        vm.prank(bettor2);
        vm.expectRevert(BattleMarket.NotOrderMaker.selector);
        battleMarket.cancelOrder(p1Rank1, orderId);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MARKET ORDER TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_marketBuy_matchesAsk() public {
        (, bytes32 p1Rank1,) = _createMarkets();

        // Bettor1 mints and places sell order
        vm.prank(bettor1);
        battleMarket.mintShares(p1Rank1, 100);

        vm.prank(bettor1);
        battleMarket.placeSellOrder(p1Rank1, true, 6000, 50); // Sell YES at 60%

        // Bettor2 market buys
        uint256 balanceBefore = usdc.balanceOf(bettor2);

        vm.prank(bettor2);
        uint256 filled = battleMarket.marketBuy(p1Rank1, true, 50, 7000); // Max price 70%

        assertEq(filled, 50);

        // Check bettor2 received shares
        (uint256 yesShares,) = battleMarket.getShareBalances(p1Rank1, bettor2);
        assertEq(yesShares, 50);

        // Check payment made (at 60% price)
        uint256 expectedCost = (50 * 6000 * 1e6) / 10000; // 30 USDC
        assertEq(usdc.balanceOf(bettor2), balanceBefore - expectedCost);
    }

    function test_marketSell_matchesBid() public {
        (, bytes32 p1Rank1,) = _createMarkets();

        // Bettor1 places bid order
        vm.prank(bettor1);
        battleMarket.placeOrder(p1Rank1, true, 5000, 50); // Buy YES at 50%

        // Bettor2 mints shares and market sells
        vm.prank(bettor2);
        battleMarket.mintShares(p1Rank1, 100);

        uint256 balanceBefore = usdc.balanceOf(bettor2);

        vm.prank(bettor2);
        uint256 filled = battleMarket.marketSell(p1Rank1, true, 50, 4000); // Min price 40%

        assertEq(filled, 50);

        // Check bettor2's shares decreased
        (uint256 yesShares,) = battleMarket.getShareBalances(p1Rank1, bettor2);
        assertEq(yesShares, 50); // 100 - 50 sold

        // Check proceeds received (at 50% price)
        uint256 expectedProceeds = (50 * 5000 * 1e6) / 10000; // 25 USDC
        assertEq(usdc.balanceOf(bettor2), balanceBefore + expectedProceeds);

        // Check bettor1 received shares
        (uint256 bettor1Shares,) = battleMarket.getShareBalances(p1Rank1, bettor1);
        assertEq(bettor1Shares, 50);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // RESOLUTION & REDEMPTION TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_resolveMarkets() public {
        (uint256 battleId, bytes32 p1Rank1, bytes32 p2Rank1) = _createMarkets();

        // Resolve: player1 wins (rank 1), player2 loses (rank 2)
        address[] memory rankings = new address[](2);
        rankings[0] = player1;
        rankings[1] = player2;

        vm.prank(address(mockBattleManager));
        battleMarket.resolveMarkets(battleId, rankings);

        // Check player1 rank 1 market - should be YES outcome
        BattleMarket.OutcomeMarket memory p1r1Market = battleMarket.getMarket(p1Rank1);
        assertTrue(p1r1Market.resolved);
        assertTrue(p1r1Market.outcome); // YES wins

        // Check player2 rank 1 market - should be NO outcome
        BattleMarket.OutcomeMarket memory p2r1Market = battleMarket.getMarket(p2Rank1);
        assertTrue(p2r1Market.resolved);
        assertFalse(p2r1Market.outcome); // NO wins
    }

    function test_redeemShares_winner() public {
        (uint256 battleId, bytes32 p1Rank1,) = _createMarkets();

        // Bettor mints and holds YES shares
        vm.prank(bettor1);
        battleMarket.mintShares(p1Rank1, 100);

        // Sell NO shares (keep YES)
        // For simplicity, just keep both and redeem after resolution

        // Resolve: player1 wins
        address[] memory rankings = new address[](2);
        rankings[0] = player1;
        rankings[1] = player2;

        vm.prank(address(mockBattleManager));
        battleMarket.resolveMarkets(battleId, rankings);

        // Redeem winning YES shares
        uint256 balanceBefore = usdc.balanceOf(bettor1);

        vm.prank(bettor1);
        battleMarket.redeemShares(p1Rank1);

        // Should receive 100 USDC (100 shares * 1 USDC)
        assertEq(usdc.balanceOf(bettor1), balanceBefore + 100e6);

        // Shares should be zero
        (uint256 yesShares,) = battleMarket.getShareBalances(p1Rank1, bettor1);
        assertEq(yesShares, 0);
    }

    function test_redeemShares_revertNotResolved() public {
        (, bytes32 p1Rank1,) = _createMarkets();

        vm.prank(bettor1);
        battleMarket.mintShares(p1Rank1, 100);

        vm.prank(bettor1);
        vm.expectRevert(BattleMarket.MarketNotResolved.selector);
        battleMarket.redeemShares(p1Rank1);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTION TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_getBestBid() public {
        (, bytes32 p1Rank1,) = _createMarkets();

        // No bids yet
        assertEq(battleMarket.getBestBid(p1Rank1, true), 0);

        // Place some bids
        vm.prank(bettor1);
        battleMarket.placeOrder(p1Rank1, true, 5000, 10);

        vm.prank(bettor2);
        battleMarket.placeOrder(p1Rank1, true, 6000, 10);

        // Best bid should be 6000
        assertEq(battleMarket.getBestBid(p1Rank1, true), 6000);
    }

    function test_getBestAsk() public {
        (, bytes32 p1Rank1,) = _createMarkets();

        // No asks yet
        assertEq(battleMarket.getBestAsk(p1Rank1, true), 10000);

        // Mint and place asks
        vm.prank(bettor1);
        battleMarket.mintShares(p1Rank1, 100);

        vm.prank(bettor1);
        battleMarket.placeSellOrder(p1Rank1, true, 7000, 10);

        vm.prank(bettor2);
        battleMarket.mintShares(p1Rank1, 100);

        vm.prank(bettor2);
        battleMarket.placeSellOrder(p1Rank1, true, 6500, 10);

        // Best ask should be 6500
        assertEq(battleMarket.getBestAsk(p1Rank1, true), 6500);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FUZZ TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function testFuzz_mintShares(uint256 amount) public {
        amount = bound(amount, 1, 1000); // Reasonable range

        (, bytes32 p1Rank1,) = _createMarkets();

        vm.prank(bettor1);
        battleMarket.mintShares(p1Rank1, amount);

        (uint256 yesShares, uint256 noShares) = battleMarket.getShareBalances(p1Rank1, bettor1);
        assertEq(yesShares, amount);
        assertEq(noShares, amount);
    }

    function testFuzz_placeOrder(uint256 price, uint256 size) public {
        price = bound(price, 1, 9999);
        size = bound(size, 1, 1000);

        (, bytes32 p1Rank1,) = _createMarkets();

        vm.prank(bettor1);
        uint256 orderId = battleMarket.placeOrder(p1Rank1, true, price, size);

        BattleMarket.LimitOrder memory order = battleMarket.getOrder(p1Rank1, orderId);
        assertEq(order.price, price);
        assertEq(order.size, size);
    }
}
