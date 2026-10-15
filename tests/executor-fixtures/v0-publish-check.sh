# Verbatim `run:` of the `dev-publish` step "Check the bundle against the plan" as shipped in `v0`
# (0.3.0, becloud-dev/workflows@ba97c52), the released major tag consumers pin. It is vendored here
# rather than read from the `v0` tag because the CI checkout has no tags (the read failed with
# `fatal: invalid object name 'v0'`): a fixture must not depend on remote history the runtime lacks.
# tests/executor-fixtures/run.sh runs it to show v0 accepts a forged plan (the #65 regression), and
# asserts this copy still matches the tag wherever the tag is present. Refresh from git show v0:... .
#@@ v0 verbatim below @@
set -euo pipefail
# the plan is read here from its comment, the only input besides the bundle and the base checkout; the
# same selection as the gate: the last comment by the bot that starts with the plan marker
plan=$(gh api --paginate "repos/$GITHUB_REPOSITORY/issues/$ISSUE/comments" --jq '.[]' \
  | jq -s 'map(select(.user.login == "github-actions[bot]" and (.body | startswith("<!-- dev-plan -->")))) | last // empty')
[ -n "$plan" ] || { echo "::error::there is no development plan comment on this issue"; exit 1; }
jq -r .body <<< "$plan" > "$RUNNER_TEMP/publish-plan.md"
# the backticked bullets between **Files** and the next bold line; the heading must be there
listing="$RUNNER_TEMP/publish-plan-files.txt"
awk 'BEGIN { seen = 0 }
     /^\*\*Files\*\*/ { inside = 1; seen = 1; next }
     inside && /^\*\*/ { inside = 0 }
     inside && /^- `[^`]+`/ { s = substr($0, 4); print substr(s, 1, index(s, "`") - 1) }
     END { exit !seen }' "$RUNNER_TEMP/publish-plan.md" > "$listing" \
  || { echo "::error::the plan has no **Files** heading"; exit 1; }
allowed=()
while IFS= read -r p; do allowed+=("$p"); done < "$listing"
# literal comparison only: an entry ending in / names a directory, any other entry one file
named() {
  local a
  for a in "${allowed[@]}"; do
    if [ "$1" = "$a" ] || { [[ $a == */ ]] && [[ $1 == "$a"* ]]; }; then return 0; fi
  done
  return 1
}
# the bundle's diff is read from the fresh git dir the verify step fetched it into, against the base of the checkout
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
base=$(git rev-parse HEAD)
export GIT_DIR="$RUNNER_TEMP/publish.git"
deleted="$RUNNER_TEMP/publish-deleted.bin" changed="$RUNNER_TEMP/publish-workflows.bin"
git diff --name-only --no-renames -z --diff-filter=D "$base...refs/push/head" > "$deleted" \
  || { echo "::error::the deletions in the bundle could not be read"; exit 1; }
git diff --name-only --no-renames -z --diff-filter=AM "$base...refs/push/head" -- .github/workflows > "$changed" \
  || { echo "::error::the workflow changes in the bundle could not be read"; exit 1; }
refused=0
while IFS= read -r -d '' p; do
  named "$p" || { echo "::error::deleted but not named in the plan Files list: $p"; refused=1; }
done < "$deleted"
while IFS= read -r -d '' p; do
  named "$p" || { echo "::error::changed under .github/workflows but not named in the plan Files list: $p"; refused=1; }
done < "$changed"
[ "$refused" = 0 ] || exit 1
