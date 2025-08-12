#!/usr/bin/env bash
# Test suite for environment variable overrides (P1.T003)

set -euo pipefail

# Colors for test output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Test counters
test_count=0
passed_count=0
failed_count=0

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

# Helper function to test hook with environment variables
test_hook_with_env() {
    local env_vars="$1"
    local input_json="$2"
    local temp_output
    
    temp_output=$(mktemp)
    
    if env -i bash -c "$env_vars ./src/claude-auto-tee.sh" <<< "$input_json" > "$temp_output" 2>&1; then
        cat "$temp_output"
        rm -f "$temp_output"
        return 0
    else
        cat "$temp_output" >&2
        rm -f "$temp_output"
        return 1
    fi
}

echo "Starting environment variable override tests..."
echo

# Create test temp directory
test_temp_dir=$(mktemp -d)
trap 'rm -rf "$test_temp_dir"' EXIT

# Test 1: CLAUDE_AUTO_TEE_TEMP_DIR override
echo "Test 1: Custom temp directory override"
result=$(test_hook_with_env \
    "CLAUDE_AUTO_TEE_TEMP_DIR=$test_temp_dir CLAUDE_AUTO_TEE_VERBOSE=true" \
    '{"tool":{"name":"Bash","input":{"command":"echo test | cat"}},"timeout":null}')

if echo "$result" | grep -q "Using CLAUDE_AUTO_TEE_TEMP_DIR override: $test_temp_dir" && 
   echo "$result" | grep -q "$test_temp_dir"; then
    print_test_result "CLAUDE_AUTO_TEE_TEMP_DIR override" "PASS"
else
    print_test_result "CLAUDE_AUTO_TEE_TEMP_DIR override" "FAIL" "Custom temp dir not used"
fi

# Test 2: CLAUDE_AUTO_TEE_VERBOSE functionality
echo
echo "Test 2: Verbose mode toggle"
result_verbose=$(test_hook_with_env \
    "CLAUDE_AUTO_TEE_VERBOSE=true" \
    '{"tool":{"name":"Bash","input":{"command":"echo test | cat"}},"timeout":null}')

result_quiet=$(test_hook_with_env \
    "CLAUDE_AUTO_TEE_VERBOSE=false" \
    '{"tool":{"name":"Bash","input":{"command":"echo test | cat"}},"timeout":null}')

if echo "$result_verbose" | grep -q "\[CLAUDE-AUTO-TEE\]" && 
   ! echo "$result_quiet" | grep -q "\[CLAUDE-AUTO-TEE\]"; then
    print_test_result "CLAUDE_AUTO_TEE_VERBOSE toggle" "PASS"
else
    print_test_result "CLAUDE_AUTO_TEE_VERBOSE toggle" "FAIL" "Verbose mode not working correctly"
fi

# Test 3: CLAUDE_AUTO_TEE_TEMP_PREFIX customization
echo
echo "Test 3: Custom temp file prefix"
result=$(test_hook_with_env \
    "CLAUDE_AUTO_TEE_TEMP_PREFIX=testprefix CLAUDE_AUTO_TEE_VERBOSE=true" \
    '{"tool":{"name":"Bash","input":{"command":"echo test | cat"}},"timeout":null}')

if echo "$result" | grep -q "testprefix-"; then
    print_test_result "CLAUDE_AUTO_TEE_TEMP_PREFIX custom prefix" "PASS"
else
    print_test_result "CLAUDE_AUTO_TEE_TEMP_PREFIX custom prefix" "FAIL" "Custom prefix not used"
fi

# Test 4: CLAUDE_AUTO_TEE_CLEANUP_ON_SUCCESS behavior
echo
echo "Test 4: Cleanup on success control"
result_cleanup=$(test_hook_with_env \
    "CLAUDE_AUTO_TEE_CLEANUP_ON_SUCCESS=true CLAUDE_AUTO_TEE_VERBOSE=true" \
    '{"tool":{"name":"Bash","input":{"command":"echo test | cat"}},"timeout":null}')

result_no_cleanup=$(test_hook_with_env \
    "CLAUDE_AUTO_TEE_CLEANUP_ON_SUCCESS=false CLAUDE_AUTO_TEE_VERBOSE=true" \
    '{"tool":{"name":"Bash","input":{"command":"echo test | cat"}},"timeout":null}')

