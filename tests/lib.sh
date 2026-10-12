# Shared by every suite: a pinned jq, a counter and the extraction of `run:` blocks from workflows.
# Sourced, not executed. The repository root is $ROOT, a scratch directory per suite is $WORK.
set -uo pipefail
TESTS=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$TESTS/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/wf-tests.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

JQ_VERSION=jq-1.7.1
JQ_SHA256=5942c9b0934e510ee61eb3e30273f1b3fe2590df93933a93d7c58b81d19c8ff5
JQ_URL=https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64

# The `run:` blocks are written for jq 1.7.1 (the runner image's): use it, or fetch the upstream binary
# and verify its SHA-256, so a newer local jq cannot hide a difference.
ensure_jq() {
  if [ "$(jq --version 2>/dev/null)" = "$JQ_VERSION" ]; then return; fi
  local cache="$TESTS/.cache"
  mkdir -p "$cache"
  if [ ! -x "$cache/jq" ]; then
    curl -fsSL -o "$cache/jq.part" "$JQ_URL"
    echo "$JQ_SHA256  $cache/jq.part" | sha256sum -c - > /dev/null || { echo "jq checksum mismatch" >&2; exit 1; }
    chmod +x "$cache/jq.part"; mv "$cache/jq.part" "$cache/jq"
  fi
  mkdir -p "$WORK/jqbin"; cp "$cache/jq" "$WORK/jqbin/jq"; export PATH="$WORK/jqbin:$PATH"
}
ensure_jq

pass=0 fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL: $1"; }
summary() { echo "$(basename "$(pwd)"): passed=$pass failed=$fail"; [ "$fail" = 0 ]; }

# extract_step <workflow-or-action yaml> <job id, or "-" for a composite action> <step name or id> <out file>
extract_step() {
  python3 -I "$TESTS/extract.py" "$1" "$2" "$3" "$4" || { echo "cannot extract '$3' from $1" >&2; exit 1; }
}
