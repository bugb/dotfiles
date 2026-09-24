# omp setup: two-vendor plan consensus, opus implements, codex reviews

Migrated from a Codex CLI `config.toml` + a Claude Code "call codex to review"
skill. This file explains why each piece is shaped the way it is, so the
reasoning survives when the config is edited six months from now.

## The idea in one line

Two vendors that fail differently must agree on a plan before code is written,
the code is then written by one vendor and reviewed by the other, and nothing is
accepted until it has been executed rather than merely read.

## Why cross-vendor

Same-model review shares the reviewer's blind spots with the author's.

This is not theoretical. During the Rust port of this repo's trading bot, a
reviewer found a partial-candle bug: bar finality was decided by
`close_time < now`. The fix — snapshot the clock *before* the request — read
correctly, reviewed clean, and was still wrong. A live boundary test showed the
bot ingesting the 14:40 bar at `85863.90` when its true close was `85855.70`,
because our clock can run ahead of the exchange's. Only execution exposed it.
The real fix was structural: Binance's newest returned kline is the in-progress
one, so everything behind it is provably closed — no clock involved.

Two lessons, both encoded below:

1. A different vendor catches what the first one structurally cannot.
2. A verdict is not proof. Running the code is proof.

## Model tiers

Every model except Claude runs through the `codex` provider — an API-key gateway
speaking the plain OpenAI Responses API. It is **not** ChatGPT Codex: omp's
native `openai-codex` provider targets `chatgpt.com/backend-api/codex/responses`
over OAuth, and this gateway 404s on those paths. Verified:

| path | result |
|---|---|
| `/v1/responses` | 200 |
| `/v1/codex/responses` | 404 |
| `/v1/backend-api/codex/responses` | 404 |

So `api: openai-responses` is correct, not a workaround.

| role | model | why |
|---|---|---|
| `default` | `codex/gpt-6-astra:high` | driver: plans, decides, integrates |
| `task` | `codex/gpt-5.6-terra` | generic subagents, the cheap bulk |
| `smol` | `codex/gpt-6-sol` | titles, summaries, throwaway lookups |
| `slow`, `plan` | `codex/gpt-6-astra:high` | deep reasoning on request |

Big model where judgment compounds, cheap models where volume lives. Research
and mechanical edits (`scout`, `sonic`) stay on `sol` because they are most of
the token spend and gain nothing from reasoning depth.

## The agents

| agent | model | writes code? |
|---|---|---|
| `plan-codex` | `codex/gpt-6-astra:high` | no |
| `plan-claude` | `claude/claude-opus-5:xhigh` | no |
| `implementer` | `claude/claude-opus-5:xhigh` | yes |
| `astra-high-review` | `codex/gpt-6-astra:high` | no |
| `sol-high-review` | `codex/gpt-6-sol:high` | no |

The reviewer is always the vendor that did **not** write the code.

Opus 5.5 (`claude-opus-5-5`) requires gateway group access. The configured key
returned `model_not_found` when checked on 2026-09-23; keep Opus 5 selected until
a live request verifies 5.5 access. GPT-6 Sol remains the lightweight model.

### Why the planners default to DISAGREE

An agreeable reviewer is worth nothing. `AGREE` is defined as "I would ship this
exactly as written, and I checked its claims against the code myself". Every
disagreement must carry `file:line` or an observed behaviour as evidence.
"I would structure it differently" is explicitly banned — a style preference
costs a full round trip and buys nothing.

### Why they plan blind

Round 1 dispatches both planners in one batch so neither sees the other's
answer. Their value is failing differently; showing one the other's plan first
collapses two independent opinions into one.

### Why the implementer may not improve the plan

A plan both vendors ratified, quietly changed by the implementer, is worse than
either plan — because nobody reviewed the change. The implementer stops and
reports instead.

## The flow

```
/plan <task>
  round 1  plan-codex  ┐ parallel, blind
           plan-claude ┘
  round 2  each critiques the peer's plan (AGREE / DISAGREE + evidence)
  round 3  both AGREE      -> settled
           one disagrees   -> driver adjudicates against the code, re-run
           both disagree   -> task is underspecified, ask the user
           cap: 3 rounds, then report both positions

implementer   writes exactly the settled slice
astra-high-review  peer review -> APPROVE | CHANGES_REQUIRED + findings
              CHANGES_REQUIRED -> fix -> review the FIXED state again
prove         reproduce, fix, confirm the reproduction stops triggering
```

The re-review step is load-bearing: the last change made is the one nobody has
looked at. It is how the `limit=1` pagination bug was caught — introduced *while
fixing* the reviewer's previous finding.

## Long-running work

`/ship <task>` encodes the full pipeline. The parts that matter:

- **Review per slice, not per PR.** A reviewer reading 200 lines with fresh
  context finds more than one reading 6,000 at the end, and finds it while
  reversing the decision is still cheap.
- **Parallel implement, serial review.** Independent slices go out as one batch
  with interfaces decided up front in the shared context. Two agents negotiating
  a contract mid-flight produce two different contracts.
- **No mid-flight validation.** Subagents skip formatters, linters and the test
  suite; siblings are editing concurrently and a full run trips over their
  half-finished work. The driver runs those once, at the end.
- **Context is the real budget.** Long tasks die from context exhaustion, not
  difficulty. Bulk reading goes to `sol` scouts returning compressed findings;
  payloads move as `local://` paths; the driver's context holds decisions and
  invariants, not file dumps.

## Hard problems

```bash
omp --config ~/.omp/agent/max.yml
```

