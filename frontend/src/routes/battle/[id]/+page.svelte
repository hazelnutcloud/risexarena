<script lang="ts">
	import { page } from '$app/state';
	import { onMount } from 'svelte';
	import {
		createChart,
		CandlestickSeries,
		type IChartApi,
		type ISeriesApi,
		type CandlestickData,
		type Time
	} from 'lightweight-charts';

	let chartContainer: HTMLDivElement | undefined = $state();
	let chart: IChartApi | null = null;
	let candlestickSeries: ISeriesApi<'Candlestick'> | null = null;

	// Mock candlestick data (BTC/USD-like prices)
	const generateCandlestickData = (): CandlestickData<Time>[] => {
		const data: CandlestickData<Time>[] = [];
		const baseTime = Math.floor(Date.now() / 1000) - 3600 * 24; // 24 hours ago
		let lastClose = 67500;

		for (let i = 0; i < 100; i++) {
			const time = (baseTime + i * 60 * 15) as Time; // 15 min intervals
			const volatility = 200 + Math.random() * 300;
			const change = (Math.random() - 0.5) * volatility;
			const open = lastClose;
			const close = open + change;
			const high = Math.max(open, close) + Math.random() * 100;
			const low = Math.min(open, close) - Math.random() * 100;
			lastClose = close;

			data.push({ time, open, high, low, close });
		}
		return data;
	};

	// Position markers data for each trader
	const traderPositionMarkers = [
		{
			traderId: 1,
			name: 'CryptoKing',
			color: '#a855f7', // primary purple
			entry: 67420,
			liquidation: 64000,
			takeProfit: 72000,
			side: 'LONG' as const
		},
		{
			traderId: 2,
			name: 'BearSlayer',
			color: '#38bdf8', // info blue
			entry: 68100,
			liquidation: 71000,
			takeProfit: 65000,
			side: 'SHORT' as const
		},
		{
			traderId: 4,
			name: 'ShortQueen',
			color: '#f87171', // error red
			entry: 68100,
			liquidation: 70500,
			takeProfit: 66000,
			side: 'SHORT' as const
		}
	];

	function initChart() {
		if (!chartContainer) return;

		// RISEx brand colors
		chart = createChart(chartContainer, {
			layout: {
				background: { color: 'transparent' },
				textColor: '#9ca3af',
				fontFamily: "'Geist Mono', monospace"
			},
			grid: {
				vertLines: { color: 'rgba(255, 255, 255, 0.05)' },
				horzLines: { color: 'rgba(255, 255, 255, 0.05)' }
			},
			crosshair: {
				mode: 0,
				vertLine: {
					color: '#00D991',
					width: 1,
					style: 2,
					labelBackgroundColor: '#00D991'
				},
				horzLine: {
					color: '#00D991',
					width: 1,
					style: 2,
					labelBackgroundColor: '#00D991'
				}
			},
			rightPriceScale: {
				borderColor: 'rgba(255, 255, 255, 0.1)',
				scaleMargins: { top: 0.1, bottom: 0.1 }
			},
			timeScale: {
				borderColor: 'rgba(255, 255, 255, 0.1)',
				timeVisible: true,
				secondsVisible: false
			},
			handleScale: { axisPressedMouseMove: true },
			handleScroll: { vertTouchDrag: true }
		});

		// Add candlestick series with RISEx styling
		candlestickSeries = chart.addSeries(CandlestickSeries, {
			upColor: '#00D991',
			downColor: '#ef4444',
			borderUpColor: '#00D991',
			borderDownColor: '#ef4444',
			wickUpColor: '#00D991',
			wickDownColor: '#ef4444'
		});

		candlestickSeries.setData(generateCandlestickData());

		// Add position markers for each trader
		traderPositionMarkers.forEach((marker) => {
			if (!candlestickSeries) return;

			// Add price lines for entry positions
			candlestickSeries.createPriceLine({
				price: marker.entry,
				color: marker.color,
				lineWidth: 2,
				lineStyle: 0, // Solid
				axisLabelVisible: true,
				title: `${marker.name} ${marker.side}`
			});

			// Add liquidation price lines (dashed, red-tinted)
			candlestickSeries.createPriceLine({
				price: marker.liquidation,
				color: marker.side === 'LONG' ? '#ef4444' : '#f97316',
				lineWidth: 1,
				lineStyle: 2, // Dashed
				axisLabelVisible: true,
				title: `${marker.name} LIQ`
			});
		});

		chart.timeScale().fitContent();

		// Handle resize
		const resizeObserver = new ResizeObserver(() => {
			if (chart && chartContainer) {
				chart.applyOptions({
					width: chartContainer.clientWidth,
					height: chartContainer.clientHeight
				});
			}
		});
		resizeObserver.observe(chartContainer);

		return () => {
			resizeObserver.disconnect();
			chart?.remove();
		};
	}

	onMount(() => {
		const cleanup = initChart();
		return cleanup;
	});

	// Update chart when pair changes
	$effect(() => {
		if (selectedPair && candlestickSeries) {
			// In production, this would fetch new data for the selected pair
			candlestickSeries.setData(generateCandlestickData());
			chart?.timeScale().fitContent();
		}
	});

	// Mock data for battle spectator view
	const tradersData = [
		{
			id: 1,
			name: 'CryptoKing',
			pnl: 2450,
			positions: [{ pair: 'BTC/USD', side: 'LONG', leverage: '10x', entry: 67420, size: 5000 }],
			liquidationDistance: 85,
			streak: 3
		},
		{
			id: 2,
			name: 'BearSlayer',
			pnl: -890,
			positions: [{ pair: 'ETH/USD', side: 'SHORT', leverage: '5x', entry: 3240, size: 2500 }],
			liquidationDistance: 45,
			streak: -2
		},
		{
			id: 3,
			name: 'LongLord',
			pnl: 1200,
			positions: [],
			liquidationDistance: 100,
			streak: 1
		},
		{
			id: 4,
			name: 'ShortQueen',
			pnl: -340,
			positions: [{ pair: 'BTC/USD', side: 'SHORT', leverage: '3x', entry: 68100, size: 1500 }],
			liquidationDistance: 72,
			streak: 0
		}
	];

	// Sort traders by PnL (highest first) and assign position/color
	const positionColors = ['primary', 'info', 'warning', 'error'] as const;
	const traders = tradersData
		.sort((a, b) => b.pnl - a.pnl)
		.map((trader, index) => ({
			...trader,
			position: index + 1,
			color: positionColors[index]
		}));

	const predictionMarkets = [
		{
			id: 1,
			question: 'Who gets liquidated first?',
			options: [
				{ name: 'CryptoKing', odds: 8.5 },
				{ name: 'BearSlayer', odds: 2.1 },
				{ name: 'LongLord', odds: 12.0 },
				{ name: 'ShortQueen', odds: 4.5 }
			],
			totalPool: 12500,
			timeRemaining: '14:32'
		},
		{
			id: 2,
			question: 'Highest PnL in next 30 min?',
			options: [
				{ name: 'CryptoKing', odds: 1.8 },
				{ name: 'BearSlayer', odds: 5.2 },
				{ name: 'LongLord', odds: 3.1 },
				{ name: 'ShortQueen', odds: 6.8 }
			],
			totalPool: 8900,
			timeRemaining: '29:45'
		}
	];

	// Unified chat messages (includes both user messages and action events)
	type ChatMessageType = 'user' | 'action_open' | 'action_close' | 'action_liquidation' | 'system';

	interface ChatMessage {
		id: number;
		type: ChatMessageType;
		username?: string;
		trader?: string;
		traderColor?: string;
		content: string;
		time: string;
		pnlType?: 'win' | 'loss';
	}

	const battleChatMessages: ChatMessage[] = [
		{
			id: 1,
			type: 'action_open',
			trader: 'CryptoKing',
			traderColor: '#a855f7',
			content: 'opened LONG 10x BTC @ $67,420',
			time: '2s ago'
		},
		{
			id: 2,
			type: 'user',
			username: 'degen_andy',
			content: 'CryptoKing going full send! 🚀',
			time: '15s ago'
		},
		{
			id: 3,
			type: 'action_close',
			trader: 'BearSlayer',
			traderColor: '#38bdf8',
			content: 'closed position -$890',
			time: '45s ago',
			pnlType: 'loss'
		},
		{
			id: 4,
			type: 'user',
			username: 'whale_watcher',
			content: 'RIP BearSlayer lmao',
			time: '50s ago'
		},
		{
			id: 5,
			type: 'action_open',
			trader: 'ShortQueen',
			traderColor: '#f87171',
			content: 'opened SHORT 3x BTC @ $68,100',
			time: '1m ago'
		},
		{
			id: 6,
			type: 'user',
			username: 'trade_goblin',
			content: 'shorting the top? bold move',
			time: '1m ago'
		},
		{
			id: 7,
			type: 'action_close',
			trader: 'LongLord',
			traderColor: '#fbbf24',
			content: 'closed position +$1,200',
			time: '2m ago',
			pnlType: 'win'
		},
		{
			id: 8,
			type: 'user',
			username: 'moon_boy_99',
			content: 'LongLord taking profits like a pro',
			time: '2m ago'
		},
		{
			id: 9,
			type: 'action_open',
			trader: 'BearSlayer',
			traderColor: '#38bdf8',
			content: 'opened SHORT 5x ETH @ $3,240',
			time: '3m ago'
		},
		{ id: 10, type: 'system', content: 'BearSlayer is revenge trading...', time: '3m ago' }
	];

	const globalChatMessages: ChatMessage[] = [
		{
			id: 1,
			type: 'user',
			username: 'crypto_chad',
			content: 'Battle #1337 is crazy rn',
			time: '10s ago'
		},
		{
			id: 2,
			type: 'user',
			username: 'perp_queen',
			content: 'who else watching CryptoKing?',
			time: '30s ago'
		},
		{
			id: 3,
			type: 'user',
			username: 'leverage_larry',
			content: 'BearSlayer down bad 💀',
			time: '1m ago'
		}
	];

	function formatPnL(pnl: number): string {
		const prefix = pnl >= 0 ? '+' : '';
		return `${prefix}$${Math.abs(pnl).toLocaleString()}`;
	}

	// Timeline event types
	type TimelineEventType =
		| 'position_open'
		| 'position_close'
		| 'liquidation'
		| 'lead_change'
		| 'big_win'
		| 'big_loss';

	interface TimelineEvent {
		id: number;
		type: TimelineEventType;
		trader: string;
		traderColor: string;
		timestamp: number; // Minutes from battle start
		description: string;
		pnl?: number;
		newLeader?: string;
	}

	// Battle timeline data (mock)
	const battleStartTime = '10:00';
	const battleDuration = 30; // minutes
	const currentTime = 15.5; // 15.5 minutes elapsed

	const timelineEvents: TimelineEvent[] = [
		{
			id: 1,
			type: 'position_open',
			trader: 'CryptoKing',
			traderColor: '#a855f7',
			timestamp: 0.5,
			description: 'Opened LONG 10x BTC'
		},
		{
			id: 2,
			type: 'position_open',
			trader: 'BearSlayer',
			traderColor: '#38bdf8',
			timestamp: 1,
			description: 'Opened SHORT 5x ETH'
		},
		{
			id: 3,
			type: 'position_open',
			trader: 'ShortQueen',
			traderColor: '#f87171',
			timestamp: 2,
			description: 'Opened SHORT 3x BTC'
		},
		{
			id: 4,
			type: 'lead_change',
			trader: 'CryptoKing',
			traderColor: '#a855f7',
			timestamp: 3,
			description: 'Takes the lead',
			newLeader: 'CryptoKing'
		},
		{
			id: 5,
			type: 'big_win',
			trader: 'LongLord',
			traderColor: '#fbbf24',
			timestamp: 5,
			description: 'Closed +$1,200',
			pnl: 1200
		},
		{
			id: 6,
			type: 'position_close',
			trader: 'BearSlayer',
			traderColor: '#38bdf8',
			timestamp: 8,
			description: 'Closed -$890',
			pnl: -890
		},
		{
			id: 7,
			type: 'lead_change',
			trader: 'LongLord',
			traderColor: '#fbbf24',
			timestamp: 9,
			description: 'Takes the lead',
			newLeader: 'LongLord'
		},
		{
			id: 8,
			type: 'position_open',
			trader: 'BearSlayer',
			traderColor: '#38bdf8',
			timestamp: 10,
			description: 'Opened SHORT 5x ETH'
		},
		{
			id: 9,
			type: 'big_win',
			trader: 'CryptoKing',
			traderColor: '#a855f7',
			timestamp: 12,
			description: 'Unrealized +$2,450',
			pnl: 2450
		},
		{
			id: 10,
			type: 'lead_change',
			trader: 'CryptoKing',
			traderColor: '#a855f7',
			timestamp: 13,
			description: 'Takes the lead',
			newLeader: 'CryptoKing'
		}
	];

	// Get position percentage on timeline
	function getEventPosition(timestamp: number): number {
		return (timestamp / battleDuration) * 100;
	}

	// Get current position on timeline
	function getCurrentPosition(): number {
		return (currentTime / battleDuration) * 100;
	}

	let hoveredEvent = $state<TimelineEvent | null>(null);
	let selectedPair = $state('BTC/USD');
	let chatTab = $state<'battle' | 'global'>('battle');
