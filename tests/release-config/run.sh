#!/usr/bin/env bash
# The release-please policy for breaking changes below 1.0.0: both config files set bump-minor-pre-major
# on the "." package, and the manifest is still 0.x, the precondition that makes the option apply.
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"

# has_option <config file>: exit 0 when the "." package sets bump-minor-pre-major to true
has_option() { jq -e '.packages["."]["bump-minor-pre-major"] == true' "$1" > /dev/null; }

has_option "$ROOT/release-please-config.json" && ok || bad "root config has bump-minor-pre-major true"
has_option "$ROOT/templates/consumer/release-please-config.json" && ok || bad "consumer template config has bump-minor-pre-major true"
jq -e '.["."] | startswith("0.")' "$ROOT/.release-please-manifest.json" > /dev/null && ok || bad "manifest is still below 1.0.0"

# the checker must fail on a config without the option, or with it set to false
CFG=$WORK/config.json
jq 'del(.packages["."]["bump-minor-pre-major"])' "$ROOT/release-please-config.json" > "$CFG"
has_option "$CFG" && bad "checker passes a config without the option" || ok
jq '.packages["."]["bump-minor-pre-major"] = false' "$ROOT/release-please-config.json" > "$CFG"
has_option "$CFG" && bad "checker passes a config with the option false" || ok
summary
