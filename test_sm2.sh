#!/usr/bin/env bash
# test_sm2.sh - Automated test suite for sm2 helper functions
# Run: bash test_sm2.sh

set -uo pipefail

# === Test Infrastructure ===

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_COUNT=0
CURRENT_GROUP=""

# Temp files for test config
TEST_DIR=""
TEST_CONFIG=""
SM2_SOURCE=""

setup() {
    TEST_DIR=$(mktemp -d)
    TEST_CONFIG="${TEST_DIR}/connections.conf"
    SM2_SOURCE="${TEST_DIR}/sm2_functions.sh"

    # Create test config with known data
    cat > "$TEST_CONFIG" << 'TESTCONF'
# SM test config
# group: Production
hostalias:prod.example.com=prod-srv
hostalias:staging.example.com=staging-srv
srv01|prod.example.com|22|deploy|/var/www|Production Server|~/.ssh/id_rsa
srv02|prod.example.com|2222|admin|/home/admin|Admin Access|
# group: Staging
srv03|staging.example.com|22|dev|/opt/app|Staging App|~/.ssh/staging_key
nodir|staging.example.com|22|user||No Directory|
default=srv01
TESTCONF

    # Create sourceable copy of sm2 with main() call removed
    local sm2_path
    sm2_path="$(dirname "${BASH_SOURCE[0]}")/sm2"
    if [[ ! -f "$sm2_path" ]]; then
        echo "FATAL: sm2 not found at $sm2_path"
        exit 2
    fi
    # Remove the final main "$@" invocation so we can source without executing
    sed 's/^main "\$@"$/# main "$@" # disabled for testing/' "$sm2_path" > "$SM2_SOURCE"

    # Source sm2 functions (override CONFIG_FILE to use test config)
    # Suppress any git version detection output
    (
        source "$SM2_SOURCE"
    ) 2>/dev/null || true

    # Now source for real in current shell
    CONFIG_FILE="$TEST_CONFIG"
    source "$SM2_SOURCE"
    CONFIG_FILE="$TEST_CONFIG"
}

