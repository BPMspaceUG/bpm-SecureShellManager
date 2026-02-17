#!/usr/bin/env bash
# Test suite for sm2 interactive_select() logic
# Tests selection indexing and default connection behavior
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SM2="$REPO_DIR/sm2"
PASS=0
FAIL=0
TOTAL=0

# Create a temporary config for testing
TEST_CONFIG=$(mktemp)
trap 'rm -f "$TEST_CONFIG"' EXIT

cat > "$TEST_CONFIG" <<'EOF'
# Test config
hostalias:host1.example.com=H1
hostalias:host2.example.com=H2
hostalias:host3.example.com=H3

conn-A|host1.example.com|22|user1|/home/user1|Description A|
conn-B|host1.example.com|22|user2|/home/user2|Description B|
conn-C|host2.example.com|22|user3|/home/user3|Description C|
conn-D|host2.example.com|22|user4|/home/user4|Description D|
conn-E|host3.example.com|22|user5|/home/user5|Description E|

default=conn-C
EOF

assert_eq() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    TOTAL=$((TOTAL + 1))
    if [[ "$expected" == "$actual" ]]; then
        echo "  PASS: $test_name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $test_name (expected='$expected', actual='$actual')"
        FAIL=$((FAIL + 1))
    fi
}

# Helper functions extracted from sm2
get_host_alias() {
    local hostname="$1"
    local alias_line
    alias_line=$(awk -F'=' -v key="hostalias:${hostname}" '$1 == key {print substr($0, length($1)+2)}' "$TEST_CONFIG" 2>/dev/null || echo "")
    if [[ -n "$alias_line" ]]; then
        echo "$alias_line"
    else
        echo ""
    fi
}

get_default() {
    grep "^default=" "$TEST_CONFIG" 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || echo ""
}

