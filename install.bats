#!/usr/bin/env bats
# ┌─────────────────────────────────────────────────────────────────┐
# │  install.sh — integration test suite                           │
# │                                                                 │
# │  Same sandboxing convention as shrutz.bats: isolated $HOME,     │
# │  stubbed launchctl, nothing touches your real shrutz install.  │
# │                                                                 │
# │  Run:  bats install.bats                                        │
# └─────────────────────────────────────────────────────────────────┘

setup() {
    TEST_HOME="$(mktemp -d /tmp/shrutz-install-test-XXXXXX)"
    export HOME="$TEST_HOME"
    export SHELL="/bin/zsh"

    # A standalone "repo" directory, exactly what a fresh git clone looks
    # like — install.sh resolves everything relative to its own location.
    REPO_DIR="$(mktemp -d /tmp/shrutz-install-repo-XXXXXX)"
    cp "${BATS_TEST_DIRNAME}/shrutz"     "$REPO_DIR/shrutz"
    cp "${BATS_TEST_DIRNAME}/install.sh" "$REPO_DIR/install.sh"
    cp "${BATS_TEST_DIRNAME}/shrutz.1"   "$REPO_DIR/shrutz.1"
    cp "${BATS_TEST_DIRNAME}/VERSION"    "$REPO_DIR/VERSION"
    chmod +x "$REPO_DIR/shrutz" "$REPO_DIR/install.sh"
    INSTALL_SH="$REPO_DIR/install.sh"

    # A source folder of fake images to import
    IMPORT_SRC="$(mktemp -d /tmp/shrutz-install-src-XXXXXX)"
    touch "$IMPORT_SRC/one.jpg" "$IMPORT_SRC/two.png"

    STUB_DIR="$TEST_HOME/stubs"
    mkdir -p "$STUB_DIR"
    cat > "$STUB_DIR/launchctl" << 'STUB'
#!/usr/bin/env bash
mkdir -p "$HOME/.local/lib/shrutz"
echo "launchctl $*" >> "$HOME/.local/lib/shrutz/launchctl.calls"
exit 0
STUB
    chmod +x "$STUB_DIR/launchctl"
    export PATH="$STUB_DIR:$PATH"
}

teardown() {
    rm -rf "$TEST_HOME" "$REPO_DIR" "$IMPORT_SRC"
}

_state_get() {
    grep "^${1}=" "$TEST_HOME/.local/lib/shrutz/state" 2>/dev/null | cut -d= -f2-
}

@test "fresh install: named set becomes ACTIVE_SET and gets imported images" {
    run bash -c "printf 'vacation\n%s\n' '$IMPORT_SRC' | '$INSTALL_SH'"
    [ "$status" -eq 0 ]
    [ "$(_state_get ACTIVE_SET)" = "vacation" ]
    [ -f "$TEST_HOME/.local/lib/shrutz/wallpapers/vacation/__init__" ]
    [ -f "$TEST_HOME/.local/lib/shrutz/wallpapers/vacation/one.jpg" ]
    [ -f "$TEST_HOME/.local/lib/shrutz/wallpapers/vacation/two.png" ]
    grep -q '^images=2$' "$TEST_HOME/.local/lib/shrutz/wallpapers/vacation/__init__"
}

@test "fresh install: named set with images loads the daemon" {
    run bash -c "printf 'vacation\n%s\n' '$IMPORT_SRC' | '$INSTALL_SH'"
    [ "$status" -eq 0 ]
    grep -q 'launchctl load' "$TEST_HOME/.local/lib/shrutz/launchctl.calls"
}

@test "fresh install: blank name defaults to 'main'" {
    run bash -c "printf '\n\n' | '$INSTALL_SH'"
    [ "$status" -eq 0 ]
    [ "$(_state_get ACTIVE_SET)" = "main" ]
    [ -d "$TEST_HOME/.local/lib/shrutz/wallpapers/main" ]
}

@test "fresh install: skipping the import prompt leaves an empty set" {
    run bash -c "printf 'empty-set\n\n' | '$INSTALL_SH'"
    [ "$status" -eq 0 ]
    [ "$(_state_get ACTIVE_SET)" = "empty-set" ]
    grep -q '^images=0$' "$TEST_HOME/.local/lib/shrutz/wallpapers/empty-set/__init__"
}

@test "fresh install: skipping import does NOT load the daemon (crash-loop guard)" {
    run bash -c "printf 'empty-set\n\n' | '$INSTALL_SH'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"has no images yet"* ]]
    ! grep -q 'launchctl load' "$TEST_HOME/.local/lib/shrutz/launchctl.calls"
    grep -q 'launchctl unload' "$TEST_HOME/.local/lib/shrutz/launchctl.calls"
}

@test "fresh install: prints a pointer to the gallery, not a forced download" {
    run bash -c "printf 'vacation\n%s\n' '$IMPORT_SRC' | '$INSTALL_SH'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"shrutz gallery list"* ]]
    [[ "$output" == *"shrutz gallery install haasan"* ]]
}

@test "fresh install: installs a VERSION file" {
    run bash -c "printf 'vacation\n%s\n' '$IMPORT_SRC' | '$INSTALL_SH'"
    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/.local/lib/shrutz/VERSION" ]
}

@test "install: writes the binary via an atomic temp-file swap, leaving no stray temp file behind" {
    run bash -c "printf 'vacation\n%s\n' '$IMPORT_SRC' | '$INSTALL_SH'"
    [ "$status" -eq 0 ]
    [ -x "$TEST_HOME/.local/bin/shrutz" ]
    diff "$TEST_HOME/.local/bin/shrutz" "$REPO_DIR/shrutz"
    # The temp file (.shrutz.XXXXXX) must have been renamed into place, not
    # left alongside it — a leftover would mean the swap didn't complete.
    run bash -c "ls -A '$TEST_HOME/.local/bin'"
    [[ "$output" != *".shrutz."* ]]
}

@test "repair run: re-installing the binary is still atomic with no stray temp file" {
    bash -c "printf 'vacation\n%s\n' '$IMPORT_SRC' | '$INSTALL_SH'" >/dev/null
    run bash -c "printf '' | '$INSTALL_SH'"
    [ "$status" -eq 0 ]
    [ -x "$TEST_HOME/.local/bin/shrutz" ]
    run bash -c "ls -A '$TEST_HOME/.local/bin'"
    [[ "$output" != *".shrutz."* ]]
}

@test "repair run: does not re-prompt and preserves the existing active set" {
    bash -c "printf 'vacation\n%s\n' '$IMPORT_SRC' | '$INSTALL_SH'" >/dev/null

    # Second run: feed no meaningful input — if it tried to prompt again,
    # blank input would silently default the set to 'main' and clobber state.
    run bash -c "printf '' | '$INSTALL_SH'"
    [ "$status" -eq 0 ]
    [ "$(_state_get ACTIVE_SET)" = "vacation" ]
    [[ "$output" == *"state file present"* ]] || [[ "$output" == *"[skip]"*"state file present"* ]]
}

@test "repair run: reloads the daemon if the active set now has images" {
    bash -c "printf 'empty-set\n\n' | '$INSTALL_SH'" >/dev/null
    rm -f "$TEST_HOME/.local/lib/shrutz/launchctl.calls"

    cp "$IMPORT_SRC"/*.jpg "$TEST_HOME/.local/lib/shrutz/wallpapers/empty-set/"

    run bash -c "printf '' | '$INSTALL_SH'"
    [ "$status" -eq 0 ]
    grep -q 'launchctl load' "$TEST_HOME/.local/lib/shrutz/launchctl.calls"
}
