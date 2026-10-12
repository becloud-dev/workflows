#!/usr/bin/env bash
# Runs every suite under tests/*/run.sh and fails when one does. This is the repository's check.
set -uo pipefail
cd "$(dirname "$0")"
failed=0
for suite in */run.sh; do
  ( cd "$(dirname "$suite")" && bash run.sh ) || failed=$((failed+1))
done
[ "$failed" = 0 ] && echo "all suites passed" || { echo "$failed suite(s) failed" >&2; exit 1; }
