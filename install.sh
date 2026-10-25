#!/usr/bin/env bash
set -euo pipefail

# Installs the pstack OpenCode tree (0.15.32 + opencode adapter) on a fresh system.
# The tree stays intact at PSTACK_DIR (default ~/pstack) so the skills'
# ../../docs/harness/opencode.md links resolve on disk. Registers it as an extra
# skill source in opencode.json, installs the two subagents with mode: subagent,
# and adds /command wrappers for skills hidden from the model.

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PSTACK_DIR="${PSTACK_DIR:-$HOME/pstack}"
OC="$HOME/.config/opencode"

echo "==> pstack tree -> $PSTACK_DIR"
rm -rf "$PSTACK_DIR"
mkdir -p "$PSTACK_DIR"
cp -R "$SRC/tree/." "$PSTACK_DIR/"

echo "==> registering $PSTACK_DIR/skills in $OC/opencode.json"
mkdir -p "$OC"
CFG="$OC/opencode.json"
if command -v node >/dev/null 2>&1; then
  node -e '
    const fs = require("fs");
    const p = process.argv[1], dir = process.argv[2];
    let cfg = {};
    if (fs.existsSync(p)) {
      try { cfg = JSON.parse(fs.readFileSync(p, "utf8")); }
      catch { console.error("existing opencode.json is not plain JSON (jsonc?); leaving it alone"); process.exit(0); }
    }
    cfg.skills = [...new Set([...(cfg.skills ?? []), dir])];
    fs.writeFileSync(p, JSON.stringify(cfg, null, 2) + "\n");
  ' "$CFG" "$PSTACK_DIR/skills" || true
  grep -q "\"$PSTACK_DIR/skills\"" "$CFG" 2>/dev/null || echo "    (not written — add by hand: { \"skills\": [\"$PSTACK_DIR/skills\"] })"
else
  echo "    node not found — add this to $CFG yourself:"
  echo "    { \"skills\": [\"$PSTACK_DIR/skills\"] }"
fi

echo "==> agents (mode: subagent) -> $OC/agents"
mkdir -p "$OC/agents"
for f in "$SRC"/tree/agents/*.md; do
  out="$OC/agents/$(basename "$f")"
  { sed -n '1p' "$f"; echo "mode: subagent"; sed -n '2,$p' "$f"; } > "$out"
  echo "    $(basename "$f")"
done

echo "==> /command wrappers for model-hidden skills -> $OC/commands"
mkdir -p "$OC/commands"
count=0
for d in "$SRC"/tree/skills/*/; do
  name="$(basename "$d")"
  grep -q "^disable-model-invocation: true" "$d/SKILL.md" 2>/dev/null || continue
  cat > "$OC/commands/$name.md" <<EOF
---
description: pstack $name (model-hidden; invoke via this command)
---
Read \`$PSTACK_DIR/skills/$name/SKILL.md\` in full and follow it.

Request: \$ARGUMENTS
EOF
  count=$((count + 1))
done
echo "    $count wrapper(s)"

cat <<EOF

Done. Next steps:

1. Restart opencode — new sessions pick up the config entry and the skills.
2. Set up models once. Ask opencode:
   "Read $PSTACK_DIR/skills/setup-pstack/SKILL.md and follow it"
   It runs \`opencode models\` and writes ~/.agents/pstack-models.md.
   Until then skills fall back to their defaults, mostly inherit-parent.
3. Use it: mention "@poteto-mode", or ask for "the poteto-mode skill".
   Model-hidden skills run via their new command, e.g. /arena.
4. Later updates: replace $PSTACK_DIR and $OC/agents, $OC/commands with a
   fresh generation. Remove the "skills" entry in $CFG to uninstall.
EOF
