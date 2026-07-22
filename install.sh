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

# ── Output helpers ─────────────────────────────────────────────
# Falls back to plain ASCII when not a TTY or NO_COLOR is set, so piped/
# redirected output (logs, CI) doesn't carry glyphs meant for a terminal.
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    FANCY=1
else
    FANCY=0
fi
ok()   { (( FANCY )) && echo "  ✓  $*" || echo "  [ok]   $*"; }
err()  { (( FANCY )) && echo "  ✗  $*" || echo "  [err]  $*"; }
skip() { (( FANCY )) && echo "  ↩  $*" || echo "  [skip] $*"; }

_count_images() {
    find "$1" -maxdepth 1 \
        \( -iname "*.jpg" -o -iname "*.jpeg" \
        -o -iname "*.png" -o -iname "*.heic" \
        -o -iname "*.webp" \) 2>/dev/null | wc -l | tr -d ' '
}

# ── Layout ─────────────────────────────────────────────────────
BIN="$HOME/.local/bin"
LIB="$HOME/.local/lib/shrutz"
ETC="$HOME/.local/etc/launchd"
MAN="$HOME/.local/share/man/man1"

WALLS_BASE="$LIB/wallpapers"

LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
LABEL="local.shrutz"
PLIST="$ETC/$LABEL.plist"
LINK="$LAUNCH_AGENTS/$LABEL.plist"

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$REPO_DIR/shrutz"

# ── Step 1: Check source script ────────────────────────────────
echo ""
echo "  shrutz installer"
echo "  ────────────────"

if [[ ! -f "$SRC" ]]; then
    err "'shrutz' not found next to install.sh"
    echo "     Keep both files in the same folder and re-run."
    exit 1
fi

# ── Step 2: Build directory tree ───────────────────────────────
# No specific set directory is created here — see Step 3. An empty
# wallpapers/ base is a safe intermediate state; `shrutz sets` already
# handles "no sets found" gracefully.
mkdir -p "$BIN" "$LIB" "$WALLS_BASE" "$ETC" "$LAUNCH_AGENTS" "$MAN"
ok "~/.local tree ready"

# ── Step 2b: Symlink the repo's wallpapers/ to the canonical store ─
# Keeps images in exactly one place (this dir) while still letting you
# browse/drop files in from the repo checkout — same idea as the
# launchd plist symlink below (canonical copy + a symlink to it).
REPO_WALLS="$REPO_DIR/wallpapers"
if [[ -L "$REPO_WALLS" ]]; then
    if [[ "$(readlink "$REPO_WALLS")" != "$WALLS_BASE" ]]; then
        rm -f "$REPO_WALLS"
        ln -s "$WALLS_BASE" "$REPO_WALLS"
        ok "repo wallpapers/ symlink repaired → $WALLS_BASE"
    else
        skip "repo wallpapers/ symlink already correct"
    fi
elif [[ -e "$REPO_WALLS" ]]; then
    err "'$REPO_WALLS' exists and isn't a symlink — leaving it alone"
    echo "     Move its contents into $WALLS_BASE and re-run install.sh to link it."
else
    ln -s "$WALLS_BASE" "$REPO_WALLS"
    ok "repo wallpapers/ → symlinked to $WALLS_BASE"
fi

# ── Step 3: Name your first wallpaper set (first install only) ─
# A fresh install has no state file yet — that's what "first install"
# means here. Re-running install.sh (repairs, `shrutz update`) always
# skips this block, so it never re-prompts. The set's directory name
# is derived directly from what's typed below, and that same value
# seeds ACTIVE_SET in Step 7 — there's no separately hardcoded default
# name for the two to drift out of sync with each other.
FIRST_INSTALL=0
[[ -f "$LIB/state" ]] || FIRST_INSTALL=1

ACTIVE_SET_DEFAULT=""
if (( FIRST_INSTALL == 1 )); then
    echo ""
    echo "  Name your first wallpaper set (this becomes your active set)."
    printf "  Set name (or Enter for 'main'): "
    read -r ACTIVE_SET_DEFAULT
    ACTIVE_SET_DEFAULT="${ACTIVE_SET_DEFAULT:-main}"

    WALLS_TARGET="$WALLS_BASE/$ACTIVE_SET_DEFAULT"
    mkdir -p "$WALLS_TARGET"
    cat > "$WALLS_TARGET/__init__" << INIT_EOF
