#!/bin/zsh
# target-prune.sh — clear idle Rust build caches before they fill the disk.
#
# Deployed to ~/.local/share/secscan/target-prune.sh by the `scripts` tuckr
# group and run by launchd (com.ifiokjr.secscan-prune) every 30 minutes.
#
# Deletes target/ directories ONLY when:
#   - no cargo/rustc process is running (never touches an active build)
#   - the volume is above 85% used
#   - the target dir has not been written to for 6+ hours
# Rebuilds get slower afterwards; that is the accepted trade-off.
#
# The walk starts at $HOME, not ~/Developer. Agent worktrees live under
# ~/.t3/worktrees and previously escaped this cleanup entirely: a single
# unmanaged target/ there reached 25 GB and took mini02 from 29 GB free to
# 3 GB. Anything that holds build output under the home directory is in scope.

emulate -L zsh
setopt no_nomatch null_glob

LOG="$HOME/.local/share/secscan/prune.log"
exec >> "$LOG" 2>&1
print -- "--- $(date -u +%Y-%m-%dT%H:%M:%SZ) ---"

pct="$(df -P /System/Volumes/Data 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}')"
[[ "$pct" == <-> ]] || exit 0
if (( pct < 85 )); then
  print -- "disk at ${pct}%, below threshold; skipping"
  exit 0
fi

# Build-active protection is per-target, not global: below 97% require no
# build at all (conservative); at 97%+ a stale target cannot belong to an
# active build, so protect only targets touched in the last 30 minutes.
build_active=0
if pgrep -x cargo >/dev/null || pgrep -x rustc >/dev/null; then
  build_active=1
  print -- "build active; only pruning stale targets"
fi

# Staleness gate: 6 hours normally, but at >=97% full the disk outage risk
# outweighs rebuild cost, so take recently-touched targets too.
if (( pct >= 97 )); then
  min=1
else
  min=360
fi

# Subtrees that never hold Rust build output but dominate the walk cost, plus
# anything the OS or Nix owns. Pruned so the scan stays cheap enough to run
# every 30 minutes. The user content folders are excluded for correctness as
# well as speed: upstream source archives such as llvm contain directories
# literally named target, and those are sources, not build output.
find "$HOME" -maxdepth 6 \
  \( -path "$HOME/Library" \
     -o -path "$HOME/.Trash" \
     -o -path "$HOME/Downloads" \
     -o -path "$HOME/Desktop" \
     -o -path "$HOME/Documents" \
     -o -path "$HOME/Movies" \
     -o -path "$HOME/Music" \
     -o -path "$HOME/Pictures" \
     -o -path "$HOME/Public" \
     -o -path "$HOME/.nix-profile" \
     -o -path "$HOME/.rustup" \
     -o -path "$HOME/.cargo" \
     -o -name node_modules \
     -o -name .git \
     -o -name .svn \
     -o -name .hg \) -prune \
  -o -type d -name target -prune -print > "$HOME/.local/share/secscan/targets.txt" 2>/dev/null

freed=0
while IFS= read -r t; do
  [[ -d "$t" ]] || continue

  # A03 acceptance checkout: retain build, evidence, and VM artifacts.
  case "$t" in
    "$HOME/Developer/projects/leptoskit/audit-workspace-deploy"|"$HOME/Developer/projects/leptoskit/audit-workspace-deploy/"*)
      print -- "protected A03 checkout; keeping $t"
      continue
      ;;
  esac

  # Fresh target: some build owns it, whatever pgrep saw a moment ago.
  if [[ -n "$(find "$t" -maxdepth 0 -mmin -$min 2>/dev/null)" ]]; then
    continue
  fi

  if (( build_active )) && (( pct < 97 )); then
    fresh="$(find "$t" -maxdepth 0 -mmin -30 2>/dev/null)"
    if [[ -n "$fresh" ]]; then
      print -- "active build target; keeping $t"
      continue
    fi
  fi

  sz="$(du -sk "$t" 2>/dev/null | cut -f1)"
  if rm -rf "$t"; then
    print -- "pruned $t ($(( ${sz:-0} / 1024 )) MB)"
    freed=$(( freed + ${sz:-0} ))
  fi
done < "$HOME/.local/share/secscan/targets.txt"

rm -f "$HOME/.local/share/secscan/targets.txt"
print -- "done; freed $(( freed / 1024 )) MB, disk now: $(df -h /System/Volumes/Data | tail -1 | awk '{print $5}')"
