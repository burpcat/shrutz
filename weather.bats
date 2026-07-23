#!/usr/bin/env bats
# ┌─────────────────────────────────────────────────────────────────┐
# │  weather — integration test suite                               │
# │                                                                 │
# │  Same sandboxing convention as shrutz.bats, plus a stubbed      │
# │  http_get (SHRUTZ_HTTP_GET_STUB) so no test ever touches the    │
# │  real network.                                                  │
# │                                                                 │
# │  Run:  bats weather.bats                                        │
# └─────────────────────────────────────────────────────────────────┘

setup() {
    TEST_HOME="$(mktemp -d /tmp/shrutz-weather-test-XXXXXX)"
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

    cat > "$STUB_DIR/launchctl" << 'STUB'
#!/usr/bin/env bash
echo "launchctl $*" >> "$HOME/.local/lib/shrutz/launchctl.calls"
exit 0
STUB

    cat > "$STUB_DIR/pgrep" << 'STUB'
#!/usr/bin/env bash
exit 1
STUB

    cat > "$STUB_DIR/osascript" << 'STUB'
#!/usr/bin/env bash
exit 0
STUB

    cat > "$STUB_DIR/ioreg" << 'STUB'
#!/usr/bin/env bash
echo "HIDIdleTime = 999999999999"
STUB

    chmod +x "$STUB_DIR"/*
    export PATH="$STUB_DIR:$PATH"

    cat > "$STATE_FILE" << STATE
CURRENT_INDEX=0
ACTIVE_SECONDS=0
ACTIVE_SET=default
PAUSED=0
PLAY_ORDER=
SHRUTZ_REPO=
STATE

    cat > "$WALLPAPER_BASE/default/__init__" << INIT
name=default
created=2025-01-01 00:00:00
images=0
INIT

    SHRUTZ="$TEST_HOME/.local/bin/shrutz"

    # http_get stub: keyed on URL substring, canned per-test via these files
    FORECAST_FIXTURE="$TEST_HOME/forecast.json"
    GEOCODE_FIXTURE="$TEST_HOME/geocode.json"
    echo '{"current":{"weather_code":0,"is_day":1,"temperature_2m":70}}' > "$FORECAST_FIXTURE"
    echo '{"results":[{"name":"Boston","admin1":"Massachusetts","country":"United States","latitude":42.36,"longitude":-71.06}]}' > "$GEOCODE_FIXTURE"

    cat > "$STUB_DIR/http_get_stub" << STUB
#!/usr/bin/env bash
case "\$1" in
    *geocoding-api*) cat "$GEOCODE_FIXTURE" ;;
    *api.open-meteo.com*) cat "$FORECAST_FIXTURE" ;;
    *) exit 1 ;;
esac
STUB
    chmod +x "$STUB_DIR/http_get_stub"
    export SHRUTZ_HTTP_GET_STUB="$STUB_DIR/http_get_stub"
}

teardown() {
    rm -rf "$TEST_HOME"
}

_state_get() {
    grep "^${1}=" "$STATE_FILE" 2>/dev/null | cut -d= -f2-
}

_make_set() {
    local name="$1"
    mkdir -p "$WALLPAPER_BASE/$name"
    touch "$WALLPAPER_BASE/$name/a.jpg"
    cat > "$WALLPAPER_BASE/$name/__init__" << EOF
name=$name
created=2025-01-01 00:00:00
images=1
EOF
}

# ── location ──────────────────────────────────────────────────────

@test "weather location: direct lat,lon is stored without a network call" {
    cat > "$STUB_DIR/http_get_stub" << 'STUB'
#!/usr/bin/env bash
exit 1
STUB
    chmod +x "$STUB_DIR/http_get_stub"

    run "$SHRUTZ" weather location "42.36,-71.06"
    [ "$status" -eq 0 ]
    [ "$(_state_get WEATHER_LAT)" = "42.36" ]
    [ "$(_state_get WEATHER_LON)" = "-71.06" ]
}

@test "weather location: rejects out-of-range coordinates" {
    run "$SHRUTZ" weather location "200,-71.06"
    [ "$status" -ne 0 ]
}

@test "weather location: city name is geocoded" {
    run "$SHRUTZ" weather location "Boston"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Boston"* ]]
    [ "$(_state_get WEATHER_LAT)" = "42.36" ]
    [ "$(_state_get WEATHER_LON)" = "-71.06" ]
}

@test "weather location: geocoding failure dies with a clear message" {
    echo '{"results":[]}' > "$GEOCODE_FIXTURE"
    run "$SHRUTZ" weather location "Nowhereville"
    [ "$status" -ne 0 ]
    [[ "$output" == *"could not resolve"* ]]
}

# ── mapping CRUD ──────────────────────────────────────────────────

@test "weather map: adds and lists a mapping" {
    _make_set rainy
    run "$SHRUTZ" weather map rain rainy
    [ "$status" -eq 0 ]
    run "$SHRUTZ" weather map
    [[ "$output" == *"rain"*"rainy"* ]]
}

@test "weather map: rejects unknown condition" {
    _make_set rainy
    run "$SHRUTZ" weather map monsoon rainy
    [ "$status" -ne 0 ]
    [[ "$output" == *"unknown condition"* ]]
}

@test "weather map: rejects nonexistent set" {
    run "$SHRUTZ" weather map rain nonexistent
    [ "$status" -ne 0 ]
}

@test "weather unmap: removes a mapping" {
    _make_set rainy
    "$SHRUTZ" weather map rain rainy
    run "$SHRUTZ" weather unmap rain
    [ "$status" -eq 0 ]
    run "$SHRUTZ" weather map
    [[ "$output" != *"rainy"* ]]
}

# ── status / on / off ─────────────────────────────────────────────

@test "weather: shows off and unset location by default" {
    run "$SHRUTZ" weather
    [ "$status" -eq 0 ]
    [[ "$output" == *"off"* ]]
    [[ "$output" == *"not set"* ]]
}

@test "weather on: refuses without a location" {
    run "$SHRUTZ" weather on
    [ "$status" -ne 0 ]
    [[ "$output" == *"no location set"* ]]
}

@test "weather on: succeeds once a location is set" {
    "$SHRUTZ" weather location "42.36,-71.06"
    run "$SHRUTZ" weather on
    [ "$status" -eq 0 ]
    [ "$(_state_get WEATHER_ENABLED)" = "1" ]
}

@test "weather off: disables auto-switching" {
    "$SHRUTZ" weather location "42.36,-71.06"
    "$SHRUTZ" weather on
    run "$SHRUTZ" weather off
    [ "$status" -eq 0 ]
    [ "$(_state_get WEATHER_ENABLED)" = "0" ]
}

@test "weather --json: emits valid JSON with the expected fields" {
    "$SHRUTZ" weather location "42.36,-71.06"
    "$SHRUTZ" weather on
    run "$SHRUTZ" weather --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['enabled'] is True
assert 'location' in d
assert 'condition' in d
assert 'temperature_f' in d
assert 'auto_switch' in d
assert 'last_checked' in d
assert d['mappings'] == []
"
}

@test "weather --json: mappings field reflects configured condition→set mappings" {
    _make_set rainy
    _make_set sunny
    "$SHRUTZ" weather location "42.36,-71.06"
    "$SHRUTZ" weather map rain rainy
    "$SHRUTZ" weather map clear sunny
    "$SHRUTZ" weather on
    run "$SHRUTZ" weather --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
mappings = {m['condition']: m['set'] for m in d['mappings']}
assert mappings == {'rain': 'rainy', 'clear': 'sunny'}, d
"
}

@test "weather --json: unmapped conditions are simply absent from mappings" {
    _make_set rainy
    "$SHRUTZ" weather location "42.36,-71.06"
    "$SHRUTZ" weather map rain rainy
    "$SHRUTZ" weather on
    run "$SHRUTZ" weather --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
conditions = {m['condition'] for m in d['mappings']}
assert conditions == {'rain'}
assert 'snow' not in conditions
"
}

@test "weather --json: mappings reflect removal after unmap" {
    _make_set rainy
    "$SHRUTZ" weather location "42.36,-71.06"
    "$SHRUTZ" weather map rain rainy
    "$SHRUTZ" weather on
    "$SHRUTZ" weather unmap rain
    run "$SHRUTZ" weather --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['mappings'] == [], d
"
}

# ── weather check: bucketing ───────────────────────────────────────

@test "weather check: clear sky maps to the mapped set" {
    _make_set sunny
    "$SHRUTZ" weather location "42.36,-71.06"
    "$SHRUTZ" weather map clear sunny
    "$SHRUTZ" weather on

    echo '{"current":{"weather_code":0,"is_day":1,"temperature_2m":75}}' > "$FORECAST_FIXTURE"
    run "$SHRUTZ" weather check
    [ "$status" -eq 0 ]
    [[ "$output" == *"clear"* ]]
    [[ "$output" == *"sunny"* ]]
    [ "$(_state_get ACTIVE_SET)" = "sunny" ]
}

@test "weather check: rain code maps to the rain bucket" {
    _make_set rainy
    "$SHRUTZ" weather location "42.36,-71.06"
    "$SHRUTZ" weather map rain rainy
    "$SHRUTZ" weather on

    echo '{"current":{"weather_code":61,"is_day":1,"temperature_2m":55}}' > "$FORECAST_FIXTURE"
    run "$SHRUTZ" weather check
    [ "$status" -eq 0 ]
    [[ "$output" == *"rain"* ]]
    [ "$(_state_get ACTIVE_SET)" = "rainy" ]
}

@test "weather check: snow code maps to the snow bucket" {
    _make_set wintery
    "$SHRUTZ" weather location "42.36,-71.06"
    "$SHRUTZ" weather map snow wintery
    "$SHRUTZ" weather on

    echo '{"current":{"weather_code":71,"is_day":1,"temperature_2m":20}}' > "$FORECAST_FIXTURE"
    run "$SHRUTZ" weather check
    [ "$status" -eq 0 ]
    [[ "$output" == *"snow"* ]]
    [ "$(_state_get ACTIVE_SET)" = "wintery" ]
}

@test "weather check: storm code maps to the storm bucket" {
    _make_set stormy
    "$SHRUTZ" weather location "42.36,-71.06"
    "$SHRUTZ" weather map storm stormy
    "$SHRUTZ" weather on

    echo '{"current":{"weather_code":95,"is_day":1,"temperature_2m":65}}' > "$FORECAST_FIXTURE"
    run "$SHRUTZ" weather check
    [ "$status" -eq 0 ]
    [[ "$output" == *"storm"* ]]
    [ "$(_state_get ACTIVE_SET)" = "stormy" ]
}

@test "weather check: fog code maps to the fog bucket" {
    _make_set foggy
    "$SHRUTZ" weather location "42.36,-71.06"
    "$SHRUTZ" weather map fog foggy
    "$SHRUTZ" weather on

    echo '{"current":{"weather_code":45,"is_day":1,"temperature_2m":50}}' > "$FORECAST_FIXTURE"
    run "$SHRUTZ" weather check
    [ "$status" -eq 0 ]
    [[ "$output" == *"fog"* ]]
    [ "$(_state_get ACTIVE_SET)" = "foggy" ]
}

@test "weather check: clear at night maps to the night bucket, not clear" {
    _make_set starry
    _make_set sunny
    "$SHRUTZ" weather location "42.36,-71.06"
    "$SHRUTZ" weather map night starry
    "$SHRUTZ" weather map clear sunny
    "$SHRUTZ" weather on

    echo '{"current":{"weather_code":0,"is_day":0,"temperature_2m":60}}' > "$FORECAST_FIXTURE"
    run "$SHRUTZ" weather check
    [ "$status" -eq 0 ]
    [[ "$output" == *"night"* ]]
    [ "$(_state_get ACTIVE_SET)" = "starry" ]
}

@test "weather check: storm at night stays storm, not night" {
    _make_set starry
    _make_set stormy
    "$SHRUTZ" weather location "42.36,-71.06"
    "$SHRUTZ" weather map night starry
    "$SHRUTZ" weather map storm stormy
    "$SHRUTZ" weather on

    echo '{"current":{"weather_code":95,"is_day":0,"temperature_2m":60}}' > "$FORECAST_FIXTURE"
    run "$SHRUTZ" weather check
    [ "$status" -eq 0 ]
    [[ "$output" == *"storm"* ]]
    [ "$(_state_get ACTIVE_SET)" = "stormy" ]
}

# ── weather check: failure modes ───────────────────────────────────

@test "weather check: unmapped condition leaves the active set unchanged" {
    "$SHRUTZ" weather location "42.36,-71.06"
    "$SHRUTZ" weather on

    echo '{"current":{"weather_code":0,"is_day":1,"temperature_2m":75}}' > "$FORECAST_FIXTURE"
    run "$SHRUTZ" weather check
    [ "$status" -eq 0 ]
    [[ "$output" == *"no set mapped"* ]]
    [ "$(_state_get ACTIVE_SET)" = "default" ]
}

@test "weather check: mapped set with no images is skipped" {
    # Map-time validation (assert_set_exists) requires images, so the set
    # must start non-empty to be mappable at all — this test is about the
    # runtime re-validation for a set that becomes empty *after* mapping
    # (e.g. the user later deleted its images), which the daemon must
    # catch independently of the one-time map-time check.
    _make_set soon-empty
    "$SHRUTZ" weather location "42.36,-71.06"
    "$SHRUTZ" weather map clear soon-empty
    "$SHRUTZ" weather on
    rm -f "$WALLPAPER_BASE/soon-empty/a.jpg"

    echo '{"current":{"weather_code":0,"is_day":1,"temperature_2m":75}}' > "$FORECAST_FIXTURE"
    run "$SHRUTZ" weather check
    [ "$status" -eq 0 ]
    [[ "$output" == *"missing or has no images"* ]]
    [ "$(_state_get ACTIVE_SET)" = "default" ]
}

@test "weather check: network failure dies with a clear message" {
    cat > "$STUB_DIR/http_get_stub" << 'STUB'
#!/usr/bin/env bash
exit 1
STUB
    chmod +x "$STUB_DIR/http_get_stub"

    "$SHRUTZ" weather location "42.36,-71.06"
    "$SHRUTZ" weather on

    run "$SHRUTZ" weather check
    [ "$status" -ne 0 ]
    [[ "$output" == *"weather fetch failed"* ]]
}

@test "weather check: refuses when auto-switching is off" {
    "$SHRUTZ" weather location "42.36,-71.06"
    run "$SHRUTZ" weather check
    [ "$status" -ne 0 ]
    [[ "$output" == *"auto-switching is off"* ]]
}

# ── anti-thrash ────────────────────────────────────────────────────

@test "weather check: does not re-trigger when the target equals the last weather-driven set" {
    _make_set rainy
    _make_set manual
    "$SHRUTZ" weather location "42.36,-71.06"
    "$SHRUTZ" weather map rain rainy
    "$SHRUTZ" weather on

    echo '{"current":{"weather_code":61,"is_day":1,"temperature_2m":55}}' > "$FORECAST_FIXTURE"
    "$SHRUTZ" weather check >/dev/null   # default -> rainy

    "$SHRUTZ" switch manual              # user manually overrides

    # Same condition again — should NOT re-trigger, since target == last weather-driven set
    run "$SHRUTZ" weather check
    [ "$status" -eq 0 ]
    [[ "$output" == *"unchanged since last weather switch"* ]]
    [ "$(_state_get ACTIVE_SET)" = "manual" ]
}

@test "weather check: reasserts control once the condition changes to a different mapped target" {
    _make_set rainy
    _make_set sunny
    _make_set manual
    "$SHRUTZ" weather location "42.36,-71.06"
    "$SHRUTZ" weather map rain rainy
    "$SHRUTZ" weather map clear sunny
    "$SHRUTZ" weather on

    echo '{"current":{"weather_code":61,"is_day":1,"temperature_2m":55}}' > "$FORECAST_FIXTURE"
    "$SHRUTZ" weather check >/dev/null   # default -> rainy
    "$SHRUTZ" switch manual              # user overrides

    # Condition changes to clear -> sunny: weather should reassert control
    echo '{"current":{"weather_code":0,"is_day":1,"temperature_2m":75}}' > "$FORECAST_FIXTURE"
    run "$SHRUTZ" weather check
    [ "$status" -eq 0 ]
    [ "$(_state_get ACTIVE_SET)" = "sunny" ]
}
