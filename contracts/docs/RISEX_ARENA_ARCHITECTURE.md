# RISExArena Smart Contract Architecture

## Overview

RISExArena is a PvP trading platform built on top of RISEx, enabling traders to compete in real-time trading battles
while spectators bet on outcomes through integrated prediction markets.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              RISExArena System                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────────────┐  │
│  │  BattleManager  │───▶│  BattleMarket   │───▶│  BattleRewardVault      │  │
│  │                 │    │  (Predictions)  │    │                         │  │
│  └────────┬────────┘    └────────┬────────┘    └─────────────────────────┘  │
│           │                      │                                          │
│           │                      │                                          │
│           ▼                      ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                         RISEx Protocol                              │    │
│  │  ┌─────────────┐  ┌──────────────────┐  ┌─────────────────────────┐ │    │
│  │  │PerpsManager │  │CollateralManager │  │      RISExOracle        │ │    │
│  │  └─────────────┘  └──────────────────┘  └─────────────────────────┘ │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Core Contracts

### 1. BattleManager

The central orchestrator for battle lifecycle management.

#### State Variables

```solidity
struct BattleConfig {
    uint8 maxPlayers;              // Maximum players (2-4)
    WinCondition winCondition;     // TimeBased or PnLTarget
    uint256 duration;              // Battle duration (for TimeBased)
    int256 pnlTarget;              // Target PnL percentage (for PnLTarget), scaled by 1e18
    uint256 minEquity;             // Minimum equity required to join
    uint256[] allowedMarkets;      // RISEx market IDs allowed for trading
}

enum WinCondition {
    TimeBased,    // Highest PnL at end of duration wins
    PnLTarget     // First to reach PnL target wins
}

enum BattleStatus {
    Open,         // Accepting join requests
    Active,       // Battle in progress
    Settled,      // Battle completed, rewards distributed
    Cancelled     // Battle cancelled (not enough players, etc.)
}

struct Battle {
    uint256 id;
    address initiator;
    BattleConfig config;
    BattleStatus status;
    uint256 startTime;
    uint256 endTime;
    address[] players;
    mapping(address => bool) isPlayer;
    mapping(address => int256) startingEquity;
    mapping(address => int256) finalEquity;
    address[] finalRankings;        // Ordered by final PnL (best to worst)
}

struct JoinRequest {
    address player;
    uint256 battleId;
    uint256 timestamp;
    bool approved;
}

// State
mapping(uint256 => Battle) public battles;
mapping(uint256 => JoinRequest[]) public joinRequests;
mapping(address => uint256) public activePlayerBattle;  // Player -> active battle ID
uint256 public nextBattleId;

// External contracts
IPerpsManager public perpsManager;
ICollateralManager public collateralManager;
IRISExOracle public oracle;
IBattleMarket public battleMarket;
IBattleRewardVault public rewardVault;
```

#### Key Functions

```solidity
/// @notice Creates a new battle with the specified configuration
/// @param config The battle configuration
/// @return battleId The ID of the created battle
function createBattle(BattleConfig calldata config) external returns (uint256 battleId);

/// @notice Request to join an open battle
/// @param battleId The battle to join
function requestJoin(uint256 battleId) external;

/// @notice Initiator approves a join request
/// @param battleId The battle ID
/// @param player The player to approve
function approveJoinRequest(uint256 battleId, address player) external;

/// @notice Initiator starts the battle (all players must be approved)
/// @param battleId The battle to start
function startBattle(uint256 battleId) external;

/// @notice Called when a PnL target is reached (for PnLTarget battles)
/// @param battleId The battle ID
/// @param winner The player who reached the target
function claimPnLTargetWin(uint256 battleId, address winner) external;

/// @notice Settles a time-based battle after duration expires
/// @param battleId The battle to settle
function settleBattle(uint256 battleId) external;

/// @notice Gets the current PnL for a player in a battle
/// @param battleId The battle ID
/// @param player The player address
/// @return pnlPercentage The PnL as a percentage (scaled by 1e18)
function getPlayerPnL(uint256 battleId, address player) external view returns (int256 pnlPercentage);

/// @notice Gets the current rankings for a battle
/// @param battleId The battle ID
/// @return rankings Ordered array of player addresses (best to worst PnL)
function getCurrentRankings(uint256 battleId) external view returns (address[] memory rankings);
```

#### PnL Calculation Logic

The contract leverages RISEx's existing infrastructure to calculate real-time PnL:

