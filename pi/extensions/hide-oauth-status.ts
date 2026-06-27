import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Suppress the "✓ Claude OAuth ready/active" and "⚠ Claude OAuth setup"
// footer status set by pi-claude-oauth-adapter, without editing the package.
const SUPPRESSED = new Set(["claude-oauth-ready", "claude-oauth-issue"]);
const patched = new WeakSet<object>();

function patch(ui: any) {
  if (!ui || typeof ui.setStatus !== "function" || patched.has(ui)) return;
  patched.add(ui);
  const original = ui.setStatus.bind(ui);
  ui.setStatus = (key: string, value?: unknown) => {
    if (SUPPRESSED.has(key)) return original(key, undefined);
    return original(key, value);
  };
  // Clear anything already shown.
  for (const key of SUPPRESSED) original(key, undefined);
}

export default function (pi: ExtensionAPI) {
  // Patch on any early event so it's in place before the adapter sets status.
  for (const ev of ["session_start", "model_select", "before_agent_start", "after_provider_response"] as const) {
    pi.on(ev, (_e: unknown, ctx: any) => patch(ctx.ui));
  }
}
