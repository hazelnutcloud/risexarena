<script lang="ts">
	// Redirect to a demo battle for now
</script>

<svelte:head>
	<title>Live Battles - RISExArena</title>
</svelte:head>

<div class="container mx-auto px-4 py-8">
	<div class="mb-8 text-center">
		<div class="relative flex h-3 w-3 justify-center mx-auto mb-4">
			<span class="absolute inline-flex h-full w-full animate-ping rounded-full bg-error opacity-75"></span>
			<span class="relative inline-flex h-3 w-3 rounded-full bg-error"></span>
		</div>
		<h1 class="font-display mb-4 text-4xl font-bold tracking-wider md:text-5xl">
			<span class="text-white">LIVE</span>
			<span class="text-primary text-glow">BATTLES</span>
		</h1>
		<p class="font-mono text-base-content/70">Select a battle to start watching</p>
	</div>

	<div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
		{#each [1, 2, 3, 4, 5, 6] as id (id)}
			<a
				href="/battle/battle-{id}"
				class="group relative overflow-hidden rounded-lg border border-base-300 bg-base-200/50 p-6 transition-all hover:border-primary/50 hover:bg-base-200/80"
			>
				<div class="flex items-center justify-between mb-4">
					<span class="font-display text-lg font-bold">BATTLE #{id}</span>
					<span class="badge badge-error badge-sm animate-pulse font-mono">LIVE</span>
				</div>
				
				<div class="flex items-center justify-between font-mono text-sm mb-4">
					<span class="text-base-content/60">4 traders competing</span>
					<span class="text-primary">BTC/USD</span>
				</div>
				
				<div class="flex items-center justify-between font-mono text-xs">
					<span class="text-base-content/60">
						<span class="text-white">{(1000 + id * 234).toLocaleString()}</span> watching
					</span>
					<span class="font-semibold text-primary">${(25000 + id * 12500).toLocaleString()}</span>
				</div>
			</a>
		{/each}
	</div>
</div>
