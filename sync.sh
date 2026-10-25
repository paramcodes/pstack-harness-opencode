#!/usr/bin/env bash
set -euo pipefail

# Sync pstack/ (and the generated tree/) from upstream cursor/plugins.
#
# Model: mirror-style refresh, same idea as the adapter mechanism itself. The
# upstream pstack/ folder is copied wholesale; our one local edit inside it,
# docs/harness/opencode.md, does not exist upstream, so rsync is told to keep it.
# scripts/generate-pstack-harness-trees.mjs is also ours (parameterized for two
# trees); upstream's version is diffed, never copied over it.
#
# Run from the repository root. Commit the result; UPSTREAM-SHA.txt records what
# was synced.

UPSTREAM_REPO="${UPSTREAM_REPO:-https://github.com/cursor/plugins.git}"
KEEP="docs/harness/opencode.md"   # our adapter; rsync --delete would remove it

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> fetching $UPSTREAM_REPO (sparse: pstack, scripts)"
git clone --depth 1 --filter=blob:none --sparse "$UPSTREAM_REPO" "$WORK/cursor" >/dev/null 2>&1
git -C "$WORK/cursor" sparse-checkout set pstack scripts >/dev/null 2>&1
SHA="$(git -C "$WORK/cursor" rev-parse HEAD)"
echo "    upstream main @ $SHA"

echo "==> refreshing pstack/ (keeping $KEEP)"
rsync -a --delete --exclude="$KEEP" "$WORK/cursor/pstack/" pstack/

# scripts/generate-pstack-harness-trees.mjs is ours (patched for two trees), so it
# always differs from upstream's. Detect real upstream changes by comparing against
# .upstream/generate-pstack-harness-trees.mjs — the last upstream copy we saw.
mkdir -p .upstream
if [ ! -f .upstream/generate-pstack-harness-trees.mjs ] || \
   ! diff -q "$WORK/cursor/scripts/generate-pstack-harness-trees.mjs" \
             .upstream/generate-pstack-harness-trees.mjs >/dev/null 2>&1; then
  echo "==> NOTE upstream changed the generator; ours is patched (multi-tree)."
  echo "    Review and re-apply our TREES parameterization:"
  echo "    diff -u .upstream/generate-pstack-harness-trees.mjs scripts/generate-pstack-harness-trees.mjs"
  echo "    (upstream's new version is what this note is about; it is stored below)"
fi
cp "$WORK/cursor/scripts/generate-pstack-harness-trees.mjs" \
   .upstream/generate-pstack-harness-trees.mjs

echo "==> regenerating trees (coverage gate runs here; it fails loudly if"
echo "    upstream introduced a Cursor term the adapter has no row for)"
node scripts/generate-pstack-harness-trees.mjs
rm -rf tree
cp -R harness/pstack/opencode tree
rm -rf harness

echo "$SHA" > UPSTREAM-SHA.txt

# A moved upstream tip with identical pstack content changes only the SHA record;
# commit that here so the workflow sees a clean tree and opens no PR for it.
if git diff --quiet && [ -z "$(git status --porcelain --untracked-files=normal)" ]; then
  echo "==> already in sync with $SHA; nothing to commit"
elif git diff --quiet -- . ':!UPSTREAM-SHA.txt' && \
     [ -z "$(git status --porcelain --untracked-files=normal -- . ':!UPSTREAM-SHA.txt')" ]; then
  git add UPSTREAM-SHA.txt
  if git commit -q -m "Record upstream cursor/plugins/pstack @ ${SHA:0:7} (pstack unchanged)" 2>/dev/null; then
    echo "==> upstream tip moved but pstack is unchanged; SHA recorded. Push when you like."
  else
    echo "==> upstream tip moved but pstack is unchanged; SHA recorded in UPSTREAM-SHA.txt (commit it yourself)."
  fi
else
  echo "==> changes ready. Commit with:"
  echo "    git add -A && git commit -m 'Sync upstream cursor/plugins/pstack @ ${SHA:0:7}'"
fi
