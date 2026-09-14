# Documentation Scaffold

The initializer creates a small portable context layer. It is organized by project area instead of by
document type, so planning, completed-change evidence, and durable understanding remain adjacent.

## Layout

```text
docs/
|-- AGENTS.md
|-- cmd.md
`-- workspace/
    |-- plan.md
    |-- log.md
    `-- overview.md
```

Create another `docs/<area>/` only when that area is a stable project boundary. Every area contains
`plan.md`, `log.md`, and `overview.md`. Do not create repository-root plan, log, bug, command, or debt
files.

The `cmd.md`, `plan.md`, `log.md`, and overview contracts are defined once in `assets/docs/AGENTS.md`,
which the initializer installs as `docs/AGENTS.md`. Update that asset instead of restating the contracts
here.

## Existing Repositories

The bundled assets are starters for a new repository. Do not force this topology onto an existing
project whose confirmed documentation structure is different. Read its active rules, propose the
smallest compatible change, and update it only after the user confirms the governance decision.
