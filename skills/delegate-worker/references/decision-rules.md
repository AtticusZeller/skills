# New, Resume, or Fork

A worker is one provider session bound to one working directory. Its value is the context it has
already built: files read, conventions learned, and its own earlier output. Its cost is that the
context carries forward everything, including misunderstandings.

Run `delegate-worker.sh list` first. The state survives across orchestrator sessions, so a worker
from yesterday is still resumable.

## Resume when all of these hold

| Condition | Why |
|---|---|
| The new request continues the same goal: a follow-up, fix, extension, or answer to its `Questions` | Its context is directly reusable |
| Same `--cwd` and provider | Sessions are stored per working directory, and resume switches into the recorded cwd |
| The last round ended as `ok` and misunderstood nothing fundamental | A local mistake is cheaper to correct than to re-explain |
| The same permission profile suffices; one or two extra `--allow` rules are fine | The profile is fixed for the worker's life |
| `total_turns` is moderate, roughly under 80, and the task has not drifted | Long sessions get compacted and lose detail |

## Start a new worker when any of these hold

- The task is unrelated, or targets another repository or directory.
- The worker misunderstood the goal, invented facts, or repeatedly claimed checks it did not run.
  Its context now anchors on the wrong picture.
- A different provider or permission profile is needed.
- You want an independent second opinion on the same question. A fresh session avoids anchoring on
  the first answer.
- The session is long, or earlier rounds were dominated by denials and retries.

A new worker starts cold. Put the needed facts from the previous worker's verified output into the
brief. Do not ask the new worker to "see what the last one did".

## Fork when

You want to try an alternative from a worker's current context without disturbing the original.
Examples: two ways to restructure the same document, or a risky variant next to a safe one.
`fork <name> <new-name>` copies the context once; afterwards the two workers diverge independently.

## Naming

Use `<scope>-<task>`, lowercase with hyphens, for example `report-v3-scaffold` or
`scholar-repo-overview`. The name is how the user refers to the worker later, so make it recognisable
without the conversation.

## Retiring

A worker needs no explicit shutdown: it exists only while a round runs. State stays on disk for
`show`. When a task is accepted, say in your report that the worker is finished. Do not resume a
finished worker for new scope; start a new one.
