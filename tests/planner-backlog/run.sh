#!/usr/bin/env bash
# planner-backlog.yml's "Plan the backlog" and the setup-cli composite's "Install Claude Code" and
# "Build the CLI", run as written against stub wf, curl, claude and cargo. The CLI itself is tested in
# cli/ (cargo test).
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"
H=$WORK
extract_step "$ROOT/.github/workflows/planner-backlog.yml" planner-backlog "Plan the backlog" "$H/plan.sh"
extract_step "$ROOT/.github/actions/setup-cli/action.yml" - "Install Claude Code" "$H/install.sh"
extract_step "$ROOT/.github/actions/setup-cli/action.yml" - "Build the CLI" "$H/build.sh"
mkdir -p "$H/bin"

fresh() { # a runner's files for one case
  T=$H/t; rm -rf "$T"; mkdir -p "$T/tmp"
  export RUNNER_TEMP=$T/tmp GITHUB_STEP_SUMMARY=$T/summary GITHUB_OUTPUT=$T/output GITHUB_PATH=$T/path
  : > "$GITHUB_STEP_SUMMARY"; : > "$GITHUB_OUTPUT"; : > "$GITHUB_PATH"
}

# --- Plan the backlog: wf's exit status is the step's; the summary and the record reach the step summary.
cat > "$H/bin/wf" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$RUNNER_TEMP/wf.args"
command -v claude > "$RUNNER_TEMP/wf.claude"
out=; while [ $# -gt 0 ]; do [ "$1" = --out ] && out=$2; shift; done
mkdir -p "$out"
case $WF_CASE in
  ok)      echo "### Backlog order" > "$out/summary.md"; echo '{"ok":true}' > "$out/run-record-planner-backlog.json"; exit 0 ;;
  refused) echo '{"ok":false}' > "$out/run-record-planner-backlog.json"; exit 1 ;;
  broken)  exit 1 ;;
esac
EOF
chmod +x "$H/bin/wf"
mkdir -p "$H/claude-code"; printf '#!/usr/bin/env bash\n' > "$H/claude-code/claude"; chmod +x "$H/claude-code/claude"
plan() { WF=$H/bin/wf CLAUDE_DIR=$H/claude-code MODEL=claude-haiku-5-5 GITHUB_REPOSITORY=o/r WF_CASE=$1 bash "$H/plan.sh" > /dev/null 2>&1; RC=$?; }

fresh; plan ok
[ "$RC" = 0 ] && ok || bad "a passing wf fails the step ($RC)"
[ "$(cat "$RUNNER_TEMP/wf.claude")" = "$H/claude-code/claude" ] && ok || bad "wf does not find the pinned claude first on PATH: $(cat "$RUNNER_TEMP/wf.claude")"
grep -q '^### Backlog order' "$GITHUB_STEP_SUMMARY" && grep -q '^### Run record' "$GITHUB_STEP_SUMMARY" && ok || bad "summary or record missing from the step summary"
[ "$(tr '\n' ' ' < "$RUNNER_TEMP/wf.args")" = "planner backlog --repo o/r --model claude-haiku-5-5 --out $RUNNER_TEMP/planner " ] && ok || bad "wf arguments: $(tr '\n' ' ' < "$RUNNER_TEMP/wf.args")"

fresh; plan refused
[ "$RC" = 1 ] && ok || bad "a refused run does not fail the step ($RC)"
grep -q '"ok":false' "$GITHUB_STEP_SUMMARY" && ! grep -q '^### Backlog order' "$GITHUB_STEP_SUMMARY" && ok || bad "a refused run's record is not in the step summary"

fresh; plan broken
[ "$RC" = 1 ] && [ ! -s "$GITHUB_STEP_SUMMARY" ] && ok || bad "a broken run: rc $RC, summary $(wc -c < "$GITHUB_STEP_SUMMARY") bytes"

