#!/usr/bin/env bash
# Regression tests for get_next_session_name (Issue #38)
# Verifies session naming logic produces correct names without spurious stderr output.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SM2="$SCRIPT_DIR/../sm2"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

# Source sm2 functions without running main
source <(sed 's/^main "\$@"$//' "$SM2")

# Stub get_sessions_for_alias AFTER sourcing so it overrides the real function.
# Tests inject session lists via STUBBED_SESSIONS.
STUBBED_SESSIONS=""
get_sessions_for_alias() { printf '%s' "$STUBBED_SESSIONS"; }

echo "=== get_next_session_name ==="

test_one() {
    local expected="$1" stub="$2" label="$3" check_err="${4:-0}"
    STUBBED_SESSIONS="$stub"
    local err_log
    err_log=$(mktemp)
    local result
    result=$(get_next_session_name "myhost" "fake-ssh-cmd" 2>"$err_log") || true
    if [[ "$result" == "$expected" ]]; then
        if [[ "$check_err" == "1" && -s "$err_log" ]]; then
            fail "$label - stderr not empty: $(cat "$err_log")"
        else
            pass "$label"
        fi
    else
        fail "$label - expected '$expected', got '$result' (stderr: $(cat "$err_log"))"
    fi
    rm -f "$err_log"
}

# Test 1: Regression for #38 - empty sessions must yield bare alias and produce no stderr noise
test_one "myhost" "" "empty sessions returns bare alias (no stderr)" 1

# Test 2: One existing bare-alias session - loop has no _N to increment, max stays 1
test_one "myhost_1" "myhost" "single bare-alias session yields _1 (no _N suffix to increment)"

# Test 3: Two sequential sessions -> alias_3
test_one "myhost_3" $'myhost\nmyhost_2' "sequential sessions yield _3"

# Test 4: Gap in sequence -> highest+1
test_one "myhost_6" $'myhost\nmyhost_2\nmyhost_5' "gap in sequence yields highest+1"

# Test 5: No bare alias, only numbered
test_one "myhost_4" $'myhost_2\nmyhost_3' "numbered-only sessions yield highest+1"

# Test 6: Trailing newline edge case
test_one "myhost_1" $'myhost\n' "trailing newline edge case (no _N suffix)"

echo
echo "PASS: $PASS / $((PASS + FAIL))"
[[ "$FAIL" -gt 0 ]] && exit 1
exit 0
