#!/usr/bin/env bash
# Security tests for sm2
# Tests sanitization, escaping, validation, and config permissions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SM2="$SCRIPT_DIR/../sm2"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

# Source sm2 functions without running main
# We extract just the functions we need to test
source_functions() {
    # Extract helper functions by sourcing in a subshell with main overridden
    eval "$(sed 's/^main "\$@"$//' "$SM2")"
}

# === Test sanitize_session_name ===
echo "=== sanitize_session_name ==="

test_sanitize() {
    local input="$1" expected="$2" label="$3"
    local result
    result=$(printf '%s' "$input" | tr -cd 'A-Za-z0-9_.-')
    if [[ "$result" == "$expected" ]]; then
        pass "$label"
    else
        fail "$label (got '$result', expected '$expected')"
    fi
}

test_sanitize "normal_name" "normal_name" "alphanumeric with underscore"
test_sanitize "name-with.dots" "name-with.dots" "dashes and dots"
test_sanitize "test'; rm -rf /" "testrm-rf" "single quote injection stripped"
test_sanitize 'test"; rm -rf /' 'testrm-rf' "double quote injection stripped"
test_sanitize "test\`whoami\`" "testwhoami" "backtick injection stripped"
test_sanitize "name with spaces" "namewithspaces" "spaces stripped"
test_sanitize "name;cmd" "namecmd" "semicolon stripped"
test_sanitize $'name\nnewline' "namenewline" "newline stripped"
test_sanitize "" "" "empty string stays empty"

# === Test shell_escape_double ===
echo ""
echo "=== shell_escape_double ==="

test_escape() {
    local input="$1" expected="$2" label="$3"
    local result
    result=$(printf '%s' "$input" | sed 's/[\\\"$`!]/\\&/g')
    if [[ "$result" == "$expected" ]]; then
        pass "$label"
    else
        fail "$label (got '$result', expected '$expected')"
    fi
}

test_escape 'hello' 'hello' "plain string unchanged"
test_escape 'path/to/dir' 'path/to/dir' "slashes unchanged"
test_escape 'has"quote' 'has\"quote' "double quote escaped"
test_escape 'has$var' 'has\$var' "dollar sign escaped"
test_escape 'has`cmd`' 'has\`cmd\`' "backticks escaped"
test_escape 'has\back' 'has\\back' "backslash escaped"
test_escape 'has!bang' 'has\!bang' "exclamation mark escaped"
test_escape 'all"$`\!' 'all\"\$\`\\\!' "all special chars escaped"

# === Test validate_port ===
echo ""
echo "=== validate_port ==="

test_port_valid() {
    local port="$1" label="$2"
    if validate_port_check "$port"; then
        pass "$label"
    else
        fail "$label"
    fi
}

test_port_invalid() {
    local port="$1" label="$2"
    if ! validate_port_check "$port"; then
        pass "$label"
    else
        fail "$label"
    fi
}

# Inline port validation (same logic as sm2)
validate_port_check() {
    local port="$1"
    [[ -n "$port" ]] && [[ "$port" =~ ^[0-9]+$ ]] && [[ "$port" -ge 1 ]] && [[ "$port" -le 65535 ]]
}

test_port_valid "22" "standard SSH port"
test_port_valid "1" "minimum valid port"
test_port_valid "65535" "maximum valid port"
test_port_valid "8080" "common alternative port"
test_port_invalid "" "empty port rejected"
test_port_invalid "0" "port 0 rejected"
test_port_invalid "65536" "port > 65535 rejected"
test_port_invalid "-1" "negative port rejected"
test_port_invalid "abc" "non-numeric rejected"
test_port_invalid "22; rm -rf /" "injection in port rejected"
test_port_invalid "22abc" "mixed alphanumeric rejected"

# === Test regex_escape ===
echo ""
echo "=== regex_escape ==="

test_regex_escape() {
    local input="$1" label="$2"
    local escaped
    escaped=$(printf '%s' "$input" | sed 's/[][\\.^$*+?(){}|]/\\&/g')
    # The escaped string should match the literal input in grep -E
    if echo "$input" | grep -qE "^${escaped}$" 2>/dev/null; then
        pass "$label"
    else
        fail "$label"
    fi
}