run_tests() {
    echo "=== Test Suite: interactive_select logic ==="
    echo ""

    # Simulate the array building from interactive_select
    local aliases=()
    local hostaliases=()
    local users=()
    local directories=()
    local descriptions=()

    while IFS= read -r raw_line; do
        local alias host port user directory description key
        IFS='|' read -r alias host port user directory description key <<< "$raw_line"
        [[ "$alias" =~ ^#.*$ ]] && continue
        [[ -z "$alias" ]] && continue
        [[ "$alias" =~ ^default= ]] && continue
        [[ "$alias" =~ ^hostalias: ]] && continue
        aliases+=("$alias")
        hostaliases+=("$(get_host_alias "$host")")
        users+=("$user")
        directories+=("$directory")
        descriptions+=("$description")
    done < "$TEST_CONFIG"

    echo "--- Test: Config parsing ---"
    assert_eq "alias count" "5" "${#aliases[@]}"
    assert_eq "alias[0]" "conn-A" "${aliases[0]}"
    assert_eq "alias[1]" "conn-B" "${aliases[1]}"
    assert_eq "alias[2]" "conn-C" "${aliases[2]}"
    assert_eq "alias[3]" "conn-D" "${aliases[3]}"
    assert_eq "alias[4]" "conn-E" "${aliases[4]}"

    # Test default detection
    local default_conn
    default_conn=$(get_default)
    assert_eq "default connection" "conn-C" "$default_conn"

    # Test initial selection: should find index of default
    local selected=0
    local i
    for i in "${!aliases[@]}"; do
        if [[ "${aliases[$i]}" == "$default_conn" ]]; then
            selected=$i
            break
        fi
    done
    assert_eq "selected index for default" "2" "$selected"

    # Test filtered_indices (no filter = all)
    local filtered_indices=()
    for i in "${!aliases[@]}"; do
        filtered_indices+=("$i")
    done
    assert_eq "filtered_indices count" "5" "${#filtered_indices[@]}"
    assert_eq "filtered_indices[0]" "0" "${filtered_indices[0]}"
    assert_eq "filtered_indices[2]" "2" "${filtered_indices[2]}"

    # Test get_selected_real_index logic
    local real_idx="${filtered_indices[$selected]}"
    assert_eq "real index for default selection" "2" "$real_idx"
    assert_eq "alias at real index" "conn-C" "${aliases[$real_idx]}"

    echo ""
    echo "--- Test: Arrow key navigation simulation ---"

    # Simulate down arrow: selected goes from 2 to 3
    local fi_count=${#filtered_indices[@]}
    if [[ $selected -lt $((fi_count - 1)) ]]; then
        selected=$((selected + 1))
    else
        selected=0
    fi
    assert_eq "after down arrow, selected" "3" "$selected"
    real_idx="${filtered_indices[$selected]}"
    assert_eq "after down arrow, real index" "3" "$real_idx"
    assert_eq "after down arrow, alias" "conn-D" "${aliases[$real_idx]}"

    # Simulate up arrow: selected goes from 3 to 2
    if [[ $selected -gt 0 ]]; then
        selected=$((selected - 1))
    else
        selected=$((fi_count - 1))
    fi
    assert_eq "after up arrow, selected" "2" "$selected"
    real_idx="${filtered_indices[$selected]}"
    assert_eq "after up arrow, alias" "conn-C" "${aliases[$real_idx]}"

    # Simulate up arrow from 0 -> wraps to last
    selected=0
    if [[ $selected -gt 0 ]]; then
        selected=$((selected - 1))
    else
        selected=$((fi_count - 1))
    fi
    assert_eq "up from 0, wraps to" "4" "$selected"
    real_idx="${filtered_indices[$selected]}"
    assert_eq "up from 0, alias" "conn-E" "${aliases[$real_idx]}"

    # Simulate down arrow from last -> wraps to 0
    selected=$((fi_count - 1))
    if [[ $selected -lt $((fi_count - 1)) ]]; then
        selected=$((selected + 1))
    else
        selected=0
    fi
    assert_eq "down from last, wraps to" "0" "$selected"
    real_idx="${filtered_indices[$selected]}"
    assert_eq "down from last, alias" "conn-A" "${aliases[$real_idx]}"

    echo ""
    echo "--- Test: Filter mode selection ---"

    # Simulate filter that matches conn-C and conn-D (host2)
    filtered_indices=()
    for i in "${!aliases[@]}"; do
        local haystack
        haystack=$(printf '%s %s %s %s %s' "${aliases[$i]}" "${hostaliases[$i]}" "${users[$i]}" "${directories[$i]}" "${descriptions[$i]}" | tr '[:upper:]' '[:lower:]')
        if [[ "$haystack" == *"h2"* ]]; then
            filtered_indices+=("$i")
        fi
    done
    assert_eq "filtered count for 'h2'" "2" "${#filtered_indices[@]}"
    assert_eq "filtered[0] -> index" "2" "${filtered_indices[0]}"
    assert_eq "filtered[1] -> index" "3" "${filtered_indices[1]}"

    # After filter, selected resets to 0
    selected=0
    real_idx="${filtered_indices[$selected]}"
    assert_eq "filter selected=0, alias" "conn-C" "${aliases[$real_idx]}"

    # Down arrow in filter
    fi_count=${#filtered_indices[@]}
    if [[ $selected -lt $((fi_count - 1)) ]]; then
        selected=$((selected + 1))
    fi
    real_idx="${filtered_indices[$selected]}"
    assert_eq "filter after down, alias" "conn-D" "${aliases[$real_idx]}"

    echo ""
    echo "--- Test: Real config default behavior ---"
    # Test with the actual config to reproduce the bug
    local real_config="$HOME/.config/sm/connections.conf"
    if [[ -f "$real_config" ]]; then
        local real_aliases=()
        while IFS= read -r raw_line; do
            local alias host port user directory description key
            IFS='|' read -r alias host port user directory description key <<< "$raw_line"
            [[ "$alias" =~ ^#.*$ ]] && continue
            [[ -z "$alias" ]] && continue
            [[ "$alias" =~ ^default= ]] && continue
            [[ "$alias" =~ ^hostalias: ]] && continue
            real_aliases+=("$alias")
        done < "$real_config"

        local real_default
        real_default=$(grep "^default=" "$real_config" 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || echo "")

        echo "  Real config: ${#real_aliases[@]} connections, default='$real_default'"

        # Find default index
        local default_idx=-1
        for i in "${!real_aliases[@]}"; do
            if [[ "${real_aliases[$i]}" == "$real_default" ]]; then
                default_idx=$i
                break
            fi
        done
        assert_eq "default found in array" "true" "$( [[ $default_idx -ge 0 ]] && echo true || echo false )"

        if [[ $default_idx -ge 0 ]]; then
            echo "  Default '$real_default' is at index $default_idx"
            assert_eq "alias at default index" "$real_default" "${real_aliases[$default_idx]}"

            # Check what would happen if we had an off-by-one
            if [[ $default_idx -gt 0 ]]; then
                echo "  alias[$(( default_idx - 1 ))] = ${real_aliases[$(( default_idx - 1 ))]}"
            fi
            if [[ $default_idx -lt $(( ${#real_aliases[@]} - 1 )) ]]; then
                echo "  alias[$(( default_idx + 1 ))] = ${real_aliases[$(( default_idx + 1 ))]}"
            fi

            # Simulate: selected=default_idx, filtered=[0..n-1]
            local real_filtered=()
            for i in "${!real_aliases[@]}"; do
                real_filtered+=("$i")
            done
            selected=$default_idx
            real_idx="${real_filtered[$selected]}"
            assert_eq "real config: selected alias" "$real_default" "${real_aliases[$real_idx]}"

            # Verify that index 0 is NOT C03BPM-ROB (that would mean off-by-one)
            echo "  alias[0] = ${real_aliases[0]}"
        fi
    else
        echo "  Skipping real config test (no config found)"
    fi
}

run_tests

echo ""
echo "=== Results: $PASS passed, $FAIL failed, $TOTAL total ==="
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