if echo "$result_cleanup" | grep -q "CLEANUP_ON_SUCCESS=true" && 
   echo "$result_no_cleanup" | grep -q "CLEANUP_ON_SUCCESS=false"; then
    print_test_result "CLAUDE_AUTO_TEE_CLEANUP_ON_SUCCESS control" "PASS"
else
    print_test_result "CLAUDE_AUTO_TEE_CLEANUP_ON_SUCCESS control" "FAIL" "Cleanup setting not respected"
fi

# Test 5: CLAUDE_AUTO_TEE_MAX_SIZE validation
echo
echo "Test 5: Max size validation"
result_valid=$(test_hook_with_env \
    "CLAUDE_AUTO_TEE_MAX_SIZE=1048576 CLAUDE_AUTO_TEE_VERBOSE=true" \
    '{"tool":{"name":"Bash","input":{"command":"echo test | cat"}},"timeout":null}')

result_invalid=$(test_hook_with_env \
    "CLAUDE_AUTO_TEE_MAX_SIZE=invalid CLAUDE_AUTO_TEE_VERBOSE=true" \
    '{"tool":{"name":"Bash","input":{"command":"echo test | cat"}},"timeout":null}')

if echo "$result_valid" | grep -q "Max temp file size limit set: 1048576 bytes" && 
   echo "$result_invalid" | grep -q "Invalid MAX_TEMP_FILE_SIZE value"; then
    print_test_result "CLAUDE_AUTO_TEE_MAX_SIZE validation" "PASS"
else
    print_test_result "CLAUDE_AUTO_TEE_MAX_SIZE validation" "FAIL" "Size validation not working"
fi

# Test 6: Fallback behavior with invalid temp directory
echo
echo "Test 6: Invalid temp directory fallback"
result=$(test_hook_with_env \
    "CLAUDE_AUTO_TEE_TEMP_DIR=/nonexistent/path CLAUDE_AUTO_TEE_VERBOSE=true" \
    '{"tool":{"name":"Bash","input":{"command":"echo test | cat"}},"timeout":null}')

if echo "$result" | grep -q "CLAUDE_AUTO_TEE_TEMP_DIR override not suitable" && 
   echo "$result" | grep -q "Testing TMPDIR\|Testing TMP\|Testing TEMP\|Using platform fallback"; then
    print_test_result "Invalid temp directory fallback" "PASS"
else
    print_test_result "Invalid temp directory fallback" "FAIL" "Fallback not working correctly"
fi

# Test 7: Environment variable priority order
echo
echo "Test 7: Environment variable priority"
result=$(test_hook_with_env \
    "CLAUDE_AUTO_TEE_TEMP_DIR=$test_temp_dir TMPDIR=/tmp CLAUDE_AUTO_TEE_VERBOSE=true" \
    '{"tool":{"name":"Bash","input":{"command":"echo test | cat"}},"timeout":null}')

if echo "$result" | grep -q "Using CLAUDE_AUTO_TEE_TEMP_DIR override: $test_temp_dir" && 
   ! echo "$result" | grep -q "Using TMPDIR:"; then
    print_test_result "Environment variable priority" "PASS"
else
    print_test_result "Environment variable priority" "FAIL" "Priority order not respected"
fi

# Test 8: Non-pipe command passthrough with environment variables
echo
echo "Test 8: Non-pipe command passthrough"
input_json='{"tool":{"name":"Bash","input":{"command":"echo test"}},"timeout":null}'
result=$(test_hook_with_env \
    "CLAUDE_AUTO_TEE_VERBOSE=true CLAUDE_AUTO_TEE_TEMP_PREFIX=test" \
    "$input_json")

if echo "$result" | grep -q '"command":"echo test"' && 
   ! echo "$result" | grep -q "test-"; then
    print_test_result "Non-pipe command env var passthrough" "PASS"
else
    print_test_result "Non-pipe command env var passthrough" "FAIL" "Environment variables affecting non-pipe commands"
fi

# Final results
echo
echo "============================================"
echo "Environment Variable Override Test Results"
echo "============================================"
echo "Total tests: $test_count"
echo -e "Passed: ${GREEN}$passed_count${NC}"
echo -e "Failed: ${RED}$failed_count${NC}"

if [[ $failed_count -eq 0 ]]; then
    echo -e "\n${GREEN}All environment variable override tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed. Please check the implementation.${NC}"
    exit 1
fi