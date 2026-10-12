#!/usr/bin/env bash
# The install step of the install-zola composite against a fake release served over file://.
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"
ACTION="$ROOT/.github/actions/install-zola/action.yml"
extract_step "$ACTION" - install "$WORK/install.sh"

fake_release() { # out.tar.gz reported-version
  local d; d=$(mktemp -d "$WORK/rel.XXXXXX")
  printf '#!/usr/bin/env bash\necho "zola %s"\n' "$2" > "$d/zola"
  chmod +x "$d/zola"
  tar -czf "$1" -C "$d" zola
}
GOOD=$WORK/good.tar.gz; fake_release "$GOOD" 0.23.6; GOOD_SHA=$(sha256sum "$GOOD" | cut -d' ' -f1)
WRONG=$WORK/wrong.tar.gz; fake_release "$WRONG" 0.23.5; WRONG_SHA=$(sha256sum "$WRONG" | cut -d' ' -f1)
ZERO_SHA=$(printf '%064d' 0)

attempt() { # name VERSION SHA256 ZOLA_URL: runs the step in a fresh destination, sets DEST, GP, GE, RC, OUT
  DEST=$(mktemp -d "$WORK/dest.XXXXXX"); GP=$DEST.github_path; GE=$DEST.github_env
  echo before > "$GP"; echo before > "$GE"
  OUT=$(VERSION=$2 SHA256=$3 ZOLA_URL=$4 ZOLA_DEST=$DEST GITHUB_PATH=$GP GITHUB_ENV=$GE bash "$WORK/install.sh" 2>&1)
  RC=$?
}
nothing_installed() { [ -z "$(ls -A "$DEST")" ]; }
env_untouched() { [ "$(cat "$GP")" = before ] && [ "$(cat "$GE")" = before ]; }

echo "# good release"
attempt good 0.23.6 "$GOOD_SHA" "file://$GOOD"
[ "$RC" = 0 ] && ok || bad "good release: exit $RC: $OUT"
[ -x "$DEST/zola" ] && ok || bad "good release: no executable zola in dest"
[ "$("$DEST/zola" --version 2>/dev/null)" = "zola 0.23.6" ] && ok || bad "good release: installed binary reports wrong version"
env_untouched && ok || bad "good release: GITHUB_PATH or GITHUB_ENV written"

echo "# checksum mismatch"
attempt mismatch 0.23.6 "$ZERO_SHA" "file://$GOOD"
[ "$RC" != 0 ] && ok || bad "checksum mismatch: exit 0"
case "$OUT" in *"checksum mismatch"*) ok ;; *) bad "checksum mismatch: message missing ($OUT)" ;; esac
nothing_installed && ok || bad "checksum mismatch: something installed"

echo "# wrong reported version"
attempt version 0.23.6 "$WRONG_SHA" "file://$WRONG"
[ "$RC" != 0 ] && ok || bad "wrong version: exit 0"
case "$OUT" in *"unexpected version"*) ok ;; *) bad "wrong version: message missing ($OUT)" ;; esac
nothing_installed && ok || bad "wrong version: something installed"

echo "# invalid version inputs"
for v in "0.23" "0.23.6; id" "0.23.6; touch $WORK/pwned"; do
  attempt version-input "$v" "$GOOD_SHA" "file://$GOOD"
  [ "$RC" != 0 ] && ok || bad "version '$v': accepted"
  nothing_installed && ok || bad "version '$v': something installed"
  [ ! -e "$WORK/pwned" ] && ok || bad "version '$v': injected command ran"
done

echo "# invalid sha inputs"
for s in "abc123" "${GOOD_SHA^^}"; do
  attempt sha-input 0.23.6 "$s" "file://$GOOD"
  [ "$RC" != 0 ] && ok || bad "sha '$s': accepted"
  nothing_installed && ok || bad "sha '$s': something installed"
done

echo "# download failure"
attempt download 0.23.6 "$GOOD_SHA" "file:///nonexistent"
[ "$RC" != 0 ] && ok || bad "download failure: exit 0"
nothing_installed && ok || bad "download failure: something installed"

echo "# defaults"
if python3 - "$ACTION" <<'PY'
import re, sys, yaml
d = yaml.safe_load(open(sys.argv[1]))["inputs"]
v, s = str(d["version"]["default"]), str(d["sha256"]["default"])
sys.exit(0 if re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", v) and re.fullmatch(r"[0-9a-f]{64}", s) else 1)
PY
then ok; else bad "defaults: version or sha256 default is not X.Y.Z or 64 lower-case hex"; fi

echo "# step hygiene"
grep -qF '${{' "$WORK/install.sh" && bad "hygiene: expression inside run" || ok
grep -qE 'GITHUB_(PATH|ENV)' "$WORK/install.sh" && bad "hygiene: writes GITHUB_PATH or GITHUB_ENV" || ok

summary
