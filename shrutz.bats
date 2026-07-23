#!/usr/bin/env bats
# ┌─────────────────────────────────────────────────────────────────┐
# │  shrutz — integration test suite                               │
# │                                                                 │
# │  Layer 2: fake filesystem, no macOS APIs, no daemon process.   │
# │  Every test runs shrutz subcommands against an isolated        │
# │  temp directory so nothing touches your real shrutz install.   │
# │                                                                 │
# │  Run:  bats shrutz.bats                                        │
# └─────────────────────────────────────────────────────────────────┘

# ── Test environment setup ────────────────────────────────────────
# We override HOME to a temp dir so shrutz resolves all its paths
# to our sandbox. The real ~/.local/lib/shrutz is never touched.

setup() {
    # Unique temp dir per test
    TEST_HOME="$(mktemp -d /tmp/shrutz-test-XXXXXX)"
    export HOME="$TEST_HOME"

    # Mirror the real path layout
    SHRUTZ_LIB="$TEST_HOME/.local/lib/shrutz"
    WALLPAPER_BASE="$SHRUTZ_LIB/wallpapers"
    STATE_FILE="$SHRUTZ_LIB/state"
    LOG_FILE="$SHRUTZ_LIB/shrutz.log"

    mkdir -p \
        "$TEST_HOME/.local/bin" \
        "$SHRUTZ_LIB/wallpapers/default" \
        "$TEST_HOME/.local/etc/launchd" \
        "$TEST_HOME/Library/LaunchAgents"

    # Install a copy of shrutz into the sandbox bin
    # SHRUTZ_BIN points to the script under test — adjust if needed
    SHRUTZ_BIN="${BATS_TEST_DIRNAME}/shrutz"
    cp "$SHRUTZ_BIN" "$TEST_HOME/.local/bin/shrutz"
    chmod +x "$TEST_HOME/.local/bin/shrutz"

    # Stub out macOS-only commands that must not run in tests.
    # Each stub is a tiny script that does nothing (or echoes a
    # safe value) and lives earlier on PATH than the real binary.
    STUB_DIR="$TEST_HOME/stubs"
    mkdir -p "$STUB_DIR"

    # launchctl — called by start/stop/restart_daemon; silenced
    cat > "$STUB_DIR/launchctl" << 'STUB'
#!/usr/bin/env bash
# Stub: record call and exit 0
echo "launchctl $*" >> "$HOME/.local/lib/shrutz/launchctl.calls"
exit 0
STUB

    # pgrep — daemon_pid(); return empty so signal commands report
    # "daemon not running" cleanly without killing real processes
    cat > "$STUB_DIR/pgrep" << 'STUB'
#!/usr/bin/env bash
exit 1
STUB

    # osascript — never called in Layer 2 but stub for safety
    cat > "$STUB_DIR/osascript" << 'STUB'
#!/usr/bin/env bash
exit 0
STUB

    # ioreg — never called in Layer 2 but stub for safety
    cat > "$STUB_DIR/ioreg" << 'STUB'
#!/usr/bin/env bash
echo "HIDIdleTime = 999999999999"
STUB

    # open — _maybe_launch_menubar_app(); record calls instead of really
    # launching anything.
    cat > "$STUB_DIR/open" << 'STUB'
#!/usr/bin/env bash
echo "open $*" >> "$HOME/.local/lib/shrutz/open.calls"
exit 0
STUB

    chmod +x "$STUB_DIR"/*
    export PATH="$STUB_DIR:$PATH"

    # Seed a minimal valid state file
    cat > "$STATE_FILE" << STATE
CURRENT_INDEX=0
ACTIVE_SECONDS=0
ACTIVE_SET=default
PAUSED=0
PLAY_ORDER=
SHRUTZ_REPO=
STATE

    # Seed the default set __init__
    cat > "$WALLPAPER_BASE/default/__init__" << INIT
name=default
created=2025-01-01 00:00:00
images=0
INIT

    # Convenience: the shrutz binary path for all tests
    SHRUTZ="$TEST_HOME/.local/bin/shrutz"
}

teardown() {
    rm -rf "$TEST_HOME"
}

# ── Helpers ───────────────────────────────────────────────────────

# Create n placeholder image files in a set directory
make_images() {
    local dir="$1" count="${2:-3}" ext="${3:-png}"
    for i in $(seq -w 1 "$count"); do
        touch "$dir/${i}.${ext}"
    done
}

# Read a single key from the state file
state_get() {
    local key="$1"
    grep "^${key}=" "$STATE_FILE" | cut -d= -f2-
}

# Read a single key from a set's __init__
init_get() {
    local set_name="$1" key="$2"
    grep "^${key}=" "$WALLPAPER_BASE/$set_name/__init__" | cut -d= -f2-
}

# Seed a minimal, valid LaunchAgent plist at the path `cmd_autostart`
# reads/writes, with RunAtLoad set to the given bool ("true"/"false").
seed_launchagent_plist() {
    local run_at_load="${1:-true}"
    mkdir -p "$TEST_HOME/Library/LaunchAgents"
    cat > "$TEST_HOME/Library/LaunchAgents/local.shrutz.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>local.shrutz</string>
    <key>RunAtLoad</key>
    <${run_at_load}/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
PLIST
}

# ══════════════════════════════════════════════════════════════════
# STATE — read / write round-trip
# ══════════════════════════════════════════════════════════════════

@test "state: all six fields survive a write then read" {
    cat > "$STATE_FILE" << STATE
CURRENT_INDEX=7
ACTIVE_SECONDS=900
ACTIVE_SET=nature
PAUSED=1
PLAY_ORDER=3 1 4 1 5
SHRUTZ_REPO=/Users/test/shrutz
STATE

    run grep "^CURRENT_INDEX=" "$STATE_FILE"
    [ "$status" -eq 0 ]
    [[ "$output" == "CURRENT_INDEX=7" ]]

    run grep "^ACTIVE_SECONDS=" "$STATE_FILE"
    [[ "$output" == "ACTIVE_SECONDS=900" ]]

    run grep "^ACTIVE_SET=" "$STATE_FILE"
    [[ "$output" == "ACTIVE_SET=nature" ]]

    run grep "^PAUSED=" "$STATE_FILE"
    [[ "$output" == "PAUSED=1" ]]

    run grep "^PLAY_ORDER=" "$STATE_FILE"
    [[ "$output" == "PLAY_ORDER=3 1 4 1 5" ]]

    run grep "^SHRUTZ_REPO=" "$STATE_FILE"
    [[ "$output" == "SHRUTZ_REPO=/Users/test/shrutz" ]]
}

@test "state: missing state file defaults cleanly (no error)" {
    rm -f "$STATE_FILE"
    # 'now' reads state; with no images it will error on image resolution
    # but it must NOT error on missing state itself — check no 'source' error
    run bash -c "source '$SHRUTZ' 2>&1; load_state; echo \$ACTIVE_SET" 2>&1 || true
    # We just need no 'No such file' error from the source call
    [[ "$output" != *"No such file"* ]]
}

# ══════════════════════════════════════════════════════════════════
# SET CREATE
# ══════════════════════════════════════════════════════════════════

@test "set create: directory is created" {
    run "$SHRUTZ" set create nature
    [ "$status" -eq 0 ]
    [ -d "$WALLPAPER_BASE/nature" ]
}

@test "set create: __init__ is written with correct name" {
    run "$SHRUTZ" set create nature
    [ -f "$WALLPAPER_BASE/nature/__init__" ]
    run grep "^name=" "$WALLPAPER_BASE/nature/__init__"
    [[ "$output" == "name=nature" ]]
}

@test "set create: __init__ contains created timestamp" {
    run "$SHRUTZ" set create nature
    run grep "^created=" "$WALLPAPER_BASE/nature/__init__"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^created=[0-9]{4} ]]
}

@test "set create: fails if set already exists" {
    "$SHRUTZ" set create nature
    run "$SHRUTZ" set create nature
    [ "$status" -ne 0 ]
    [[ "$output" == *"already exists"* ]]
}

@test "set create: with source path imports images immediately" {
    local src="$TEST_HOME/src_images"
    mkdir -p "$src"
    touch "$src/a.png" "$src/b.jpg" "$src/c.heic"

    run "$SHRUTZ" set create outdoor "$src"
    [ "$status" -eq 0 ]
    [ -f "$WALLPAPER_BASE/outdoor/a.png" ]
    [ -f "$WALLPAPER_BASE/outdoor/b.jpg" ]
    [ -f "$WALLPAPER_BASE/outdoor/c.heic" ]
}

@test "set create: with source path updates image count in __init__" {
    local src="$TEST_HOME/src_images"
    mkdir -p "$src"
    touch "$src/a.png" "$src/b.png"

    "$SHRUTZ" set create outdoor "$src"
    run grep "^images=" "$WALLPAPER_BASE/outdoor/__init__"
    [[ "$output" == "images=2" ]]
}

@test "set create: no args prints usage and exits non-zero" {
    run "$SHRUTZ" set create
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

# ══════════════════════════════════════════════════════════════════
# SET DELETE
# ══════════════════════════════════════════════════════════════════

@test "set delete: removes the directory when confirmed" {
    "$SHRUTZ" set create old
    touch "$WALLPAPER_BASE/old/wall.png"
    # Pipe 'y' to answer the confirmation prompt
    run bash -c "echo y | '$SHRUTZ' set delete old"
    [ "$status" -eq 0 ]
    [ ! -d "$WALLPAPER_BASE/old" ]
}

@test "set delete: cancelled when user answers N" {
    "$SHRUTZ" set create old
    run bash -c "echo N | '$SHRUTZ' set delete old"
    [ "$status" -eq 0 ]
    [ -d "$WALLPAPER_BASE/old" ]
    [[ "$output" == *"cancelled"* ]]
}

@test "set delete: blocks deletion of the active set" {
    # default is active per the seeded state file
    run bash -c "echo y | '$SHRUTZ' set delete default"
    [ "$status" -ne 0 ]
    [[ "$output" == *"cannot delete"* ]]
    [ -d "$WALLPAPER_BASE/default" ]
}

@test "set delete: fails if set does not exist" {
    run bash -c "echo y | '$SHRUTZ' set delete nonexistent"
    [ "$status" -ne 0 ]
    [[ "$output" == *"does not exist"* ]]
}

@test "set delete: no args prints usage" {
    run "$SHRUTZ" set delete
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "set delete: -y skips the confirmation prompt entirely" {
    "$SHRUTZ" set create old
    touch "$WALLPAPER_BASE/old/wall.png"
    run "$SHRUTZ" set delete old -y
    [ "$status" -eq 0 ]
    [ ! -d "$WALLPAPER_BASE/old" ]
    [[ "$output" != *"[y/N]"* ]]
}

@test "set delete: --yes is a synonym for -y" {
    "$SHRUTZ" set create old
    run "$SHRUTZ" set delete old --yes
    [ "$status" -eq 0 ]
    [ ! -d "$WALLPAPER_BASE/old" ]
}

@test "set delete: -y still refuses to delete the active set" {
    run "$SHRUTZ" set delete default -y
    [ "$status" -ne 0 ]
    [[ "$output" == *"cannot delete"* ]]
    [ -d "$WALLPAPER_BASE/default" ]
}

@test "set delete: -y does not block on stdin (proves the prompt was actually skipped, not just answered EOF/no)" {
    "$SHRUTZ" set create old
    run bash -c "'$SHRUTZ' set delete old -y < /dev/null"
    [ "$status" -eq 0 ]
    [ ! -d "$WALLPAPER_BASE/old" ]
}

# ══════════════════════════════════════════════════════════════════
# SET RENAME
# ══════════════════════════════════════════════════════════════════

@test "set rename: directory is moved" {
    "$SHRUTZ" set create oldname
    run "$SHRUTZ" set rename oldname newname
    [ "$status" -eq 0 ]
    [ ! -d "$WALLPAPER_BASE/oldname" ]
    [ -d "$WALLPAPER_BASE/newname" ]
}

@test "set rename: __init__ name field is updated" {
    "$SHRUTZ" set create oldname
    "$SHRUTZ" set rename oldname newname
    run grep "^name=" "$WALLPAPER_BASE/newname/__init__"
    [[ "$output" == "name=newname" ]]
}

@test "set rename: patches ACTIVE_SET in state when active set is renamed" {
    # Make 'myset' the active set in state
    cat > "$STATE_FILE" << STATE
CURRENT_INDEX=0
ACTIVE_SECONDS=500
ACTIVE_SET=myset
PAUSED=0
PLAY_ORDER=
SHRUTZ_REPO=
STATE
    mkdir -p "$WALLPAPER_BASE/myset"
    cat > "$WALLPAPER_BASE/myset/__init__" << INIT
name=myset
created=2025-01-01 00:00:00
images=0
INIT

    run "$SHRUTZ" set rename myset renamed
    [ "$status" -eq 0 ]
    run grep "^ACTIVE_SET=" "$STATE_FILE"
    [[ "$output" == "ACTIVE_SET=renamed" ]]
}

@test "set rename: does not touch ACTIVE_SET when renaming inactive set" {
    "$SHRUTZ" set create other
    "$SHRUTZ" set rename other other2
    run grep "^ACTIVE_SET=" "$STATE_FILE"
    [[ "$output" == "ACTIVE_SET=default" ]]
}

@test "set rename: fails if target name already exists" {
    "$SHRUTZ" set create alpha
    "$SHRUTZ" set create beta
    run "$SHRUTZ" set rename alpha beta
    [ "$status" -ne 0 ]
    [[ "$output" == *"already exists"* ]]
}

@test "set rename: fails if source does not exist" {
    run "$SHRUTZ" set rename ghost something
    [ "$status" -ne 0 ]
    [[ "$output" == *"does not exist"* ]]
}

@test "set rename: no args prints usage" {
    run "$SHRUTZ" set rename
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

# ══════════════════════════════════════════════════════════════════
# SET INFO
# ══════════════════════════════════════════════════════════════════

@test "set info: prints set name" {
    make_images "$WALLPAPER_BASE/default" 3
    run "$SHRUTZ" set info default
    [ "$status" -eq 0 ]
    [[ "$output" == *"default"* ]]
}

@test "set info: shows correct image count" {
    make_images "$WALLPAPER_BASE/default" 5
    run "$SHRUTZ" set info default
    [[ "$output" == *"5"* ]]
}

@test "set info: marks active set with (active)" {
    make_images "$WALLPAPER_BASE/default" 1
    run "$SHRUTZ" set info default
    [[ "$output" == *"(active)"* ]]
}

@test "set info: does not mark inactive set as active" {
    "$SHRUTZ" set create other
    make_images "$WALLPAPER_BASE/other" 1
    run "$SHRUTZ" set info other
    [[ "$output" != *"(active)"* ]]
}

@test "set info: shows progress fields for active set" {
    make_images "$WALLPAPER_BASE/default" 3
    cat > "$STATE_FILE" << STATE
CURRENT_INDEX=1
ACTIVE_SECONDS=900
ACTIVE_SET=default
PAUSED=0
PLAY_ORDER=
SHRUTZ_REPO=
STATE
    run "$SHRUTZ" set info default
    [[ "$output" == *"Progress"* ]]
    [[ "$output" == *"Position"* ]]
}

@test "set info: fails if set does not exist" {
    run "$SHRUTZ" set info ghost
    [ "$status" -ne 0 ]
    [[ "$output" == *"does not exist"* ]]
}

# ══════════════════════════════════════════════════════════════════
# SET SHUFFLE
# ══════════════════════════════════════════════════════════════════

@test "set shuffle on: writes shuffle=true to __init__" {
    run "$SHRUTZ" set shuffle default on
    [ "$status" -eq 0 ]
    run grep "^shuffle=" "$WALLPAPER_BASE/default/__init__"
    [[ "$output" == "shuffle=true" ]]
}

@test "set shuffle off: writes shuffle=false to __init__" {
    # First turn on, then off
    "$SHRUTZ" set shuffle default on
    run "$SHRUTZ" set shuffle default off
    [ "$status" -eq 0 ]
    run grep "^shuffle=" "$WALLPAPER_BASE/default/__init__"
    [[ "$output" == "shuffle=false" ]]
}

@test "set shuffle: toggling twice ends at original value" {
    "$SHRUTZ" set shuffle default on
    "$SHRUTZ" set shuffle default off
    run grep "^shuffle=" "$WALLPAPER_BASE/default/__init__"
    [[ "$output" == "shuffle=false" ]]
}

@test "set shuffle: clears PLAY_ORDER in state when toggled on active set" {
    # Seed a non-empty PLAY_ORDER
    cat > "$STATE_FILE" << STATE
CURRENT_INDEX=0
ACTIVE_SECONDS=0
ACTIVE_SET=default
PAUSED=0
PLAY_ORDER=2 0 1
SHRUTZ_REPO=
STATE
    run "$SHRUTZ" set shuffle default on
    run grep "^PLAY_ORDER=" "$STATE_FILE"
    [[ "$output" == "PLAY_ORDER=" ]]
}

@test "set shuffle: fails with invalid mode" {
    run "$SHRUTZ" set shuffle default maybe
    [ "$status" -ne 0 ]
    [[ "$output" == *"must be"* ]]
}

@test "set shuffle: fails if set does not exist" {
    run "$SHRUTZ" set shuffle ghost on
    [ "$status" -ne 0 ]
    [[ "$output" == *"does not exist"* ]]
}

@test "set shuffle: no args prints usage" {
    run "$SHRUTZ" set shuffle
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

# ══════════════════════════════════════════════════════════════════
# SWITCH
# ══════════════════════════════════════════════════════════════════

@test "switch: updates ACTIVE_SET in state" {
    "$SHRUTZ" set create nature
    make_images "$WALLPAPER_BASE/nature" 2
    run "$SHRUTZ" switch nature
    [ "$status" -eq 0 ]
    run grep "^ACTIVE_SET=" "$STATE_FILE"
    [[ "$output" == "ACTIVE_SET=nature" ]]
}

@test "switch: resets CURRENT_INDEX to 0" {
    cat > "$STATE_FILE" << STATE
CURRENT_INDEX=5
ACTIVE_SECONDS=600
ACTIVE_SET=default
PAUSED=0
PLAY_ORDER=
SHRUTZ_REPO=
STATE
    "$SHRUTZ" set create nature
    make_images "$WALLPAPER_BASE/nature" 3
    "$SHRUTZ" switch nature
    run grep "^CURRENT_INDEX=" "$STATE_FILE"
    [[ "$output" == "CURRENT_INDEX=0" ]]
}

@test "switch: preserves ACTIVE_SECONDS (timer never resets)" {
    cat > "$STATE_FILE" << STATE
CURRENT_INDEX=0
ACTIVE_SECONDS=1234
ACTIVE_SET=default
PAUSED=0
PLAY_ORDER=
SHRUTZ_REPO=
STATE
    "$SHRUTZ" set create nature
    make_images "$WALLPAPER_BASE/nature" 2
    "$SHRUTZ" switch nature
    run grep "^ACTIVE_SECONDS=" "$STATE_FILE"
    [[ "$output" == "ACTIVE_SECONDS=1234" ]]
}

@test "switch: preserves PAUSED flag" {
    cat > "$STATE_FILE" << STATE
CURRENT_INDEX=0
ACTIVE_SECONDS=0
ACTIVE_SET=default
PAUSED=1
PLAY_ORDER=
SHRUTZ_REPO=
STATE
    "$SHRUTZ" set create nature
    make_images "$WALLPAPER_BASE/nature" 2
    "$SHRUTZ" switch nature
    run grep "^PAUSED=" "$STATE_FILE"
    [[ "$output" == "PAUSED=1" ]]
}

@test "switch: no-ops when switching to already active set" {
    make_images "$WALLPAPER_BASE/default" 2
    run "$SHRUTZ" switch default
    [ "$status" -eq 0 ]
    [[ "$output" == *"already the active set"* ]]
}

@test "switch: fails if set does not exist" {
    run "$SHRUTZ" switch ghost
    [ "$status" -ne 0 ]
    [[ "$output" == *"does not exist"* ]]
}

@test "switch: fails if set exists but has no images" {
    "$SHRUTZ" set create empty
    run "$SHRUTZ" switch empty
    [ "$status" -ne 0 ]
    [[ "$output" == *"no images"* ]]
}

@test "switch: no args prints usage" {
    run "$SHRUTZ" switch
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

# ══════════════════════════════════════════════════════════════════
# IMPORT
# ══════════════════════════════════════════════════════════════════

@test "import: copies a single file into the active set" {
    local src="$TEST_HOME/wall.png"
    touch "$src"
    run "$SHRUTZ" import "$src"
    [ "$status" -eq 0 ]
    [ -f "$WALLPAPER_BASE/default/wall.png" ]
}

@test "import: copies all supported formats from a directory" {
    local src="$TEST_HOME/src"
    mkdir -p "$src"
    touch "$src/a.png" "$src/b.jpg" "$src/c.jpeg" "$src/d.heic" "$src/e.webp"
    run "$SHRUTZ" import "$src"
    [ "$status" -eq 0 ]
    [ -f "$WALLPAPER_BASE/default/a.png" ]
    [ -f "$WALLPAPER_BASE/default/b.jpg" ]
    [ -f "$WALLPAPER_BASE/default/c.jpeg" ]
    [ -f "$WALLPAPER_BASE/default/d.heic" ]
    [ -f "$WALLPAPER_BASE/default/e.webp" ]
}

@test "import: ignores unsupported file types" {
    local src="$TEST_HOME/src"
    mkdir -p "$src"
    touch "$src/doc.pdf" "$src/movie.mp4" "$src/note.txt"
    run "$SHRUTZ" import "$src"
    [ "$status" -eq 0 ]
    [ ! -f "$WALLPAPER_BASE/default/doc.pdf" ]
    [ ! -f "$WALLPAPER_BASE/default/movie.mp4" ]
}

@test "import: deduplicates by filename — second import is skipped" {
    local src="$TEST_HOME/src"
    mkdir -p "$src"
    touch "$src/wall.png"
    "$SHRUTZ" import "$src"
    # Modify the source file (different content, same name)
    echo "new content" > "$src/wall.png"
    run "$SHRUTZ" import "$src"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 skipped"* ]]
}

@test "import: reports correct added and skipped counts" {
    local src="$TEST_HOME/src"
    mkdir -p "$src"
    touch "$src/a.png" "$src/b.png" "$src/c.png"
    "$SHRUTZ" import "$src"
    touch "$src/d.png"  # new file
    run "$SHRUTZ" import "$src"
    [[ "$output" == *"1 added"* ]]
    [[ "$output" == *"3 skipped"* ]]
}

@test "import: updates __init__ image count after import" {
    local src="$TEST_HOME/src"
    mkdir -p "$src"
    touch "$src/a.png" "$src/b.png"
    "$SHRUTZ" import "$src"
    run grep "^images=" "$WALLPAPER_BASE/default/__init__"
    [[ "$output" == "images=2" ]]
}

@test "import --set: imports into a named set, not the active set" {
    "$SHRUTZ" set create other
    local src="$TEST_HOME/src"
    mkdir -p "$src"
    touch "$src/wall.png"
    run "$SHRUTZ" import "$src" --set other
    [ "$status" -eq 0 ]
    [ -f "$WALLPAPER_BASE/other/wall.png" ]
    [ ! -f "$WALLPAPER_BASE/default/wall.png" ]
}

@test "import --set: fails if target set does not exist" {
    local src="$TEST_HOME/src"
    mkdir -p "$src"
    touch "$src/wall.png"
    run "$SHRUTZ" import "$src" --set ghost
    [ "$status" -ne 0 ]
    [[ "$output" == *"does not exist"* ]]
}

@test "import: fails if source path does not exist" {
    run "$SHRUTZ" import /nonexistent/path
    [ "$status" -ne 0 ]
    [[ "$output" == *"not a file or directory"* ]]
}

@test "import: no args prints usage" {
    run "$SHRUTZ" import
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

# ══════════════════════════════════════════════════════════════════
# SETS LIST
# ══════════════════════════════════════════════════════════════════

@test "sets: lists the default set" {
    run "$SHRUTZ" sets
    [ "$status" -eq 0 ]
    [[ "$output" == *"default"* ]]
}

@test "sets: marks the active set with active indicator" {
    run "$SHRUTZ" sets
    [[ "$output" == *"active"* ]]
}

@test "sets: lists multiple sets" {
    "$SHRUTZ" set create alpha
    "$SHRUTZ" set create beta
    run "$SHRUTZ" sets
    [[ "$output" == *"alpha"* ]]
    [[ "$output" == *"beta"* ]]
}

@test "sets: shows image count per set" {
    make_images "$WALLPAPER_BASE/default" 4
    run "$SHRUTZ" sets
    [[ "$output" == *"4"* ]]
}

# ══════════════════════════════════════════════════════════════════
# NOW
# ══════════════════════════════════════════════════════════════════

@test "now: shows active set name" {
    make_images "$WALLPAPER_BASE/default" 3
    run "$SHRUTZ" now
    [ "$status" -eq 0 ]
    [[ "$output" == *"default"* ]]
}

@test "now: shows timer info" {
    make_images "$WALLPAPER_BASE/default" 3
    cat > "$STATE_FILE" << STATE
CURRENT_INDEX=1
ACTIVE_SECONDS=600
ACTIVE_SET=default
PAUSED=0
PLAY_ORDER=
SHRUTZ_REPO=
STATE
    run "$SHRUTZ" now
    [[ "$output" == *"Timer"* ]]
    [[ "$output" == *"10m"* ]]
}

@test "now: shows PAUSED label when paused" {
    make_images "$WALLPAPER_BASE/default" 3
    cat > "$STATE_FILE" << STATE
CURRENT_INDEX=0
ACTIVE_SECONDS=0
ACTIVE_SET=default
PAUSED=1
PLAY_ORDER=
SHRUTZ_REPO=
STATE
    run "$SHRUTZ" now
    [[ "$output" == *"PAUSED"* ]]
}

@test "now: shows position in set" {
    make_images "$WALLPAPER_BASE/default" 5
    cat > "$STATE_FILE" << STATE
CURRENT_INDEX=2
ACTIVE_SECONDS=0
ACTIVE_SET=default
PAUSED=0
PLAY_ORDER=
SHRUTZ_REPO=
STATE
    run "$SHRUTZ" now
    [[ "$output" == *"3 of 5"* ]]
}

# ══════════════════════════════════════════════════════════════════
# STATS
# ══════════════════════════════════════════════════════════════════

@test "stats: exits cleanly with no log file" {
    rm -f "$LOG_FILE"
    make_images "$WALLPAPER_BASE/default" 2
    run "$SHRUTZ" stats
    [ "$status" -eq 0 ]
}

@test "stats: shows active set name" {
    run "$SHRUTZ" stats
    [[ "$output" == *"default"* ]]
}

@test "stats: counts total switches from log" {
    cat > "$LOG_FILE" << LOG
[2025-01-01 09:00:00] Switched → [2/5] 02.png
[2025-01-01 09:30:00] Switched → [3/5] 03.png
[2025-01-01 10:00:00] Switched → [4/5] 04.png
LOG
    run "$SHRUTZ" stats
    [[ "$output" == *"3"* ]]
}

@test "stats: counts sets and total images" {
    make_images "$WALLPAPER_BASE/default" 3
    "$SHRUTZ" set create other
    make_images "$WALLPAPER_BASE/other" 2
    run "$SHRUTZ" stats
    [[ "$output" == *"5"* ]]   # total images
    [[ "$output" == *"2"* ]]   # set count (at least)
}

@test "stats: shows paused label when paused" {
    cat > "$STATE_FILE" << STATE
CURRENT_INDEX=0
ACTIVE_SECONDS=0
ACTIVE_SET=default
PAUSED=1
PLAY_ORDER=
SHRUTZ_REPO=
STATE
    run "$SHRUTZ" stats
    [[ "$output" == *"paused"* ]]
}

# ══════════════════════════════════════════════════════════════════
# HISTORY
# ══════════════════════════════════════════════════════════════════

@test "history: exits cleanly with no log" {
    rm -f "$LOG_FILE"
    run "$SHRUTZ" history
    [ "$status" -eq 0 ]
}

@test "history: shows switch entries from log" {
    cat > "$LOG_FILE" << LOG
[2025-01-01 09:00:00] Switched → [2/5] 02.png (timer unchanged)
[2025-01-01 09:30:00] Switched → [3/5] 03.png (timer unchanged)
LOG
    run "$SHRUTZ" history
    [[ "$output" == *"02.png"* ]]
    [[ "$output" == *"03.png"* ]]
}

@test "history: respects count argument" {
    for i in $(seq 1 15); do
        printf '[2025-01-01 09:%02d:00] Switched → [%d/15] %02d.png\n' \
            "$i" "$i" "$i" >> "$LOG_FILE"
    done
    run "$SHRUTZ" history 5
    # Should show exactly 5 data rows (plus 2 header lines)
    local data_lines
    data_lines=$(echo "$output" | grep -c '\.png' || true)
    [ "$data_lines" -eq 5 ]
}

@test "history: defaults to 10 entries" {
    for i in $(seq 1 15); do
        printf '[2025-01-01 09:%02d:00] Switched → [%d/15] %02d.png\n' \
            "$i" "$i" "$i" >> "$LOG_FILE"
    done
    run "$SHRUTZ" history
    local data_lines
    data_lines=$(echo "$output" | grep -c '\.png' || true)
    [ "$data_lines" -eq 10 ]
}

@test "history: includes next/prev entries" {
    cat > "$LOG_FILE" << LOG
[2025-01-01 09:00:00] next → [3/5] 03.png (timer unchanged)
[2025-01-01 09:01:00] prev → [2/5] 02.png (timer unchanged)
LOG
    run "$SHRUTZ" history
    [[ "$output" == *"03.png"* ]]
    [[ "$output" == *"02.png"* ]]
}

@test "history: fails with non-numeric count" {
    run "$SHRUTZ" history abc
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

# ══════════════════════════════════════════════════════════════════
# CONFIG
# ══════════════════════════════════════════════════════════════════

@test "config: no args prints all three tunables" {
    run "$SHRUTZ" config
    [ "$status" -eq 0 ]
    [[ "$output" == *"ACTIVE_MINS"* ]]
    [[ "$output" == *"IDLE_THRESHOLD"* ]]
    [[ "$output" == *"CHECK_EVERY"* ]]
}

@test "config: patches ACTIVE_MINS in the script" {
    run "$SHRUTZ" config ACTIVE_MINS 45
    [ "$status" -eq 0 ]
    # grep returns full line including inline comment — match with glob
    run grep "^ACTIVE_MINS=" "$SHRUTZ"
    [[ "$output" == "ACTIVE_MINS=45"* ]]
}

@test "config: patches IDLE_THRESHOLD in the script" {
    run "$SHRUTZ" config IDLE_THRESHOLD 120
    [ "$status" -eq 0 ]
    run grep "^IDLE_THRESHOLD=" "$SHRUTZ"
    [[ "$output" == "IDLE_THRESHOLD=120"* ]]
}

@test "config: patches CHECK_EVERY in the script" {
    run "$SHRUTZ" config CHECK_EVERY 60
    [ "$status" -eq 0 ]
    run grep "^CHECK_EVERY=" "$SHRUTZ"
    [[ "$output" == "CHECK_EVERY=60"* ]]
}

@test "config: rejects unknown key" {
    run "$SHRUTZ" config UNKNOWN_KEY 99
    [ "$status" -ne 0 ]
    [[ "$output" == *"unknown config key"* ]]
}

@test "config: rejects non-integer value" {
    run "$SHRUTZ" config ACTIVE_MINS thirty
    [ "$status" -ne 0 ]
    [[ "$output" == *"positive integer"* ]]
}

@test "config: rejects missing value" {
    run "$SHRUTZ" config ACTIVE_MINS
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

# ══════════════════════════════════════════════════════════════════
# EXPORT
# ══════════════════════════════════════════════════════════════════

@test "export: creates a zip file at the default destination" {
    make_images "$WALLPAPER_BASE/default" 3
    mkdir -p "$TEST_HOME/Desktop"
    run "$SHRUTZ" export default "$TEST_HOME/Desktop"
    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/Desktop/default.zip" ]
}

@test "export: zip contains the images" {
    make_images "$WALLPAPER_BASE/default" 2
    mkdir -p "$TEST_HOME/Desktop"
    "$SHRUTZ" export default "$TEST_HOME/Desktop"
    run unzip -l "$TEST_HOME/Desktop/default.zip"
    [[ "$output" == *".png"* ]]
}

@test "export: zip contains __init__" {
    make_images "$WALLPAPER_BASE/default" 1
    mkdir -p "$TEST_HOME/Desktop"
    "$SHRUTZ" export default "$TEST_HOME/Desktop"
    run unzip -l "$TEST_HOME/Desktop/default.zip"
    [[ "$output" == *"__init__"* ]]
}

@test "export: fails if set does not exist" {
    mkdir -p "$TEST_HOME/Desktop"
    run "$SHRUTZ" export ghost "$TEST_HOME/Desktop"
    [ "$status" -ne 0 ]
    [[ "$output" == *"does not exist"* ]]
}

@test "export: fails if destination does not exist" {
    make_images "$WALLPAPER_BASE/default" 1
    run "$SHRUTZ" export default /nonexistent/path
    [ "$status" -ne 0 ]
    [[ "$output" == *"does not exist"* ]]
}

@test "export: no args prints usage" {
    run "$SHRUTZ" export
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

# ══════════════════════════════════════════════════════════════════
# HELP / UNKNOWN COMMANDS
# ══════════════════════════════════════════════════════════════════

@test "help: exits 0 and lists command groups" {
    run "$SHRUTZ" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Daemon"* ]]
    [[ "$output" == *"Playback"* ]]
    [[ "$output" == *"Sets"* ]]
    [[ "$output" == *"Info"* ]]
}

@test "--help flag: same as help" {
    run "$SHRUTZ" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "unknown command: exits non-zero with helpful message" {
    run "$SHRUTZ" foobar
    [ "$status" -ne 0 ]
    [[ "$output" == *"unknown command"* ]]
    [[ "$output" == *"shrutz help"* ]]
}

# ══════════════════════════════════════════════════════════════════
# EDGE CASES — filesystem and format
# ══════════════════════════════════════════════════════════════════

@test "count_images: ignores __init__ and non-image files" {
    touch "$WALLPAPER_BASE/default/notes.txt"
    touch "$WALLPAPER_BASE/default/script.sh"
    make_images "$WALLPAPER_BASE/default" 2
    run "$SHRUTZ" set info default
    [[ "$output" == *"Images:     2"* ]]
}

@test "import: handles filenames with spaces" {
    local src="$TEST_HOME/src"
    mkdir -p "$src"
    touch "$src/my wallpaper.png"
    run "$SHRUTZ" import "$src"
    [ "$status" -eq 0 ]
    [ -f "$WALLPAPER_BASE/default/my wallpaper.png" ]
}

@test "set create: name with hyphens and underscores is valid" {
    run "$SHRUTZ" set create my-cool_set
    [ "$status" -eq 0 ]
    [ -d "$WALLPAPER_BASE/my-cool_set" ]
}

@test "switch: CURRENT_INDEX in state is always 0 after switch" {
    cat > "$STATE_FILE" << STATE
CURRENT_INDEX=12
ACTIVE_SECONDS=999
ACTIVE_SET=default
PAUSED=0
PLAY_ORDER=
SHRUTZ_REPO=
STATE
    "$SHRUTZ" set create fresh
    make_images "$WALLPAPER_BASE/fresh" 3
    "$SHRUTZ" switch fresh
    run grep "^CURRENT_INDEX=" "$STATE_FILE"
    [[ "$output" == "CURRENT_INDEX=0" ]]
}

@test "import then switch: images in original set are untouched" {
    local src="$TEST_HOME/src"
    mkdir -p "$src"
    touch "$src/wall.png"
    "$SHRUTZ" import "$src"
    "$SHRUTZ" set create other
    make_images "$WALLPAPER_BASE/other" 2
    "$SHRUTZ" switch other
    [ -f "$WALLPAPER_BASE/default/wall.png" ]
}

@test "set delete then create same name: works cleanly" {
    "$SHRUTZ" set create temp
    bash -c "echo y | '$SHRUTZ' set delete temp"
    run "$SHRUTZ" set create temp
    [ "$status" -eq 0 ]
    [ -d "$WALLPAPER_BASE/temp" ]
}

@test "refresh_init_count: image count updates after additional import" {
    local src="$TEST_HOME/src"
    mkdir -p "$src"
    touch "$src/a.png"
    "$SHRUTZ" import "$src"
    touch "$src/b.png"
    "$SHRUTZ" import "$src"
    run grep "^images=" "$WALLPAPER_BASE/default/__init__"
    [[ "$output" == "images=2" ]]
}

# ══════════════════════════════════════════════════════════════════
# DIEANDDONTCOMEBACK — soft delete and full wipe
# ══════════════════════════════════════════════════════════════════

@test "dieanddontcomeback: cancelled when answer does not contain yes" {
    run bash -c "echo 'no' | '$SHRUTZ' dieanddontcomeback"
    [ "$status" -eq 0 ]
    [[ "$output" == *"fine, staying"* ]]
    [ -f "$SHRUTZ" ]
}

@test "dieanddontcomeback: cancelled when answer is y alone" {
    run bash -c "echo 'y' | '$SHRUTZ' dieanddontcomeback"
    [ "$status" -eq 0 ]
    [[ "$output" == *"fine, staying"* ]]
    [ -f "$SHRUTZ" ]
}

@test "dieanddontcomeback: cancelled when answer is yep" {
    run bash -c "echo 'yep' | '$SHRUTZ' dieanddontcomeback"
    [ "$status" -eq 0 ]
    [[ "$output" == *"fine, staying"* ]]
    [ -f "$SHRUTZ" ]
}

@test "dieanddontcomeback: accepts bare 'yes'" {
    run bash -c "echo 'yes' | '$SHRUTZ' dieanddontcomeback"
    [ "$status" -eq 0 ]
    [[ "$output" != *"fine, staying"* ]]
}

@test "dieanddontcomeback: accepts 'yes' anywhere in the answer" {
    run bash -c "echo 'yeah yes go ahead' | '$SHRUTZ' dieanddontcomeback"
    [ "$status" -eq 0 ]
    [[ "$output" != *"fine, staying"* ]]
}

@test "dieanddontcomeback: accepts uppercase YES" {
    run bash -c "echo 'YES' | '$SHRUTZ' dieanddontcomeback"
    [ "$status" -eq 0 ]
    [[ "$output" != *"fine, staying"* ]]
}

@test "dieanddontcomeback: soft delete removes the binary" {
    run bash -c "echo 'yes' | '$SHRUTZ' dieanddontcomeback"
    [ "$status" -eq 0 ]
    [ ! -f "$SHRUTZ" ]
}

@test "dieanddontcomeback: soft delete preserves wallpaper sets" {
    make_images "$WALLPAPER_BASE/default" 3
    "$SHRUTZ" set create nature
    make_images "$WALLPAPER_BASE/nature" 2
    bash -c "echo 'yes' | '$SHRUTZ' dieanddontcomeback"
    [ -d "$WALLPAPER_BASE/default" ]
    [ -d "$WALLPAPER_BASE/nature" ]
    [ -f "$WALLPAPER_BASE/default/1.png" ]
}

@test "dieanddontcomeback: soft delete preserves state file" {
    bash -c "echo 'yes' | '$SHRUTZ' dieanddontcomeback"
    [ -f "$STATE_FILE" ]
}

@test "dieanddontcomeback: soft delete preserves log file" {
    printf '[2025-01-01 09:00:00] shrutz started\n' > "$LOG_FILE"
    bash -c "echo 'yes' | '$SHRUTZ' dieanddontcomeback"
    [ -f "$LOG_FILE" ]
}

@test "dieanddontcomeback: soft delete output mentions wallpapers are untouched" {
    run bash -c "echo 'yes' | '$SHRUTZ' dieanddontcomeback"
    [[ "$output" == *"untouched"* ]]
}

@test "dieanddontcomeback --ever: cancelled when answer does not contain yes" {
    run bash -c "echo 'nope' | '$SHRUTZ' dieanddontcomeback --ever"
    [ "$status" -eq 0 ]
    [[ "$output" == *"fine, staying"* ]]
    [ -f "$SHRUTZ" ]
}

@test "dieanddontcomeback --ever: removes the binary" {
    run bash -c "echo 'yes' | '$SHRUTZ' dieanddontcomeback --ever"
    [ "$status" -eq 0 ]
    [ ! -f "$SHRUTZ" ]
}

@test "dieanddontcomeback --ever: removes the entire lib directory" {
    bash -c "echo 'yes' | '$SHRUTZ' dieanddontcomeback --ever"
    [ ! -d "$SHRUTZ_LIB" ]
}

@test "dieanddontcomeback --ever: removes wallpaper sets" {
    make_images "$WALLPAPER_BASE/default" 3
    "$SHRUTZ" set create nature
    bash -c "echo 'yes' | '$SHRUTZ' dieanddontcomeback --ever"
    [ ! -d "$WALLPAPER_BASE" ]
}

@test "dieanddontcomeback --ever: removes launchd plist" {
    touch "$TEST_HOME/.local/etc/launchd/local.shrutz.plist"
    bash -c "echo 'yes' | '$SHRUTZ' dieanddontcomeback --ever"
    [ ! -f "$TEST_HOME/.local/etc/launchd/local.shrutz.plist" ]
}

@test "dieanddontcomeback --ever: removes man page if present" {
    mkdir -p "$TEST_HOME/.local/share/man/man1"
    touch "$TEST_HOME/.local/share/man/man1/shrutz.1"
    bash -c "echo 'yes' | '$SHRUTZ' dieanddontcomeback --ever"
    [ ! -f "$TEST_HOME/.local/share/man/man1/shrutz.1" ]
}

@test "dieanddontcomeback --ever: removes the menu bar app if installed" {
    mkdir -p "$TEST_HOME/Applications/Shrutz.app/Contents/MacOS"
    bash -c "echo 'yes' | '$SHRUTZ' dieanddontcomeback --ever"
    [ ! -d "$TEST_HOME/Applications/Shrutz.app" ]
}

@test "dieanddontcomeback --ever: succeeds cleanly when the menu bar app isn't installed" {
    run bash -c "echo 'yes' | '$SHRUTZ' dieanddontcomeback --ever"
    [ "$status" -eq 0 ]
    [[ "$output" == *"goodbye"* ]]
}

@test "dieanddontcomeback -e: short flag works identically to --ever" {
    run bash -c "echo 'yes' | '$SHRUTZ' dieanddontcomeback -e"
    [ "$status" -eq 0 ]
    [ ! -f "$SHRUTZ" ]
    [ ! -d "$SHRUTZ_LIB" ]
}

@test "dieanddontcomeback --ever: strips PATH line from .zshrc" {
    local rc="$TEST_HOME/.zshrc"
    printf '# Added by shrutz installer\nexport PATH="$HOME/.local/bin:$PATH"\n' > "$rc"
    bash -c "echo 'yes' | '$SHRUTZ' dieanddontcomeback --ever"
    run grep '\.local/bin' "$rc"
    [ "$status" -ne 0 ]
}

@test "dieanddontcomeback --ever: strips MANPATH line from .zshrc" {
    local rc="$TEST_HOME/.zshrc"
    printf 'export MANPATH="$HOME/.local/share/man:$MANPATH"\n' > "$rc"
    bash -c "echo 'yes' | '$SHRUTZ' dieanddontcomeback --ever"
    run grep 'MANPATH' "$rc"
    [ "$status" -ne 0 ]
}

@test "dieanddontcomeback --ever: leaves unrelated .zshrc content intact" {
    local rc="$TEST_HOME/.zshrc"
    printf 'export NVM_DIR="$HOME/.nvm"\n# Added by shrutz installer\nexport PATH="$HOME/.local/bin:$PATH"\nalias ll="ls -la"\n' > "$rc"
    bash -c "echo 'yes' | '$SHRUTZ' dieanddontcomeback --ever"
    run grep 'NVM_DIR' "$rc"
    [ "$status" -eq 0 ]
    run grep 'alias ll' "$rc"
    [ "$status" -eq 0 ]
}

@test "dieanddontcomeback --ever: exits 0 cleanly when .zshrc does not exist" {
    run bash -c "echo 'yes' | '$SHRUTZ' dieanddontcomeback --ever"
    [ "$status" -eq 0 ]
}

@test "dieanddontcomeback: no args (no flag) prompts and does soft delete only" {
    # Confirm it's the soft path: lib dir must survive
    bash -c "echo 'yes' | '$SHRUTZ' dieanddontcomeback"
    [ -d "$SHRUTZ_LIB" ]
}

# ══════════════════════════════════════════════════════════════════
# MENUBAR
# ══════════════════════════════════════════════════════════════════
# Only the pure-bash guard clauses are covered here — actually invoking
# xcodebuild is out of scope for this suite, same as cmd_update's `git
# pull` is never exercised either.

@test "menubar: unknown subcommand prints usage and exits non-zero" {
    run "$SHRUTZ" menubar bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage: shrutz menubar install"* ]]
}

@test "menubar install: dies when SHRUTZ_REPO is unknown" {
    run "$SHRUTZ" menubar install
    [ "$status" -ne 0 ]
    [[ "$output" == *"repo path unknown"* ]]
}

@test "menubar install: dies when the repo has no menubar/ Xcode project" {
    local fake_repo="$TEST_HOME/fake-repo"
    mkdir -p "$fake_repo"
    printf 'CURRENT_INDEX=0\nACTIVE_SECONDS=0\nACTIVE_SET=default\nPAUSED=0\nPLAY_ORDER=\nSHRUTZ_REPO=%s\n' "$fake_repo" > "$STATE_FILE"
    run "$SHRUTZ" menubar install
    [ "$status" -ne 0 ]
    [[ "$output" == *"no ShrutzMenuBar.xcodeproj found"* ]]
}

@test "menubar uninstall: reports nothing to do when Shrutz.app isn't installed" {
    run "$SHRUTZ" menubar uninstall
    [ "$status" -eq 0 ]
    [[ "$output" == *"not installed"* ]]
    [[ "$output" == *"nothing to do"* ]]
}

@test "menubar uninstall: declining the confirmation prompt leaves the app in place" {
    mkdir -p "$TEST_HOME/Applications/Shrutz.app/Contents/MacOS"
    run bash -c "echo 'no' | '$SHRUTZ' menubar uninstall"
    [ "$status" -eq 0 ]
    [[ "$output" == *"fine, staying."* ]]
    [ -d "$TEST_HOME/Applications/Shrutz.app" ]
}

@test "menubar uninstall: confirming removes the installed app" {
    mkdir -p "$TEST_HOME/Applications/Shrutz.app/Contents/MacOS"
    run bash -c "echo 'yes' | '$SHRUTZ' menubar uninstall"
    [ "$status" -eq 0 ]
    [[ "$output" == *"removing"* ]]
    [ ! -d "$TEST_HOME/Applications/Shrutz.app" ]
}

# ══════════════════════════════════════════════════════════════════
# DAEMON — MENUBAR AUTO-LAUNCH
# ══════════════════════════════════════════════════════════════════
# _maybe_launch_menubar_app() is called once from run_daemon() at
# startup. run_daemon() itself loops forever and is never invoked
# directly in this suite (same reason cmd_update's `git pull` and
# menubar install's `xcodebuild` are never exercised) — instead we
# source the script (which just re-defines every function and then
# runs the dispatch `case` for a harmless subcommand) and call the
# function directly.

@test "_maybe_launch_menubar_app: does nothing when the app isn't installed" {
    run bash -c "source '$SHRUTZ' --help >/dev/null 2>&1; _maybe_launch_menubar_app"
    [ "$status" -eq 0 ]
    [ ! -f "$SHRUTZ_LIB/open.calls" ]
}

@test "_maybe_launch_menubar_app: launches the app when installed and not running" {
    mkdir -p "$TEST_HOME/Applications/Shrutz.app/Contents/MacOS"
    run bash -c "source '$SHRUTZ' --help >/dev/null 2>&1; _maybe_launch_menubar_app"
    [ "$status" -eq 0 ]
    [ -f "$SHRUTZ_LIB/open.calls" ]
    grep -q -- '-g' "$SHRUTZ_LIB/open.calls"
    grep -q "Shrutz.app" "$SHRUTZ_LIB/open.calls"
}

@test "_maybe_launch_menubar_app: does not relaunch when already running" {
    mkdir -p "$TEST_HOME/Applications/Shrutz.app/Contents/MacOS"
    cat > "$STUB_DIR/pgrep" << 'STUB'
#!/usr/bin/env bash
echo 4242
exit 0
STUB
    chmod +x "$STUB_DIR/pgrep"

    run bash -c "source '$SHRUTZ' --help >/dev/null 2>&1; _maybe_launch_menubar_app"
    [ "$status" -eq 0 ]
    [ ! -f "$SHRUTZ_LIB/open.calls" ]
}

# ══════════════════════════════════════════════════════════════════
# AUTOSTART
# ══════════════════════════════════════════════════════════════════
# Toggles the daemon LaunchAgent's RunAtLoad key — separate from whether
# it's loaded/running right now. Never touches the current session's
# load state (that's start/stop, already stubbed via the launchctl stub).

@test "autostart status: reports on when RunAtLoad is true" {
    seed_launchagent_plist true
    run "$SHRUTZ" autostart status
    [ "$status" -eq 0 ]
    [[ "$output" == *"is on"* ]]
}

@test "autostart status: reports off when RunAtLoad is false" {
    seed_launchagent_plist false
    run "$SHRUTZ" autostart status
    [ "$status" -eq 0 ]
    [[ "$output" == *"is off"* ]]
}

@test "autostart status: reports off when no plist exists yet" {
    run "$SHRUTZ" autostart status
    [ "$status" -eq 0 ]
    [[ "$output" == *"is off"* ]]
}

@test "autostart on: flips RunAtLoad to true and persists it" {
    seed_launchagent_plist false
    run "$SHRUTZ" autostart on
    [ "$status" -eq 0 ]
    run "$SHRUTZ" autostart status
    [[ "$output" == *"is on"* ]]
}

@test "autostart off: flips RunAtLoad to false and persists it" {
    seed_launchagent_plist true
    run "$SHRUTZ" autostart off
    [ "$status" -eq 0 ]
    run "$SHRUTZ" autostart status
    [[ "$output" == *"is off"* ]]
}

@test "autostart on: dies with a clear message when no plist exists" {
    run "$SHRUTZ" autostart on
    [ "$status" -ne 0 ]
    [[ "$output" == *"run install.sh first"* ]]
}

@test "autostart --json: emits valid JSON reflecting the current state" {
    seed_launchagent_plist true
    run "$SHRUTZ" autostart --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['autostart_enabled'] is True, d
"
}

@test "autostart: unknown subcommand prints usage" {
    run "$SHRUTZ" autostart bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage: shrutz autostart"* ]]
}

@test "autostart: does not affect the current session's loaded state" {
    seed_launchagent_plist false
    "$SHRUTZ" autostart on
    # No launchctl load/unload call should have been made by autostart itself
    [ ! -f "$SHRUTZ_LIB/launchctl.calls" ]
}

@test "status --json: includes autostart_enabled reflecting the plist" {
    seed_launchagent_plist true
    run "$SHRUTZ" status --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['autostart_enabled'] is True, d
"
}

# ══════════════════════════════════════════════════════════════════
# VERSION
# ══════════════════════════════════════════════════════════════════

@test "--version: prints 'unknown' when no VERSION file is installed" {
    run "$SHRUTZ" --version
    [ "$status" -eq 0 ]
    [[ "$output" == "shrutz unknown" ]]
}

@test "-v: is an alias for --version" {
    run "$SHRUTZ" -v
    [ "$status" -eq 0 ]
    [[ "$output" == "shrutz unknown" ]]
}

@test "--version: reads the installed VERSION file when present" {
    echo "2.1.0" > "$SHRUTZ_LIB/VERSION"
    run "$SHRUTZ" --version
    [ "$status" -eq 0 ]
    [[ "$output" == "shrutz 2.1.0" ]]
}
