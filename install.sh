#!/usr/bin/env bash
# ┌─────────────────────────────────────────────────────────────┐
# │  shrutz — install.sh                                        │
# │                                                             │
# │  Run once. Sets up the full ~/.local layout,               │
# │  writes the LaunchAgent plist, symlinks it into             │
# │  ~/Library/LaunchAgents/, and starts the agent.            │
# │                                                             │
# │  Re-runnable: safe to run again to update or repair.       │
# └─────────────────────────────────────────────────────────────┘

set -euo pipefail

# ── Layout ─────────────────────────────────────────────────────
BIN="$HOME/.local/bin"
LIB="$HOME/.local/lib/shrutz"
ETC="$HOME/.local/etc/launchd"
MAN="$HOME/.local/share/man/man1"

WALLS_BASE="$LIB/wallpapers"
WALLS_DEFAULT="$WALLS_BASE/default"

LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
LABEL="local.shrutz"
PLIST="$ETC/$LABEL.plist"
LINK="$LAUNCH_AGENTS/$LABEL.plist"

SRC="$(cd "$(dirname "$0")" && pwd)/shrutz"

# ── Step 1: Check source script ────────────────────────────────
echo ""
echo "  shrutz installer"
echo "  ────────────────"

if [[ ! -f "$SRC" ]]; then
    echo "  ✗  'shrutz' not found next to install.sh"
    echo "     Keep both files in the same folder and re-run."
    exit 1
fi

# ── Step 2: Build directory tree ───────────────────────────────
mkdir -p "$BIN" "$LIB" "$WALLS_DEFAULT" "$ETC" "$LAUNCH_AGENTS" "$MAN"
echo "  ✓  ~/.local tree ready"

# ── Step 3: Write default set __init__ if absent ───────────────
if [[ ! -f "$WALLS_DEFAULT/__init__" ]]; then
    cat > "$WALLS_DEFAULT/__init__" << INIT_EOF
name=default
created=$(date '+%Y-%m-%d %H:%M:%S')
images=0
INIT_EOF
    echo "  ✓  default wallpaper set initialised"
else
    echo "  ↩  default set already exists — skipped"
fi

# ── Step 4: Install script ─────────────────────────────────────
cp "$SRC" "$BIN/shrutz"
chmod +x "$BIN/shrutz"
echo "  ✓  $BIN/shrutz"

# ── Step 5: Add ~/.local/bin and MANPATH to shell RC ───────────
SHELL_RC=""
if [[ "$SHELL" == */zsh ]];  then SHELL_RC="$HOME/.zshrc"; fi
if [[ "$SHELL" == */bash ]]; then SHELL_RC="$HOME/.bashrc"; fi

if [[ -n "$SHELL_RC" ]]; then
    if ! grep -q '\.local/bin' "$SHELL_RC" 2>/dev/null; then
        printf '\n# Added by shrutz installer\nexport PATH="$HOME/.local/bin:$PATH"\n' \
            >> "$SHELL_RC"
        echo "  ✓  PATH updated in $SHELL_RC"
    else
        echo "  ↩  PATH already set — skipped"
    fi

    if ! grep -q 'local/share/man' "$SHELL_RC" 2>/dev/null; then
        printf 'export MANPATH="$HOME/.local/share/man:$MANPATH"\n' \
            >> "$SHELL_RC"
        echo "  ✓  MANPATH updated in $SHELL_RC"
    else
        echo "  ↩  MANPATH already set — skipped"
    fi
fi

# ── Step 6: Remove legacy shrutz() shell function if present ───
# Previous versions injected a shell function — no longer needed
# since shrutz is now a direct binary on PATH.
if [[ -n "$SHELL_RC" ]] && grep -q '# shrutz shell function' "$SHELL_RC" 2>/dev/null; then
    # Strip the block between the marker comment and the closing brace
    perl -i -0pe 's/\n# shrutz shell function.*?^}\n//ms' "$SHELL_RC" 2>/dev/null || true
    echo "  ✓  legacy shrutz() shell function removed from $SHELL_RC"
fi

# ── Step 7: Seed state file if absent ─────────────────────────
if [[ ! -f "$LIB/state" ]]; then
    printf 'CURRENT_INDEX=0\nACTIVE_SECONDS=0\nACTIVE_SET=default\n' > "$LIB/state"
    echo "  ✓  state file initialised"
else
    # Patch legacy state files that lack ACTIVE_SET
    if ! grep -q '^ACTIVE_SET=' "$LIB/state" 2>/dev/null; then
        echo 'ACTIVE_SET=default' >> "$LIB/state"
        echo "  ✓  state file patched (ACTIVE_SET added)"
    else
        echo "  ↩  state file present — skipped"
    fi
fi

# ── Step 8: Write the LaunchAgent plist ────────────────────────
cat > "$PLIST" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>

    <key>Label</key>
    <string>$LABEL</string>

    <!-- No arguments = daemon mode. The shrutz binary checks argv[1]
         and falls through to run_daemon when nothing is passed. -->
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/env</string>
        <string>bash</string>
        <string>$BIN/shrutz</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>$LIB/shrutz.log</string>
    <key>StandardErrorPath</key>
    <string>$LIB/shrutz.err</string>

</dict>
</plist>
PLIST_EOF

echo "  ✓  $PLIST"

# ── Step 9: Symlink into LaunchAgents ──────────────────────────
[[ -L "$LINK" || -f "$LINK" ]] && rm -f "$LINK"
ln -s "$PLIST" "$LINK"
echo "  ✓  Symlinked → $LINK"

# ── Step 10: Load the agent ────────────────────────────────────
launchctl unload "$LINK" 2>/dev/null || true
launchctl load   "$LINK"
echo "  ✓  Agent loaded and running"

# ── Done ───────────────────────────────────────────────────────
echo ""
echo "  Layout"
echo "  ──────────────────────────────────────────────────────────────"
echo "  ~/.local/bin/shrutz                           main binary"
echo "  ~/.local/lib/shrutz/wallpapers/<set>/         wallpaper sets"
echo "  ~/.local/lib/shrutz/wallpapers/default/       default set"
echo "  ~/.local/lib/shrutz/state                     active index + timer"
echo "  ~/.local/lib/shrutz/shrutz.log                activity log"
echo "  ~/.local/lib/shrutz/shrutz.err                stderr (crash info)"
echo "  ~/.local/etc/launchd/local.shrutz.plist       plist source"
echo "  ~/Library/LaunchAgents/local.shrutz.plist  →  (symlink)"
echo ""
echo "  Commands (reload your shell first: source $SHELL_RC)"
echo "  ──────────────────────────────────────────────────────────────"
echo "  shrutz status              daemon status"
echo "  shrutz log                 stream the live log"
echo "  shrutz start / stop        manage the daemon"
echo "  shrutz sets                list all wallpaper sets"
echo "  shrutz set create <name>   create a new set"
echo "  shrutz set info <name>     set details and progress"
echo "  shrutz switch <set>        switch active wallpaper set"
echo "  shrutz import <path>       import images into active set"
echo "  shrutz help                full command reference"
echo ""
echo "  Drop wallpapers into: $WALLS_DEFAULT"
echo "  Or: shrutz import ~/path/to/images"
echo ""