Bumps every thinking stage on both vendors to `max`: planners, implementer,
reviewers, driver. `scout` and `sonic` deliberately stay on `sol`. Per-run, so
it never leaks into ordinary work.

## Secrets

`models.yml` contains no literal key. It resolves one at request time:

```yaml
apiKey: '!/bin/sed -n "s/.*\"OPENAI_API_KEY\": *\"\([^\"]*\)\".*/\1/p" $HOME/.codex/auth.json'
```

Codex CLI and omp therefore share one source of truth, and this repo stays safe
to commit. Two details in that line are deliberate:

- **`$HOME`, not a hardcoded path.** The secret command runs through a shell, so
  `$HOME` expands — verified by pointing it at a nonexistent file and watching
  auth fail, which also proves the key is resolved per request rather than
  cached. A hardcoded `/root` would work only on this box.
- **`/bin/sed`, spelled absolutely.** `jq` on this host is an omp-internal shim
  rather than a real binary, and secret resolution must not depend on the
  harness it is configuring.

## Codex TOML settings that did not migrate

| setting | why |
|---|---|
| `review_model = "gpt-5.6-astra"` | no such model on the gateway at migration; reviewers use `gpt-6-astra`. |
| `mcp_servers.github` | `/root/.local/bin/github-mcp-codex` does not exist here; omp's native `github` tool is enabled instead. |
| `[projects."/root/poly-rust"]` | directory does not exist; `approvalMode: yolo` covers trust anyway. |
| `windows_wsl_setup_acknowledged`, `network_access`, `tui.model_availability_nux`, `notice.hide_rate_limit_model_nudge` | no omp equivalent; they are Codex-TUI bookkeeping, not behaviour. |

Everything else mapped: `model_context_window` → `contextWindow`,
`model_auto_compact_token_limit` → `compaction.thresholdTokens`,
`effective_context_window_percent` → `compaction.thresholdPercent`,
`approval_policy = "never"` + `sandbox_mode` → `tools.approvalMode: yolo`,
`model_reasoning_effort` → `defaultThinkingLevel`, `features.goals` →
`goal.enabled`, `max_concurrent_threads_per_session` → `task.maxConcurrency`,
`tui.status_line` → `statusLine`, `disable_response_storage` →
`compat.supportsStore`.

## Where these files live

This repo is the single source of truth. `~/.omp/agent` holds symlinks into it:

```
.config/omp/config.yml    ->  ~/.omp/agent/config.yml
.config/omp/models.yml    ->  ~/.omp/agent/models.yml
.config/omp/max.yml       ->  ~/.omp/agent/max.yml
.config/omp/agents/       ->  ~/.omp/agent/agents
.config/omp/commands/     ->  ~/.omp/agent/commands
```

Applied by `./install.sh --link-omp` (or `--all`), reported by `--status`, and
idempotent. `ARCHITECTURE.md` is not linked: it is documentation, not config.

Everything omp keeps in `~/.omp/agent` that is *not* linked — `agent.db`,
`history.db`, `models.db`, `sessions/`, `terminal-sessions/`, `cache/` — is
runtime state and stays out of the repo. `sessions/` in particular holds full
conversation transcripts, so tracking it would leak far more than config.

### Why symlinking config.yml is safe

omp rewrites `config.yml` whenever a setting changes (`/settings`, `/model`,
`omp config set`). If it wrote atomically — temp file plus rename — the symlink
would be **replaced by a regular file** and this repo would silently stop being
the source of truth.

It does not. Verified by pointing `~/.omp/agent/config.yml` at a scratch target,
running `omp config set` twice, and confirming both that the link survived and
that the new value landed in the target file. omp edits in place, so writes flow
through into this repo.

That makes `git diff` here the audit trail for everything omp does to its own
config.

## Files, and who owns them

```
config.yml    roles, agent model overrides, approval, compaction, status line
models.yml    the codex provider and its three models
max.yml       hard-problem overlay, loaded per run with --config
agents/       plan-codex, plan-claude, implementer, astra-high-review, sol-high-review
commands/     /plan (consensus), /review (diff review loop), /ship (full pipeline)
```

**`config.yml` is machine-owned. Never put comments in it.** The rewrite above
reserialises the YAML and **deletes every comment**. Measured, not assumed: a
single `omp config set symbolPreset unicode` removed all nine rationale comments
while leaving every value intact. That is why the reasoning lives in this file.

Everything else is hand-owned and omp does not write it: `models.yml`, `max.yml`,
`agents/*.md`, and `commands/*.md` keep their comments across runs.

## Surviving upgrades

The binary lives at `~/.local/bin/omp`; configuration lives at `~/.omp/agent`
and, through the symlinks, here. Separate trees, so upgrading the binary cannot
clobber this config. What an upgrade *can* do is migrate settings in place —
bump `setupVersion`, rename a key, write a new default.

Which is the point of keeping it in git. The protection is not that omp leaves
the files alone; it is that anything it changes shows up as a diff:

```bash
cd ~/dotfiles && git diff .config/omp   # what did the upgrade or /settings change?
git checkout .config/omp/config.yml     # reject it
```

Skim that diff after an upgrade. A migration that silently retargets a model
role is otherwise invisible until a cheap model starts doing review work.

## Setting this up on a new machine

```bash
git clone git@github.com:bugb/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./install.sh --no-deps --link-omp
```

Then provide the key the codex provider reads:

```bash
mkdir -p ~/.codex && chmod 700 ~/.codex
printf '{\n  "OPENAI_API_KEY": "sk-..."\n}\n' > ~/.codex/auth.json
chmod 600 ~/.codex/auth.json
```

Claude models authenticate separately through omp's own credential store; this
repo carries no Anthropic credentials either.