# --- Install Claude Code: the binary is used only when its SHA-256 and its version match.
cat > "$H/bin/curl" <<'EOF'
#!/usr/bin/env bash
o=; url=; while [ $# -gt 0 ]; do case $1 in -o) o=$2; shift ;; http*) url=$1 ;; esac; shift; done
echo "$url" > "$CURL_LOG"
printf '#!/usr/bin/env bash\necho "%s (Claude Code)"\n' "$STUB_VERSION" > "$o"
EOF
chmod +x "$H/bin/curl"
install() { # version-the-stub-prints sha-to-expect
  CURL_LOG=$T/curl.log STUB_VERSION=$1 CLAUDE_CODE_VERSION=2.1.296 CLAUDE_CODE_SHA256=$2 PATH="$H/bin:$PATH" bash "$H/install.sh" > /dev/null 2>&1; RC=$?
}
stub_sha() { # the SHA-256 of what the stub curl writes for a version
  printf '#!/usr/bin/env bash\necho "%s (Claude Code)"\n' "$1" | sha256sum | cut -d' ' -f1
}

fresh; install 2.1.296 "$(stub_sha 2.1.296)"
[ "$RC" = 0 ] && grep -qx "claude_dir=$RUNNER_TEMP/claude-code" "$GITHUB_OUTPUT" && ok || bad "a matching binary is not given as the output (rc $RC)"
[ ! -s "$GITHUB_PATH" ] && ok || bad "the install writes GITHUB_PATH, which every later step would inherit"
[ "$(cat "$T/curl.log")" = https://downloads.claude.ai/claude-code-releases/2.1.296/linux-x64/claude ] && ok || bad "download URL: $(cat "$T/curl.log")"

fresh; install 2.1.296 "$(stub_sha 2.1.295)"
[ "$RC" != 0 ] && [ ! -s "$GITHUB_OUTPUT" ] && ok || bad "a binary with another SHA-256 is used (rc $RC)"

fresh; install 2.1.295 "$(stub_sha 2.1.295)"
[ "$RC" != 0 ] && [ ! -s "$GITHUB_OUTPUT" ] && ok || bad "a binary of another version is used (rc $RC)"

# The pins in the action are a version and a 64-hex SHA-256.
grep -Eq '^        CLAUDE_CODE_VERSION: [0-9]+\.[0-9]+\.[0-9]+$' "$ROOT/.github/actions/setup-cli/action.yml" \
  && grep -Eq '^        CLAUDE_CODE_SHA256: [0-9a-f]{64}$' "$ROOT/.github/actions/setup-cli/action.yml" && ok || bad "the pins are not a version and a SHA-256"

# --- Build the CLI: --release --locked in the CLI directory; wf's path is the step output.
for tool in cargo rustup; do
  printf '#!/usr/bin/env bash\necho "%s $PWD $*" >> "$TOOL_LOG"\n' "$tool" > "$H/bin/$tool"; chmod +x "$H/bin/$tool"
done
fresh; mkdir -p "$T/src/cli"
TOOL_LOG=$T/tools.log CLI_DIR=$T/src/cli PATH="$H/bin:$PATH" bash "$H/build.sh" > /dev/null 2>&1; RC=$?
[ "$RC" = 0 ] && [ "$(cat "$T/tools.log")" = "rustup $T/src/cli toolchain install --no-self-update
cargo $T/src/cli build --release --locked" ] && ok || bad "toolchain and build calls: $(tr '\n' ';' < "$T/tools.log") (rc $RC)"
grep -qx "wf=$T/src/cli/target/release/wf" "$GITHUB_OUTPUT" && ok || bad "wf output: $(cat "$GITHUB_OUTPUT")"
grep -Eq '^- Rust toolchain install: [0-9]+ s$' "$GITHUB_STEP_SUMMARY" && grep -Eq '^- CLI build \(release, --locked, no cache\): [0-9]+ s$' "$GITHUB_STEP_SUMMARY" && ok || bad "toolchain or build time not in the step summary"

summary
