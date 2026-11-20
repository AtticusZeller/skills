// Run: node ~/.pi/agent/extensions/tokyo-footer/test.mjs [--live]
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { mkdtempDisposableSync, readFileSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { homedir, tmpdir } from 'node:os';
import { join } from 'node:path';
// This machine uses Pi's managed installation layout.
const install = join(homedir(), '.pi/agent/install');
const version = readFileSync(join(install, 'current-version'), 'utf8').trim();
const root = join(install, 'releases', version);
const require = createRequire(join(root, 'package.json'));
const { createJiti } = require('jiti');
const tui = await import(require.resolve('@earendil-works/pi-tui'));
const jiti = createJiti(import.meta.url, { alias: {
  '@earendil-works/pi-tui': require.resolve('@earendil-works/pi-tui'),
  '@earendil-works/pi-coding-agent': join(root, 'node_modules/@earendil-works/pi-coding-agent/dist/index.js'),
} });
const mod = await jiti.import(new URL('./index.ts', import.meta.url).pathname);
const handlers = new Map();
let footer;
const notices = [];
let settings = {};
const pi = {
  on: (name, fn) => handlers.set(name, fn),
  registerCommand() {},
  getThinkingLevel: () => 'high',
  getSettings: () => settings,
  exec: async (cmd, args, opts) => {
    try { return { ...(await promisify(execFile)(cmd, args, opts)), code: 0 }; }
    catch (e) { return { stdout: '', code: e.code || 1 }; }
  },
};
mod.default(pi);
const live = process.argv.includes('--live');
let entries = [];
if (live && process.env.PI_SESSION_FILE) {
  entries = readFileSync(process.env.PI_SESSION_FILE, 'utf8').trim().split('\n').map(x => JSON.parse(x));
}
let modelName = 'GPT-5.4';
const model = { provider: 'openai-codex', api: 'openai-codex-responses', id: 'test' };
let contextUsage = { percent: 32, tokens: 128000, contextWindow: 400000 };
const ctx = {
  mode: 'tui', cwd: homedir(),
  get model() { return { ...model, name: modelName }; },
  getContextUsage: () => contextUsage,
  sessionManager: {
    getBranch: () => entries,
    getEntries: () => entries,
    getHeader: () => entries.find(x => x.type === 'session') ?? { timestamp: new Date(Date.now() - 120000).toISOString() },
  },
  ui: {
    notify: (...args) => notices.push(args),
  },
};
const plain = line => line.replace(/\x1b\[[\d;]*m/g, '');
const oldPath = process.env.PATH;
const realNow = Date.now;
const now = Date.parse('2026-11-20T02:18:00Z');
const temp = live ? undefined : mkdtempDisposableSync(join(tmpdir(), 'tokyo-footer-'));
if (temp) {
  const limits = {
    primary: { usedPercent: 10, windowDurationMins: 300, resetsAt: now / 1000 + 3 * 3600 },
    secondary: { usedPercent: 65, windowDurationMins: 10080, resetsAt: now / 1000 + 27 * 3600 },
  };
  writeFileSync(join(temp.path, 'codex'), `#!/bin/sh
read -r initialize
printf '%s\\n' '{"id":1,"result":{}}'
read -r initialized
read -r request
printf '%s\\n' '${JSON.stringify({ id: 2, result: { rateLimitsByLimitId: { codex: limits } } })}'
`, { mode: 0o700 });
  process.env.PATH = `${temp.path}:${oldPath}`;
  Date.now = () => now;
} else {
  settings = JSON.parse(readFileSync(join(install, '..', 'settings.json'), 'utf8'));
  model.provider = process.env.PI_PROVIDER ?? settings.defaultProvider ?? model.provider;
  model.id = process.env.PI_MODEL ?? settings.defaultModel ?? model.id;
  const latest = entries.findLast(e => e.type === 'message' && e.message.role === 'assistant' && e.message.provider === model.provider && e.message.model === model.id);
  if (latest) model.api = latest.message.api;
}
let quotaReady;
const loaded = new Promise(resolve => { quotaReady = resolve; });
ctx.ui.setFooter = fn => {
  footer = fn({ requestRender() {
    if (notices.length || plain(footer.render(160)[1]).includes('󰔟')) quotaReady();
  } }, {}, { onBranchChange: () => () => {}, getExtensionStatuses: () => new Map([['test', 'worker: idle']]) });
};
try {
  await handlers.get('session_start')({}, ctx);
  const timeout = setTimeout(quotaReady, 25000);
  await loaded;
  clearTimeout(timeout);
  if (!live) {
    const [first, second] = footer.render(160).map(plain);
    assert.match(first, /11-20 10:18$/);
    assert.equal(tui.visibleWidth(first), 160);
    assert.equal(tui.visibleWidth(second), 160);
    assert.match(second, /^↑0 ↓0 │ 󰔟 5h ▀{8} 90% \+30% ↻3h00m │ 7d ▀{8} 35% \+19% ↻1d3h {3,}󱦻 2m00s$/);
    assert.match(plain(footer.render(38)[0]), /10:18$/);
    assert.doesNotMatch(plain(footer.render(38)[0]), /11-20/);
    assert.match(plain(footer.render(24)[1]), /5h 90% │ 7d 35%/);
    assert.match(first, / 256k/);
    settings = { compaction: { reserveTokens: 30000, modelOverrides: { 'openai-codex/test': { reserveTokens: 50000 } } } };
    assert.match(plain(footer.render(160)[0]), / 222k/);
    contextUsage = { ...contextUsage, tokens: 351000 };
    assert.match(plain(footer.render(160)[0]), / 0\b/);
    contextUsage = { ...contextUsage, tokens: null, percent: null };
    assert.doesNotMatch(plain(footer.render(160)[0]), //);
    settings = { compaction: { enabled: false } };
    assert.match(plain(footer.render(160)[0]), / off/);

    const assistant = (input, cacheRead, cacheWrite, overrides = {}) => ({ type: 'message', message: {
      role: 'assistant', provider: model.provider, model: model.id, api: model.api, stopReason: 'stop',
      usage: { input, cacheRead, cacheWrite, output: 1000, cost: { total: 0 } }, ...overrides,
    } });
    entries = [assistant(990, 10, 0), assistant(40, 940, 20), assistant(1000, 0, 0, { stopReason: 'aborted' }), assistant(1000, 0, 0, { model: 'other' })];
    const [clockRow, statsRow] = footer.render(160).map(plain);
    assert.match(statsRow, /^ hit 94% │ ↑3k ↓4k │ 󰔟 5h .* {3,}󱦻 2m00s$/);
    assert.doesNotMatch(statsRow, /TTL|expired|✗|\b[RW]\d|\$/);
    assert.equal(tui.visibleWidth(clockRow), 160);
    assert.equal(tui.visibleWidth(statsRow), 160);
    const [narrowClock, narrowStats] = footer.render(40).map(plain);
    assert.equal(tui.visibleWidth(narrowClock), 40);
    assert.ok(tui.visibleWidth(narrowStats) <= 40);
    assert.match(narrowStats, /^ (?:hit )?94% │ 󰔟 5h .*7d /);
    entries.push(assistant(1000, 0, 0));
    assert.match(plain(footer.render(160)[1]), /hit 0%/);
    entries = [];
    assert.doesNotMatch(plain(footer.render(160)[1]), /|hit|TTL|\b[RW]\d|\$/);
    Date.now = () => now + 7 * 60000;
    assert.doesNotMatch(plain(footer.render(160)[1]), /󰔟/);
    Date.now = () => now;
  }
  for (const width of [1, 20, 40, 60, 80, 120, 180]) {
    const lines = footer.render(width);
    assert.equal(lines.length, 3);
    for (const line of lines) assert.ok(tui.visibleWidth(line) <= width, `overflow at ${width}`);
    assert.ok(lines[2].includes(width >= 12 ? 'worker: idle' : ''));
  }
  modelName = '很长的中文模型名称'.repeat(15);
  for (const width of [20, 60, 120]) {
    for (const line of footer.render(width)) assert.ok(tui.visibleWidth(line) <= width);
  }
  modelName = 'GPT-5.4';
  console.log(live ? 'PASS: Pi imports, narrow widths, CJK and extension statuses' : 'PASS: Pi imports, quota/pace, clock, compact layout, cache hit, compaction settings, CJK and extension statuses');
  if (live) {
    const limits = await mod.readCodexLimits();
    console.log('Live quota windows:', JSON.stringify({ primary: limits.primary, secondary: limits.secondary }));
    modelName = model.id;
    console.log('Preview (context is illustrative; quota and available session usage are live):');
    console.log(footer.render(140).slice(0, 2).join('\n'));
  }
  assert.deepEqual(notices, []);
} finally {
  footer?.dispose();
  handlers.get('session_shutdown')();
  Date.now = realNow;
  process.env.PATH = oldPath;
  temp?.remove();
}
