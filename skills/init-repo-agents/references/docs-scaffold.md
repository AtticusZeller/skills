# docs/ Memory Scaffold

This reference defines the in-repo memory layer and root command handoff that `init-repo-agents` creates. The point of keeping these files inside the repo (instead of a CLI's global memory) is portability: the same context follows the project across machines and across agents.

Create each file only if it is absent. Never overwrite an existing file — if it exists, leave it untouched and report that it was already present.

Write the file bodies in Chinese (user-facing docs); keep any code/identifiers in English.

## docs/plan.md

The shared, forward-looking plan that user and agent both read. Newest entry on top. This is what a fresh session reads first to recover where things left off.

```markdown
# Development Plan

> 用户和 agent 共同维护的当前计划。最新的在最上面。

<!-- 新条目追加到本行下方，保持最新在最上 -->
```

## docs/log.md

Append-only record of verified, completed tasks, newest on top. A candidate implementation does not belong here until all required agent-run or user-run checks have passed. Distinct from `plan.md`: `plan.md` looks forward, `log.md` looks back.

```markdown
# Development Log

> 已验证完成的任务记录。最新的在最上面。

<!-- 每个任务通过全部必要验证后，在本行下方追加一条 -->
```

## docs/bug.md

Hard-won lessons: how a bug was triggered, how it was resolved, and why. Append-only. Keep entries lean — only record bugs likely to bite again (architecture/data-flow issues, obscure third-party pitfalls, environment/config conflicts, non-obvious root causes).

```markdown
# Bug Journal

> 开发过程中的硬核经验：触发情况、解决方案、原因解释。

<!-- 新 bug 追加到本行下方 -->
```

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

Create root `cmd.md` if it is absent. This is a user-facing command interface, not a completion log. Keep stable, commonly reused commands under "常用命令". Keep at most one current manual verification handoff under "待用户验证"; do not accumulate stale task-specific commands there.

```markdown
# Command Reference

> 项目常用命令与用户侧验证入口。命令应可直接复制执行。

## 常用命令

<!-- 按用途记录稳定命令，例如 lint、test、train、eval；优先引用 dev.sh 子命令 -->

## 待用户验证

- **状态**：None
```

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
