#!/bin/sh
# The fork must be the upstream tag plus our patches and nothing else: for each line with
# SB_<line>_FORK_COMMIT in versions.env, apply patches/v<line> to v<SB_<line>_VERSION> in a
# scratch index and compare the resulting tree with the tree of the fork commit.
#   scripts/check-fork.sh [-C <sing-box clone>] [lines...]
# Without -C a temporary bare repository fetches only the tag (SagerNet/sing-box) and the fork
# commit (podkop-net/sing-box), both with depth 1. With -C the clone must already have both.
# A line without SB_<line>_FORK_COMMIT is reported and skipped.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
UPSTREAM=${UPSTREAM:-https://github.com/SagerNet/sing-box.git}
FORK=${FORK:-https://github.com/podkop-net/sing-box.git}
repo=
if [ "${1:-}" = -C ]; then repo=$(cd "$2" && pwd); shift 2; fi
. "$here/versions.env"
[ $# -gt 0 ] || set -- $LINES

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
if [ -z "$repo" ]; then
  repo=$tmp/sb.git
  git init -q --bare "$repo"
  fetch=1
else
  fetch=
fi
# no automatic maintenance: a fetch starts it in the background, and it may rewrite the shallow file
# while the next fetch reads it ("shallow file has changed since we read it", the fork check of r25)
G() { git -C "$repo" -c maintenance.auto=false -c gc.auto=0 "$@"; }

status=0
for LINE in "$@"; do
  key=$(echo "$LINE" | tr . _)
  v=; fc=; eval "v=\${SB_${key}_VERSION:-}; fc=\${SB_${key}_FORK_COMMIT:-}"
  dir=$here/patches/v$LINE
  if [ -z "$v" ] || [ ! -d "$dir" ]; then echo "$LINE: unknown line" >&2; status=1; continue; fi
  if [ -z "$fc" ]; then echo "$LINE: no SB_${key}_FORK_COMMIT, skipped"; continue; fi
  if [ -n "$fetch" ]; then
    G fetch -q --depth 1 "$UPSTREAM" "refs/tags/v$v:refs/tags/v$v"
    G fetch -q --depth 1 "$FORK" "$fc"
  fi
  idx=$tmp/index-$key
  GIT_INDEX_FILE=$idx G read-tree "v$v^{tree}"
  n=0
  for p in "$dir"/*.patch; do
    # --cached: the index only, no work tree; no fuzz, so a patch that needs it fails here
    if ! GIT_INDEX_FILE=$idx G apply --cached "$p"; then
      echo "$LINE: $(basename "$p") does not apply to v$v" >&2; status=1; continue 2
    fi
    n=$((n + 1))
  done
  got=$(GIT_INDEX_FILE=$idx G write-tree)
  want=$(G rev-parse "$fc^{tree}")
  if [ "$got" = "$want" ]; then
    echo "$LINE: v$v + $n patches == fork $fc (tree $got)"
  else
    echo "$LINE: MISMATCH v$v + $n patches gives tree $got, fork $fc has $want" >&2
    if [ -z "$fetch" ]; then G diff --stat "$got" "$want" >&2; fi
    status=1
  fi
done
exit $status
