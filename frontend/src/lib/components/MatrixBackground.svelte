<script lang="ts">
	import { onMount } from 'svelte';

	let canvas: HTMLCanvasElement;
	let animationId: number;

	const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789$%&@#';
	const fontSize = 14;
	const primaryGreen = '#00D991';

	onMount(() => {
		const ctx = canvas.getContext('2d');
		if (!ctx) return;

		const resize = () => {
			canvas.width = window.innerWidth;
			canvas.height = window.innerHeight;
		};
		resize();
		window.addEventListener('resize', resize);

		const columns = Math.floor(canvas.width / fontSize);
		const drops: number[] = Array(columns).fill(1);

		const draw = () => {
			ctx.fillStyle = 'rgba(0, 0, 0, 0.05)';
			ctx.fillRect(0, 0, canvas.width, canvas.height);

			ctx.fillStyle = primaryGreen;
			ctx.font = `${fontSize}px "Geist Mono", monospace`;

			for (let i = 0; i < drops.length; i++) {
				const char = chars[Math.floor(Math.random() * chars.length)];
				const x = i * fontSize;
				const y = drops[i] * fontSize;

				ctx.globalAlpha = Math.random() * 0.3 + 0.1;
				ctx.fillText(char, x, y);

				if (y > canvas.height && Math.random() > 0.975) {
					drops[i] = 0;
				}
				drops[i]++;
			}

			animationId = requestAnimationFrame(draw);
		};

		draw();

		return () => {
			window.removeEventListener('resize', resize);
			cancelAnimationFrame(animationId);
		};
	});
</script>

<canvas bind:this={canvas} class="pointer-events-none fixed inset-0 -z-10 opacity-30"></canvas>
