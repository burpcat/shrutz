#!/usr/bin/env bats
# ┌─────────────────────────────────────────────────────────────────┐
# │  gallery (Creators Publish) — integration test suite            │
# │                                                                 │
# │  Same sandboxing convention as shrutz.bats/weather.bats, plus a │
# │  stubbed http_get (SHRUTZ_HTTP_GET_STUB) serving fixture zips   │
# │  and a fixture manifest — nothing touches the real network.    │
# │                                                                 │
# │  Run:  bats gallery.bats                                        │
# └─────────────────────────────────────────────────────────────────┘

setup() {
    TEST_HOME="$(mktemp -d /tmp/shrutz-gallery-test-XXXXXX)"
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
exit 0
STUB
    cat > "$STUB_DIR/pgrep" << 'STUB'
#!/usr/bin/env bash
exit 1
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

    # ── Fixture zips, built on the fly so the suite is self-contained ──
    VALID_ZIP="$TEST_HOME/haasan.zip"
    python3 -c "
import zipfile
with zipfile.ZipFile('$VALID_ZIP', 'w') as zf:
    zf.writestr('haasan/__init__', 'name=haasan\ncreated=2025-01-01 00:00:00\nimages=2\n')
    zf.writestr('haasan/a.jpg', b'fakeimage1')
    zf.writestr('haasan/b.jpg', b'fakeimage2')
"
    VALID_SHA=$(shasum -a 256 "$VALID_ZIP" | awk '{print $1}')

    EVIL_ZIP="$TEST_HOME/evil.zip"
    python3 -c "
import zipfile
with zipfile.ZipFile('$EVIL_ZIP', 'w') as zf:
    zf.writestr('evilset/../../../../tmp/shrutz-zipslip-pwned.txt', b'pwned')
"

    CORRUPT_ZIP="$TEST_HOME/corrupt.zip"
    echo "this is not a zip file" > "$CORRUPT_ZIP"

    # ── Fixture manifest ────────────────────────────────────────────
    MANIFEST_FIXTURE="$TEST_HOME/manifest.json"
    cat > "$MANIFEST_FIXTURE" << EOF
{
  "schema_version": 1,
  "sets": [
    {"name": "haasan", "author": "burpcat", "description": "The original set", "images": 2, "download_url": "https://example.com/haasan.zip"},
    {"name": "checksummed", "author": "burpcat", "description": "sha256 verified", "images": 2, "download_url": "https://example.com/haasan.zip", "sha256": "$VALID_SHA"},
    {"name": "badsum", "author": "burpcat", "description": "wrong sha256", "images": 2, "download_url": "https://example.com/haasan.zip", "sha256": "0000000000000000000000000000000000000000000000000000000000000"},
    {"name": "evilset", "author": "attacker", "description": "zip-slip attempt", "images": 1, "download_url": "https://example.com/evil.zip"},
    {"name": "corruptset", "author": "burpcat", "description": "corrupt archive", "images": 1, "download_url": "https://example.com/corrupt.zip"},
    {"name": "unreachable", "author": "burpcat", "description": "download always fails", "images": 1, "download_url": "https://example.com/fail.zip"}
  ]
}
EOF

    cat > "$STUB_DIR/http_get_stub" << STUB
#!/usr/bin/env bash
case "\$1" in
    *manifest.json*)  cat "$MANIFEST_FIXTURE" ;;
    *haasan.zip*)     cat "$VALID_ZIP" ;;
    *evil.zip*)       cat "$EVIL_ZIP" ;;
    *corrupt.zip*)    cat "$CORRUPT_ZIP" ;;
    *fail.zip*)       exit 1 ;;
    *)                exit 1 ;;
esac
STUB
    chmod +x "$STUB_DIR/http_get_stub"
    export SHRUTZ_HTTP_GET_STUB="$STUB_DIR/http_get_stub"
}

teardown() {
    rm -f /tmp/shrutz-zipslip-pwned.txt   # in case a zip-slip guard regression ever wrote it
    rm -rf "$TEST_HOME"
}

# ── list ────────────────────────────────────────────────────────

@test "gallery list: shows entries from the manifest" {
    run "$SHRUTZ" gallery list
    [ "$status" -eq 0 ]
    [[ "$output" == *"haasan"* ]]
    [[ "$output" == *"burpcat"* ]]
}

@test "gallery list: marks nothing installed when nothing is" {
    run "$SHRUTZ" gallery list
    [ "$status" -eq 0 ]
    [[ "$output" == *"no"* ]]
}

@test "gallery list --json: emits a valid JSON array with expected fields" {
    run "$SHRUTZ" gallery list --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert isinstance(d, list) and len(d) > 0
names = {e['name'] for e in d}
assert 'haasan' in names
haasan = next(e for e in d if e['name'] == 'haasan')
assert haasan['installed'] is False
assert 'description' in haasan
"
}

@test "gallery list --json: reflects an already-installed set" {
    mkdir -p "$WALLPAPER_BASE/haasan"
    run "$SHRUTZ" gallery list --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
haasan = next(e for e in d if e['name'] == 'haasan')
assert haasan['installed'] is True
"
}

