#!/usr/bin/env bash
# Test suite for temp file size limits (P1.T018)
# Verifies that CLAUDE_AUTO_TEE_MAX_SIZE environment variable controls temp file size

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
readonly CLAUDE_AUTO_TEE_SCRIPT="$PROJECT_ROOT/src/claude-auto-tee.sh"

# Test helper functions
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
            echo -e "  ${YELLOW}Details${NC}: $details"
        fi
        ((failed_count++))
    fi
}

# Create test input JSON
create_test_input() {
    local command="$1"
    printf '{"tool":{"name":"Bash","input":{"command":"%s"}},"timeout":null}\n' "$command"
}

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Size Limits Test Suite (P1.T018)${NC}"
echo -e "${BLUE}=========================================${NC}"
echo

echo "Testing temp file size limit functionality..."

echo -e "${BLUE}=== Test 1: Size Limit Environment Variable Detection ===${NC}"

# Test 1: Verify the script recognizes MAX_SIZE environment variable
test_input='{"tool":{"name":"Bash","input":{"command":"echo hello | head -1"}},"timeout":null}'
export CLAUDE_AUTO_TEE_VERBOSE=true
export CLAUDE_AUTO_TEE_MAX_SIZE=1024
output=$(echo "$test_input" | "$CLAUDE_AUTO_TEE_SCRIPT" 2>&1)

if echo "$output" | grep -q "Max temp file size limit: 1024 bytes"; then
    print_test_result "MAX_SIZE environment variable detection" "PASS"
else
    print_test_result "MAX_SIZE environment variable detection" "FAIL" "Output: $output"
fi

echo -e "${BLUE}=== Test 2: Size Limit Command Structure ===${NC}"

# Test 2: Verify the generated command includes head -c size limit
output_json=$(echo "$test_input" | "$CLAUDE_AUTO_TEE_SCRIPT")
command_from_json=$(echo "$output_json" | sed -n 's/.*"command":"\([^"]*\)".*/\1/p')

if echo "$command_from_json" | grep -q "head -c 1024"; then
    print_test_result "Size limit command structure" "PASS"
else
    print_test_result "Size limit command structure" "FAIL" "head -c 1024 not found in command"
fi

echo -e "${BLUE}=== Test 3: Invalid Size Limit Value Handling ===${NC}"

# Test 3: Test invalid size limit value
export CLAUDE_AUTO_TEE_MAX_SIZE="invalid"
output=$(echo "$test_input" | "$CLAUDE_AUTO_TEE_SCRIPT" 2>&1)

if echo "$output" | grep -q "Warning: Invalid MAX_TEMP_FILE_SIZE value"; then
    print_test_result "Invalid size limit handling" "PASS"
else
    print_test_result "Invalid size limit handling" "FAIL" "Expected invalid size warning"
fi

echo -e "${BLUE}=== Test 4: Non-pipe Command Handling ===${NC}"

# Test 4: Test that size limits only apply to piped commands
export CLAUDE_AUTO_TEE_MAX_SIZE=1024
test_no_pipe='{"tool":{"name":"Bash","input":{"command":"echo hello"}},"timeout":null}'
output=$(echo "$test_no_pipe" | "$CLAUDE_AUTO_TEE_SCRIPT")

# Should pass through unchanged for non-piped commands
if echo "$output" | grep -q '"command":"echo hello"'; then
    print_test_result "Non-piped commands pass through unchanged" "PASS"
else
    print_test_result "Non-piped commands pass through unchanged" "FAIL" "Non-piped command was modified"
fi

echo -e "${BLUE}=== Test 5: Truncation Warning System ===${NC}"

# Test 5: Verify truncation warning is included in command
export CLAUDE_AUTO_TEE_MAX_SIZE=1000
output_json=$(echo "$test_input" | "$CLAUDE_AUTO_TEE_SCRIPT")
command_from_json=$(echo "$output_json" | sed -n 's/.*"command":"\([^"]*\)".*/\1/p')

if echo "$command_from_json" | grep -q "WARNING.*Output truncated"; then
    print_test_result "Truncation warning system" "PASS"
else
    print_test_result "Truncation warning system" "FAIL" "Truncation warning not found in command"
fi

# Clean up environment variables
unset CLAUDE_AUTO_TEE_VERBOSE
unset CLAUDE_AUTO_TEE_MAX_SIZE

echo
echo -e "${BLUE}=== Final Results ===${NC}"
echo "Tests run: $test_count"
echo -e "Passed: ${GREEN}$passed_count${NC}"
echo -e "Failed: ${RED}$failed_count${NC}"

if [[ $failed_count -eq 0 ]]; then
    echo
    echo -e "${GREEN}✓ All size limit tests passed!${NC}"
    echo "P1.T018 implementation verified successfully."
    exit 0
else
    echo
    echo -e "${RED}✗ Some size limit tests failed.${NC}"
    exit 1
fi