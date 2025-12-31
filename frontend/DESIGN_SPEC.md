# RISExArena UI Design Prompt

## Project Overview

Design a **PvP trading battle platform** called **RISExArena** where traders compete in real-time battles while spectators watch, engage, and participate in prediction markets. This is NOT a traditional trading dashboard—it's an **entertainment-first, esports-style viewing experience** for competitive trading.

---

## Brand Identity (Strict Adherence Required)

### Color Palette

- **Primary Background**: Pure Black `#000000` / Deep Black `#0A0A0A`
- **Primary Accent**: RISEx Green `#00D991` (vibrant, electric green)
- **Secondary Text**: White `#FFFFFF` and Gray variants
- **Supporting Colors**: Dark grays for cards/containers

### Typography

- **Display/Headlines**: **SPEEDAY** (Bold for emphasis, Regular for subheads) — aggressive, angular, futuristic racing aesthetic
- **Body/UI Text**: **Geist Mono** — technical, clean, monospace for data-heavy elements
- **Hierarchy**: Use SPEEDAY for battle titles, player names, dramatic moments; Geist Mono for stats, numbers, feeds, chat

### Art Style

- **ASCII / Halftone / Dither** aesthetic throughout
- Matrix-style cascading characters as background texture
- Retro-digital, terminal-inspired visual language
- Subtle scan lines, pixel noise, and glitch effects where appropriate

### Tone of Voice

- **Energetic / Playfully Aggressive**
- Tagline energy: _"Too fast for average."_
- UI copy should feel bold, competitive, slightly irreverent

### Logo Usage

- RISEx wordmark (white) + X icon (green geometric blocks)
- Maintain clearspace as shown in brand kit
- Add blur background layer when placing over textured backgrounds

---

## Core User Personas

### 1. Spectators (Primary Focus)

- Want entertainment, not complexity
- Engage through prediction markets and chat
- Need clear visual storytelling of the battle
- May watch multiple battles simultaneously

### 2. Traders (Secondary)

- Competing in 1v1v1v1 battles
- Need their own battle interface (separate from spectator view)
- Aware they're being watched and bet on

---

## Key Screens to Design

### Screen 1: Battle Arena Lobby

The main hub where users browse and join live battles.

**Requirements:**

- Grid/list of live battles with preview cards showing:
  - 4 trader avatars/names
  - Current standings (PnL leaderboard)
  - Available trading pairs for that battle
  - Active prediction market count
  - Viewer count
  - Time remaining in battle
- "Hot battles" section highlighting dramatic moments
- Quick filters: By trading pairs, prize pool, battle phase
- Global chat sidebar (collapsible)
- Create/Join battle CTA (for traders)

**Design Direction:**

- Think esports tournament bracket meets trading terminal
- Battle cards should feel like fight cards in MMA/boxing
- Visual hierarchy should emphasize battles with high stakes or dramatic moments

---

### Screen 2: Live Battle Spectator View (CRITICAL - Main Screen)

This is the **primary entertainment experience**. NOT a trading dashboard clone.

**Layout Composition:**

#### A. Central Price Chart (40% of viewport)