name=$ACTIVE_SET_DEFAULT
created=$(date '+%Y-%m-%d %H:%M:%S')
images=0
INIT_EOF
    ok "set '$ACTIVE_SET_DEFAULT' created"

    echo ""
    echo "  Where are your wallpapers?"
    echo "  Enter a folder path to import now, or press Enter to skip."
    echo "  (Supported: .jpg .jpeg .png .heic .webp)"
    echo ""
    printf "  Path (or Enter to skip): "
    read -r WALL_SRC
    WALL_SRC="${WALL_SRC%/}"

    if [[ -z "$WALL_SRC" ]]; then
        skip "no folder given — add images later with: shrutz import <path>"
    elif [[ ! -d "$WALL_SRC" ]]; then
        err "'$WALL_SRC' is not a directory — skipped"
        echo "     Add images later with: shrutz import <path>"
    else
        # Copy supported images inline — binary isn't on PATH yet so we
        # can't call `shrutz import`; this mirrors _import_into in the script.
        _install_import() {
            local src="$1" dest="$2"
            local added=0 skipped=0 fname
            while IFS= read -r -d '' f; do
                fname=$(basename "$f")
                if [[ -f "$dest/$fname" ]]; then
                    (( skipped++ )) || true
                else
                    cp "$f" "$dest/$fname"
                    (( added++ )) || true
                fi
            done < <(find "$src" -maxdepth 1 \
                \( -iname "*.jpg"  -o -iname "*.jpeg" \
                -o -iname "*.png"  -o -iname "*.heic" \
                -o -iname "*.webp" \) \
                -print0)
            ok "$added images imported, $skipped skipped (duplicate filename)"
            local count init
            count=$(_count_images "$dest")
            init="$dest/__init__"
            if [[ -f "$init" ]]; then
                local tmp; tmp=$(grep -v '^images=' "$init")
                printf '%s\nimages=%s\n' "$tmp" "$count" > "$init"
            fi
        }
        echo "  Importing from '$WALL_SRC'..."
        _install_import "$WALL_SRC" "$WALLS_TARGET"
    fi
    echo ""

    if [[ "$(_count_images "$WALLS_TARGET")" == "0" ]]; then
        echo "  Note: '$ACTIVE_SET_DEFAULT' has no images yet, so the daemon won't"
        echo "  start automatically. Add some, then run: shrutz start"
        echo ""
    fi
fi

# ── Step 4: Install script ─────────────────────────────────────
cp "$SRC" "$BIN/shrutz"
chmod +x "$BIN/shrutz"
ok "$BIN/shrutz"

# ── Step 5: Add ~/.local/bin and MANPATH to shell RC ───────────
SHELL_RC=""
if [[ "$SHELL" == */zsh ]];  then SHELL_RC="$HOME/.zshrc"; fi
if [[ "$SHELL" == */bash ]]; then SHELL_RC="$HOME/.bashrc"; fi

if [[ -n "$SHELL_RC" ]]; then
    if ! grep -q '\.local/bin' "$SHELL_RC" 2>/dev/null; then
        printf '\n# Added by shrutz installer\nexport PATH="$HOME/.local/bin:$PATH"\n' \
            >> "$SHELL_RC"
        ok "PATH updated in $SHELL_RC"
    else
        skip "PATH already set"
    fi

    if ! grep -q 'local/share/man' "$SHELL_RC" 2>/dev/null; then
        printf 'export MANPATH="$HOME/.local/share/man:$MANPATH"\n' \
            >> "$SHELL_RC"
        ok "MANPATH updated in $SHELL_RC"
    else
        skip "MANPATH already set"
    fi
fi

# ── Step 6: Remove legacy shrutz() shell function if present ───
# Previous versions injected a shell function — no longer needed
# since shrutz is now a direct binary on PATH.
if [[ -n "$SHELL_RC" ]] && grep -q '# shrutz shell function' "$SHELL_RC" 2>/dev/null; then
    # Strip the block between the marker comment and the closing brace
    perl -i -0pe 's/\n# shrutz shell function.*?^}\n//ms' "$SHELL_RC" 2>/dev/null || true
    ok "legacy shrutz() shell function removed from $SHELL_RC"
fi

