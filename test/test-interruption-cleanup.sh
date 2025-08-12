#!/usr/bin/env bash
# Test suite for cleanup on script interruption (P1.T014)
# Verifies that temp files and cleanup scripts are properly removed when the script is interrupted

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

# Find temp files created by claude-auto-tee
find_claude_temp_files() {
    find "${TMPDIR:-/tmp}" -name "claude-*.log" 2>/dev/null || true
}

# Find cleanup scripts created by claude-auto-tee  
find_claude_cleanup_scripts() {
    find "${TMPDIR:-/tmp}" -name "claude-cleanup-*.sh" 2>/dev/null || true
}

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Interruption Cleanup Test Suite (P1.T014)${NC}"
echo -e "${BLUE}=========================================${NC}"
echo

echo "Testing script interruption cleanup functionality..."

echo -e "${BLUE}=== Test 1: Signal Handler Installation ===${NC}"

# Test 1: Verify signal handlers are installed
test_input='{"tool":{"name":"Bash","input":{"command":"echo hello | cat"}},"timeout":null}'
export CLAUDE_AUTO_TEE_VERBOSE=true
output=$(echo "$test_input" | timeout 5s "$CLAUDE_AUTO_TEE_SCRIPT" 2>&1) || true

if echo "$output" | grep -q "Signal handlers installed for cleanup on interruption"; then
    print_test_result "Signal handler installation" "PASS"
else
    print_test_result "Signal handler installation" "FAIL" "No signal handler installation message found"
fi

echo -e "${BLUE}=== Test 2: Temp File Creation and Tracking ===${NC}"

# Test 2: Verify temp files are created and tracked
initial_temp_files=$(find_claude_temp_files | wc -l)
(echo "$test_input" | timeout 10s "$CLAUDE_AUTO_TEE_SCRIPT" > /dev/null 2>&1) || true
final_temp_files=$(find_claude_temp_files | wc -l)

if [[ $final_temp_files -eq $initial_temp_files ]]; then
    print_test_result "Temp file cleanup after normal execution" "PASS"
else
    print_test_result "Temp file cleanup after normal execution" "FAIL" "Found leftover temp files"
fi

echo -e "${BLUE}=== Test 3: Cleanup Script Creation and Tracking ===${NC}"

# Test 3: Verify cleanup scripts are created and cleaned up
initial_cleanup_scripts=$(find_claude_cleanup_scripts | wc -l)
(echo "$test_input" | timeout 10s "$CLAUDE_AUTO_TEE_SCRIPT" > /dev/null 2>&1) || true
final_cleanup_scripts=$(find_claude_cleanup_scripts | wc -l)

if [[ $final_cleanup_scripts -eq $initial_cleanup_scripts ]]; then
    print_test_result "Cleanup script removal after normal execution" "PASS"
else
    print_test_result "Cleanup script removal after normal execution" "FAIL" "Found leftover cleanup scripts"
fi

echo -e "${BLUE}=== Test 4: SIGINT (Ctrl+C) Interrupt Cleanup ===${NC}"

# Test 4: Test cleanup on SIGINT
test_long_command='{"tool":{"name":"Bash","input":{"command":"yes | head -1000"}},"timeout":null}'
initial_temp_files=$(find_claude_temp_files | wc -l)
initial_cleanup_scripts=$(find_claude_cleanup_scripts | wc -l)

# Start the script and interrupt it
{
    echo "$test_long_command" | "$CLAUDE_AUTO_TEE_SCRIPT" &
    script_pid=$!
    sleep 1  # Let it start
    kill -INT $script_pid 2>/dev/null || true
    wait $script_pid 2>/dev/null || true
} > /dev/null 2>&1

sleep 1  # Let cleanup finish
final_temp_files=$(find_claude_temp_files | wc -l)
final_cleanup_scripts=$(find_claude_cleanup_scripts | wc -l)

if [[ $final_temp_files -eq $initial_temp_files ]] && [[ $final_cleanup_scripts -eq $initial_cleanup_scripts ]]; then
    print_test_result "SIGINT cleanup" "PASS"
else
    print_test_result "SIGINT cleanup" "FAIL" "Temp files: $initial_temp_files -> $final_temp_files, Scripts: $initial_cleanup_scripts -> $final_cleanup_scripts"
