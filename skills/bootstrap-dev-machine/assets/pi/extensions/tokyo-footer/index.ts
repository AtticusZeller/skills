// Local Pi footer, styled after ~/.claude/statusline-command.sh.
// Quotas belong to the locally logged-in Codex CLI account (not Pi API billing).
import { spawn } from "node:child_process";
import { createInterface } from "node:readline";
import { basename } from "node:path";
import { SettingsManager, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

type Window = { usedPercent: number; windowDurationMins: number; resetsAt: number };
type Limits = { primary?: Window | null; secondary?: Window | null };
const colors = { text: "c0caf5", muted: "565f89", track: "3b4261", blue: "7aa2f7", green: "9ece6a", cyan: "7dcfff", purple: "bb9af7", orange: "ff9e64", cache: "73daca", warn: "e0af68", red: "f7768e" };
const rgb = (c: string) => [0, 2, 4].map(i => parseInt(c.slice(i, i + 2), 16)).join(";");
const fg = (c: string, s: string) => `\x1b[38;2;${rgb(c)}m${s}\x1b[0m`;
const sep = fg(colors.track, " │ ");
const join = (xs: string[]) => xs.filter(Boolean).join(sep);
const tok = (n: number) => n >= 1e6 ? `${(n / 1e6).toFixed(1)}M` : n >= 1000 ? `${Math.round(n / 1000)}k` : String(n);
const duration = (s: number) => s >= 86400 ? `${Math.floor(s / 86400)}d${Math.floor(s % 86400 / 3600)}h` : s >= 3600 ? `${Math.floor(s / 3600)}h${String(Math.floor(s % 3600 / 60)).padStart(2, "0")}m` : s >= 600 ? `${Math.floor(s / 60)}m` : s >= 60 ? `${Math.floor(s / 60)}m${String(Math.floor(s % 60)).padStart(2, "0")}s` : `${Math.floor(s)}s`;
const severity = (p: number) => p >= 90 ? colors.red : p >= 70 ? colors.warn : colors.green;
const bar = (p: number, cells: number, color: string) => {
  const n = Math.max(0, Math.min(cells, Math.round(p * cells / 100)));
  return fg(color, "▰".repeat(n)) + fg(colors.track, "▱".repeat(cells - n));
};
const clean = (s: string) => s.replace(/[\x00-\x1f\x7f-\x9f]/g, "");
const clockFormat = new Intl.DateTimeFormat("en-US", { timeZone: "Asia/Shanghai", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", hourCycle: "h23" });
const clampPercent = (p: number) => Math.max(0, Math.min(100, p));

function quotaSegment(w: Window | null | undefined, now: number, level: number) {
  if (!w || !Number.isFinite(w.usedPercent) || !Number.isFinite(w.windowDurationMins) || w.windowDurationMins <= 0 || !Number.isFinite(w.resetsAt)) return "";
  const secondsLeft = w.resetsAt - now;
  if (secondsLeft <= 0) return "";
  const remaining = 100 - Math.round(clampPercent(w.usedPercent));
  const timeLeft = Math.floor(clampPercent(100 * secondsLeft / (60 * w.windowDurationMins)));
  const pace = remaining - timeLeft;
  const label = w.windowDurationMins === 10080 ? "7d" : w.windowDurationMins === 300 ? "5h" : `${w.windowDurationMins}m`;
  const color = remaining <= 10 ? colors.red : remaining <= 30 ? colors.warn : colors.orange;
  const cells = level < 3 ? 8 : level < 7 ? 6 : level < 10 ? 4 : 0;
  const q = Math.round(remaining * cells / 100), t = Math.round(timeLeft * cells / 100);
  const paceBar = Array.from({ length: cells }, (_, i) =>
    `\x1b[48;2;${rgb(i < t ? colors.muted : "292e42")}m${fg(i < q ? color : colors.track, "▀")}`,
  ).join("");
  return fg(colors.muted, label) + " " + (paceBar ? paceBar + " " : "") + fg(color, `${remaining}%`)
    + (level < 5 ? fg(pace > 0 ? colors.green : pace < 0 ? colors.warn : colors.muted, ` ${pace > 0 ? "+" : pace === 0 ? "±" : ""}${pace}%`) : "")
    + (level < (label === "7d" ? 1 : 2) ? fg(colors.muted, ` ↻${duration(secondsLeft)}`) : "");
}

function latestCacheHit(ctx: ExtensionContext): number | undefined {
  const model = ctx.model;
  if (!model) return;
  const branch = ctx.sessionManager.getBranch();
  for (let i = branch.length - 1; i >= 0; i--) {
    const e = branch[i];
    if (e.type !== "message" || e.message.role !== "assistant") continue;
    const m = e.message;
    if (m.provider !== model.provider || m.api !== model.api || m.model !== model.id || m.stopReason === "error" || m.stopReason === "aborted") continue;
    const { input, cacheRead, cacheWrite } = m.usage;
    const total = input + cacheRead + cacheWrite;
    if (total > 0) return Math.round(100 * cacheRead / total);
  }
}

function compactionSegment(pi: ExtensionAPI, ctx: ExtensionContext, usage: ReturnType<ExtensionContext["getContextUsage"]>) {
  if (!ctx.model) return "";
  const { compaction } = pi.getSettings();
  const settings = SettingsManager.inMemory({ compaction });
  if (!settings.getCompactionEnabled()) return fg(colors.muted, " off");
  if (usage?.tokens == null || usage.contextWindow <= 0) return "";
  const { reserveTokens } = settings.getCompactionSettings(ctx.model);
  const room = usage.contextWindow - reserveTokens - usage.tokens;
  const color = room < 20000 ? colors.red : room * 4 < usage.contextWindow - reserveTokens ? colors.warn : colors.green;
  return fg(color, ` ${tok(Math.max(0, room))}`);
}

function measureRow(left: string, right: string) {
  return visibleWidth(left) + (right ? (left ? 3 : 0) + visibleWidth(right) : 0);
}

function fitRow(width: number, atLevel: (level: number) => [string, string]): [string, string] {
  for (let level = 0; level < 12; level++) {
    const row = atLevel(level);
    if (measureRow(...row) <= width) return row;
  }
  return atLevel(12);
}

function alignRow([left, right]: [string, string], width: number) {
  if (!right) return truncateToWidth(left, width);
  const rightWidth = visibleWidth(right);
  if (rightWidth >= width) return truncateToWidth(right, width);
  if (!left || rightWidth + 3 >= width) return " ".repeat(width - rightWidth) + right;
  left = truncateToWidth(left, width - rightWidth - 3);
  return left + " ".repeat(width - visibleWidth(left) - rightWidth) + right;
}

// One short-lived stdio app-server per refresh; no credential parsing or chat requests.
export function readCodexLimits(signal?: AbortSignal): Promise<Limits> {
  return new Promise((resolve, reject) => {
    const child = spawn("codex", ["app-server"], { stdio: ["pipe", "pipe", "ignore"] });
    const lines = createInterface({ input: child.stdout });
    let done = false;
    const killTimer = setTimeout(() => child.kill("SIGKILL"), 23000);
    killTimer.unref();
    child.once("close", () => clearTimeout(killTimer));
    const finish = (error?: Error, limits?: Limits) => {
      if (done) return;
      done = true;
      clearTimeout(timer);
      signal?.removeEventListener("abort", abort);
      lines.close();
      child.stdin.end();
      child.kill();
      if (error) reject(error); else resolve(limits!);
    };
    const abort = () => finish(new Error("cancelled"));
    const timer = setTimeout(() => finish(new Error("Codex quota timeout")), 20000);
    signal?.addEventListener("abort", abort, { once: true });
    child.on("error", error => finish(error));
    child.stdin.on("error", error => finish(error));
    child.on("exit", () => finish(new Error("Codex app-server exited")));
    const send = (x: object) => child.stdin.write(JSON.stringify(x) + "\n");
    lines.on("line", line => {
      if (done) return;
      let x;
      try { x = JSON.parse(line); } catch { return; }
      if (x.error) return finish(new Error(x.error.message || "Codex quota error"));
      if (x.id === 1) {
        send({ method: "initialized" });
        send({ method: "account/rateLimits/read", id: 2 });
      }
      if (x.id === 2) {
        const limits = x.result?.rateLimitsByLimitId?.codex ?? x.result?.rateLimits;
        if (!limits || (limits.limitId && limits.limitId !== "codex")) return finish(new Error("Codex quota unavailable"));
        finish(undefined, limits);
      }
    });
    if (signal?.aborted) abort();
    else send({ method: "initialize", id: 1, params: { clientInfo: { name: "pi-tokyo-footer", version: "1.0.0" } } });
  });
}

export default function (pi: ExtensionAPI) {
  let controller: AbortController | undefined;
  let current: ExtensionContext;
  let limits: Limits | undefined;
  let fetchedAt = 0;
  let quotaBusy = false;
  let warned = false;
  let git = "", gitBranch = "";
  let gitBusy = false;
  let requestRender = () => {};
  let timer: ReturnType<typeof setInterval> | undefined;
  const refreshQuota = async () => {
    if (quotaBusy || !controller || controller.signal.aborted) return;
    quotaBusy = true;
    try {
      const result = await readCodexLimits(controller.signal);
      if (controller.signal.aborted) return;
      limits = result;
      fetchedAt = Date.now();
      warned = false;
    } catch {
      limits = undefined;
      if (!controller?.signal.aborted && !warned) {
        current.ui.notify("Codex 配额获取失败，已隐藏配额。可用 /codex-quota 重试。", "warning");
        warned = true;
      }
    } finally { quotaBusy = false; requestRender(); }
  };
  const refreshGit = async () => {
    if (gitBusy || !controller || controller.signal.aborted) return;
    gitBusy = true;
    try {
      const r = await pi.exec("git", ["--no-optional-locks", "status", "--porcelain=v2", "--branch"], { cwd: current.cwd, timeout: 3000, signal: controller.signal });
      if (r.code !== 0 || controller.signal.aborted) { git = gitBranch = ""; return; }
      let branch = "", staged = 0, modified = 0, untracked = 0, ahead = 0, behind = 0;
      for (const line of r.stdout.split("\n")) {
        if (line.startsWith("# branch.head ")) branch = line.slice(14);
        if (line.startsWith("# branch.ab ")) {
          const ab = line.match(/\+(\d+) -(\d+)/);
          if (ab) { ahead = Number(ab[1]); behind = Number(ab[2]); }
        }
        if (/^[12] /.test(line)) {
          const xy = line.split(" ")[1];
          if (xy[0] !== ".") staged++;
          if (xy[1] !== ".") modified++;
        }
        if (line.startsWith("u ")) modified++;
        if (line.startsWith("? ")) untracked++;
      }
      gitBranch = branch ? fg(colors.cyan, `󰊢 ${clean(branch)}`) : "";
      git = gitBranch + (ahead ? fg(colors.cyan, ` ⇡${ahead}`) : "") + (behind ? fg(colors.cyan, ` ⇣${behind}`) : "") + (staged ? fg(colors.green, ` +${staged}`) : "") + (modified ? fg(colors.warn, ` !${modified}`) : "") + (untracked ? fg(colors.muted, ` ?${untracked}`) : "");
    } catch {
      git = gitBranch = "";
    } finally { gitBusy = false; requestRender(); }
  };
  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;
    current = ctx;
    controller = new AbortController();
    ctx.ui.setFooter((tui, _theme, data) => {
      requestRender = () => tui.requestRender();
      const unsub = data.onBranchChange(() => { void refreshGit(); });
      return {
        invalidate() {},
        dispose() { unsub(); requestRender = () => {}; },
        render(width) {
          const now = Date.now();
          const usage = current.getContextUsage();
          const cacheHit = latestCacheHit(current);
          const compaction = compactionSegment(pi, current, usage);
          let input = 0, output = 0;
          for (const e of current.sessionManager.getEntries()) {
            if (e.type !== "message" || e.message.role !== "assistant") continue;
            input += e.message.usage.input;
            output += e.message.usage.output;
          }
          const totals = fg(colors.text, `↑${tok(input)} ↓${tok(output)}`);
          const start = Date.parse(current.sessionManager.getHeader()?.timestamp ?? new Date(now).toISOString());
          const [date, time] = clockFormat.format(now).replace("/", "-").split(", ");
          const row1 = fitRow(width, level => {
            const cells = level < 3 ? 10 : level < 7 ? 8 : level < 10 ? 6 : 4;
            let model = fg(colors.blue, ` ${clean(current.model?.name ?? "no model")}`) + (level < 4 ? fg(colors.muted, ` ${pi.getThinkingLevel()}`) : "");
            const used = usage?.percent != null ? fg(colors.purple, " ") + (level < 12 ? bar(usage.percent, cells, severity(usage.percent)) + " " : "") + fg(colors.text, `${Math.round(usage.percent)}%`) : "";
            const context = [used, level < 12 ? compaction : ""].filter(Boolean).join(" ");
            const right = (level < 8 ? fg(colors.muted, date) + " " : "") + fg(colors.text, time);
            if (level === 12) {
              const modelWidth = width - measureRow(context, right) - (context ? 3 : 0);
              model = modelWidth < 4 ? "" : truncateToWidth(model, modelWidth);
            }
            const left = join([model, level < 9 ? fg(colors.green, `󰉋 ${clean(basename(current.cwd))}`) : "", level < 11 ? git : level < 12 ? gitBranch : "", context]);
            return [left, right];
          });
          const row2 = fitRow(width, level => {
            const quota = limits && now - fetchedAt <= 6 * 60000
              ? join([limits.primary, limits.secondary].map(w => quotaSegment(w, now / 1000, level)))
              : "";
            const cache = cacheHit != null && level < 12
              ? fg(colors.cache, " ") + (level < 3 ? fg(colors.muted, "hit ") : "") + fg(colors.text, `${cacheHit}%`)
              : "";
            const left = join([cache, level < 4 ? totals : "", quota ? fg(colors.orange, "󰔟 ") + quota : ""]);
            const right = level < 6 ? fg(colors.purple, `󱦻 ${duration(Math.max(0, (now - start) / 1000))}`) : "";
            return [left, right];
          });
          const rows = [alignRow(row1, width), alignRow(row2, width)];
          const statuses = [...data.getExtensionStatuses().values()];
          if (statuses.length) rows.push(truncateToWidth(statuses.join(" "), width));
          return rows;
        },
      };
    });
    void refreshGit();
    void refreshQuota();
    let ticks = 0;
    timer = setInterval(() => {
      requestRender();
      void refreshGit();
      if (++ticks % 60 === 0) void refreshQuota();
    }, 5000);
    timer.unref();
  });
  pi.registerCommand("codex-quota", {
    description: "Refresh Codex quota in the Tokyo Night footer",
    handler: async (_args, ctx) => {
      if (ctx.mode !== "tui") return;
      await refreshQuota();
    },
  });
  pi.on("session_shutdown", () => {
    if (timer) clearInterval(timer);
    controller?.abort();
    requestRender = () => {};
  });
}
