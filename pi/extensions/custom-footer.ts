/**
 * Custom status bar for pi.
 *
 * A polished, segmented footer:
 *
 *   ● opus-4-8   ▰▰▰▱▱▱▱▱▱▱ 31%   ↑12.3k ↓4.5k   $0.182      ~/work/arch-dotfiles   main
 *
 * Segments (left → right):
 *   - model        accent dot + bold model id
 *   - context      10-slot meter of last-turn context usage vs the model's
 *                  context window; colors shift green → amber → red as it fills
 *   - tokens       cumulative ↑input / ↓output for the session
 *   - cost         cumulative $ spend for the session
 *   - right group  extension statuses (ctx.ui.setStatus) + cwd path + git branch
 *
 * Enabled by default on session start. Toggle with /footer.
 *
 * Data sources:
 *   - tokens/cost/context  ctx.sessionManager + ctx.model (already accessible)
 *   - git branch + statuses  footerData (not otherwise accessible)
 */

import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

export default function (pi: ExtensionAPI) {
	let enabled = true;

	const fmt = (n: number): string =>
		n < 1000 ? `${n}` : n < 1_000_000 ? `${(n / 1000).toFixed(1)}k` : `${(n / 1_000_000).toFixed(1)}M`;

	const install = (ctx: ExtensionContext) => {
		ctx.ui.setFooter((tui, theme, footerData) => {
			const unsub = footerData.onBranchChange(() => tui.requestRender());

			return {
				dispose: unsub,
				invalidate() {},
				render(width: number): string[] {
					// Aggregate session usage; keep the most recent turn's context size.
					let input = 0,
						output = 0,
						cost = 0,
						lastContext = 0;
					for (const e of ctx.sessionManager.getBranch()) {
						if (e.type === "message" && e.message.role === "assistant") {
							const m = e.message as AssistantMessage;
							input += m.usage.input;
							output += m.usage.output;
							cost += m.usage.cost.total;
							lastContext = m.usage.input + m.usage.cacheRead;
						}
					}

					const sep = "   ";
					const segs: string[] = [];

					// Model
					const model = ctx.model?.id?.replace(/^claude-/, "") ?? "no-model";
					segs.push(theme.fg("accent", "●") + " " + theme.bold(theme.fg("accent", model)));

					// Context meter (only when the model exposes a context window)
					const cw = ctx.model?.contextWindow ?? 0;
					if (cw > 0) {
						const pct = Math.min(1, lastContext / cw);
						const slots = 10;
						const filled = Math.max(0, Math.min(slots, Math.round(pct * slots)));
						const level = pct >= 0.9 ? "error" : pct >= 0.7 ? "warning" : "success";
						const bar =
							theme.fg(level, "▰".repeat(filled)) + theme.fg("dim", "▱".repeat(slots - filled));
						segs.push(bar + theme.fg(level, ` ${Math.round(pct * 100)}%`));
					}

					// Tokens + cost
					segs.push(theme.fg("dim", `↑${fmt(input)} ↓${fmt(output)}`));
					segs.push(theme.fg("dim", `$${cost.toFixed(3)}`));

					const left = " " + segs.join(sep);

					// Right group: extension statuses + cwd path + git branch
					const rightParts: string[] = [];
					const statuses = [...footerData.getExtensionStatuses().values()].filter(Boolean);
					if (statuses.length) rightParts.push(statuses.join(sep));
					const cwd = process.cwd().replace(/^\/home\/[^/]+/, "~");
					rightParts.push(theme.fg("muted", cwd));
					const branch = footerData.getGitBranch();
					if (branch) rightParts.push(theme.fg("accent", branch));
					const right = rightParts.length ? rightParts.join(sep) + " " : "";

					const pad = " ".repeat(Math.max(1, width - visibleWidth(left) - visibleWidth(right)));
					return [truncateToWidth(left + pad + right, width)];
				},
			};
		});
	};

	pi.on("session_start", async (_event, ctx) => {
		if (enabled) install(ctx);
	});

	pi.registerCommand("footer", {
		description: "Toggle the custom status bar",
		handler: async (_args, ctx) => {
			enabled = !enabled;
			if (enabled) {
				install(ctx);
				ctx.ui.notify("Status bar enabled", "info");
			} else {
				ctx.ui.setFooter(undefined);
				ctx.ui.notify("Default footer restored", "info");
			}
		},
	});
}
