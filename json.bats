#!/usr/bin/env bats
# ┌─────────────────────────────────────────────────────────────────┐
# │  --json output modes — integration test suite                  │
# │                                                                 │
# │  Same sandboxing convention as shrutz.bats. Covers the JSON     │
# │  contract now/sets/status/stats/config expose for the menu bar  │
# │  companion app.                                                 │
# │                                                                 │
# │  Run:  bats json.bats                                            │
# └─────────────────────────────────────────────────────────────────┘

setup() {
    TEST_HOME="$(mktemp -d /tmp/shrutz-json-test-XXXXXX)"
    export HOME="$TEST_HOME"

    SHRUTZ_LIB="$TEST_HOME/.local/lib/shrutz"
    WALLPAPER_BASE="$SHRUTZ_LIB/wallpapers"
    STATE_FILE="$SHRUTZ_LIB/state"
    LOG_FILE="$SHRUTZ_LIB/shrutz.log"

    mkdir -p \
        "$TEST_HOME/.local/bin" \
        "$SHRUTZ_LIB/wallpapers/default" \
        "$TEST_HOME/.local/etc/launchd" \
        "$TEST_HOME/Library/LaunchAgents"

    cp "${BATS_TEST_DIRNAME}/shrutz" "$TEST_HOME/.local/bin/shrutz"
    chmod +x "$TEST_HOME/.local/bin/shrutz"

    STUB_DIR="$TEST_HOME/stubs"
    mkdir -p "$STUB_DIR"

    # launchctl: `list <label>` behavior is controlled per-test via this
    # file — empty/absent means "not loaded" (exit 1, no output).
    LAUNCHCTL_LIST_FIXTURE="$TEST_HOME/launchctl_list_output"
    cat > "$STUB_DIR/launchctl" << STUB
#!/usr/bin/env bash
if [[ "\$1" == "list" && -n "\$2" ]]; then
    if [[ -s "$LAUNCHCTL_LIST_FIXTURE" ]]; then
        cat "$LAUNCHCTL_LIST_FIXTURE"
        exit 0
    else
        exit 1
    fi
fi
exit 0
STUB
    chmod +x "$STUB_DIR/launchctl"

    cat > "$STUB_DIR/pgrep" << 'STUB'
#!/usr/bin/env bash
exit 1
STUB
    chmod +x "$STUB_DIR/pgrep"
    export PATH="$STUB_DIR:$PATH"

    cat > "$STATE_FILE" << STATE
CURRENT_INDEX=1
ACTIVE_SECONDS=300
ACTIVE_SET=nature
PAUSED=0
PLAY_ORDER=
SHRUTZ_REPO=
STATE

    mkdir -p "$WALLPAPER_BASE/nature"
    touch "$WALLPAPER_BASE/nature/a.jpg" "$WALLPAPER_BASE/nature/b.jpg" "$WALLPAPER_BASE/nature/c.jpg"
    cat > "$WALLPAPER_BASE/nature/__init__" << EOF
name=nature
created=2025-01-01 00:00:00
images=3
EOF

    cat > "$WALLPAPER_BASE/default/__init__" << EOF
name=default
created=2025-01-01 00:00:00
images=0
EOF

    SHRUTZ="$TEST_HOME/.local/bin/shrutz"
}

teardown() {
    rm -rf "$TEST_HOME"
}

_valid_json() {
    echo "$1" | python3 -c "import json,sys; json.load(sys.stdin)"
}

# ── now --json ──────────────────────────────────────────────────

@test "now --json: emits valid JSON with expected fields and values" {
    run "$SHRUTZ" now --json
    [ "$status" -eq 0 ]
    run _valid_json "$output"
    [ "$status" -eq 0 ]

    result="$("$SHRUTZ" now --json)"
    echo "$result" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['wallpaper'] == 'b.jpg', d
assert d['wallpaper_path'].endswith('/nature/b.jpg'), d
assert d['set'] == 'nature'
assert d['position'] == 2
assert d['total'] == 3
assert d['active_seconds'] == 300
assert d['active_minutes_needed'] == 30
assert d['paused'] is False
assert d['shuffle'] is False
"
}

@test "now --json: reflects paused state" {
    sed -i '' 's/^PAUSED=.*/PAUSED=1/' "$STATE_FILE"
    result="$("$SHRUTZ" now --json)"
    echo "$result" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['paused'] is True
"
}

# ── sets --json ─────────────────────────────────────────────────

@test "sets --json: emits an array with expected fields and active flag" {
    run "$SHRUTZ" sets --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert isinstance(d, list)
names = {e['name']: e for e in d}
assert 'nature' in names and 'default' in names
assert names['nature']['images'] == 3
assert names['nature']['active'] is True
assert names['default']['active'] is False
"
}

# ── status --json ───────────────────────────────────────────────

@test "status --json: reports not loaded when the agent isn't running" {
    : > "$LAUNCHCTL_LIST_FIXTURE"
    run "$SHRUTZ" status --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['loaded'] is False
assert d['pid'] == 0
"
}

@test "status --json: reports pid and exit status when loaded" {
    cat > "$LAUNCHCTL_LIST_FIXTURE" << 'EOF'
{
    "Label" = "local.shrutz";
    "PID" = 4242;
    "LastExitStatus" = 0;
};
EOF
    run "$SHRUTZ" status --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['loaded'] is True
assert d['pid'] == 4242
assert d['last_exit_status'] == 0
"
}

# ── stats --json ────────────────────────────────────────────────

@test "stats --json: emits valid JSON with expected fields" {
    run "$SHRUTZ" stats --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['active_set'] == 'nature'
assert d['set_count'] == 2
assert d['total_images'] == 3
assert d['active_seconds'] == 300
assert d['active_minutes_needed'] == 30
assert d['paused'] is False
assert 'uptime_seconds' in d
assert 'uptime_human' in d
assert 'total_switches' in d
"
}

# ── config --json ───────────────────────────────────────────────

@test "config --json: emits the four tunables" {
    run "$SHRUTZ" config --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['active_mins'] == 30
assert d['idle_threshold'] == 60
assert d['check_every'] == 30
assert d['weather_poll_mins'] == 20
"
}

@test "config --json: reflects a patched tunable" {
    "$SHRUTZ" config ACTIVE_MINS 45
    run "$SHRUTZ" config --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['active_mins'] == 45
"
}
