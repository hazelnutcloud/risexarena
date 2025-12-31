<script lang="ts">
	import { page } from '$app/stores';

	// Mock battle results data
	const results = {
		id: $page.params.id,
		duration: '45:00',
		prizePool: 50000,
		totalBets: 125000,
		standings: [
			{ rank: 1, name: 'CryptoKing', pnl: 4520, prize: 25000 },
			{ rank: 2, name: 'LongLord', pnl: 2100, prize: 15000 },
			{ rank: 3, name: 'ShortQueen', pnl: -340, prize: 7500 },
			{ rank: 4, name: 'BearSlayer', pnl: -2890, prize: 2500 }
		],
		keyMoments: [
			{ time: '12:34', description: 'CryptoKing opens 10x LONG on BTC' },
			{ time: '23:45', description: 'BearSlayer gets LIQUIDATED!' },
			{ time: '34:56', description: 'CryptoKing closes position +$4,520' }
		],
		userBets: [
			{ market: 'Who wins?', pick: 'CryptoKing', result: 'win', pnl: 450 },
			{ market: 'First liquidation?', pick: 'ShortQueen', result: 'loss', pnl: -100 }
		]
	};

	function formatPnL(pnl: number): string {
		const prefix = pnl >= 0 ? '+' : '';
		return `${prefix}$${Math.abs(pnl).toLocaleString()}`;
	}

	const rankColors = ['bg-yellow-500', 'bg-gray-400', 'bg-amber-700', 'bg-base-300'];
</script>

<svelte:head>
	<title>Battle Results #{$page.params.id} - RISExArena</title>
</svelte:head>

