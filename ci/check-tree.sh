#!/bin/bash
# Fails when generated or local output is tracked: the tree is published as-is
# to the public mirror, so only source belongs in it. Run: bash ci/check-tree.sh
set -euo pipefail
cd "$(dirname "$0")/.."
bad=$(git ls-files | grep -E '(^|/)__pycache__/|\.pyc$|\.xcodeproj/|\.xcresult/|(^|/)build/|\.log$|\.DS_Store$|\.(p8|p12|mobileprovision)$' || true)
if [ -n "$bad" ]; then
  echo "[check-tree] generated or local files are tracked; remove them and ignore them:"
  echo "$bad" | sed 's/^/  /'
  exit 1
fi
echo "[check-tree] only source is tracked ($(git ls-files | wc -l) files)"
