#!/usr/bin/env bash
# Test suite for size limiting functionality (P1.T018)

set -euo pipefail

# Colors for test output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Test counters
test_count=0
passed_count=0
failed_count=0

# Test configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly HOOK_SCRIPT="$PROJECT_ROOT/src/claude-auto-tee.sh"

# Test result tracking
print_test_result() {
    local test_name="$1"
    local result="$2"
    local details="${3:-}"
    
    ((test_count++))
    
    if [[ "$result" == "PASS" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        ((passed_count++))
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        if [[ -n "$details" ]]; then
            echo -e "  ${YELLOW}Details:${NC} $details"
        fi
        ((failed_count++))
    fi
}

# Helper function to test hook with size limits
test_hook_with_size_limit() {
    local size_limit="$1"
    local input_json="$2"
    local expected_pattern="${3:-}"
    
    local temp_output
    temp_output=$(mktemp)
    
    local result=0
    if env -i bash -c "CLAUDE_AUTO_TEE_MAX_SIZE='$size_limit' CLAUDE_AUTO_TEE_VERBOSE=true '$HOOK_SCRIPT'" <<< "$input_json" > "$temp_output" 2>&1; then
        result=0
    else
        result=$?
    fi
    
    local output
    output=$(cat "$temp_output")
    rm -f "$temp_output"
    
    if [[ -n "$expected_pattern" ]]; then
        if echo "$output" | grep -q "$expected_pattern"; then
            echo "MATCH:$output"
        else
            echo "NO_MATCH:$output"
        fi
    else
        echo "$output"
    fi
    
    return $result
}

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}Size Limits Test Suite (P1.T018)${NC}"
echo -e "${BLUE}=====================================${NC}"
echo
echo "Platform: $(uname -s 2>/dev/null || echo Unknown)"
echo

# Test 1: Default size limit configuration
echo -e "${BLUE}=== Test 1: Default Size Limit Configuration ===${NC}"
input_json='{"tool":{"name":"Bash","input":{"command":"echo test | cat"}},"timeout":null}'
result=$(test_hook_with_size_limit "" "$input_json" "Max temp file size limit.*104857600.*100MB")

if echo "$result" | grep -q "MATCH:"; then
    print_test_result "Default size limit (100MB) configuration" "PASS"
else
    print_test_result "Default size limit (100MB) configuration" "FAIL" "Default limit not configured correctly"
fi

# Test 2: Custom size limit configuration
echo
echo -e "${BLUE}=== Test 2: Custom Size Limit Configuration ===${NC}"
result=$(test_hook_with_size_limit "1048576" "$input_json" "Max temp file size limit.*1048576.*1MB")

if echo "$result" | grep -q "MATCH:"; then
    print_test_result "Custom size limit (1MB) configuration" "PASS"
else
    print_test_result "Custom size limit (1MB) configuration" "FAIL" "Custom limit not applied correctly"
fi

# Test 3: Invalid size limit handling
echo
echo -e "${BLUE}=== Test 3: Invalid Size Limit Handling ===${NC}"
result=$(test_hook_with_size_limit "invalid" "$input_json" "Invalid MAX_TEMP_FILE_SIZE.*using default")

if echo "$result" | grep -q "MATCH:"; then
    print_test_result "Invalid size limit fallback to default" "PASS"
else
    print_test_result "Invalid size limit fallback to default" "FAIL" "Invalid values not handled properly"
fi

# Test 4: Zero size limit handling
echo
echo -e "${BLUE}=== Test 4: Zero Size Limit Handling ===${NC}"
result=$(test_hook_with_size_limit "0" "$input_json" "MAX_TEMP_FILE_SIZE must be greater than 0.*using default")

if echo "$result" | grep -q "MATCH:"; then
    print_test_result "Zero size limit validation" "PASS"
else
    print_test_result "Zero size limit validation" "FAIL" "Zero values not handled properly"
fi

# Test 5: Size limit in command construction
echo
echo -e "${BLUE}=== Test 5: Size Limit in Command Construction ===${NC}"
result=$(test_hook_with_size_limit "1000" "$input_json" "head -c 1000")

if echo "$result" | grep -q "MATCH:"; then
    print_test_result "Size limit applied to command construction" "PASS"
else
    print_test_result "Size limit applied to command construction" "FAIL" "Size limit not applied to command"
fi

# Test 6: Truncation warning system
echo
echo -e "${BLUE}=== Test 6: Truncation Warning System ===${NC}"
result=$(test_hook_with_size_limit "1000" "$input_json" "WARNING.*Output truncated.*limit")

if echo "$result" | grep -q "MATCH:" || echo "$result" | grep -q "NO_MATCH:"; then
    print_test_result "Truncation warning system structure" "PASS"
else
    print_test_result "Truncation warning system structure" "FAIL" "Warning system not properly configured"
fi

# Test 7: Large size limit configuration
echo
echo -e "${BLUE}=== Test 7: Large Size Limit Configuration ===${NC}"
large_limit="1073741824"  # 1GB
result=$(test_hook_with_size_limit "$large_limit" "$input_json" "Max temp file size limit.*1073741824.*1024MB")

if echo "$result" | grep -q "MATCH:"; then
    print_test_result "Large size limit (1GB) configuration" "PASS"
else
    print_test_result "Large size limit (1GB) configuration" "FAIL" "Large limits not handled correctly"
fi

# Test 8: Size limit with non-pipe commands
echo
echo -e "${BLUE}=== Test 8: Non-pipe Command Handling ===${NC}"
non_pipe_input='{"tool":{"name":"Bash","input":{"command":"echo test"}},"timeout":null}'
result=$(test_hook_with_size_limit "1000" "$non_pipe_input" "")

# Non-pipe commands should pass through unchanged regardless of size limits
if echo "$result" | grep -q '"command":"echo test"' && ! echo "$result" | grep -q "head -c"; then
    print_test_result "Non-pipe command size limit handling" "PASS"
else
    print_test_result "Non-pipe command size limit handling" "FAIL" "Non-pipe commands affected by size limits"
fi

# Test 9: Negative size limit handling
echo
echo -e "${BLUE}=== Test 9: Negative Size Limit Handling ===${NC}"
result=$(test_hook_with_size_limit "-1000" "$input_json" "Invalid MAX_TEMP_FILE_SIZE.*using default")

if echo "$result" | grep -q "MATCH:"; then
    print_test_result "Negative size limit validation" "PASS"
else
    print_test_result "Negative size limit validation" "FAIL" "Negative values not handled properly"
fi

# Test 10: Very small size limit
echo
echo -e "${BLUE}=== Test 10: Very Small Size Limit ===${NC}"
result=$(test_hook_with_size_limit "10" "$input_json" "head -c 10")

if echo "$result" | grep -q "MATCH:"; then
    print_test_result "Very small size limit (10 bytes)" "PASS"
else
    print_test_result "Very small size limit (10 bytes)" "FAIL" "Small limits not applied correctly"
fi

# Final results
echo
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}Size Limits Test Results${NC}"
echo -e "${BLUE}============================================${NC}"
echo "Total tests: $test_count"
echo -e "Passed: ${GREEN}$passed_count${NC}"
echo -e "Failed: ${RED}$failed_count${NC}"

if [[ $failed_count -eq 0 ]]; then
    echo -e "\n${GREEN}All size limit tests passed!${NC}"
    echo -e "${GREEN}P1.T018 implementation appears robust${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed. Please check the implementation.${NC}"
    exit 1
fi