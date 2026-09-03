# Documentation Scaffold

The initializer creates a small portable context layer. It is organized by project area instead of by
document type, so planning, completed-change evidence, and durable understanding remain adjacent.

## Layout

```text
docs/
|-- AGENTS.md
`-- workspace/
    |-- plan.md
    |-- log.md
    `-- overview.md
```

Create another `docs/<area>/` only when that area is a stable project boundary. Every area contains
`plan.md`, `log.md`, and `overview.md`. Do not create root-level plan, log, bug, command, or debt files.

## Plan

`plan.md` stores confirmed, unfinished transactions only. Remove a transaction after acceptance and
summarize it in `log.md`.

Each task contains:

```markdown
### Task: <observable objective>

**Change**

- <what will change>

**Verification**

1. <check the agent can actually run>

**Done**

- <observable acceptance result>
```

One transaction may contain several dependent tasks. Do not use circular Done statements such as
“implementation completed” or “tests passed.”

## Log

`log.md` records one complete substantial change at a time, newest first. One entry may compress several
commits with the same intent. It contains background/purpose, implementation idea, component changes,
the few important file paths, and verification results. It is not a terminal transcript or commit list.

## Overview

`overview.md` preserves responsibilities, boundaries, architecture and information flow, non-obvious
design rationale, limitations, and durable conclusions from human-agent discussions. Exclude directory
trees, symbol inventories, command output, repeated source code, and details obvious from a quick code
read.

## Existing Repositories

The bundled assets are starters for a new repository. Do not force this topology onto an existing
project whose confirmed documentation structure is different. Read its active rules, propose the
smallest compatible change, and update it only after the user confirms the governance decision.
