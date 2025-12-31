// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "solady/auth/Ownable.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {IBattleManager} from "./interfaces/IBattleManager.sol";
import {IBattleMarket} from "./interfaces/IBattleMarket.sol";
import {IBattleRewardVault} from "./interfaces/IBattleRewardVault.sol";
import {IPerpsManager} from "./interfaces/IPerpsManager.sol";
import {ICollateralManager} from "./interfaces/ICollateralManager.sol";
import {IRISExOracle} from "./interfaces/IRISExOracle.sol";

/// @title BattleManager
/// @notice Central orchestrator for battle lifecycle management
contract BattleManager is IBattleManager, Ownable {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for int256;

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Maximum number of players per battle
    uint8 public constant MAX_PLAYERS = 4;

    /// @notice Minimum number of players per battle
    uint8 public constant MIN_PLAYERS = 2;

    /// @notice WAD constant (1e18)
    int256 internal constant WAD = 1e18;

    // ═══════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ═══════════════════════════════════════════════════════════════════════════

    error ZeroAddress();
    error InvalidMaxPlayers();
    error InvalidDuration();
    error InvalidPnLTarget();
    error BattleNotOpen();
    error BattleNotActive();
    error BattleNotSettleable();
    error NotInitiator();
    error PlayerAlreadyInBattle();
    error PlayerNotInBattle();
    error InsufficientEquity();
    error NotEnoughPlayers();
    error TooManyPlayers();
    error JoinRequestNotFound();
    error JoinRequestAlreadyApproved();
    error AlreadyRequested();
    error PnLTargetNotReached();
    error NotTimeBased();
    error NotPnLTarget();
    error BattleAlreadyStarted();

    // ═══════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════════════════

    event BattleCreated(uint256 indexed battleId, address indexed initiator, BattleConfig config);
    event JoinRequested(uint256 indexed battleId, address indexed player);
    event JoinApproved(uint256 indexed battleId, address indexed player);
    event BattleStarted(uint256 indexed battleId, uint256 startTime, address[] players);
    event BattleSettled(uint256 indexed battleId, address[] rankings, int256[] pnls);
    event BattleCancelled(uint256 indexed battleId);
    event PnLTargetReached(uint256 indexed battleId, address indexed winner, int256 pnl);

    // ═══════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ═══════════════════════════════════════════════════════════════════════════

    struct JoinRequest {
        address player;
        uint256 battleId;
        uint256 timestamp;
        bool approved;
    }

    struct BattleData {
        uint256 id;
        address initiator;
        BattleConfig config;
        BattleStatus status;
        uint256 startTime;
        uint256 endTime;
        address[] players;
        address[] finalRankings;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Next battle ID
    uint256 public nextBattleId;

    /// @notice Battle data storage
    mapping(uint256 => BattleData) internal _battles;

    /// @notice Player membership in battles
    mapping(uint256 => mapping(address => bool)) public isPlayer;

    /// @notice Starting equity snapshots
    mapping(uint256 => mapping(address => int256)) public startingEquity;

    /// @notice Final equity snapshots
    mapping(uint256 => mapping(address => int256)) public finalEquity;

    /// @notice Join requests per battle
    mapping(uint256 => JoinRequest[]) public joinRequests;

    /// @notice Track pending join requests
    mapping(uint256 => mapping(address => bool)) public hasPendingRequest;

    /// @notice Active battle per player (stores battleId + 1, so 0 = no active battle)
    mapping(address => uint256) internal _activePlayerBattle;

    // External contracts
    IPerpsManager public perpsManager;
    ICollateralManager public collateralManager;
    IRISExOracle public oracle;
    IBattleMarket public battleMarket;
    IBattleRewardVault public rewardVault;

    /// @notice USDC token address
    address public immutable usdc;

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════════════

    constructor(
        address usdc_,
        address perpsManager_,
        address collateralManager_,
        address oracle_,
        address battleMarket_,
        address rewardVault_
    ) {
        if (usdc_ == address(0)) revert ZeroAddress();
        usdc = usdc_;

        perpsManager = IPerpsManager(perpsManager_);
        collateralManager = ICollateralManager(collateralManager_);
        oracle = IRISExOracle(oracle_);
        battleMarket = IBattleMarket(battleMarket_);
        rewardVault = IBattleRewardVault(rewardVault_);

        _initializeOwner(msg.sender);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Set external contract addresses
    function setContracts(
        address perpsManager_,
        address collateralManager_,
        address oracle_,
        address battleMarket_,
        address rewardVault_
    ) external onlyOwner {
        if (perpsManager_ != address(0)) perpsManager = IPerpsManager(perpsManager_);
        if (collateralManager_ != address(0)) collateralManager = ICollateralManager(collateralManager_);
        if (oracle_ != address(0)) oracle = IRISExOracle(oracle_);
        if (battleMarket_ != address(0)) battleMarket = IBattleMarket(battleMarket_);
        if (rewardVault_ != address(0)) rewardVault = IBattleRewardVault(rewardVault_);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // BATTLE CREATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IBattleManager
    function createBattle(BattleConfig calldata config) external returns (uint256 battleId) {
        // Validate config
        if (config.maxPlayers < MIN_PLAYERS || config.maxPlayers > MAX_PLAYERS) {
            revert InvalidMaxPlayers();
        }
        if (config.winCondition == WinCondition.TimeBased && config.duration == 0) {
            revert InvalidDuration();
        }
        if (config.winCondition == WinCondition.PnLTarget && config.pnlTarget <= 0) {
            revert InvalidPnLTarget();
        }

        // Check initiator is not in another active battle
        if (_activePlayerBattle[msg.sender] != 0) {
            revert PlayerAlreadyInBattle();
        }

        // Check initiator meets minimum equity
        int256 equity = _calculatePlayerEquity(msg.sender);
        if (config.minEquity > 0 && equity < int256(config.minEquity)) {
            revert InsufficientEquity();
        }

        battleId = nextBattleId++;

        BattleData storage battle = _battles[battleId];
        battle.id = battleId;
        battle.initiator = msg.sender;
        battle.config = config;
        battle.status = BattleStatus.Open;
        battle.players.push(msg.sender);

        isPlayer[battleId][msg.sender] = true;
        _activePlayerBattle[msg.sender] = battleId + 1;

        emit BattleCreated(battleId, msg.sender, config);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // JOIN FLOW
    // ═══════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IBattleManager
    function requestJoin(uint256 battleId) external {
        BattleData storage battle = _battles[battleId];

        if (battle.status != BattleStatus.Open) revert BattleNotOpen();
        if (_activePlayerBattle[msg.sender] != 0) revert PlayerAlreadyInBattle();
        if (hasPendingRequest[battleId][msg.sender]) revert AlreadyRequested();
        if (isPlayer[battleId][msg.sender]) revert PlayerAlreadyInBattle();

        // Check minimum equity
        int256 equity = _calculatePlayerEquity(msg.sender);
        if (battle.config.minEquity > 0 && equity < int256(battle.config.minEquity)) {
            revert InsufficientEquity();
        }

        // Create join request
        joinRequests[battleId].push(
            JoinRequest({player: msg.sender, battleId: battleId, timestamp: block.timestamp, approved: false})
        );
        hasPendingRequest[battleId][msg.sender] = true;

        emit JoinRequested(battleId, msg.sender);
    }

    /// @inheritdoc IBattleManager
    function approveJoinRequest(uint256 battleId, address player) external {
        BattleData storage battle = _battles[battleId];

        if (battle.status != BattleStatus.Open) revert BattleNotOpen();
        if (msg.sender != battle.initiator) revert NotInitiator();
        if (battle.players.length >= battle.config.maxPlayers) revert TooManyPlayers();

        // Find and approve the request
        JoinRequest[] storage requests = joinRequests[battleId];
        bool found = false;
        for (uint256 i = 0; i < requests.length; i++) {
            if (requests[i].player == player && !requests[i].approved) {
                requests[i].approved = true;
                found = true;
                break;
            }
        }
        if (!found) revert JoinRequestNotFound();

        // Re-check player not in another battle (could have joined another)
        if (_activePlayerBattle[player] != 0) revert PlayerAlreadyInBattle();

        // Add player to battle
        battle.players.push(player);
        isPlayer[battleId][player] = true;
        _activePlayerBattle[player] = battleId + 1;
        hasPendingRequest[battleId][player] = false;

        emit JoinApproved(battleId, player);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // BATTLE START
    // ═══════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IBattleManager
    function startBattle(uint256 battleId) external {
        BattleData storage battle = _battles[battleId];

        if (battle.status != BattleStatus.Open) revert BattleNotOpen();
        if (msg.sender != battle.initiator) revert NotInitiator();
        if (battle.players.length < MIN_PLAYERS) revert NotEnoughPlayers();

        // Snapshot starting equity for all players
        for (uint256 i = 0; i < battle.players.length; i++) {
            address player = battle.players[i];
            startingEquity[battleId][player] = _calculatePlayerEquity(player);
        }

        battle.status = BattleStatus.Active;
        battle.startTime = block.timestamp;

        if (battle.config.winCondition == WinCondition.TimeBased) {
            battle.endTime = block.timestamp + battle.config.duration;
        }

        // Create prediction markets for this battle
        battleMarket.createMarkets(battleId, battle.players);

        emit BattleStarted(battleId, battle.startTime, battle.players);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // BATTLE SETTLEMENT
    // ═══════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IBattleManager
    function claimPnLTargetWin(uint256 battleId, address winner) external {
        BattleData storage battle = _battles[battleId];

        if (battle.status != BattleStatus.Active) revert BattleNotActive();
        if (battle.config.winCondition != WinCondition.PnLTarget) revert NotPnLTarget();
        if (!isPlayer[battleId][winner]) revert PlayerNotInBattle();

        // Calculate winner's PnL
        int256 pnl = _calculatePnLPercentage(startingEquity[battleId][winner], _calculatePlayerEquity(winner));

        // Check if target is reached
        if (pnl < battle.config.pnlTarget) revert PnLTargetNotReached();

        emit PnLTargetReached(battleId, winner, pnl);

        // Settle the battle with winner first, then rank others by PnL
        _settleBattleWithWinner(battleId, winner);
    }

    /// @inheritdoc IBattleManager
    function settleBattle(uint256 battleId) external {
        BattleData storage battle = _battles[battleId];

        if (battle.status != BattleStatus.Active) revert BattleNotActive();
        if (battle.config.winCondition != WinCondition.TimeBased) revert NotTimeBased();
        if (block.timestamp < battle.endTime) revert BattleNotSettleable();

        _settleBattleByPnL(battleId);
    }

    /// @notice Cancel a battle (initiator only, before start)
    /// @param battleId The battle ID
    function cancelBattle(uint256 battleId) external {
        BattleData storage battle = _battles[battleId];

        if (battle.status != BattleStatus.Open) revert BattleNotOpen();
        if (msg.sender != battle.initiator) revert NotInitiator();

        // Clear active battle status for all players
        for (uint256 i = 0; i < battle.players.length; i++) {
            _activePlayerBattle[battle.players[i]] = 0;
        }

        battle.status = BattleStatus.Cancelled;
        emit BattleCancelled(battleId);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IBattleManager
    function getPlayerPnL(uint256 battleId, address player) external view returns (int256 pnlPercentage) {
        if (!isPlayer[battleId][player]) revert PlayerNotInBattle();
        return _calculatePnLPercentage(startingEquity[battleId][player], _calculatePlayerEquity(player));
    }

    /// @inheritdoc IBattleManager
    function getCurrentRankings(uint256 battleId) external view returns (address[] memory rankings) {
        BattleData storage battle = _battles[battleId];
        uint256 numPlayers = battle.players.length;

        // Create array of players with their PnLs
        rankings = new address[](numPlayers);
        int256[] memory pnls = new int256[](numPlayers);

        for (uint256 i = 0; i < numPlayers; i++) {
            rankings[i] = battle.players[i];
            pnls[i] = _calculatePnLPercentage(
                startingEquity[battleId][battle.players[i]], _calculatePlayerEquity(battle.players[i])
            );
        }

        // Sort by PnL descending (bubble sort for simplicity, small array)
        for (uint256 i = 0; i < numPlayers; i++) {
            for (uint256 j = i + 1; j < numPlayers; j++) {
                if (pnls[j] > pnls[i]) {
                    // Swap
                    (rankings[i], rankings[j]) = (rankings[j], rankings[i]);
                    (pnls[i], pnls[j]) = (pnls[j], pnls[i]);
                }
            }
        }
    }

    /// @inheritdoc IBattleManager
    function getBattlePlayers(uint256 battleId) external view returns (address[] memory) {
        return _battles[battleId].players;
    }

    /// @inheritdoc IBattleManager
    function getBattleInitiator(uint256 battleId) external view returns (address) {
        return _battles[battleId].initiator;
    }

    /// @inheritdoc IBattleManager
    function getBattleStatus(uint256 battleId) external view returns (BattleStatus) {
        return _battles[battleId].status;
    }

    /// @notice Get battle config
    /// @param battleId The battle ID
    /// @return config The battle configuration
    function getBattleConfig(uint256 battleId) external view returns (BattleConfig memory) {
        return _battles[battleId].config;
    }

    /// @notice Get active battle for a player
    /// @param player The player address
    /// @return battleId The active battle ID (or 0 if not in a battle)
    function activePlayerBattle(address player) external view returns (uint256) {
        uint256 stored = _activePlayerBattle[player];
        return stored > 0 ? stored - 1 : 0;
    }

    /// @notice Check if player is in any active battle
    /// @param player The player address
    /// @return isActive Whether player is in an active battle
    function isPlayerInBattle(address player) external view returns (bool) {
        return _activePlayerBattle[player] != 0;
    }

    /// @notice Get battle timing info
    /// @param battleId The battle ID
    /// @return startTime The battle start time
    /// @return endTime The battle end time
    function getBattleTiming(uint256 battleId) external view returns (uint256 startTime, uint256 endTime) {
        BattleData storage battle = _battles[battleId];
        return (battle.startTime, battle.endTime);
    }

    /// @notice Get final rankings for a settled battle
    /// @param battleId The battle ID
    /// @return rankings The final rankings
    function getFinalRankings(uint256 battleId) external view returns (address[] memory) {
        return _battles[battleId].finalRankings;
    }

    /// @notice Get join requests for a battle
    /// @param battleId The battle ID
    /// @return requests The join requests
    function getJoinRequests(uint256 battleId) external view returns (JoinRequest[] memory) {
        return joinRequests[battleId];
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// @dev Calculate total equity for a player using RISEx infrastructure
    function _calculatePlayerEquity(address player) internal view returns (int256) {
        // Get collateral balance
        int256 collateralBalance = collateralManager.getAccountCollateralTokenBalance(player, usdc);

        // Get active markets and calculate unsettled PnL
        uint256[] memory activeMarketBitmaps = perpsManager.getActiveMarkets(player);

        int256 total = collateralBalance;

        for (uint256 i = 0; i < activeMarketBitmaps.length; i++) {
            uint256 bitmap = activeMarketBitmaps[i];
            while (bitmap > 0) {
                // Extract least significant set bit
                uint256 lsb = bitmap & (~bitmap + 1);
                uint256 bitIndex = _log2(lsb);
                uint256 marketId = (i << 8) + bitIndex;

                // Get position and mark price
                IPerpsManager.Position memory position = perpsManager.getPosition(marketId, player);
                uint256 markPrice = oracle.getMarkPrice(marketId);

                // Calculate unsettled PnL: size * markPrice + quoteAmount
                int256 unsettledPnL = _unsettledUsdc(position, markPrice);
                total += unsettledPnL;

                // Clear the bit
                bitmap = bitmap & (bitmap - 1);
            }
        }

        return total;
    }

    /// @dev Calculate unsettled USDC for a position
    /// @param position The position struct
    /// @param markPrice The current mark price
    /// @return unsettled The unsettled USDC amount
    function _unsettledUsdc(IPerpsManager.Position memory position, uint256 markPrice) internal pure returns (int256) {
        // Unsettled USDC = size * markPrice + quoteAmount
        // Assembly justification: Efficient signed multiplication with WAD scaling
        // Equivalent Solidity: return (int256(position.size) * int256(markPrice) / 1e18) + int256(position.quoteAmount);
        int256 sizeValue;
        assembly ("memory-safe") {
            // size * markPrice / WAD
            sizeValue := sdiv(mul(mload(position), markPrice), 1000000000000000000)
        }
        return sizeValue + int256(position.quoteAmount);
    }

    /// @dev Calculate PnL percentage
    /// @param startEquity Starting equity
    /// @param currentEquity Current equity
    /// @return pnlPercentage PnL as percentage scaled by 1e18
    function _calculatePnLPercentage(int256 startEquity, int256 currentEquity)
        internal
        pure
        returns (int256 pnlPercentage)
    {
        if (startEquity <= 0) return 0;
        return ((currentEquity - startEquity) * WAD) / startEquity;
    }

    /// @dev Settle battle with a specific winner (for PnL target mode)
    function _settleBattleWithWinner(uint256 battleId, address winner) internal {
        BattleData storage battle = _battles[battleId];
        uint256 numPlayers = battle.players.length;

        // Store final equity for all players
        int256[] memory pnls = new int256[](numPlayers);
        address[] memory rankings = new address[](numPlayers);

        for (uint256 i = 0; i < numPlayers; i++) {
            address player = battle.players[i];
            int256 equity = _calculatePlayerEquity(player);
            finalEquity[battleId][player] = equity;
            pnls[i] = _calculatePnLPercentage(startingEquity[battleId][player], equity);
            rankings[i] = player;
        }

        // Put winner first
        for (uint256 i = 0; i < numPlayers; i++) {
            if (rankings[i] == winner) {
                (rankings[0], rankings[i]) = (rankings[i], rankings[0]);
                (pnls[0], pnls[i]) = (pnls[i], pnls[0]);
                break;
            }
        }

        // Sort remaining players by PnL
        for (uint256 i = 1; i < numPlayers; i++) {
            for (uint256 j = i + 1; j < numPlayers; j++) {
                if (pnls[j] > pnls[i]) {
                    (rankings[i], rankings[j]) = (rankings[j], rankings[i]);
                    (pnls[i], pnls[j]) = (pnls[j], pnls[i]);
                }
            }
        }

        _finalizeBattle(battleId, rankings, pnls);
    }

    /// @dev Settle battle by PnL ranking (for time-based mode)
    function _settleBattleByPnL(uint256 battleId) internal {
        BattleData storage battle = _battles[battleId];
        uint256 numPlayers = battle.players.length;

        int256[] memory pnls = new int256[](numPlayers);
        address[] memory rankings = new address[](numPlayers);

        for (uint256 i = 0; i < numPlayers; i++) {
            address player = battle.players[i];
            int256 equity = _calculatePlayerEquity(player);
            finalEquity[battleId][player] = equity;
            pnls[i] = _calculatePnLPercentage(startingEquity[battleId][player], equity);
            rankings[i] = player;
        }

        // Sort by PnL descending
        for (uint256 i = 0; i < numPlayers; i++) {
            for (uint256 j = i + 1; j < numPlayers; j++) {
                if (pnls[j] > pnls[i]) {
                    (rankings[i], rankings[j]) = (rankings[j], rankings[i]);
                    (pnls[i], pnls[j]) = (pnls[j], pnls[i]);
                }
            }
        }

        _finalizeBattle(battleId, rankings, pnls);
    }

    /// @dev Finalize battle settlement
    function _finalizeBattle(uint256 battleId, address[] memory rankings, int256[] memory pnls) internal {
        BattleData storage battle = _battles[battleId];

        battle.finalRankings = rankings;
        battle.status = BattleStatus.Settled;

        // Clear active battle status for all players
        for (uint256 i = 0; i < battle.players.length; i++) {
            _activePlayerBattle[battle.players[i]] = 0;
        }

        // Resolve prediction markets
        battleMarket.resolveMarkets(battleId, rankings);

        // Distribute rewards
        rewardVault.distributeRewards(battleId, rankings);

        emit BattleSettled(battleId, rankings, pnls);
    }

    /// @dev Calculate log2 of a power of 2
    function _log2(uint256 x) internal pure returns (uint256 r) {
        // Assembly justification: Efficient log2 calculation for power of 2
        // Equivalent Solidity: while (x > 1) { x >>= 1; r++; }
        assembly ("memory-safe") {
            r := 0
            if gt(x, 0xffffffffffffffffffffffffffffffff) {
                x := shr(128, x)
                r := 128
            }
            if gt(x, 0xffffffffffffffff) {
                x := shr(64, x)
                r := or(r, 64)
            }
            if gt(x, 0xffffffff) {
                x := shr(32, x)
                r := or(r, 32)
            }
            if gt(x, 0xffff) {
                x := shr(16, x)
                r := or(r, 16)
            }
            if gt(x, 0xff) {
                x := shr(8, x)
                r := or(r, 8)
            }
            if gt(x, 0xf) {
                x := shr(4, x)
                r := or(r, 4)
            }
            if gt(x, 0x3) {
                x := shr(2, x)
                r := or(r, 2)
            }
            if gt(x, 0x1) {
                r := or(r, 1)
            }
        }
    }
}
