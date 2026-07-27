# claude

A status line for Claude Code. One file, works on macOS and Linux.

```
⚑ main* │ work/dotfiles │ Opus 5·max │ 🌤 +30°C │ cpu 28% │ ram 4.7G/16G │ disk 27G/228G │ ↑96.9M ↓354k │ ctx 42% │ $1.20 │ 5h 18% 7d 31%
```

## Install

`../../install.sh` does this as part of a normal run. By hand:

```bash
ln -sfn "$PWD/.config/claude/statusline.py" ~/.claude/statusline.py
python3 ~/.claude/statusline.py --install-settings
```

Then **restart Claude Code, or open `/hooks` once**, so the new configuration
loads. Until then the directory stays pinned to wherever the session started —
see "following `cd`" below.

`--install-settings` merges two keys into `~/.claude/settings.json` and leaves
everything else untouched. It backs the previous file up and is safe to re-run.
That file is merged rather than symlinked because it also holds machine-local
preferences and anything Claude Code writes to it itself.

Requirements: `python3` (standard library only), `git`, and `curl` for the
weather. Nothing else.

## What it shows

| Segment | Notes |
| --- | --- |
| branch | red on `master`/`main`, green elsewhere, yellow short-sha when detached; `*` means the worktree is dirty |
| directory | last two path components |
| model | plus effort level, and `·nothink` / `·fast` when set |
| weather | cached 30 minutes, refreshed by a detached background process |
| cpu | 1-minute load average as a share of cores |
| ram | available/total |
| disk | free/total on the volume holding the working directory |
| tokens | cumulative input/output for the session |
| ctx | context window used |
| cost | session cost in USD |
| quota | 5-hour and 7-day plan usage, when the plan reports it |

Every segment is independent: one that cannot be computed drops out rather than
breaking the line. Colours run green to yellow to red as a value approaches its
limit. Set `CLAUDE_STATUSLINE_WEATHER` to change the location from Hanoi.

To remove a segment entirely, delete its entry from the list in `main()`; the
separators adjust themselves.

### Fitting the terminal

The full line is around 134 columns. When that does not fit, Claude Code
truncates it with an ellipsis, so segments are dropped to fit instead — machine
metrics first, since those are ambient and visible from any other terminal,
while the session figures exist nowhere else. The order is `DROP_ORDER`.

Width is detected by asking `/dev/tty` directly. `shutil.get_terminal_size` is
no use here: stdout is a pipe, so it always returns its 80-column fallback.
Set `CLAUDE_STATUSLINE_WIDTH` to override, or `0` to disable dropping and always
print everything.

Emoji and CJK are counted as two columns, because that is what terminals draw —
measuring codepoints instead lets the line overflow by exactly the width of the
weather icon.

## Things worth knowing

**Colour is never the only signal.** The branch carries `⚑` on the default branch
and `⎇` elsewhere, so it still reads correctly with a colour vision deficiency —
red against green is the worst possible pair for that.

**Following `cd`.** The payload Claude Code passes in carries the *session*
directory, which does not move when you `cd`. Claude Code emits a `CwdChanged`
event, but only when a hook for it is registered — so `--install-settings`
registers one that records the new path, and the status line prefers it. This is
why installing needs a restart to take effect.

**Token counting.** The transcript repeats a message's usage record every time it
is rewritten, up to six times, with identical values; counting each occurrence
inflates the total by about half. Each message id is therefore counted once. Only
the bytes appended since the previous render are parsed, so the cost of this does
not grow with session length.

**Memory.** "Available" means reclaimable-without-swapping on both platforms:
`MemAvailable` on Linux, and free + inactive + speculative + purgeable on macOS.
Note that `df /` on macOS reports the capacity of the sealed system volume, which
can look far emptier than the disk really is — the figure here is the shared APFS
container, which is the one that matters.

**Speed.** Roughly 60 ms per render, most of it Python interpreter startup plus
the `git diff` that detects a dirty worktree. Branch detection reads `.git/HEAD`
directly, since `git rev-parse` measures ~15 ms against ~0.04 ms for the file
read. Nothing blocks on the network.
