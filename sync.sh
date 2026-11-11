#!/usr/bin/env bash
#
# Bring this machine up to date with origin/main, then link any new managed
# paths. Built to run unattended, every hour, on every machine:
#
#   ./sync.sh                     sync once
#   ./sync.sh --install-schedule  sync every hour (launchd on macOS, systemd on Linux)
#   ./sync.sh --remove-schedule   stop the hourly sync
#   ./sync.sh --status            show the schedule and the last sync results
#
# What it will and will not do:
#
#   - It only fast-forwards. It never rebases, merges, stashes, resets or
#     commits, so local work is never rewritten. A local change that conflicts
#     with an incoming commit stops the sync, and the log says which file.
#   - After a pull it runs `./install.sh --relink`: new manifest entries are
#     linked in groups this machine already uses, and no existing file is ever
#     moved or replaced.
#   - It fetches over the configured remote, and falls back to anonymous HTTPS
#     for a public GitHub repo, so a missing SSH agent (launchd, systemd) does
#     not stop it.
#
# Written for bash 3.2, which is what macOS ships.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRANCH="main"
LABEL="dotfiles-sync"
PLIST="$HOME/Library/LaunchAgents/local.$LABEL.plist"
MAC_LOG="$HOME/Library/Logs/$LABEL.log"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

# ------------------------------------------------------------------ sync ----

fetch() {
  local url https
  if GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=15" \
       git fetch -q origin "$BRANCH" 2>/dev/null; then
    return 0
  fi
  url="$(git remote get-url origin)"
  case "$url" in
    git@github.com:*) https="https://github.com/${url#git@github.com:}" ;;
    ssh://git@github.com/*) https="https://github.com/${url#ssh://git@github.com/}" ;;
    *) log "fetch from origin failed ($url)"; return 1 ;;
  esac
  log "fetch over origin failed, trying $https"
  GIT_TERMINAL_PROMPT=0 git fetch -q "$https" "+refs/heads/$BRANCH:refs/remotes/origin/$BRANCH"
}

sync_once() {
  cd "$REPO_DIR"

  # One run at a time. A lock older than an hour is left over from a killed
  # run, so it is removed rather than blocking every later sync.
  local lock="$REPO_DIR/.git/$LABEL.lock"
  if [ -d "$lock" ] && [ -n "$(find "$lock" -maxdepth 0 -mmin +60 2>/dev/null)" ]; then
    rmdir "$lock" 2>/dev/null || true
  fi
  if ! mkdir "$lock" 2>/dev/null; then
    log "another sync is running, skipped"
    return 0
  fi
  # shellcheck disable=SC2064  # expand $lock now
  trap "rmdir '$lock' 2>/dev/null || true" EXIT

  local current
  current="$(git symbolic-ref --short -q HEAD || echo detached)"
  if [ "$current" != "$BRANCH" ]; then
    log "on $current, not $BRANCH: skipped"
    return 0
  fi

  fetch || { log "FAILED: cannot fetch"; return 1; }

  local ahead behind dirty
  ahead="$(git rev-list --count "origin/$BRANCH..HEAD")"
  behind="$(git rev-list --count "HEAD..origin/$BRANCH")"
  dirty="$(git status --porcelain --untracked-files=no | awk '{print $2}' | tr '\n' ' ')"

  [ -z "$dirty" ] || log "note: uncommitted changes in: $dirty"
  [ "$ahead" -eq 0 ] || log "note: $ahead local commit(s) not pushed"

  if [ "$behind" -eq 0 ]; then
    log "up to date at $(git rev-parse --short HEAD)"
  elif [ "$ahead" -gt 0 ]; then
    log "FAILED: local and origin/$BRANCH have diverged ($ahead ahead, $behind behind); resolve by hand"
    return 1
  else
    local before out
    before="$(git rev-parse --short HEAD)"
    if ! out="$(git merge --ff-only -q "origin/$BRANCH" 2>&1)"; then
      log "FAILED: fast-forward refused, a local change conflicts with an incoming commit:"
      printf '%s\n' "$out" | sed 's/^/    /'
      return 1
    fi
    log "updated $before -> $(git rev-parse --short HEAD) ($behind commit(s))"
  fi

  # Run the installer as it is now, after the pull, so new manifest entries count.
  "$REPO_DIR/install.sh" --relink 2>&1 | sed 's/^/    /'
}

# -------------------------------------------------------------- schedule ----

