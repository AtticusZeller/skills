# docs/ Memory Scaffold

This reference defines the in-repo memory layer and root command handoff that `init-repo-agents` creates. The point of keeping these files inside the repo (instead of a CLI's global memory) is portability: the same context follows the project across machines and across agents.

Create each file only through `scripts/init-repo-agents.sh`. The script installs the fixed bodies from `assets/`; agents must not reconstruct them from this reference. Never overwrite an existing file — if it exists, leave it untouched and report that it was already present.

Write the file bodies in Chinese (user-facing docs); keep any code/identifiers in English.

## Fixed scaffold assets

- `assets/docs/plan.md` — shared forward-looking plan, newest entry on top.
- `assets/docs/log.md` — append-only record of verified completed tasks, newest entry on top.
- `assets/docs/bug.md` — reusable hard-won lessons about unusual bugs.
- `assets/cmd.md` — stable command reference and current user-test handoff.

These files are executable inputs to the initializer, not examples for an agent to copy. Edit the assets when the initial scaffold must change, then update and run the regression test.

Entry template (use when recording a bug later):

~~~~markdown
## [Bug 标题]
**Date**: YYYY-MM-DD
**Category**: [如 Dataset / Model Config / Environment / API]
**Status**: Resolved

### 1. 触发与现象
- **Trigger**: 什么操作或条件触发了问题
- **Symptom**: 可观察到的报错或行为

### 2. 关键日志
```text
[从对话里抽出最具诊断价值的几行 — 去噪留信号]
```

### 3. 排查推理
[探索了哪些方向、排除了什么、如何定位到根因]

### 4. 解决方案
[最终修复 — 代码片段或步骤]

**为什么有效**: [一两句底层机制]
~~~~

## Root `cmd.md` — command reference and user-test handoff

The initializer creates root `cmd.md` from `assets/cmd.md` if it is absent. This is a user-facing command interface, not a completion log. Keep stable, commonly reused commands under "常用命令". Keep at most one current manual verification handoff under "待用户验证"; do not accumulate stale task-specific commands there.

When a required check depends on a real robot, VLA setup, dedicated hardware, user credentials, or another environment the agent cannot access, replace the "待用户验证" block with:

```markdown
## 待用户验证

- **状态**：Pending
- **验证目的**：<这次改动需要证明什么>
- **前置条件**：<设备、环境、数据或服务要求>
- **执行命令**：`<可直接复制的命令；多条命令按顺序列出>`
- **通过标准**：<可观察、可判定的成功结果>
- **失败时请回传**：<日志、输出、截图或设备现象>
```

Writing the handoff does not count as passing verification. Wait for the user's result. On failure, return to code and update the handoff for the next run; on success, clear the pending block during the normal `neat-freak` reconciliation and only then record the task in `docs/log.md`.

## docs/<module>.md — code documentation index convention

Do **not** generate module doc bodies during init. Instead:

1. During init, do a shallow structural scan of the top-level source tree (e.g. `src/<pkg>/*/`) — directory names only, no deep code reading.
2. Seed the "Code Documentation Index" section of `AGENTS.md` with one `[[docs/<module>.md]]` entry per notable module, each pointing at a doc to be written later.

Index entry format (goes into `AGENTS.md`, not into a docs file):

```markdown
- [[docs/<module>.md]] —— <一句话职责>（`src/<pkg>/<module>/`）
```

Module docs are then filled **incrementally** — the first time an agent explores a module in depth, it writes that module's `docs/<module>.md` so future sessions read the doc instead of re-reading the code. A reasonable per-module doc covers: 职责与边界、关键入口文件、对外接口、与其他模块的依赖关系。
