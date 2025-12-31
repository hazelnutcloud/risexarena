<script lang="ts">
	// Mock user data
	const user = {
		username: 'TradingPro',
		address: '0x1234...5678',
		balance: 12500,
		totalBets: 156,
		winRate: 62,
		totalPnL: 4520,
		rank: 234
	};

	const bettingHistory = [
		{
			id: 1,
			battle: 'Battle #1234',
			market: 'Who gets liquidated first?',
			pick: 'BearSlayer',
			odds: 2.1,
			amount: 100,
			result: 'win',
			pnl: 110
		},
		{
			id: 2,
			battle: 'Battle #1233',
			market: 'Highest PnL?',
			pick: 'CryptoKing',
			odds: 1.8,
			amount: 250,
			result: 'win',
			pnl: 200
		},
		{
			id: 3,
			battle: 'Battle #1232',
			market: 'First to $1000?',
			pick: 'LongLord',
			odds: 3.5,
			amount: 50,
			result: 'loss',
			pnl: -50
		}
	];

	const badges = [
		{ id: 1, name: 'Early Adopter', icon: '1', earned: true },
		{ id: 2, name: '10 Win Streak', icon: 'F', earned: true },
		{ id: 3, name: 'Whale Watcher', icon: 'W', earned: false },
		{ id: 4, name: 'Market Maker', icon: 'M', earned: true }
	];
</script>

<svelte:head>
	<title>Profile - RISExArena</title>
</svelte:head>

<div class="container mx-auto px-4 py-8">
	<!-- Profile Header -->
	<section class="mb-8 flex flex-col items-center gap-6 md:flex-row md:items-start">
		<div class="flex h-24 w-24 items-center justify-center rounded-full bg-primary text-4xl font-bold">
			{user.username.charAt(0)}
		</div>
		<div class="flex-1 text-center md:text-left">
			<h1 class="font-display mb-2 text-3xl font-bold tracking-wider">{user.username}</h1>
			<p class="font-mono text-base-content/60">{user.address}</p>
			<div class="mt-4 flex flex-wrap justify-center gap-4 md:justify-start">
				<div class="rounded-lg border border-base-300 bg-base-200/50 px-4 py-2">
					<div class="font-mono text-xs text-base-content/60">BALANCE</div>
					<div class="font-display text-xl font-bold text-primary">
						${user.balance.toLocaleString()}
					</div>
				</div>
				<div class="rounded-lg border border-base-300 bg-base-200/50 px-4 py-2">
					<div class="font-mono text-xs text-base-content/60">WIN RATE</div>
					<div class="font-display text-xl font-bold text-white">{user.winRate}%</div>
				</div>
				<div class="rounded-lg border border-base-300 bg-base-200/50 px-4 py-2">
					<div class="font-mono text-xs text-base-content/60">TOTAL P&L</div>
					<div class="text-profit font-display text-xl font-bold">
						+${user.totalPnL.toLocaleString()}
					</div>
				</div>
				<div class="rounded-lg border border-base-300 bg-base-200/50 px-4 py-2">
					<div class="font-mono text-xs text-base-content/60">RANK</div>
					<div class="font-display text-xl font-bold text-white">#{user.rank}</div>
				</div>
			</div>
		</div>
	</section>

	<div class="grid gap-8 lg:grid-cols-3">
		<!-- Betting History -->
		<section class="lg:col-span-2">
			<h2 class="font-display mb-4 text-xl font-bold tracking-wider">BETTING HISTORY</h2>
			<div class="overflow-x-auto rounded-lg border border-base-300">
				<table class="table font-mono text-sm">
					<thead>
						<tr class="text-base-content/60">
							<th>Battle</th>
							<th>Market</th>
							<th>Pick</th>
							<th>Amount</th>
							<th>Result</th>
						</tr>
					</thead>
					<tbody>
						{#each bettingHistory as bet (bet.id)}
							<tr class="hover:bg-base-200/50">
								<td>{bet.battle}</td>
								<td class="max-w-32 truncate">{bet.market}</td>
								<td>
									{bet.pick}
									<span class="text-base-content/50">@{bet.odds}x</span>
								</td>
								<td>${bet.amount}</td>
								<td>
									<span
										class="font-semibold"
										class:text-profit={bet.result === 'win'}
										class:text-loss={bet.result === 'loss'}
									>
										{bet.result === 'win' ? '+' : ''}{bet.pnl >= 0 ? '+' : ''}${Math.abs(bet.pnl)}
									</span>
								</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		</section>

		<!-- Badges & Stats -->
		<section>
			<h2 class="font-display mb-4 text-xl font-bold tracking-wider">BADGES</h2>
			<div class="grid grid-cols-2 gap-3">
				{#each badges as badge (badge.id)}
					<div
						class="flex flex-col items-center rounded-lg border p-4 text-center transition-all {badge.earned
							? 'border-primary/50 bg-primary/10'
							: 'border-base-300 bg-base-200/30 opacity-50'}"
					>
						<div
							class="mb-2 flex h-12 w-12 items-center justify-center rounded-full text-xl font-bold {badge.earned
								? 'bg-primary text-primary-content'
								: 'bg-base-300 text-base-content/50'}"
						>
							{badge.icon}
						</div>
						<span class="font-mono text-xs">{badge.name}</span>
					</div>
				{/each}
			</div>

			<h2 class="font-display mb-4 mt-8 text-xl font-bold tracking-wider">QUICK STATS</h2>
			<div class="space-y-3">
				<div
					class="flex items-center justify-between rounded-lg border border-base-300 bg-base-200/50 p-3"
				>
					<span class="font-mono text-sm text-base-content/60">Total Bets</span>
					<span class="font-mono font-semibold">{user.totalBets}</span>
				</div>
				<div
					class="flex items-center justify-between rounded-lg border border-base-300 bg-base-200/50 p-3"
				>
					<span class="font-mono text-sm text-base-content/60">Battles Watched</span>
					<span class="font-mono font-semibold">89</span>
				</div>
				<div
					class="flex items-center justify-between rounded-lg border border-base-300 bg-base-200/50 p-3"
				>
					<span class="font-mono text-sm text-base-content/60">Favorite Trader</span>
					<span class="font-mono font-semibold text-primary">CryptoKing</span>
				</div>
			</div>
		</section>
	</div>
</div>