- Clean, focused candlestick chart using **TradingView Lightweight Charts**
- **Trading pair selector** tabs above chart (BTC/USD, ETH/USD, SOL/USD)
- **Position visualization overlay**:
  - Price lines showing each trader's entry positions (color-coded per trader)
  - Liquidation price lines (dashed, red/orange tinted)
  - Color scheme: CryptoKing (#a855f7 purple), BearSlayer (#38bdf8 blue), ShortQueen (#f87171 red), LongLord (#fbbf24 yellow)
- Time interval selector (1m, 5m, 15m, 1h buttons)
- **Price display overlay** (top-left): Current price + percentage change
- **Position legend** (top-right): Lists active positions with trader colors and LONG/SHORT indicators
- RISEx brand styling: Green (#00D991) for bullish candles, red (#ef4444) for bearish, dark transparent background

#### B. Trader Cards (Bottom grid)

- 4 trader cards in a responsive grid (2 cols mobile, 4 cols desktop)
- Each card shows:
  - Position badge (#1-#4) with color-coded background
  - Avatar initial + Username
  - Current PnL (green for profit, red for loss)
  - Open positions summary (side, leverage, pair)
  - Liquidation distance progress bar (green >50%, red ≤50%)
  - Win/loss streak indicator
  - "DANGER" badge when liquidation distance < 30%
- Cards have distinct border colors matching trader (primary/info/warning/error)
- Danger zone cards have pulsing animation and red tinted background

#### C. Unified Battle Chat (Right sidebar)

The Action Feed and Chat have been **merged into a single unified chat interface**:

- **Tab system**: "BATTLE CHAT" and "GLOBAL" tabs
- **Battle Chat** includes both user messages AND trader action events interleaved chronologically
- **Message types with distinct styling**:
  - **User messages**: Standard chat bubble with username and timestamp
  - **Trade opens**: Green left border, primary tinted background, trader color indicator
  - **Trade closes (win)**: Blue left border, profit text color
  - **Trade closes (loss)**: Red left border, loss text color
  - **Liquidations**: Red left border, red tinted background
  - **System messages**: Yellow/warning centered text (e.g., "BearSlayer is revenge trading...")
- Each action shows trader's color dot, name, action description, and timestamp
- Chat input with Send button at bottom
- Global chat shows only user messages from across all battles

#### D. Prediction Markets Panel (Left sidebar)

- Active prediction markets for this battle
- Each market card shows:
  - Question/Title (e.g., "Who gets liquidated first?")
  - Options with current odds (clickable buttons)
  - Total pool size
  - Time remaining
- Compact card design with hover states

#### E. Battle Timeline Bar (Between chart and trader cards)

A horizontal timeline showing the narrative arc of the battle:

- **Visual format**: Horizontal track with gradient progress bar (elapsed time)
- **Event markers with distinct icons**:
  - Position opens: Colored dot with ring effect (matches trader color)
  - Position closes: Smaller colored dot
  - Liquidations: 💀 Skull emoji with pulsing red background
  - Lead changes: 👑 Crown emoji on yellow background
  - Big wins: ▲ Green up arrow on trader-colored background
  - Big losses: ▼ Red down arrow on trader-colored background
- **Interactivity**:
  - Fixed-size hit areas prevent hover flicker
  - Hover shows tooltip with trader name, timestamp, description, and PnL
  - Scale effect on hover (1.25x)
- **Live indicator**: Pulsing green dot showing current position with ping animation
- **Time labels**: 0:00, 7:30, 15:00, 22:30, 30:00 markers
- **Placeholder text**: "Hover over events to see details" when no event selected
- Fixed-height tooltip container prevents layout shifts

#### F. Battle Status Bar (Top)

- Battle title/ID (e.g., "BATTLE #1337")
- LIVE badge with pulse animation
- Viewer count
- Prize pool display
- Time remaining

**Design Direction:**

- Think Twitch meets Bloomberg terminal meets esports HUD
- Drama and tension should be visually communicated
- Liquidation events should feel like eliminations in a battle royale
- Winner's card should have glory effects (glow, particles)
- The chart should feel like a battlefield, not a spreadsheet

---

### Screen 3: Prediction Market Detail Modal

When user clicks into a specific prediction market:

**Requirements:**

- Full market title and description
- Clear visualization of odds (bar chart, pie chart, or similar)
- All betting options with:
  - Current odds
  - Total amount bet
  - Number of bettors
- Bet input:
  - Amount selector
  - Potential payout calculator
  - Confirm bet button
- Market history/price movement chart (optional)
- Recent bets ticker
- Rules and resolution criteria
- Time remaining countdown

---

### Screen 4: User Profile/Dashboard

**Requirements:**

- Betting history with P&L
- Favorite battles/traders to follow
- Wallet balance and transaction history
- Badges/achievements
- Leaderboard position (spectator rankings)
- Settings

---

### Screen 5: Battle Results Summary

Shown when a battle concludes:

**Requirements:**

- Final standings podium (1st, 2nd, 3rd, 4th)
- Each trader's final PnL
- Key moments replay carousel
- Prediction market outcomes
- User's personal betting P&L for this battle
- "Watch replay" and "Share results" CTAs

---

## UI Components Library

Design these reusable components:

1. **Trader Card** - Compact player status display with PnL, positions, liquidation bar
2. **Price Chart with Position Overlay** - Candlestick chart with trader position price lines
3. **Battle Timeline** - Horizontal event timeline with hover tooltips and live indicator
4. **Chat Message** - Unified message component supporting user, action, and system types
5. **Prediction Market Card** - Compact betting interface with odds
6. **Bet Slip** - Amount input and confirmation
7. **Battle Preview Card** - For lobby grid
8. **Timer/Countdown** - Various sizes
9. **PnL Display** - With color states (profit green, loss red)
10. **Liquidation Warning** - DANGER badge + pulsing card effect
11. **Navigation Header** - With wallet connection
12. **Toast Notifications** - For important events

---

## Interaction & Animation Requirements

### Critical Moments (High Drama)

- **Liquidation Event**: Screen shake, glitch effect, elimination sound cue placeholder, trader card "death" animation
- **Position Open/Close**: Smooth animation of marker appearing on chart
- **Big Win**: Celebration particles, glow effects
- **Market Resolution**: Reveal animation for winning outcome
- **Timeline Events**: New events pop onto timeline with subtle bounce, liquidations get skull icon with emphasis pulse

### Micro-interactions

- Hover states on all interactive elements
- Number counters should animate when values change
- Chat messages should slide in smoothly
- Odds should animate when changing
- Trader cards should pulse subtly when action taken
- Timeline nodes expand on hover to show details
- Timeline scrubbing should update chart in real-time

### Transitions

- Smooth page transitions
- Modal overlays with backdrop blur
- Tab switches should be instant/snappy

---

## Technical Specifications

- **Framework**: SvelteKit with TypeScript (Svelte 5 with runes)
- **Styling**: Tailwind CSS v4 with DaisyUI
- **Charts**: TradingView Lightweight Charts (`lightweight-charts` npm package)
- **Animations**: CSS animations (Tailwind's animate-pulse, animate-ping) + transitions
- **Icons**: Emoji icons (💀👑▲▼) + custom SVG
- **Fonts**: Self-hosted SPEEDAY (display) + Geist Mono (UI/data)
- **Responsive**: Desktop-first, 3-column layout (markets | main | chat) with responsive breakpoints

---

## Design Deliverables

1. **High-fidelity mockups** for all 5 screens
2. **Component library** with all states
3. **Interaction specifications** for animations
4. **Mobile responsive variants** (at minimum: battle spectator view)
5. **Dark mode only** (per brand guidelines)

---

## Reference Inspiration

- Polymarket (prediction markets UX)
- Twitch (live streaming layouts, chat)
- ESPN/sports betting apps (live odds display)
- Blast.tv / HLTV (esports spectator UI)
- Bloomberg Terminal (data density done right)
- Hyperliquid / dYdX (perps trading UI elements to NOT copy)

---

## Key Design Principles

1. **Entertainment First**: This is a spectator sport, not a tool
2. **Clarity in Chaos**: 4 traders, multiple markets, lots of data—but still readable
3. **Drama Amplification**: Design should heighten tension and excitement
4. **Brand Consistency**: ASCII aesthetic, SPEEDAY + Geist, green on black
5. **Betting Should Be Frictionless**: Quick bets, clear odds, instant feedback

---

## What NOT to Do

- ❌ Don't make it look like a standard perps trading dashboard
- ❌ Don't use light mode or pastel colors
- ❌ Don't overcrowd the chart with indicators
- ❌ Don't make betting feel hidden or secondary
- ❌ Don't use generic UI kit components without brand styling
- ❌ Don't forget the entertainment/gamification layer

---

## Success Criteria

The design is successful if:

- A spectator can understand the battle state within 5 seconds
- Placing a prediction bet takes fewer than 3 clicks
- Liquidation events feel dramatic and memorable
- The interface looks like nothing else in DeFi/trading
- Users want to share screenshots because it looks cool

---

_"Built for traders. Watched by everyone."_