# ── Step 7: Seed state file ─────────────────────────────────────
if [[ ! -f "$LIB/state" ]]; then
    printf 'CURRENT_INDEX=0\nACTIVE_SECONDS=0\nACTIVE_SET=%s\n' "$ACTIVE_SET_DEFAULT" > "$LIB/state"
    ok "state file initialised (active set: $ACTIVE_SET_DEFAULT)"
else
    # Patch legacy (pre-sets) state files that lack ACTIVE_SET — a narrow
    # upgrade path from v1, never hit on a fresh install. Falls back to
    # the same "default" name load_state()'s own in-script fallback
    # already assumes when the key is missing entirely.
    if ! grep -q '^ACTIVE_SET=' "$LIB/state" 2>/dev/null; then
        echo "ACTIVE_SET=${ACTIVE_SET_DEFAULT:-default}" >> "$LIB/state"
        ok "state file patched (ACTIVE_SET added)"
    else
        skip "state file present"
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

ok "$PLIST"

# ── Step 9: Symlink into LaunchAgents ──────────────────────────
[[ -L "$LINK" || -f "$LINK" ]] && rm -f "$LINK"
ln -s "$PLIST" "$LINK"
ok "Symlinked → $LINK"

# ── Step 10: Load the agent — only if the active set has images ─
# Loading with an empty set would have the daemon hit its own
# TOTAL==0 guard, exit, and — since KeepAlive=true — get endlessly
# respawned by launchd in a silent crash loop. Skip loading until
# there's actually something to show.
ACTIVE_SET_NOW="$(grep '^ACTIVE_SET=' "$LIB/state" 2>/dev/null | cut -d= -f2-)"
ACTIVE_SET_NOW="${ACTIVE_SET_NOW:-${ACTIVE_SET_DEFAULT:-default}}"

launchctl unload "$LINK" 2>/dev/null || true
if [[ -d "$WALLS_BASE/$ACTIVE_SET_NOW" ]] && (( $(_count_images "$WALLS_BASE/$ACTIVE_SET_NOW") > 0 )); then
    launchctl load "$LINK"
    ok "Agent loaded and running"
else
    skip "active set '$ACTIVE_SET_NOW' has no images yet — daemon not started"
    echo "     add images, then run: shrutz start"
fi

# ── Step 11: Install man page ──────────────────────────────────
MAN_SRC="$(cd "$(dirname "$0")" && pwd)/shrutz.1"
if [[ -f "$MAN_SRC" ]]; then
    cp "$MAN_SRC" "$MAN/shrutz.1"
    ok "Man page installed → $MAN/shrutz.1"
else
    skip "shrutz.1 not found next to install.sh — man page skipped"
fi

# ── Step 11b: Install VERSION file ─────────────────────────────
VERSION_SRC="$REPO_DIR/VERSION"
if [[ -f "$VERSION_SRC" ]]; then
    cp "$VERSION_SRC" "$LIB/VERSION"
    ok "Version file installed → $LIB/VERSION"
else
    skip "VERSION not found next to install.sh — version file skipped"
fi

# ── Step 12: Record repo path in state ────────────────────────
if grep -q '^SHRUTZ_REPO=' "$LIB/state" 2>/dev/null; then
    sed -i '' "s|^SHRUTZ_REPO=.*|SHRUTZ_REPO=$REPO_DIR|" "$LIB/state"
else
    printf 'SHRUTZ_REPO=%s\n' "$REPO_DIR" >> "$LIB/state"
fi
ok "Repo path recorded ($REPO_DIR)"

# ── Done ───────────────────────────────────────────────────────
echo ""
echo "  Layout"
echo "  ──────────────────────────────────────────────────────────────"
echo "  ~/.local/bin/shrutz                           main binary"
echo "  ~/.local/lib/shrutz/wallpapers/<set>/         wallpaper sets"
echo "  ~/.local/lib/shrutz/wallpapers/$ACTIVE_SET_NOW/     your active set"
echo "  ~/.local/lib/shrutz/state                     active index + timer"
echo "  ~/.local/lib/shrutz/VERSION                   installed version"
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
echo "  Want more wallpapers?"
echo "  ──────────────────────────────────────────────────────────────"
echo "  shrutz ships with no bundled images. A small gallery of developer-"
echo "  curated sets — including the original \"haasan\" set — is available:"
echo ""
echo "    shrutz gallery list             browse available sets"
echo "    shrutz gallery install haasan   download and install one"
echo ""