```solidity
function _calculatePlayerEquity(address player) internal view returns (int256) {
    int256 collateralBalance = collateralManager.getAccountCollateralTokenBalance(
        player,
        USDC_TOKEN
    );

    // Uses Collateral.accountEquity which includes unsettled PnL
    return Collateral.accountEquity(collateralBalance, perpsManager, oracle, player);
}

function _calculatePnLPercentage(
    int256 startingEquity,
    int256 currentEquity
) internal pure returns (int256) {
    if (startingEquity <= 0) return 0;
    return ((currentEquity - startingEquity) * 1e18) / startingEquity;
}
```

#### Events

```solidity
event BattleCreated(uint256 indexed battleId, address indexed initiator, BattleConfig config);
event JoinRequested(uint256 indexed battleId, address indexed player);
event JoinApproved(uint256 indexed battleId, address indexed player);
event BattleStarted(uint256 indexed battleId, uint256 startTime, address[] players);
event BattleSettled(uint256 indexed battleId, address[] rankings, int256[] pnls);
event BattleCancelled(uint256 indexed battleId);
event PnLTargetReached(uint256 indexed battleId, address indexed winner, int256 pnl);
```

---

### 2. BattleMarket

Implements Polymarket-style YES/NO prediction markets for battle outcomes.

#### Architecture

For an N-player battle, `N * N` outcome markets are created:

- N markets for "Player X finishes 1st"
- N markets for "Player X finishes 2nd"
- ... and so on

Each outcome market is a binary market with YES/NO shares.

```
4-Player Battle Market Structure:
┌─────────────────────────────────────────────────────────────────────┐
│                        Battle #123 Markets                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Player A          Player B          Player C          Player D    │
│  ┌─────────┐       ┌─────────┐       ┌─────────┐       ┌─────────┐ │
│  │ 1st: Y/N│       │ 1st: Y/N│       │ 1st: Y/N│       │ 1st: Y/N│ │
│  │ 2nd: Y/N│       │ 2nd: Y/N│       │ 2nd: Y/N│       │ 2nd: Y/N│ │
│  │ 3rd: Y/N│       │ 3rd: Y/N│       │ 3rd: Y/N│       │ 3rd: Y/N│ │
│  │ 4th: Y/N│       │ 4th: Y/N│       │ 4th: Y/N│       │ 4th: Y/N│ │
│  └─────────┘       └─────────┘       └─────────┘       └─────────┘ │
│                                                                     │
│  Total: 16 binary markets                                          │
└─────────────────────────────────────────────────────────────────────┘
```

#### State Variables

```solidity
struct OutcomeMarket {
    uint256 battleId;
    address player;           // The player this market is about
    uint8 rank;               // The rank being predicted (1-4)
    uint256 yesShares;        // Total YES shares minted
    uint256 noShares;         // Total NO shares minted
    bool resolved;
    bool outcome;             // true if player finished at this rank
}

struct Order {
    address maker;
    bool isYes;               // true = buying YES, false = buying NO
    uint256 price;            // Price in basis points (0-10000)
    uint256 size;             // Number of shares
    uint256 filled;
    bool active;
}

struct MarketState {
    OutcomeMarket market;
    mapping(uint256 => Order) orders;
    uint256 nextOrderId;
    mapping(uint256 => uint256) yesOrderBook;  // price -> orderId (tick-based)
    mapping(uint256 => uint256) noOrderBook;   // price -> orderId
    mapping(address => uint256) yesBalances;
    mapping(address => uint256) noBalances;
}

// outcomeId = keccak256(battleId, player, rank)
mapping(bytes32 => MarketState) public markets;

// Fee configuration
uint256 public mintFeeBps;        // Fee charged when minting shares
address public rewardVault;       // Where fees are sent

// External
IBattleManager public battleManager;
```

#### Share Mechanics (Polymarket Model)

1. **Share Minting**: Users pay `$1` to mint 1 YES + 1 NO share pair
2. **Trading**: Users trade shares via CLOB orderbook
3. **Resolution**: Winning shares redeem for `$1`, losing shares worth `$0`