</script>

<svelte:head>
	<title>Battle #{page.params.id} - RISExArena</title>
</svelte:head>

<div class="flex h-[calc(100vh-4rem)] flex-col lg:flex-row">
	<!-- Left Sidebar: Prediction Markets -->
	<aside class="hidden w-72 shrink-0 border-r border-base-300 bg-base-200/50 lg:block">
		<div class="p-4">
			<h2 class="mb-4 flex items-center gap-2 font-display text-lg font-bold tracking-wider">
				<svg class="h-5 w-5 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor">
					<path
						stroke-linecap="round"
						stroke-linejoin="round"
						stroke-width="2"
						d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"
					/>
				</svg>
				MARKETS
			</h2>

			<div class="space-y-4">
				{#each predictionMarkets as market (market.id)}
					<div class="rounded-lg border border-base-300 bg-base-100/50 p-3">
						<h3 class="mb-2 font-mono text-sm font-semibold">{market.question}</h3>
						<div class="space-y-1">
							{#each market.options as option (option.name)}
								<button
									class="flex w-full items-center justify-between rounded bg-base-200 p-2 text-left transition-colors hover:bg-base-300"
								>
									<span class="font-mono text-xs">{option.name}</span>
									<span class="font-mono text-xs font-bold text-primary">{option.odds}x</span>
								</button>
							{/each}
						</div>
						<div
							class="mt-2 flex items-center justify-between font-mono text-xs text-base-content/60"
						>
							<span>${market.totalPool.toLocaleString()} pool</span>
							<span class="text-primary">{market.timeRemaining}</span>
						</div>
					</div>
				{/each}
			</div>
		</div>
	</aside>

	<!-- Main Content: Chart + Trader Cards -->
	<main class="flex flex-1 flex-col overflow-auto">
		<!-- Battle Status Bar -->
		<div
			class="flex items-center justify-between border-b border-base-300 bg-base-200/30 px-4 py-2"
		>
			<div class="flex items-center gap-4">
				<span class="font-display text-lg font-bold">BATTLE #{page.params.id}</span>
				<span class="badge animate-pulse font-mono badge-sm badge-error">LIVE</span>
			</div>
			<div class="flex items-center gap-4 font-mono text-sm">
				<span class="text-base-content/60">
					<span class="font-semibold text-white">1,234</span> watching
				</span>
				<span class="text-base-content/60">
					Prize: <span class="font-semibold text-primary">$50,000</span>
				</span>
				<span class="font-semibold text-primary">14:32</span>
			</div>
		</div>

		<!-- Chart Area -->
		<div class="flex-1 p-4">
			<!-- Pair Selector -->
			<div class="mb-4 flex items-center gap-4">
				<div class="join">
					{#each ['BTC/USD', 'ETH/USD', 'SOL/USD'] as pair (pair)}
						<button
							class="btn join-item font-mono btn-sm {selectedPair === pair
								? 'btn-primary'
								: 'btn-ghost'}"
							onclick={() => (selectedPair = pair)}
						>
							{pair}
						</button>
					{/each}
				</div>
				<div class="join">
					{#each ['1m', '5m', '15m', '1h'] as interval (interval)}
						<button class="btn join-item font-mono btn-ghost btn-xs">{interval}</button>
					{/each}
				</div>
			</div>

			<!-- Chart with Position Overlays -->
			<div class="relative h-100 overflow-hidden rounded-lg border border-base-300 bg-base-200/30">
				<!-- Price Display Overlay -->
				<div class="absolute top-3 left-3 z-10 rounded bg-black/60 px-3 py-2 backdrop-blur-sm">
					<div class="font-mono text-2xl font-bold text-primary">$67,892.45</div>
					<div class="font-mono text-sm text-profit">+2.34%</div>
				</div>

				<!-- Position Legend -->
				<div
					class="absolute top-3 right-3 z-10 space-y-1 rounded bg-black/60 px-3 py-2 backdrop-blur-sm"
				>
					<div class="font-mono text-xs font-semibold text-base-content/70">POSITIONS</div>
					{#each traderPositionMarkers as marker (marker.traderId)}
						<div class="flex items-center gap-2 font-mono text-xs">
							<div class="h-2 w-2 rounded-full" style="background-color: {marker.color}"></div>
							<span class="text-base-content/80">{marker.name}</span>
							<span
								class:text-profit={marker.side === 'LONG'}
								class:text-loss={marker.side === 'SHORT'}
							>
								{marker.side}
							</span>
						</div>
					{/each}
				</div>

				<!-- Lightweight Charts Container -->
				<div bind:this={chartContainer} class="h-full w-full"></div>
			</div>
		</div>

		<!-- Battle Timeline Bar -->
		<div class="border-t border-base-300 bg-base-200/30 px-4 pt-3 pb-6">
			<div class="mb-2 flex items-center justify-between">
				<h3 class="font-display text-xs font-bold tracking-wider text-base-content/70">
					BATTLE TIMELINE
				</h3>
				<div class="flex items-center gap-3 font-mono text-xs text-base-content/50">
					<span>{battleStartTime}</span>
					<span class="text-primary"
						>{Math.floor(currentTime)}:{String(Math.round((currentTime % 1) * 60)).padStart(2, '0')} elapsed</span
					>
				</div>
			</div>

			<!-- Timeline Track -->
			<div class="relative h-10">
				<!-- Background Track -->
				<div
					class="absolute top-1/2 left-0 h-1 w-full -translate-y-1/2 rounded-full bg-base-300"
				></div>

				<!-- Progress Track (elapsed time) -->
				<div
					class="absolute top-1/2 left-0 h-1 -translate-y-1/2 rounded-full bg-gradient-to-r from-primary/50 to-primary"
					style="width: {getCurrentPosition()}%"
				></div>

				<!-- Event Markers -->
				{#each timelineEvents as event (event.id)}
					{@const position = getEventPosition(event.timestamp)}
					<!-- Wrapper with fixed size hit area to prevent hover flicker -->
					<div
						class="absolute top-1/2 z-10 flex h-8 w-8 -translate-x-1/2 -translate-y-1/2 cursor-pointer items-center justify-center"
						style="left: {position}%"
						onmouseenter={() => (hoveredEvent = event)}
						onmouseleave={() => (hoveredEvent = null)}
						role="button"
						tabindex="0"
					>
						<!-- Visual marker with scale effect -->
						<div class="transition-transform duration-200 group-hover:scale-150 hover:scale-125">
							{#if event.type === 'liquidation'}
								<!-- Skull icon for liquidation - highly emphasized -->
								<div
									class="flex h-6 w-6 animate-pulse items-center justify-center rounded-full bg-error text-sm shadow-lg shadow-error/50"
								>
									💀
								</div>
							{:else if event.type === 'lead_change'}
								<!-- Crown icon for lead changes -->
								<div
									class="flex h-5 w-5 items-center justify-center rounded-full bg-warning/20 text-xs"
								>
									👑
								</div>
							{:else if event.type === 'big_win'}
								<!-- Green up arrow for big wins -->
								<div
									class="flex h-4 w-4 items-center justify-center rounded-full text-xs font-bold text-profit"
									style="background-color: {event.traderColor}33"
								>
									▲
								</div>
							{:else if event.type === 'big_loss'}
								<!-- Red down arrow for big losses -->
								<div
									class="flex h-4 w-4 items-center justify-center rounded-full text-xs font-bold text-loss"
									style="background-color: {event.traderColor}33"
								>
									▼
								</div>
							{:else}
								<!-- Colored dot for positions -->
								<div
									class="h-3 w-3 rounded-full border-2 border-base-100 shadow-sm"
									style="background-color: {event.traderColor}"
									class:ring-2={event.type === 'position_open'}
									class:ring-offset-1={event.type === 'position_open'}
									style:--tw-ring-color={event.traderColor}
								></div>
							{/if}
						</div>
					</div>
				{/each}

				<!-- Live Indicator (Current Position) -->
				<div
					class="pointer-events-none absolute top-1/2 z-20 -translate-x-1/2 -translate-y-1/2"
					style="left: {getCurrentPosition()}%"
				>
					<div class="relative">
						<!-- Pulsing outer ring -->
						<div
							class="absolute inset-0 h-4 w-4 animate-ping rounded-full bg-primary opacity-75"
						></div>
						<!-- Solid inner dot -->
						<div
							class="relative h-4 w-4 rounded-full border-2 border-base-100 bg-primary shadow-lg shadow-primary/50"
						></div>
					</div>
				</div>

				<!-- Time markers -->
				<div
					class="pointer-events-none absolute -bottom-4 left-0 font-mono text-[10px] text-base-content/40"
				>
					0:00
				</div>
				<div
					class="pointer-events-none absolute -bottom-4 left-1/4 -translate-x-1/2 font-mono text-[10px] text-base-content/40"
				>
					7:30
				</div>
				<div
					class="pointer-events-none absolute -bottom-4 left-1/2 -translate-x-1/2 font-mono text-[10px] text-base-content/40"
				>
					15:00
				</div>
				<div
					class="pointer-events-none absolute -bottom-4 left-3/4 -translate-x-1/2 font-mono text-[10px] text-base-content/40"
				>
					22:30
				</div>
				<div
					class="pointer-events-none absolute right-0 -bottom-4 font-mono text-[10px] text-base-content/40"
				>
					30:00
				</div>
			</div>

			<!-- Tooltip - fixed height container to prevent layout shift -->
			<div class="relative z-10 mt-2">
				{#if hoveredEvent}
					{@const position = getEventPosition(hoveredEvent.timestamp)}
					<div
						class="absolute top-full right-(--offset-right) left-(--offset-left) rounded border border-base-300 bg-base-100/90 p-2 backdrop-blur-sm"
						style:--offset-left="{position > 50 ? 'auto' : position - 1}%"
						style:--offset-right="{position < 50 ? 'auto' : 100 - position}%"
					>
						<div class="flex items-center gap-2">
							<div
								class="h-2 w-2 rounded-full"
								style="background-color: {hoveredEvent.traderColor}"
							></div>
							<span class="font-mono text-xs font-semibold">{hoveredEvent.trader}</span>
							<span class="font-mono text-xs text-base-content/50">
								@ {Math.floor(hoveredEvent.timestamp)}:{String(
									Math.round((hoveredEvent.timestamp % 1) * 60)
								).padStart(2, '0')}
							</span>
						</div>
						<p class="mt-1 font-mono text-xs text-base-content/80">
							{hoveredEvent.description}
							{#if hoveredEvent.pnl !== undefined}
								<span
									class:text-profit={hoveredEvent.pnl >= 0}
									class:text-loss={hoveredEvent.pnl < 0}
								>
									{hoveredEvent.pnl >= 0 ? '+' : ''}${Math.abs(hoveredEvent.pnl).toLocaleString()}
								</span>
							{/if}
						</p>
					</div>
				{/if}
			</div>
		</div>

		<!-- Trader Cards Grid -->
		<div class="grid grid-cols-2 gap-2 border-t border-base-300 p-4 lg:grid-cols-4">
			{#each traders as trader (trader.id)}
				{@const isInDanger = trader.liquidationDistance < 30}
				<div
					class="relative rounded-lg border p-3 transition-all {isInDanger
						? 'animate-pulse bg-error/10'
						: ''}"
					class:border-primary={trader.color === 'primary'}
					class:border-error={trader.color === 'error'}
					class:border-info={trader.color === 'info'}
					class:border-warning={trader.color === 'warning'}
				>
					<!-- Position Badge -->
					<div
						class="absolute -top-1 -left-1 flex h-6 w-6 items-center justify-center rounded-full font-mono text-xs font-bold"
						class:bg-primary={trader.color === 'primary'}
						class:bg-info={trader.color === 'info'}
						class:bg-warning={trader.color === 'warning'}
						class:bg-error={trader.color === 'error'}
					>
						#{trader.position}
					</div>

					{#if isInDanger}
						<div class="absolute -top-1 -right-1 rounded bg-error px-1 font-mono text-xs font-bold">
							DANGER
						</div>
					{/if}

					<div class="mb-2 flex items-center gap-2 pt-2">
						<div
							class="flex h-8 w-8 items-center justify-center rounded-full text-sm font-bold {trader.color ===
							'primary'
								? 'bg-primary/20 text-primary'
								: trader.color === 'error'
									? 'bg-error/20 text-error'
									: trader.color === 'info'
										? 'bg-info/20 text-info'
										: 'bg-warning/20 text-warning'}"
						>
							{trader.name.charAt(0)}
						</div>
						<div>
							<div class="font-mono text-sm font-semibold">{trader.name}</div>
							<div class="font-mono text-xs text-base-content/60">
								{#if trader.streak > 0}
									<span class="text-profit">{trader.streak}W streak</span>
								{:else if trader.streak < 0}
									<span class="text-loss">{Math.abs(trader.streak)}L streak</span>
								{:else}
									<span>No streak</span>
								{/if}
							</div>
						</div>
					</div>

					<div
						class="font-mono text-xl font-bold"
						class:text-profit={trader.pnl >= 0}
						class:text-loss={trader.pnl < 0}
					>
						{formatPnL(trader.pnl)}
					</div>

					{#if trader.positions.length > 0}
						<div class="mt-2 font-mono text-xs text-base-content/70">
							{#each trader.positions as pos (pos.pair)}
								<div class="flex justify-between">
									<span
										class:text-profit={pos.side === 'LONG'}
										class:text-loss={pos.side === 'SHORT'}
									>
										{pos.side}
										{pos.leverage}
									</span>
									<span>{pos.pair}</span>
								</div>
							{/each}
						</div>
					{:else}
						<div class="mt-2 font-mono text-xs text-base-content/50">No open positions</div>
					{/if}

					<!-- Liquidation Bar -->
					<div class="mt-2">
						<div class="mb-1 flex justify-between font-mono text-xs">
							<span class="text-base-content/50">Liq. Distance</span>
							<span
								class:text-profit={trader.liquidationDistance > 50}
								class:text-loss={trader.liquidationDistance <= 50}
							>
								{trader.liquidationDistance}%
							</span>
						</div>
						<div class="h-1 w-full overflow-hidden rounded-full bg-base-300">
							<div
								class="h-full transition-all"
								class:bg-success={trader.liquidationDistance > 50}
								class:bg-error={trader.liquidationDistance <= 50}
								style="width: {trader.liquidationDistance}%"
							></div>
						</div>
					</div>
				</div>
			{/each}
		</div>
	</main>

	<!-- Right Sidebar: Unified Chat -->
	<aside class="hidden w-80 shrink-0 flex-col border-l border-base-300 bg-base-200/50 xl:flex">
		<!-- Chat Header with Tabs -->
		<div class="flex border-b border-base-300">
			<button
				class="flex-1 px-4 py-3 font-mono text-xs font-semibold tracking-wider transition-colors {chatTab ===
				'battle'
					? 'border-b-2 border-primary bg-primary/10 text-primary'
					: 'text-base-content/60 hover:text-white'}"
				onclick={() => (chatTab = 'battle')}
			>
				BATTLE CHAT
			</button>
			<button
				class="flex-1 px-4 py-3 font-mono text-xs font-semibold tracking-wider transition-colors {chatTab ===
				'global'
					? 'border-b-2 border-primary bg-primary/10 text-primary'
					: 'text-base-content/60 hover:text-white'}"
				onclick={() => (chatTab = 'global')}
			>
				GLOBAL
			</button>
		</div>

		<!-- Chat Messages -->
		<div class="flex-1 gap-y-2 overflow-y-auto p-2 flex flex-col-reverse">
			{#if chatTab === 'battle'}
				{#each battleChatMessages as msg (msg.id)}
					{#if msg.type === 'user'}
						<!-- User chat message -->
						<div class="rounded bg-base-100/30 p-2">
							<div class="flex items-center justify-between">
								<span class="font-mono text-xs font-semibold text-base-content/80"
									>{msg.username}</span
								>
								<span class="font-mono text-[10px] text-base-content/40">{msg.time}</span>
							</div>
							<p class="mt-1 font-mono text-xs text-base-content/70">{msg.content}</p>
						</div>
					{:else if msg.type === 'system'}
						<!-- System message -->
						<div class="rounded border border-warning/20 bg-warning/10 p-2 text-center">
							<p class="font-mono text-xs text-warning/80">{msg.content}</p>
						</div>
					{:else}
						<!-- Action event (trade opened/closed/liquidation) -->
						{@const isOpen = msg.type === 'action_open'}
						{@const isClose = msg.type === 'action_close'}
						{@const isLoss = isClose && msg.pnlType === 'loss'}
						{@const isWin = isClose && msg.pnlType === 'win'}
						{@const isLiquidation = msg.type === 'action_liquidation'}
						<div
							class="rounded border-l-2 p-2
								{isOpen ? 'border-l-primary bg-primary/10' : ''}
								{isClose && !isLoss ? 'border-l-info bg-base-100/50' : ''}
								{isLoss ? 'border-l-error bg-base-100/50' : ''}
								{isLiquidation ? 'border-l-error bg-error/10' : ''}"
						>
							<div class="flex items-center justify-between">
								<div class="flex items-center gap-2">
									<div
										class="h-2 w-2 rounded-full"
										style="background-color: {msg.traderColor}"
									></div>
									<span class="font-mono text-xs font-bold" style="color: {msg.traderColor}">
										{msg.trader}
									</span>
								</div>
								<span class="font-mono text-[10px] text-base-content/40">{msg.time}</span>
							</div>
							<p
								class="mt-1 font-mono text-xs {isWin ? 'text-profit' : ''} {isLoss
									? 'text-loss'
									: ''} {!msg.pnlType ? 'text-base-content/80' : ''}"
							>
								{msg.content}
							</p>
						</div>
					{/if}
				{/each}
			{:else}
				{#each globalChatMessages as msg (msg.id)}
					<div class="rounded bg-base-100/30 p-2">
						<div class="flex items-center justify-between">
							<span class="font-mono text-xs font-semibold text-base-content/80"
								>{msg.username}</span
							>
							<span class="font-mono text-[10px] text-base-content/40">{msg.time}</span>
						</div>
						<p class="mt-1 font-mono text-xs text-base-content/70">{msg.content}</p>
					</div>
				{/each}
			{/if}
		</div>

		<!-- Chat Input -->
		<div class="border-t border-base-300 p-2">
			<div class="flex gap-2">
				<input
					type="text"
					placeholder="Send a message..."
					class="input input-sm flex-1 font-mono text-xs"
				/>
				<button class="btn font-mono text-xs btn-sm btn-primary">Send</button>
			</div>
		</div>
	</aside>
</div>