@test "gallery list: network failure dies with a clear message" {
    cat > "$STUB_DIR/http_get_stub" << 'STUB'
#!/usr/bin/env bash
exit 1
STUB
    chmod +x "$STUB_DIR/http_get_stub"
    run "$SHRUTZ" gallery list
    [ "$status" -ne 0 ]
    [[ "$output" == *"could not reach the gallery manifest"* ]]
}

# ── install ─────────────────────────────────────────────────────

@test "gallery install: downloads and extracts a set" {
    run "$SHRUTZ" gallery install haasan
    [ "$status" -eq 0 ]
    [ -f "$WALLPAPER_BASE/haasan/__init__" ]
    [ -f "$WALLPAPER_BASE/haasan/a.jpg" ]
    [ -f "$WALLPAPER_BASE/haasan/b.jpg" ]
    grep -q '^images=2$' "$WALLPAPER_BASE/haasan/__init__"
    grep -q '^name=haasan$' "$WALLPAPER_BASE/haasan/__init__"
}

@test "gallery install: installed set behaves like a normal set afterward" {
    "$SHRUTZ" gallery install haasan
    run "$SHRUTZ" switch haasan
    [ "$status" -eq 0 ]
    run "$SHRUTZ" sets
    [[ "$output" == *"haasan"* ]]
}

@test "gallery install: --as installs under a different local name" {
    run "$SHRUTZ" gallery install haasan --as my-haasan
    [ "$status" -eq 0 ]
    [ -d "$WALLPAPER_BASE/my-haasan" ]
    [ ! -d "$WALLPAPER_BASE/haasan" ]
    grep -q '^name=my-haasan$' "$WALLPAPER_BASE/my-haasan/__init__"
}

@test "gallery install: refuses when the local name already exists" {
    mkdir -p "$WALLPAPER_BASE/haasan"
    run "$SHRUTZ" gallery install haasan
    [ "$status" -ne 0 ]
    [[ "$output" == *"already exists"* ]]
}

@test "gallery install: unknown name dies with a helpful message" {
    run "$SHRUTZ" gallery install nonexistent-set
    [ "$status" -ne 0 ]
    [[ "$output" == *"no gallery entry named"* ]]
}

@test "gallery install: download failure dies with a clear message" {
    run "$SHRUTZ" gallery install unreachable
    [ "$status" -ne 0 ]
    [[ "$output" == *"download failed"* ]]
    [ ! -d "$WALLPAPER_BASE/unreachable" ]
}

@test "gallery install: corrupt zip is rejected and cleaned up" {
    run "$SHRUTZ" gallery install corruptset
    [ "$status" -ne 0 ]
    [[ "$output" == *"failed to extract"* ]]
    [ ! -d "$WALLPAPER_BASE/corruptset" ]
}

@test "gallery install: rejects a zip-slip attempt and writes nothing outside the set dir" {
    run "$SHRUTZ" gallery install evilset
    [ "$status" -ne 0 ]
    [ ! -f "/tmp/shrutz-zipslip-pwned.txt" ]
    [ ! -d "$WALLPAPER_BASE/evilset" ]
}

@test "gallery install: verifies sha256 when the manifest provides one" {
    run "$SHRUTZ" gallery install checksummed
    [ "$status" -eq 0 ]
    [ -d "$WALLPAPER_BASE/checksummed" ]
}

@test "gallery install: rejects a checksum mismatch" {
    run "$SHRUTZ" gallery install badsum
    [ "$status" -ne 0 ]
    [[ "$output" == *"checksum mismatch"* ]]
    [ ! -d "$WALLPAPER_BASE/badsum" ]
}

@test "gallery install: preserves a shuffle=true flag from the extracted set" {
    SHUFFLE_ZIP="$TEST_HOME/shuffled.zip"
    python3 -c "
import zipfile
with zipfile.ZipFile('$SHUFFLE_ZIP', 'w') as zf:
    zf.writestr('shuffled/__init__', 'name=shuffled\ncreated=2025-01-01 00:00:00\nimages=1\nshuffle=true\n')
    zf.writestr('shuffled/a.jpg', b'fakeimage')
"
    cat > "$STUB_DIR/http_get_stub" << STUB
#!/usr/bin/env bash
case "\$1" in
    *manifest.json*) cat "$MANIFEST_FIXTURE" ;;
    *shuffled.zip*)  cat "$SHUFFLE_ZIP" ;;
    *) exit 1 ;;
esac
STUB
    chmod +x "$STUB_DIR/http_get_stub"
    python3 -c "
import json
with open('$MANIFEST_FIXTURE') as f:
    data = json.load(f)
data['sets'].append({'name': 'shuffled', 'author': 'burpcat', 'description': 'shuffle test', 'images': 1, 'download_url': 'https://example.com/shuffled.zip'})
with open('$MANIFEST_FIXTURE', 'w') as f:
    json.dump(data, f)
"

    run "$SHRUTZ" gallery install shuffled
    [ "$status" -eq 0 ]
    grep -q '^shuffle=true$' "$WALLPAPER_BASE/shuffled/__init__"
}