<div class="container mx-auto px-4 py-8">
	<!-- Header -->
	<div class="mb-8 text-center">
		<div class="font-mono mb-2 text-base-content/60">BATTLE COMPLETED</div>
		<h1 class="font-display mb-4 text-4xl font-bold tracking-wider md:text-5xl">
			<span class="text-white">BATTLE</span>
			<span class="text-primary">#{results.id}</span>
		</h1>
		<div class="flex flex-wrap justify-center gap-4 font-mono text-sm">
			<span>Duration: <span class="text-white">{results.duration}</span></span>
			<span>Prize Pool: <span class="text-primary">${results.prizePool.toLocaleString()}</span></span>
			<span>Total Bets: <span class="text-white">${results.totalBets.toLocaleString()}</span></span>
		</div>
	</div>

	<!-- Podium -->
	<section class="mb-12">
		<div class="flex items-end justify-center gap-4">
			<!-- 2nd Place -->
			<div class="flex flex-col items-center">
				<div
					class="mb-2 flex h-16 w-16 items-center justify-center rounded-full bg-gray-400 text-2xl font-bold"
				>
					{results.standings[1].name.charAt(0)}
				</div>
				<div class="font-mono text-sm font-semibold">{results.standings[1].name}</div>
				<div class="text-profit font-mono text-xs">{formatPnL(results.standings[1].pnl)}</div>
				<div
					class="mt-2 flex h-24 w-24 items-center justify-center rounded-t-lg bg-gray-400/20 font-display text-2xl font-bold"
				>
					2
				</div>
			</div>

			<!-- 1st Place -->
			<div class="flex flex-col items-center">
				<div class="glow-primary-lg mb-2 flex h-20 w-20 items-center justify-center rounded-full bg-yellow-500 text-3xl font-bold">
					{results.standings[0].name.charAt(0)}
				</div>
				<div class="font-mono text-lg font-semibold">{results.standings[0].name}</div>
				<div class="text-profit font-mono text-sm font-bold">{formatPnL(results.standings[0].pnl)}</div>
				<div
					class="mt-2 flex h-32 w-28 items-center justify-center rounded-t-lg bg-yellow-500/20 font-display text-3xl font-bold"
				>
					1
				</div>
			</div>

			<!-- 3rd Place -->
			<div class="flex flex-col items-center">
				<div
					class="mb-2 flex h-14 w-14 items-center justify-center rounded-full bg-amber-700 text-xl font-bold"
				>
					{results.standings[2].name.charAt(0)}
				</div>
				<div class="font-mono text-sm font-semibold">{results.standings[2].name}</div>
				<div class="text-loss font-mono text-xs">{formatPnL(results.standings[2].pnl)}</div>
				<div
					class="mt-2 flex h-16 w-20 items-center justify-center rounded-t-lg bg-amber-700/20 font-display text-xl font-bold"
				>
					3
				</div>
			</div>
		</div>
	</section>

	<div class="grid gap-8 lg:grid-cols-2">
		<!-- Final Standings -->
		<section>
			<h2 class="font-display mb-4 text-xl font-bold tracking-wider">FINAL STANDINGS</h2>
			<div class="space-y-2">
				{#each results.standings as standing, i (standing.rank)}
					<div
						class="flex items-center justify-between rounded-lg border border-base-300 bg-base-200/50 p-4"
					>
						<div class="flex items-center gap-4">
							<div
								class="flex h-10 w-10 items-center justify-center rounded-full font-bold {rankColors[
									i
								]}"
							>
								{standing.rank}
							</div>
							<div>
								<div class="font-mono font-semibold">{standing.name}</div>
								<div
									class="font-mono text-sm"
									class:text-profit={standing.pnl >= 0}
									class:text-loss={standing.pnl < 0}
								>
									{formatPnL(standing.pnl)}
								</div>
							</div>
						</div>
						<div class="text-right">
							<div class="font-mono text-xs text-base-content/60">PRIZE</div>
							<div class="font-mono font-bold text-primary">
								${standing.prize.toLocaleString()}
							</div>
						</div>
					</div>
				{/each}
			</div>
		</section>

		<!-- Key Moments -->
		<section>
			<h2 class="font-display mb-4 text-xl font-bold tracking-wider">KEY MOMENTS</h2>
			<div class="space-y-2">
				{#each results.keyMoments as moment, i (i)}
					<div class="flex gap-4 rounded-lg border border-base-300 bg-base-200/50 p-4">
						<div class="font-mono text-sm text-primary">{moment.time}</div>
						<div class="font-mono text-sm">{moment.description}</div>
					</div>
				{/each}
			</div>

			<h2 class="font-display mb-4 mt-8 text-xl font-bold tracking-wider">YOUR BETS</h2>
			{#if results.userBets.length > 0}
				<div class="space-y-2">
					{#each results.userBets as bet, i (i)}
						<div
							class="flex items-center justify-between rounded-lg border border-base-300 bg-base-200/50 p-4"
						>
							<div>
								<div class="font-mono text-sm">{bet.market}</div>
								<div class="font-mono text-xs text-base-content/60">Pick: {bet.pick}</div>
							</div>
							<div
								class="font-mono font-bold"
								class:text-profit={bet.result === 'win'}
								class:text-loss={bet.result === 'loss'}
							>
								{bet.pnl >= 0 ? '+' : ''}${Math.abs(bet.pnl)}
							</div>
						</div>
					{/each}
				</div>
			{:else}
				<div class="rounded-lg border border-base-300 bg-base-200/50 p-4 text-center font-mono text-sm text-base-content/60">
					You didn't place any bets on this battle
				</div>
			{/if}
		</section>
	</div>

	<!-- Actions -->
	<div class="mt-8 flex flex-wrap justify-center gap-4">
		<button class="btn btn-primary font-mono glow-primary">
			<svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z" />
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
			</svg>
			WATCH REPLAY
		</button>
		<button class="btn btn-ghost font-mono">
			<svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 00-5.368-2.684z" />
			</svg>
			SHARE RESULTS
		</button>
		<a href="/" class="btn btn-ghost font-mono">
			BACK TO ARENA
		</a>
	</div>
</div>