fi

echo -e "${BLUE}=== Test 5: SIGTERM Interrupt Cleanup ===${NC}"

# Test 5: Test cleanup on SIGTERM
initial_temp_files=$(find_claude_temp_files | wc -l)
initial_cleanup_scripts=$(find_claude_cleanup_scripts | wc -l)

# Start the script and terminate it
{
    echo "$test_long_command" | "$CLAUDE_AUTO_TEE_SCRIPT" &
    script_pid=$!
    sleep 1  # Let it start
    kill -TERM $script_pid 2>/dev/null || true
    wait $script_pid 2>/dev/null || true
} > /dev/null 2>&1

sleep 1  # Let cleanup finish
final_temp_files=$(find_claude_temp_files | wc -l)
final_cleanup_scripts=$(find_claude_cleanup_scripts | wc -l)

if [[ $final_temp_files -eq $initial_temp_files ]] && [[ $final_cleanup_scripts -eq $initial_cleanup_scripts ]]; then
    print_test_result "SIGTERM cleanup" "PASS"
else
    print_test_result "SIGTERM cleanup" "FAIL" "Temp files: $initial_temp_files -> $final_temp_files, Scripts: $initial_cleanup_scripts -> $final_cleanup_scripts"
fi

echo -e "${BLUE}=== Test 6: Exit Code on Interruption ===${NC}"

# Test 6: Verify correct exit code on interruption (130 for SIGINT)
{
    echo "$test_long_command" | "$CLAUDE_AUTO_TEE_SCRIPT" &
    script_pid=$!
    sleep 1  # Let it start
    kill -INT $script_pid 2>/dev/null || true
    wait $script_pid
    exit_code=$?
} > /dev/null 2>&1 || exit_code=$?

if [[ $exit_code -eq 130 ]]; then
    print_test_result "Correct exit code on SIGINT" "PASS"
else
    print_test_result "Correct exit code on SIGINT" "FAIL" "Expected 130, got $exit_code"
fi

echo -e "${BLUE}=== Test 7: Global Variable Initialization ===${NC}"

# Test 7: Test that global variables are properly initialized
output=$(echo "$test_input" | CLAUDE_AUTO_TEE_VERBOSE=true "$CLAUDE_AUTO_TEE_SCRIPT" 2>&1)

if echo "$output" | grep -q "Generated temp file:" && echo "$output" | grep -q "Generated cleanup script:"; then
    print_test_result "Global variable initialization" "PASS"
else
    print_test_result "Global variable initialization" "FAIL" "Temp file or cleanup script generation messages not found"
fi

echo -e "${BLUE}=== Test 8: Non-Piped Commands Skip Cleanup Setup ===${NC}"

# Test 8: Non-piped commands should not set up cleanup
test_simple='{"tool":{"name":"Bash","input":{"command":"echo hello"}},"timeout":null}'
output=$(echo "$test_simple" | CLAUDE_AUTO_TEE_VERBOSE=true "$CLAUDE_AUTO_TEE_SCRIPT" 2>&1)

# Should not create temp files for non-piped commands
if ! echo "$output" | grep -q "Generated temp file:" && ! echo "$output" | grep -q "Generated cleanup script:"; then
    print_test_result "Non-piped commands skip cleanup setup" "PASS"
else
    print_test_result "Non-piped commands skip cleanup setup" "FAIL" "Cleanup setup found for non-piped command"
fi

# Clean up any leftover files before finishing
find_claude_temp_files | xargs rm -f 2>/dev/null || true
find_claude_cleanup_scripts | xargs rm -f 2>/dev/null || true

# Clean up environment variables
unset CLAUDE_AUTO_TEE_VERBOSE

echo
echo -e "${BLUE}=== Final Results ===${NC}"
echo "Tests run: $test_count"
echo -e "Passed: ${GREEN}$passed_count${NC}"
echo -e "Failed: ${RED}$failed_count${NC}"

if [[ $failed_count -eq 0 ]]; then
    echo
    echo -e "${GREEN}✓ All interruption cleanup tests passed!${NC}"
    echo "P1.T014 implementation verified successfully."
    exit 0
else
    echo
    echo -e "${RED}✗ Some interruption cleanup tests failed.${NC}"
    exit 1
fi