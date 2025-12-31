<script lang="ts">
	// Mock battle data for the lobby
	const liveBattles = [
		{
			id: 'battle-1',
			traders: [
				{ name: 'CryptoKing', pnl: 2450, avatar: '1' },
				{ name: 'BearSlayer', pnl: -890, avatar: '2' },
				{ name: 'LongLord', pnl: 1200, avatar: '3' },
				{ name: 'ShortQueen', pnl: -340, avatar: '4' }
			],
			pairs: ['BTC/USD', 'ETH/USD'],
			viewers: 1234,
			timeRemaining: '14:32',
			prizePool: 50000,
			predictionMarkets: 4,
			isHot: true
		},
		{
			id: 'battle-2',
			traders: [
				{ name: 'WhaleWatch', pnl: 890, avatar: '5' },
				{ name: 'DipBuyer', pnl: 450, avatar: '6' },
				{ name: 'MoonBoi', pnl: -120, avatar: '7' },
				{ name: 'SatoshiSam', pnl: -670, avatar: '8' }
			],
			pairs: ['SOL/USD'],
			viewers: 567,
			timeRemaining: '28:15',
			prizePool: 25000,
			predictionMarkets: 3,
			isHot: false
		},
		{
			id: 'battle-3',
			traders: [
				{ name: 'AlphaTrader', pnl: 3200, avatar: '9' },
				{ name: 'BetaMaker', pnl: 1100, avatar: '10' },
				{ name: 'GammaSeller', pnl: -2100, avatar: '11' },
				{ name: 'DeltaNeutral', pnl: -890, avatar: '12' }
			],
			pairs: ['BTC/USD', 'ETH/USD', 'SOL/USD'],
			viewers: 2341,
			timeRemaining: '05:48',
			prizePool: 100000,
			predictionMarkets: 6,
			isHot: true
		}
	];

	function formatPnL(pnl: number): string {
		const prefix = pnl >= 0 ? '+' : '';
		return `${prefix}$${Math.abs(pnl).toLocaleString()}`;
	}
</script>