```solidity
/// @notice Mint YES/NO share pairs for an outcome market
/// @param outcomeId The market identifier
/// @param amount Number of share pairs to mint
function mintShares(bytes32 outcomeId, uint256 amount) external;

/// @notice Place a limit order on the orderbook
/// @param outcomeId The market identifier
/// @param isYes Whether buying YES or NO
/// @param price Price in basis points (e.g., 6500 = $0.65)
/// @param size Number of shares
function placeOrder(
    bytes32 outcomeId,
    bool isYes,
    uint256 price,
    uint256 size
) external returns (uint256 orderId);

/// @notice Cancel an existing order
function cancelOrder(bytes32 outcomeId, uint256 orderId) external;

/// @notice Redeem winning shares after market resolution
function redeemShares(bytes32 outcomeId) external;
```

#### Fee Distribution

```solidity
function mintShares(bytes32 outcomeId, uint256 amount) external {
    MarketState storage state = markets[outcomeId];
    require(!state.market.resolved, "Market resolved");

    uint256 cost = amount * SHARE_PRICE;  // 1 USDC per pair
    uint256 fee = (cost * mintFeeBps) / 10000;

    // Transfer cost + fee from user
    USDC.transferFrom(msg.sender, address(this), cost + fee);

    // Send fee to reward vault for trader prize pool
    USDC.transfer(rewardVault, fee);
    rewardVault.addToPool(state.market.battleId, fee);

    // Mint share pairs
    state.market.yesShares += amount;
    state.market.noShares += amount;
    state.yesBalances[msg.sender] += amount;
    state.noBalances[msg.sender] += amount;

    emit SharesMinted(outcomeId, msg.sender, amount, fee);
}
```

#### Market Resolution

```solidity
/// @notice Called by BattleManager when battle is settled
function resolveMarkets(
    uint256 battleId,
    address[] calldata finalRankings
) external onlyBattleManager {
    for (uint8 rank = 1; rank <= finalRankings.length; rank++) {
        for (uint256 i = 0; i < finalRankings.length; i++) {
            address player = finalRankings[i];
            bytes32 outcomeId = getOutcomeId(battleId, player, rank);
            MarketState storage state = markets[outcomeId];

            // Player at index (rank-1) finished at that rank
            bool playerWon = (i == rank - 1);

            state.market.resolved = true;
            state.market.outcome = playerWon;

            emit MarketResolved(outcomeId, playerWon);
        }
    }
}
```

#### Events

```solidity
event MarketsCreated(uint256 indexed battleId, bytes32[] outcomeIds);
event SharesMinted(bytes32 indexed outcomeId, address indexed minter, uint256 amount, uint256 fee);
event OrderPlaced(bytes32 indexed outcomeId, uint256 indexed orderId, address maker, bool isYes, uint256 price, uint256 size);
event OrderMatched(bytes32 indexed outcomeId, uint256 makerOrderId, uint256 takerOrderId, uint256 size, uint256 price);
event OrderCancelled(bytes32 indexed outcomeId, uint256 indexed orderId);
event MarketResolved(bytes32 indexed outcomeId, bool outcome);
event SharesRedeemed(bytes32 indexed outcomeId, address indexed redeemer, uint256 amount, uint256 payout);
```

---

### 3. BattleRewardVault

Manages the prize pool funded by prediction market fees and distributes rewards to traders.

#### State Variables

```solidity
struct PrizePool {
    uint256 totalAmount;
    uint256[] distribution;    // Percentage per rank (scaled by 1e4, e.g., [5000, 3000, 1500, 500] = 50/30/15/5%)
    bool distributed;
}

mapping(uint256 => PrizePool) public prizePools;  // battleId => PrizePool

// Default distributions by player count
mapping(uint8 => uint256[]) public defaultDistributions;
// 2 players: [7000, 3000]           // 70% / 30%
// 3 players: [5000, 3000, 2000]     // 50% / 30% / 20%
// 4 players: [4000, 3000, 2000, 1000] // 40% / 30% / 20% / 10%

IBattleManager public battleManager;
IBattleMarket public battleMarket;
```

#### Key Functions

