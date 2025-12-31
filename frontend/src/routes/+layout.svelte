<script lang="ts">
	import './layout.css';
	import favicon from '$lib/assets/favicon.svg';
	import Navbar from '$lib/components/Navbar.svelte';
	import MatrixBackground from '$lib/components/MatrixBackground.svelte';

	let { children } = $props();
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
	<title>RISExArena - PvP Trading Battles</title>
	<meta
		name="description"
		content="Watch traders compete in real-time battles. Bet on outcomes. Win big."
	/>
</svelte:head>

<div class="flex min-h-screen flex-col bg-base-100">
	<MatrixBackground />
	<Navbar />
	<main class="flex-1">
		{@render children()}
	</main>
</div>