<div class="container mx-auto px-4 py-8">
	<!-- Hero Section -->
	<section class="mb-12 text-center">
		<h1 class="font-display mb-4 text-5xl font-bold tracking-wider md:text-7xl">
			<span class="text-white">BATTLE</span>
			<span class="text-primary text-glow">ARENA</span>
		</h1>
		<p class="font-mono mx-auto max-w-2xl text-lg text-base-content/70">
			Watch traders compete in real-time PvP battles. Bet on outcomes. Win big.
		</p>
		<p class="font-display mt-2 text-sm tracking-widest text-primary/80">
			TOO FAST FOR AVERAGE.
		</p>
	</section>

	<!-- Quick Stats -->
	<section class="mb-8 grid grid-cols-2 gap-4 md:grid-cols-4">
		<div class="rounded-lg border border-base-300 bg-base-200/50 p-4 text-center">
			<div class="font-display text-2xl font-bold text-primary">12</div>
			<div class="font-mono text-xs text-base-content/60">LIVE BATTLES</div>
		</div>
		<div class="rounded-lg border border-base-300 bg-base-200/50 p-4 text-center">
			<div class="font-display text-2xl font-bold text-white">4,521</div>
			<div class="font-mono text-xs text-base-content/60">WATCHING NOW</div>
		</div>
		<div class="rounded-lg border border-base-300 bg-base-200/50 p-4 text-center">
			<div class="font-display text-2xl font-bold text-primary">$1.2M</div>
			<div class="font-mono text-xs text-base-content/60">TOTAL POOL</div>
		</div>
		<div class="rounded-lg border border-base-300 bg-base-200/50 p-4 text-center">
			<div class="font-display text-2xl font-bold text-white">89</div>
			<div class="font-mono text-xs text-base-content/60">ACTIVE MARKETS</div>
		</div>
	</section>

	<!-- Filters -->
	<section class="mb-6 flex flex-wrap items-center gap-4">
		<div class="flex items-center gap-2">
			<span class="font-mono text-sm text-base-content/60">FILTER:</span>
			<div class="join">
				<button class="btn join-item btn-sm btn-primary font-mono">ALL</button>
				<button class="btn join-item btn-sm btn-ghost font-mono">BTC</button>
				<button class="btn join-item btn-sm btn-ghost font-mono">ETH</button>
				<button class="btn join-item btn-sm btn-ghost font-mono">SOL</button>
			</div>
		</div>
		<div class="flex items-center gap-2">
			<span class="font-mono text-sm text-base-content/60">SORT:</span>
			<select class="select select-sm font-mono">
				<option>Prize Pool</option>
				<option>Viewers</option>
				<option>Time Left</option>
			</select>
		</div>
	</section>

	<!-- Hot Battles Section -->
	<section class="mb-8">
		<div class="mb-4 flex items-center gap-2">
			<span class="relative flex h-3 w-3">
				<span
					class="absolute inline-flex h-full w-full animate-ping rounded-full bg-error opacity-75"
				></span>
				<span class="relative inline-flex h-3 w-3 rounded-full bg-error"></span>
			</span>
			<h2 class="font-display text-xl font-bold tracking-wider text-white">HOT BATTLES</h2>
		</div>

		<div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
			{#each liveBattles.filter((b) => b.isHot) as battle (battle.id)}
				<a
					href="/battle/{battle.id}"
					class="group relative overflow-hidden rounded-lg border border-primary/30 bg-base-200/80 p-4 transition-all hover:border-primary hover:shadow-lg hover:shadow-primary/20"
				>
					<!-- Hot Badge -->
					<div
						class="absolute right-2 top-2 flex items-center gap-1 rounded bg-error/20 px-2 py-0.5"
					>
						<span class="h-1.5 w-1.5 animate-pulse rounded-full bg-error"></span>
						<span class="font-mono text-xs text-error">HOT</span>
					</div>

					<!-- Battle Header -->
					<div class="mb-4 flex items-center justify-between">
						<div class="font-mono text-xs text-base-content/60">
							{battle.pairs.join(' / ')}
						</div>
						<div class="font-mono text-xs text-primary">{battle.timeRemaining}</div>
					</div>

					<!-- Traders -->
					<div class="mb-4 space-y-2">
						{#each battle.traders as trader, i}
							<div class="flex items-center justify-between">
								<div class="flex items-center gap-2">
									<div
										class="flex h-6 w-6 items-center justify-center rounded-full text-xs font-bold"
										class:bg-primary={i === 0}
										class:bg-error={i === 1}
										class:bg-info={i === 2}
										class:bg-warning={i === 3}
									>
										{i + 1}
									</div>
									<span class="font-mono text-sm">{trader.name}</span>
								</div>
								<span
									class="font-mono text-sm font-semibold"
									class:text-profit={trader.pnl >= 0}
									class:text-loss={trader.pnl < 0}
								>
									{formatPnL(trader.pnl)}
								</span>
							</div>
						{/each}
					</div>

					<!-- Battle Footer -->
					<div
						class="flex items-center justify-between border-t border-base-300 pt-3 font-mono text-xs"
					>
						<div class="flex items-center gap-4">
							<span class="text-base-content/60">
								<span class="text-white">{battle.viewers.toLocaleString()}</span> watching
							</span>
							<span class="text-base-content/60">
								<span class="text-primary">{battle.predictionMarkets}</span> markets
							</span>
						</div>
						<span class="font-semibold text-primary">${battle.prizePool.toLocaleString()}</span>
					</div>
				</a>
			{/each}
		</div>
	</section>

	<!-- All Battles Section -->
	<section>
		<h2 class="font-display mb-4 text-xl font-bold tracking-wider text-white">ALL BATTLES</h2>

		<div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
			{#each liveBattles as battle (battle.id)}
				<a
					href="/battle/{battle.id}"
					class="group relative overflow-hidden rounded-lg border border-base-300 bg-base-200/50 p-4 transition-all hover:border-primary/50 hover:bg-base-200/80"
				>
					<!-- Battle Header -->
					<div class="mb-4 flex items-center justify-between">
						<div class="font-mono text-xs text-base-content/60">
							{battle.pairs.join(' / ')}
						</div>
						<div class="font-mono text-xs text-primary">{battle.timeRemaining}</div>
					</div>

					<!-- Traders -->
					<div class="mb-4 space-y-2">
						{#each battle.traders as trader, i}
							<div class="flex items-center justify-between">
								<div class="flex items-center gap-2">
									<div
										class="flex h-6 w-6 items-center justify-center rounded-full text-xs font-bold"
										class:bg-primary={i === 0}
										class:bg-error={i === 1}
										class:bg-info={i === 2}
										class:bg-warning={i === 3}
									>
										{i + 1}
									</div>
									<span class="font-mono text-sm">{trader.name}</span>
								</div>
								<span
									class="font-mono text-sm font-semibold"
									class:text-profit={trader.pnl >= 0}
									class:text-loss={trader.pnl < 0}
								>
									{formatPnL(trader.pnl)}
								</span>
							</div>
						{/each}
					</div>

					<!-- Battle Footer -->
					<div
						class="flex items-center justify-between border-t border-base-300 pt-3 font-mono text-xs"
					>
						<div class="flex items-center gap-4">
							<span class="text-base-content/60">
								<span class="text-white">{battle.viewers.toLocaleString()}</span> watching
							</span>
							<span class="text-base-content/60">
								<span class="text-primary">{battle.predictionMarkets}</span> markets
							</span>
						</div>
						<span class="font-semibold text-primary">${battle.prizePool.toLocaleString()}</span>
					</div>
				</a>
			{/each}
		</div>
	</section>
</div>