install_schedule() {
  case "$(uname -s)" in
    Darwin)
      mkdir -p "$(dirname "$PLIST")" "$(dirname "$MAC_LOG")"
      cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>local.$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$REPO_DIR/sync.sh</string></array>
  <key>EnvironmentVariables</key>
  <dict><key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string></dict>
  <key>StartInterval</key><integer>3600</integer>
  <key>RunAtLoad</key><true/>
  <key>LowPriorityIO</key><true/>
  <key>StandardOutPath</key><string>$MAC_LOG</string>
  <key>StandardErrorPath</key><string>$MAC_LOG</string>
</dict>
</plist>
EOF
      launchctl bootout "gui/$(id -u)/local.$LABEL" 2>/dev/null || true
      launchctl bootstrap "gui/$(id -u)" "$PLIST"
      echo "installed: launchd agent local.$LABEL, every hour, log $MAC_LOG"
      ;;
    Linux)
      command -v systemctl >/dev/null || {
        echo "no systemd here; add this to crontab -e instead:"
        echo "  17 * * * * $REPO_DIR/sync.sh >> \$HOME/.$LABEL.log 2>&1"
        return 1
      }
      local dir ctl jflag
      if [ "$(id -u)" -eq 0 ]; then dir=/etc/systemd/system; ctl="systemctl"; jflag=""
      else dir="$HOME/.config/systemd/user"; ctl="systemctl --user"; jflag="--user "; mkdir -p "$dir"; fi
      cat > "$dir/$LABEL.service" <<EOF
[Unit]
Description=Sync dotfiles with origin/$BRANCH ($REPO_DIR)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
Environment=HOME=$HOME
ExecStart=/usr/bin/env bash $REPO_DIR/sync.sh
Nice=10
EOF
      cat > "$dir/$LABEL.timer" <<EOF
[Unit]
Description=Sync dotfiles every hour

[Timer]
OnCalendar=hourly
RandomizedDelaySec=300
Persistent=true

[Install]
WantedBy=timers.target
EOF
      $ctl daemon-reload
      $ctl enable --now "$LABEL.timer"
      echo "installed: $dir/$LABEL.timer, every hour; logs: journalctl ${jflag}-u $LABEL"
      [ "$(id -u)" -eq 0 ] || echo "for it to run while you are logged out: loginctl enable-linger $(id -un)"
      ;;
    *) echo "unsupported OS: $(uname -s)"; return 1 ;;
  esac
}

remove_schedule() {
  case "$(uname -s)" in
    Darwin)
      launchctl bootout "gui/$(id -u)/local.$LABEL" 2>/dev/null || true
      rm -f "$PLIST"; echo "removed: local.$LABEL" ;;
    Linux)
      local dir ctl
      if [ "$(id -u)" -eq 0 ]; then dir=/etc/systemd/system; ctl="systemctl"
      else dir="$HOME/.config/systemd/user"; ctl="systemctl --user"; fi
      $ctl disable --now "$LABEL.timer" 2>/dev/null || true
      rm -f "$dir/$LABEL.timer" "$dir/$LABEL.service"
      $ctl daemon-reload; echo "removed: $LABEL.timer" ;;
  esac
}

show_schedule() {
  case "$(uname -s)" in
    Darwin)
      if launchctl print "gui/$(id -u)/local.$LABEL" >/dev/null 2>&1; then
        echo "schedule: launchd local.$LABEL, every hour"
        launchctl print "gui/$(id -u)/local.$LABEL" | grep -E "last exit code|runs =" | sed 's/^[[:space:]]*/  /'
      else
        echo "schedule: none (./sync.sh --install-schedule)"
      fi
      echo "last results ($MAC_LOG):"
      tail -n 12 "$MAC_LOG" 2>/dev/null | sed 's/^/  /' || true ;;
    Linux)
      local ctl="systemctl" jflag=""
      [ "$(id -u)" -eq 0 ] || { ctl="systemctl --user"; jflag="--user"; }
      $ctl list-timers "$LABEL.timer" --no-pager 2>/dev/null | head -2 || echo "schedule: none"
      echo "last results:"
      # shellcheck disable=SC2086  # empty or --user
      journalctl $jflag -u "$LABEL" -n 12 --no-pager -o cat 2>/dev/null | sed 's/^/  /' || true ;;
  esac
}

case "${1:-}" in
  "")                  sync_once ;;
  --install-schedule)  install_schedule ;;
  --remove-schedule)   remove_schedule ;;
  --status)            show_schedule ;;
  -h|--help)           sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//' ;;
  *)                   echo "unknown option: $1 (see --help)"; exit 2 ;;
esac
