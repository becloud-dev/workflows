#!/usr/bin/env bash
# Bootstrap a repository that uses the shared workflows: labels, repository variables and the
# seed tag. Run by the repository owner after the template files are pushed to the default
# branch. Needs `gh` logged in with write access to the repository and read access to the
# organisation's issue fields.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: bootstrap.sh --repo OWNER/NAME --owners LOGIN[,LOGIN] --check CMD --test CMD
                    --test-paths GLOB[,GLOB] [--seed X.Y.Z] [--dry-run]

  --repo        repository to set up; the template files are already on its default branch
  --owners      comma-separated logins, no spaces (variable OWNERS)
  --check       check command (variable CHECK_COMMAND)
  --test        test command (variable TEST_COMMAND)
  --test-paths  comma-separated globs of test files (variable TEST_PATHS)
  --seed        version of the seed tag v<seed> (default 0.1.0); must equal .release-please-manifest.json
  --dry-run     read what is needed, print the writes, make none
EOF
  exit 2
}

repo="" owners="" check="" test_cmd="" test_paths="" seed="0.1.0" dry=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo=${2:-}; shift 2 || usage ;;
    --owners) owners=${2:-}; shift 2 || usage ;;
    --check) check=${2:-}; shift 2 || usage ;;
    --test) test_cmd=${2:-}; shift 2 || usage ;;
    --test-paths) test_paths=${2:-}; shift 2 || usage ;;
    --seed) seed=${2:-}; shift 2 || usage ;;
    --dry-run) dry=1; shift ;;
    *) usage ;;
  esac
done
[ -n "$repo" ] && [ -n "$owners" ] && [ -n "$check" ] && [ -n "$test_cmd" ] && [ -n "$test_paths" ] || usage

fail() { echo "bootstrap: $*" >&2; exit 1; }
[[ "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || fail "--repo must be OWNER/NAME"
[[ "$owners" =~ ^[A-Za-z0-9-]+(,[A-Za-z0-9-]+)*$ ]] || fail "--owners must be logins separated by commas, no spaces"
[[ "$seed" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "--seed must be X.Y.Z"

# reads first: nothing is written when one of them fails
branch=$(gh api "repos/$repo" --jq .default_branch) || fail "cannot read $repo"
[ -n "$branch" ] || fail "no default branch for $repo"
sha=$(gh api "repos/$repo/commits/$branch" --jq .sha) \
  || fail "no commit on $branch; push the template files first"
org=${repo%%/*}
priority_id=$(gh api "orgs/$org/issue-fields" \
  --jq '[.[] | select(.name == "Priority")] | if length == 1 then .[0].id else empty end') \
  || fail "cannot read the issue fields of $org"
[[ "$priority_id" =~ ^[0-9]+$ ]] || fail "$org must have exactly one issue field named Priority"
tag="v$seed"
if tag_sha=$(gh api "repos/$repo/git/ref/tags/$tag" --jq .object.sha 2>/dev/null); then
  tag_exists=1
else
  tag_exists=0
fi

run() {
  if [ "$dry" = 1 ]; then printf '+'; printf ' %q' "$@"; echo; else "$@"; fi
}

labels=(
  "triage|006B75|Start the AI triage run"
  "needs-info|F9D0C4|Triage needs an answer from the reporter"
  "UX/UI|7057ff|Start UX and UI research"
  "RELEASE|0e8a16|Start the development plan"
  "release-blocker|B60205|Blocks the release until closed"
  "READY TO LIVE|0E8A16|Release reviewed and accepted by the owner"
)
for entry in "${labels[@]}"; do
  IFS='|' read -r name color desc <<< "$entry"
  run gh label create "$name" --repo "$repo" --color "$color" --description "$desc" --force
done

run gh variable set OWNERS --repo "$repo" --body "$owners"
run gh variable set CHECK_COMMAND --repo "$repo" --body "$check"
run gh variable set TEST_COMMAND --repo "$repo" --body "$test_cmd"
run gh variable set TEST_PATHS --repo "$repo" --body "$test_paths"
run gh variable set PRIORITY_FIELD_ID --repo "$repo" --body "$priority_id"

if [ "$tag_exists" = 1 ]; then
  echo "tag $tag exists on $repo (object $tag_sha); left as it is. Default branch tip: $sha"
else
  run gh api -X POST "repos/$repo/git/refs" -f "ref=refs/tags/$tag" -f "sha=$sha"
fi

cat <<EOF

Done for $repo (default branch $branch, tip $sha).
Not done by this script (settings; run them yourself):
  - grant $repo the organisation secrets CLAUDE_CODE_OAUTH_TOKEN and APP_PRIVATE_KEY and the
    organisation variable APP_CLIENT_ID (their visibility is "selected");
  - default workflow permissions stay "read"; "Allow GitHub Actions to create and approve pull
    requests" stays off (the development execution PR step then fails: accepted gap).
EOF
