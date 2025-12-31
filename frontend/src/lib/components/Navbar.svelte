<script lang="ts">
	import { page } from '$app/stores';

	const navItems = [
		{ href: '/', label: 'ARENA', icon: 'battles' },
		{ href: '/battle', label: 'LIVE', icon: 'live' },
		{ href: '/profile', label: 'PROFILE', icon: 'profile' }
	] as const;

	let isWalletConnected = $state(false);
</script>

<nav class="navbar sticky top-0 z-50 border-b border-base-300 bg-base-100/80 backdrop-blur-md">
	<div class="navbar-start">
		<a href="/" class="flex items-center gap-2">
			<div class="flex items-center gap-1">
				<span class="font-display text-2xl font-bold tracking-wider text-white">RISE</span>
				<span class="font-display text-2xl font-bold tracking-wider text-primary">X</span>
			</div>
			<span class="badge badge-primary badge-sm font-mono">ARENA</span>
		</a>
	</div>

	<div class="navbar-center hidden lg:flex">
		<ul class="menu menu-horizontal gap-1 px-1">
			{#each navItems as item (item.href)}
				{@const isActive = $page.url.pathname === item.href}
				<li>
					<a
						href={item.href}
						class="font-mono text-sm tracking-wide {isActive
							? 'bg-primary/10 text-primary'
							: 'text-base-content/70 hover:text-primary'}"
					>
						{#if item.icon === 'battles'}
							<svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path
									stroke-linecap="round"
									stroke-linejoin="round"
									stroke-width="2"
									d="M4 6h16M4 12h16M4 18h16"
								/>
							</svg>
						{:else if item.icon === 'live'}
							<span class="relative flex h-2 w-2">
								<span
									class="absolute inline-flex h-full w-full animate-ping rounded-full bg-error opacity-75"
								></span>
								<span class="relative inline-flex h-2 w-2 rounded-full bg-error"></span>
							</span>
						{:else if item.icon === 'profile'}
							<svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path
									stroke-linecap="round"
									stroke-linejoin="round"
									stroke-width="2"
									d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
								/>
							</svg>
						{/if}
						{item.label}
					</a>
				</li>
			{/each}
		</ul>
	</div>

	<div class="navbar-end gap-2">
		<div class="hidden items-center gap-2 font-mono text-sm sm:flex">
			<span class="text-base-content/50">POOL:</span>
			<span class="font-semibold text-primary">$1.2M</span>
		</div>

		<div class="dropdown dropdown-end lg:hidden">
			<button class="btn btn-ghost btn-square" aria-label="Open navigation menu">
				<svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
					<path
						stroke-linecap="round"
						stroke-linejoin="round"
						stroke-width="2"
						d="M4 6h16M4 12h16M4 18h16"
					/>
				</svg>
			</button>
			<ul class="menu dropdown-content z-50 mt-3 w-52 rounded-box bg-base-200 p-2 shadow-lg">
				{#each navItems as item (item.href)}
					<li>
						<a href={item.href} class="font-mono">{item.label}</a>
					</li>
				{/each}
			</ul>
		</div>

		{#if isWalletConnected}
			<button class="btn btn-ghost btn-sm font-mono">
				<span class="h-2 w-2 rounded-full bg-success"></span>
				0x1234...5678
			</button>
		{:else}
			<button
				class="btn btn-primary btn-sm glow-primary font-mono"
				onclick={() => (isWalletConnected = true)}
			>
				CONNECT
			</button>
		{/if}
	</div>
</nav>