```solidity
/// @notice Add funds to a battle's prize pool (called by BattleMarket on mint fees)
function addToPool(uint256 battleId, uint256 amount) external onlyBattleMarket;

/// @notice Set custom distribution for a battle (before it starts)
function setDistribution(uint256 battleId, uint256[] calldata distribution) external onlyBattleInitiator;

/// @notice Distribute prizes based on final rankings
function distributeRewards(
    uint256 battleId,
    address[] calldata rankings
) external onlyBattleManager {
    PrizePool storage pool = prizePools[battleId];
    require(!pool.distributed, "Already distributed");

    uint256[] memory distribution = pool.distribution.length > 0
        ? pool.distribution
        : defaultDistributions[uint8(rankings.length)];

    for (uint256 i = 0; i < rankings.length; i++) {
        uint256 reward = (pool.totalAmount * distribution[i]) / 10000;
        if (reward > 0) {
            USDC.transfer(rankings[i], reward);
            emit RewardDistributed(battleId, rankings[i], i + 1, reward);
        }
    }

    pool.distributed = true;
    emit PrizePoolDistributed(battleId, pool.totalAmount);
}

/// @notice View the current prize pool for a battle
function getPrizePool(uint256 battleId) external view returns (uint256);

/// @notice View expected rewards per rank for a battle
function getExpectedRewards(uint256 battleId) external view returns (uint256[] memory);
```

#### Events

```solidity
event PoolFunded(uint256 indexed battleId, uint256 amount, uint256 newTotal);
event DistributionSet(uint256 indexed battleId, uint256[] distribution);
event RewardDistributed(uint256 indexed battleId, address indexed player, uint8 rank, uint256 amount);
event PrizePoolDistributed(uint256 indexed battleId, uint256 totalAmount);
```

---

## Integration with RISEx

### Trading Authorization

RISExArena needs to track trades without restricting them. The system uses RISEx's event system for monitoring:

```solidity
// BattleManager listens to RISEx events for real-time tracking
// No trading restrictions are imposed - players trade freely on RISEx

// Events monitored:
// - MatchOrder: Track position changes and PnL impact
// - PlaceOrder: Monitor trading activity
// - Liquidate: Handle liquidation scenarios
```

### Equity Calculation

The system leverages RISEx's existing margin calculation infrastructure:

```solidity
interface IEquityCalculator {
    /// @notice Calculates total equity for a player
    /// @dev Uses RISEx's Collateral.accountEquity internally
    function calculateEquity(address player) external view returns (int256);
}

// Implementation uses:
// 1. ICollateralManager.getAccountCollateralTokenBalance() - Get collateral balance
// 2. IPerpsManager.getPosition() - Get all positions
// 3. IRISExOracle.getMarkPrice() - Get current mark prices
// 4. Margin.unsettledUsdc() - Calculate unrealized PnL per position
```

### Market Restrictions (Optional)

Battles can optionally restrict which RISEx markets players can trade:

```solidity
// In BattleConfig:
uint256[] allowedMarkets;  // Empty = all markets allowed

// Validation hook (if implemented):
modifier onlyAllowedMarkets(uint256 battleId, uint256 marketId) {
    Battle storage battle = battles[battleId];
    if (battle.config.allowedMarkets.length > 0) {
        bool allowed = false;
        for (uint i = 0; i < battle.config.allowedMarkets.length; i++) {
            if (battle.config.allowedMarkets[i] == marketId) {
                allowed = true;
                break;
            }
        }
        require(allowed, "Market not allowed in this battle");
    }
    _;
}
```

---

## Battle Flow Sequence

```
                    BATTLE LIFECYCLE

    ┌──────────────────────────────────────────────────────┐
    │                    1. CREATION                       │
    │  Initiator calls createBattle(config)                │
    │  - Validates config (players, duration, etc.)        │
    │  - Sets initiator as first player                    │
    │  - Creates battle in Open status                     │
    │  - BattleMarket.createMarkets() called               │
    └────────────────────────┬─────────────────────────────┘
                             │
                             ▼
    ┌──────────────────────────────────────────────────────┐
    │                  2. JOIN PHASE                       │
    │  Other players call requestJoin(battleId)            │
    │  - Verifies player meets minimum equity              │
    │  - Verifies player not in another active battle      │
    │  - Creates pending JoinRequest                       │
    │                                                      │
    │  Initiator calls approveJoinRequest(battleId, player)│
    │  - Adds player to battle                             │
    │  - Updates prediction market odds (new player added) │
    └────────────────────────┬─────────────────────────────┘
                             │
                             ▼
    ┌──────────────────────────────────────────────────────┐
    │                   3. START                           │
    │  Initiator calls startBattle(battleId)               │
    │  - Requires minimum 2 players                        │
    │  - Snapshots starting equity for all players         │
    │  - Sets status to Active                             │
    │  - Records startTime                                 │
    │  - Prediction markets begin accepting bets           │
    └────────────────────────┬─────────────────────────────┘
                             │
                             ▼
    ┌──────────────────────────────────────────────────────┐
    │               4. ACTIVE TRADING                      │
    │  Players trade freely on RISEx                       │
    │  - No restrictions on trading                        │
    │  - BattleManager tracks PnL via RISEx queries        │
    │  - Spectators bet on outcomes in BattleMarket        │
    │  - Fees from bets fund prize pool in RewardVault     │
    │                                                      │
    │  [PnL Target Mode Only]                              │
    │  If player reaches target, they call                 │
    │  claimPnLTargetWin(battleId, address)               │
    └────────────────────────┬─────────────────────────────┘
                             │
                             ▼
    ┌──────────────────────────────────────────────────────┐
    │                 5. SETTLEMENT                        │
    │  [Time-Based] Anyone calls settleBattle after expiry │
    │  [PnL Target] Triggered by claimPnLTargetWin         │
    │                                                      │
    │  - Calculates final equity for all players           │
    │  - Determines rankings based on PnL %                │
    │  - Resolves all prediction markets                   │
    │  - Distributes prize pool to traders                 │
    │  - Sets status to Settled                            │
    └──────────────────────────────────────────────────────┘
```