teardown() {
    if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

# Assertion helpers
assert_eq() {
    local actual="$1"
    local expected="$2"
    local description="$3"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    if [[ "$actual" == "$expected" ]]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        printf "  PASS: %s\n" "$description"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        printf "  FAIL: %s\n" "$description"
        printf "    expected: '%s'\n" "$expected"
        printf "    actual:   '%s'\n" "$actual"
    fi
}

assert_neq() {
    local actual="$1"
    local unexpected="$2"
    local description="$3"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    if [[ "$actual" != "$unexpected" ]]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        printf "  PASS: %s\n" "$description"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        printf "  FAIL: %s\n" "$description"
        printf "    should NOT be: '%s'\n" "$unexpected"
    fi
}

assert_match() {
    local actual="$1"
    local pattern="$2"
    local description="$3"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    if [[ "$actual" =~ $pattern ]]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        printf "  PASS: %s\n" "$description"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        printf "  FAIL: %s\n" "$description"
        printf "    value:   '%s'\n" "$actual"
        printf "    pattern: '%s'\n" "$pattern"
    fi
}

assert_exit_code() {
    local expected="$1"
    shift
    local description="$1"
    shift
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    # Run in subshell to avoid set +e leaking into the test suite
    local actual
    actual=$(set +e; "$@" >/dev/null 2>&1; echo $?)
    if [[ $actual -eq $expected ]]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        printf "  PASS: %s\n" "$description"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        printf "  FAIL: %s\n" "$description"
        printf "    expected exit: %d\n" "$expected"
        printf "    actual exit:   %d\n" "$actual"
    fi
}

group() {
    CURRENT_GROUP="$1"
    echo ""
    echo "=== $1 ==="
}

# === Test Groups ===

test_sanitize_session_name() {
    group "sanitize_session_name()"

    assert_eq "$(sanitize_session_name "myserver")" "myserver" \
        "alphanumeric passes unchanged"

    assert_eq "$(sanitize_session_name "my-server_01.prod")" "my-server_01.prod" \
        "dashes, underscores, dots preserved"

    assert_eq "$(sanitize_session_name 'rm -rf /; echo $(whoami)')" "rm-rfechowhoami" \
        "strips spaces, semicolons, slashes, parens, dollar"

    assert_eq "$(sanitize_session_name "hello\`world\`")" "helloworld" \
        "strips backticks"

    assert_eq "$(sanitize_session_name "")" "" \
        "empty string returns empty"
}

test_shell_escape_double() {
    group "shell_escape_double()"

    assert_eq "$(shell_escape_double 'hello')" "hello" \
        "plain string unchanged"

    assert_eq "$(shell_escape_double 'back\slash')" 'back\\slash' \
        "escapes backslash"

    assert_eq "$(shell_escape_double 'say "hi"')" 'say \"hi\"' \
        "escapes double quotes"

    assert_eq "$(shell_escape_double 'cost $5')" 'cost \$5' \
        "escapes dollar sign"

    assert_eq "$(shell_escape_double 'run `cmd`')" 'run \`cmd\`' \
        "escapes backticks"

    assert_eq "$(shell_escape_double 'a\b"c$d`e')" 'a\\b\"c\$d\`e' \
        "escapes mixed special chars"
}

test_build_cd_cmd() {
    group "build_cd_cmd()"

    assert_eq "$(build_cd_cmd "")" "" \
        "empty directory returns empty string"

    assert_eq "$(build_cd_cmd "/var/www")" 'cd "/var/www" 2>/dev/null; ' \
        "simple directory produces cd command"

    assert_eq "$(build_cd_cmd "/my path/dir")" 'cd "/my path/dir" 2>/dev/null; ' \
        "directory with spaces is quoted"

    assert_eq "$(build_cd_cmd '/path/$HOME')" 'cd "/path/\$HOME" 2>/dev/null; ' \
        "dollar sign in path is escaped"

    assert_eq "$(build_cd_cmd '/path/with"quotes')" 'cd "/path/with\"quotes" 2>/dev/null; ' \
        "double quotes in path are escaped"

    assert_eq "$(build_cd_cmd '/path/back\slash')" 'cd "/path/back\\slash" 2>/dev/null; ' \
        "backslash in path is escaped"
}

test_parse_connection() {
    group "parse_connection()"

    # Valid alias
    parse_connection "srv01"
    local rc=$?
    assert_eq "$rc" "0" "valid alias returns 0"
    assert_eq "$CONN_HOST" "prod.example.com" "parses host correctly"
    assert_eq "$CONN_PORT" "22" "parses port correctly"
    assert_eq "$CONN_USER" "deploy" "parses user correctly"
    assert_eq "$CONN_DIR" "/var/www" "parses directory correctly"
    assert_eq "$CONN_DESC" "Production Server" "parses description correctly"
    assert_eq "$CONN_KEY" "~/.ssh/id_rsa" "parses SSH key correctly"

    # Connection without SSH key
    parse_connection "srv02"
    assert_eq "$CONN_PORT" "2222" "parses non-standard port"
    assert_eq "$CONN_KEY" "" "empty SSH key parsed as empty"

    # Connection without directory
    parse_connection "nodir"
    assert_eq "$CONN_DIR" "" "empty directory parsed as empty"

    # Invalid alias
    assert_exit_code 1 "unknown alias returns 1" parse_connection "nonexistent"

    # Verify globals are cleared on failed parse
    # First set them via a valid parse, then try an invalid one
    parse_connection "srv01"
    parse_connection "nonexistent" || true
    assert_eq "$CONN_HOST" "" "CONN_HOST cleared after failed parse"
    assert_eq "$CONN_PORT" "" "CONN_PORT cleared after failed parse"
    assert_eq "$CONN_USER" "" "CONN_USER cleared after failed parse"
}

test_validate_port() {
    group "validate_port()"

    assert_exit_code 0 "port 1 is valid" validate_port "1" "test"
    assert_exit_code 0 "port 22 is valid" validate_port "22" "test"
    assert_exit_code 0 "port 443 is valid" validate_port "443" "test"
    assert_exit_code 0 "port 8080 is valid" validate_port "8080" "test"
    assert_exit_code 0 "port 65535 is valid" validate_port "65535" "test"

    assert_exit_code 1 "port 0 is invalid" validate_port "0" "test"
    assert_exit_code 1 "port 65536 is invalid" validate_port "65536" "test"
    assert_exit_code 1 "port 'abc' is invalid" validate_port "abc" "test"
    assert_exit_code 1 "empty port is invalid" validate_port "" "test"
    assert_exit_code 1 "port -1 is invalid" validate_port "-1" "test"
}

test_regex_escape() {
    group "regex_escape()"

    assert_eq "$(regex_escape "hello")" "hello" \
        "plain string unchanged"

    assert_eq "$(regex_escape "C02BPM-ROB")" "C02BPM-ROB" \
        "alias with dash unchanged (dash not special outside charset)"

    assert_eq "$(regex_escape "a.b*c+d")" 'a\.b\*c\+d' \
        "escapes dot, star, plus"

    assert_eq "$(regex_escape 'x(y)[z]{w}')" 'x\(y\)\[z\]\{w\}' \
        "escapes parens, brackets, braces"

    assert_eq "$(regex_escape 'a|b')" 'a\|b' \
        "escapes pipe"

    assert_eq "$(regex_escape 'a\b')" 'a\\b' \
        "escapes backslash"

    assert_eq "$(regex_escape '^start$')" '\^start\$' \
        "escapes caret and dollar"

    assert_eq "$(regex_escape 'x?y')" 'x\?y' \
        "escapes question mark"

    # Verify escaped string works in grep -E
    local escaped
    escaped=$(regex_escape "srv01")
    local match
    match=$(echo "srv01" | grep -cE "^${escaped}$" || echo "0")
    assert_eq "$match" "1" "escaped alias matches in grep -E"
}

test_get_default() {
    group "get_default()"

    local result
    result=$(get_default)
    assert_eq "$result" "srv01" "returns correct default"

    # Test with no default
    local orig_config="$CONFIG_FILE"
    local no_default_config="${TEST_DIR}/no_default.conf"
    grep -v '^default=' "$TEST_CONFIG" > "$no_default_config"
    CONFIG_FILE="$no_default_config"
    result=$(get_default)
    assert_eq "$result" "" "returns empty when no default set"
    CONFIG_FILE="$orig_config"
}

test_get_host_alias() {
    group "get_host_alias()"

    local result
    result=$(get_host_alias "prod.example.com")
    assert_eq "$result" "prod-srv" "returns alias for known host"

    result=$(get_host_alias "staging.example.com")
    assert_eq "$result" "staging-srv" "returns alias for second known host"

    result=$(get_host_alias "unknown.example.com")
    assert_eq "$result" "" "returns empty for unknown host"
}

test_build_ssh_cmd() {
    group "build_ssh_cmd()"

    # Basic (no key, no auth)
    build_ssh_cmd "host.example.com" "22" "user" ""
    # SSH_CMD should be: ssh -R 52698:localhost:52698 -p 22 user@host.example.com
    local cmd_str="${SSH_CMD[*]}"
    assert_match "$cmd_str" "^ssh " "starts with ssh"
    assert_match "$cmd_str" "-p 22 " "includes port 22 (anchored with trailing space)"
    assert_match "$cmd_str" "user@host\.example\.com$" "ends with user@host"
    assert_match "$cmd_str" "-R 52698:localhost:52698" "includes rmate port forward"

    # With key
    build_ssh_cmd "host.example.com" "22" "user" "/path/to/key"
    cmd_str="${SSH_CMD[*]}"
    assert_match "$cmd_str" "-i /path/to/key" "includes -i with key path"

    # With auth mode
    build_ssh_cmd "host.example.com" "22" "user" "" "auth"
    cmd_str="${SSH_CMD[*]}"
    assert_match "$cmd_str" "-L 1455:localhost:1455" "includes auth port forward"

    # With key + auth
    build_ssh_cmd "host.example.com" "2222" "admin" "/key" "auth"
    cmd_str="${SSH_CMD[*]}"
    assert_match "$cmd_str" "-i /key" "key present with auth mode"
    assert_match "$cmd_str" "-L 1455:localhost:1455" "auth forward present with key"
    assert_match "$cmd_str" "-p 2222 " "custom port 2222 (anchored with trailing space)"

    # Verify port 22 does NOT match port 2222
    build_ssh_cmd "host.example.com" "2222" "user" ""
    cmd_str="${SSH_CMD[*]}"
    local has_22_only=""
    # Check individual array elements for exact port match
    for elem in "${SSH_CMD[@]}"; do
        [[ "$elem" == "22" ]] && has_22_only="found"
    done
    assert_eq "$has_22_only" "" "port 2222 does not have element '22'"
}

test_build_connection_title() {
    group "build_connection_title()"

    # With hostalias and description
    local result
    result=$(build_connection_title "deploy" "prod.example.com" "Production Server")
    assert_eq "$result" "deploy@prod-srv - Production Server" \
        "title with hostalias and description"

    # Without description
    result=$(build_connection_title "user" "prod.example.com" "")
    assert_eq "$result" "user@prod-srv" \
        "title without description"

    # Without hostalias (unknown host)
    result=$(build_connection_title "root" "unknown.host.com" "My Server")
    assert_eq "$result" "root@unknown.host.com - My Server" \
        "title falls back to hostname when no hostalias"
}

test_exit_or_return() {
    group "exit_or_return()"

    # With stay=1, should return (not exit)
    local rc=0
    exit_or_return 0 1 || rc=$?
    assert_eq "$rc" "0" "stay=1 code=0 returns 0"

    rc=0
    exit_or_return 42 1 || rc=$?
    assert_eq "$rc" "42" "stay=1 code=42 returns 42"

    # With stay=0, should exit - test in subshell
    rc=0
    (exit_or_return 0 0) || rc=$?
    assert_eq "$rc" "0" "stay=0 code=0 exits 0"

    rc=0
    (exit_or_return 7 0) || rc=$?
    assert_eq "$rc" "7" "stay=0 code=7 exits 7"
}

test_calculate_column_widths() {
    group "calculate_column_widths()"

    calculate_column_widths

    # Minimum widths (from the code: W_ALIAS=5, W_HOST=9, etc.)
    # After processing, W_ALIAS gets +2 padding
    # srv01 is 5 chars, so W_ALIAS should be max(5,5)+2 = 7
    local min_alias=7
    assert_match "$W_ALIAS" "^[0-9]+$" "W_ALIAS is numeric"
    if [[ $W_ALIAS -ge $min_alias ]]; then
        TOTAL_COUNT=$((TOTAL_COUNT + 1))
        PASS_COUNT=$((PASS_COUNT + 1))
        printf "  PASS: W_ALIAS >= %d (actual: %d)\n" "$min_alias" "$W_ALIAS"
    else
        TOTAL_COUNT=$((TOTAL_COUNT + 1))
        FAIL_COUNT=$((FAIL_COUNT + 1))
        printf "  FAIL: W_ALIAS >= %d (actual: %d)\n" "$min_alias" "$W_ALIAS"
    fi

    # W_DESC should accommodate "Production Server" (17 chars) + 2 padding = 19
    local min_desc=19
    if [[ $W_DESC -ge $min_desc ]]; then
        TOTAL_COUNT=$((TOTAL_COUNT + 1))
        PASS_COUNT=$((PASS_COUNT + 1))
        printf "  PASS: W_DESC >= %d (actual: %d)\n" "$min_desc" "$W_DESC"
    else
        TOTAL_COUNT=$((TOTAL_COUNT + 1))
        FAIL_COUNT=$((FAIL_COUNT + 1))
        printf "  FAIL: W_DESC >= %d (actual: %d)\n" "$min_desc" "$W_DESC"
    fi
}

# === Main ===

run_all_tests() {
    setup

    test_sanitize_session_name
    test_shell_escape_double
    test_build_cd_cmd
    test_parse_connection
    test_validate_port
    test_regex_escape
    test_get_default
    test_get_host_alias
    test_build_ssh_cmd
    test_build_connection_title
    test_exit_or_return
    test_calculate_column_widths

    teardown

    echo ""
    echo "==============================="
    echo "Results: ${PASS_COUNT} passed, ${FAIL_COUNT} failed, ${TOTAL_COUNT} total"
    echo "==============================="

    if [[ $FAIL_COUNT -gt 0 ]]; then
        return 1
    fi
    return 0
}

run_all_tests
exit $?
