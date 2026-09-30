#!/usr/bin/env bash
# Verify every model omp is configured to use is actually served by a
# logged-in provider. Run after `omp login openai-codex` (or -device).
# Exit 0 = all present, 1 = something missing, 2 = cannot list models.
set -euo pipefail

dir="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
omp_bin="${OMP_BIN:-$(command -v omp || echo "$HOME/.local/bin/omp")}"

wanted="$(grep -hoE '[a-z0-9-]+/gpt-[A-Za-z0-9.-]+|[a-z0-9-]+/claude-[A-Za-z0-9.-]+' \
  "$dir/config.yml" "$dir/max.yml" "$dir"/agents/*.md | sort -u)"

if ! available="$("$omp_bin" models --json 2>/dev/null |
  python3 -c 'import json,sys; d=json.load(sys.stdin); print("\n".join(m["selector"] for m in d.get("models", [])))')"; then
  echo "cannot list models: run '$omp_bin models' to see why" >&2
  exit 2
fi

missing=0
while read -r sel; do
  [ -z "$sel" ] && continue
  if grep -qxF "$sel" <<<"$available"; then
    echo "ok       $sel"
  else
    echo "MISSING  $sel"
    missing=1
  fi
done <<<"$wanted"

if [ "$missing" -ne 0 ]; then
  echo
  echo "Served by logged-in providers:"
  sed 's/^/  /' <<<"$available"
  echo "Replace each MISSING selector in config.yml / max.yml / agents/*.md with one listed above."
fi
exit "$missing"
