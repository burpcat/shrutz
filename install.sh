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

# ── Layout (mirrors XDG conventions, macOS-compatible) ─────────
BIN="$HOME/.local/bin"                  # executables on PATH
LIB="$HOME/.local/lib/shrutz"          # runtime data for shrutz
ETC="$HOME/.local/etc/launchd"         # source-of-truth for your plists
WALLS="$LIB/wallpapers"                # drop your images here

LAUNCH_AGENTS="$HOME/Library/LaunchAgents"   # where macOS reads agents from
LABEL="local.shrutz"
PLIST="$ETC/$LABEL.plist"
LINK="$LAUNCH_AGENTS/$LABEL.plist"

SRC="$(cd "$(dirname "$0")" && pwd)/shrutz"  # shrutz must sit next to install.sh

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
mkdir -p "$BIN" "$LIB" "$WALLS" "$ETC" "$LAUNCH_AGENTS"
echo "  ✓  ~/.local tree ready"

# ── Step 3: Install script ─────────────────────────────────────
cp "$SRC" "$BIN/shrutz"
chmod +x "$BIN/shrutz"
echo "  ✓  $BIN/shrutz"

# ── Step 4: Add ~/.local/bin to PATH (non-destructive) ─────────
SHELL_RC=""
if [[ "$SHELL" == */zsh ]];  then SHELL_RC="$HOME/.zshrc"; fi
if [[ "$SHELL" == */bash ]]; then SHELL_RC="$HOME/.bashrc"; fi

if [[ -n "$SHELL_RC" ]] && ! grep -q '\.local/bin' "$SHELL_RC" 2>/dev/null; then
    printf '\n# Added by shrutz installer\nexport PATH="$HOME/.local/bin:$PATH"\n' \
        >> "$SHELL_RC"
    echo "  ✓  PATH updated in $SHELL_RC"
fi

# ── Step 5: Inject shrutz() shell function ─────────────────────
# Uses $HOME so it resolves correctly for any user, in any session.
# Guarded by a marker comment so re-running install doesn't duplicate it.
if [[ -n "$SHELL_RC" ]] && ! grep -q '# shrutz shell function' "$SHELL_RC" 2>/dev/null; then
    cat >> "$SHELL_RC" << 'FUNC_EOF'

# shrutz shell function — added by shrutz installer
shrutz() {
  case "$1" in
    log)
      tail -f "$HOME/.local/lib/shrutz/shrutz.log"
      ;;
    start)
      launchctl load "$HOME/Library/LaunchAgents/local.shrutz.plist"
      ;;
    stop)
      launchctl unload "$HOME/Library/LaunchAgents/local.shrutz.plist"
      ;;
    status)
      launchctl list | grep shrutz
      ;;
    *)
      echo "Usage: shrutz [log|start|stop|status]"
      ;;
  esac
}
FUNC_EOF
    echo "  ✓  shrutz() function added to $SHELL_RC"
else
    echo "  ↩  shrutz() already in $SHELL_RC — skipped"
fi

# ── Step 6: Write the LaunchAgent plist ────────────────────────
# Plists do NOT support shell variable expansion — real paths must be
# written in at install time. The source of truth lives in ~/.local/etc/launchd/
# and is symlinked into ~/Library/LaunchAgents/ so your ~/.local stays canonical.
cat > "$PLIST" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>

    <!-- Unique reverse-DNS label. launchctl uses this as the job ID. -->
    <key>Label</key>
    <string>$LABEL</string>

    <!-- The command launchd will run. Using /usr/bin/env bash makes it
         independent of wherever bash lives on this machine. -->
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/env</string>
        <string>bash</string>
        <string>$BIN/shrutz</string>
    </array>

    <!-- Start the job as soon as the agent is loaded (i.e. at login). -->
    <key>RunAtLoad</key>
    <true/>

    <!-- If shrutz exits for any reason, launchd restarts it automatically. -->
    <key>KeepAlive</key>
    <true/>

    <!-- Stdout/stderr go to the lib folder alongside state and logs. -->
    <key>StandardOutPath</key>
    <string>$LIB/shrutz.log</string>
    <key>StandardErrorPath</key>
    <string>$LIB/shrutz.err</string>

</dict>
</plist>
PLIST_EOF

echo "  ✓  $PLIST"

# ── Step 7: Symlink into LaunchAgents ──────────────────────────
# Source of truth = ~/.local/etc/launchd/
# macOS reads from  = ~/Library/LaunchAgents/
# Symlink keeps both in sync without copying.
[[ -L "$LINK" || -f "$LINK" ]] && rm -f "$LINK"
ln -s "$PLIST" "$LINK"
echo "  ✓  Symlinked → $LINK"

# ── Step 8: Load the agent (takes effect immediately) ──────────
launchctl unload "$LINK" 2>/dev/null || true
launchctl load   "$LINK"
echo "  ✓  Agent loaded and running"

# ── Done ───────────────────────────────────────────────────────
echo ""
echo "  Layout"
echo "  ──────────────────────────────────────────────────────"
echo "  ~/.local/bin/shrutz                      main script"
echo "  ~/.local/lib/shrutz/wallpapers/          put images here"
echo "  ~/.local/lib/shrutz/state                active index + timer"
echo "  ~/.local/lib/shrutz/shrutz.log           activity log"
echo "  ~/.local/lib/shrutz/shrutz.err           stderr (crash info)"
echo "  ~/.local/etc/launchd/local.shrutz.plist  plist source"
echo "  ~/Library/LaunchAgents/local.shrutz.plist → (symlink)"
echo ""
echo "  Commands (reload your shell first: source $SHELL_RC)"
echo "  ──────────────────────────────────────────────────────"
echo "  shrutz log     stream the live log"
echo "  shrutz start   load and start the agent"
echo "  shrutz stop    unload and stop the agent"
echo "  shrutz status  check if the daemon is running"
echo ""
echo "  Drop your wallpapers into: $WALLS"
echo ""
