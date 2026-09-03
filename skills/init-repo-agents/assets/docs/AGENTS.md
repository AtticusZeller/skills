# Documentation Rules

These rules apply to every file under `docs/`.

Documentation is human-facing project context. Organize it into first-level area directories. Every area
must contain `plan.md`, `log.md`, and `overview.md`; keep root-level documentation limited to this rule
file unless the repository explicitly defines another public document.

`plan.md` contains confirmed, unfinished work only. Each task must define Task, Change, Verification, and
Done so completion is observable. Remove accepted work from the plan and summarize it in the area log.

`log.md` records completed substantial changes, newest first. Each entry states the background and
purpose, implementation idea, component changes, a few important file paths, and verification results.
Compress changes with the same intent instead of reproducing commit history or terminal output.

`overview.md` stores durable responsibilities, boundaries, information flow, non-obvious design choices,
limitations, and discussion conclusions. Do not copy source inventories, commands, or details obvious
from reading the code.

Write for humans in the repository's chosen documentation language. Keep the explanation concise and at
the design level.