---

## Security Considerations

### Battle Integrity

1. **Equity Snapshots**: Starting equity is recorded atomically when battle starts to prevent manipulation
2. **No Re-entry**: Players cannot join multiple active battles simultaneously
3. **Minimum Equity**: Prevents dust accounts from participating
4. **Time Verification**: Uses block.timestamp with reasonable tolerance

### Prediction Market Safety

1. **Resolution Atomicity**: All markets for a battle are resolved in a single transaction
2. **Fee Isolation**: Mint fees are immediately transferred to RewardVault
3. **Share Accounting**: YES + NO shares always sum correctly
4. **Orderbook Protection**: Standard CLOB security measures (price bounds, size limits)

### Prize Distribution

1. **Distribution Validation**: Percentages must sum to 100%
2. **One-time Distribution**: `distributed` flag prevents double-claiming
3. **Ranking Verification**: Rankings are determined by BattleManager, not external input

---

## Gas Optimization Strategies

1. **Bitmap for Active Battles**: Use bitmaps to track active player participation
2. **Lazy Evaluation**: Calculate PnL only when queried, not on every trade
3. **Batch Resolution**: Resolve all markets for a battle in one transaction
4. **Minimal Storage**: Store only essential battle state, derive rankings on-demand

---

## Future Extensions

1. **Team Battles**: 2v2 or team-based competitions
2. **Tournament Mode**: Bracket-style elimination tournaments
3. **Leaderboards**: Historical performance tracking and rankings
4. **Battle Tokens**: NFT trophies for battle winners
5. **Staking Requirements**: Require stake that can be slashed for rule violations
6. **Automated Market Makers**: AMM-based prediction markets for more liquidity
7. **Cross-Protocol Battles**: Battles across multiple perps protocols

---

## Contract Deployment Order

1. Deploy `BattleRewardVault`
2. Deploy `BattleMarket` with RewardVault address
3. Deploy `BattleManager` with BattleMarket, RewardVault, and RISEx contract addresses
4. Configure permissions:
   - BattleMarket.setBattleManager()
   - BattleRewardVault.setBattleManager()
   - BattleRewardVault.setBattleMarket()

---

## Appendix: Key RISEx Integration Points

| RISEx Component                                                       | Usage in Arena                                |
| --------------------------------------------------------------------- | --------------------------------------------- |
| `IPerpsManager.getPosition(marketId, account)`                        | Get position size/side for PnL calc           |
| `ICollateralManager.getAccountCollateralTokenBalance(account, token)` | Get collateral balance                        |
| `IRISExOracle.getMarkPrice(marketId)`                                 | Get current mark price for equity calc        |
| `Margin.unsettledUsdc(position, markPrice)`                           | Calculate unrealized PnL                      |
| `Collateral.accountEquity(...)`                                       | Calculate total account equity                |
| `MatchOrder` event                                                    | Track trade execution for activity monitoring |

---

## Appendix: Outcome ID Generation

```solidity
function getOutcomeId(
    uint256 battleId,
    address player,
    uint8 rank
) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(battleId, player, rank));
}

// Example for 4-player battle #123:
// Player A 1st: keccak256(123, 0xA..., 1)
// Player A 2nd: keccak256(123, 0xA..., 2)
// Player B 1st: keccak256(123, 0xB..., 1)
// ... etc.
```
