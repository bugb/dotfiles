# claude

Claude Code custom statusline.

## Install

Symlink or copy the script into place, then reference it from `~/.claude/settings.json`:

```bash
mkdir -p ~/.claude
ln -sf ~/.config/claude/statusline.sh ~/.claude/statusline.sh
```

`~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline.sh",
    "padding": 0,
    "refreshInterval": 30
  }
}
```

Restart Claude Code so the daemon picks up the new command.

## What it shows

`<cwd>  <branch>  <tokens>  <cost>  Hanoi <weather>  cpu <%>  ram <free/total>  disk <free/total>`

- Branch color: `master`/`main` = red, everything else = green.
- CPU: instant sample from `/proc/stat` delta (0–100%).
- RAM: `/proc/meminfo` `MemAvailable` / `MemTotal`.
- Disk: `df -hP /` avail / total.
- Weather: `wttr.in/Hanoi`, cached 30 min at `/tmp/claude_weather_hanoi.txt`, refreshed in background.
- Session tokens: cumulative from the current transcript `.jsonl`, deduped by message id.
- Cost: `cost.total_cost_usd` from the stdin JSON Claude Code passes.

Thresholds (cpu / ram / disk %used): green < 75, yellow 75–89, red ≥ 90.

## Requirements

`jq`, `curl`, GNU `awk`, `git`, `df`, `nproc`. All standard on Linux.