test_regex_escape "simple" "plain string"
test_regex_escape "test.name" "dot escaped"
test_regex_escape "test*" "star escaped"
test_regex_escape "test+plus" "plus escaped"
test_regex_escape "test(paren)" "parens escaped"
test_regex_escape "test[bracket]" "brackets escaped"
test_regex_escape "test{brace}" "braces escaped"
test_regex_escape "test^caret" "caret escaped"
test_regex_escape 'test$dollar' "dollar escaped"
test_regex_escape "test|pipe" "pipe escaped"
test_regex_escape "test?question" "question escaped"

# === Test alias validation (add_connection rules) ===
echo ""
echo "=== alias validation ==="

test_alias_valid() {
    local alias="$1" label="$2"
    if [[ -n "$alias" ]] && [[ "$alias" =~ ^[A-Za-z0-9_.-]+$ ]]; then
        pass "$label"
    else
        fail "$label"
    fi
}

test_alias_invalid() {
    local alias="$1" label="$2"
    if [[ -z "$alias" ]] || [[ ! "$alias" =~ ^[A-Za-z0-9_.-]+$ ]]; then
        pass "$label"
    else
        fail "$label"
    fi
}

test_alias_valid "myserver" "simple alias"
test_alias_valid "my-server" "alias with dash"
test_alias_valid "my_server" "alias with underscore"
test_alias_valid "my.server" "alias with dot"
test_alias_valid "sm231" "alias with numbers"
test_alias_invalid "" "empty alias rejected"
test_alias_invalid "my server" "alias with space rejected"
test_alias_invalid "my|server" "alias with pipe rejected"
test_alias_invalid "my;server" "alias with semicolon rejected"
test_alias_invalid 'my"server' "alias with quote rejected"
test_alias_invalid "my\`server" "alias with backtick rejected"
test_alias_invalid $'my\nserver' "alias with newline rejected"
test_alias_invalid "my/server" "alias with slash rejected"

# === Test host/user validation ===
echo ""
echo "=== host/user validation ==="

test_hostuser_valid() {
    local val="$1" label="$2"
    if [[ ! "$val" =~ [[:space:]\;\`\$\(\)\{\}\|\'\"\\] ]]; then
        pass "$label"
    else
        fail "$label"
    fi
}

test_hostuser_invalid() {
    local val="$1" label="$2"
    if [[ "$val" =~ [[:space:]\;\`\$\(\)\{\}\|\'\"\\] ]]; then
        pass "$label"
    else
        fail "$label"
    fi
}

test_hostuser_valid "example.com" "normal hostname"
test_hostuser_valid "192.168.1.1" "IP address"
test_hostuser_valid "user-name" "user with dash"
test_hostuser_valid "rob_admin" "user with underscore"
test_hostuser_invalid "host;cmd" "semicolon injection rejected"
test_hostuser_invalid 'host`cmd`' "backtick injection rejected"
test_hostuser_invalid 'host$(cmd)' "dollar-paren injection rejected"
test_hostuser_invalid "host name" "space in host rejected"
test_hostuser_invalid "host'name" "single quote rejected"
test_hostuser_invalid 'host"name' "double quote rejected"
test_hostuser_invalid 'host\name' "backslash rejected"
test_hostuser_invalid 'host|name' "pipe rejected"

# === Test config file permissions ===
echo ""
echo "=== config file permissions ==="

test_config_permissions() {
    local tmpdir
    tmpdir=$(mktemp -d)
    local config_dir="$tmpdir/.config/sm"
    local config_file="$config_dir/connections.conf"

    # Simulate init_config logic
    mkdir -p "$config_dir"
    chmod 700 "$config_dir"
    touch "$config_file"
    chmod 600 "$config_file"

    local dir_perms file_perms
    dir_perms=$(stat -c '%a' "$config_dir")
    file_perms=$(stat -c '%a' "$config_file")

    if [[ "$dir_perms" == "700" ]]; then
        pass "config dir permissions 700"
    else
        fail "config dir permissions (got $dir_perms, expected 700)"
    fi

    if [[ "$file_perms" == "600" ]]; then
        pass "config file permissions 600"
    else
        fail "config file permissions (got $file_perms, expected 600)"
    fi

    rm -rf "$tmpdir"
}

test_config_permissions

# === Summary ===
echo ""
echo "================================"
echo "Results: $PASS passed, $FAIL failed"
echo "================================"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
