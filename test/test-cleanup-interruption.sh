#!/usr/bin/env bash
# Test suite for cleanup on script interruption (P1.T014)
# Tests that temp files and cleanup scripts are properly cleaned up when the script is interrupted

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

# Create test directories
test_temp_dir=$(mktemp -d)
test_output_dir="$test_temp_dir/outputs"
mkdir -p "$test_output_dir"

# Cleanup function
cleanup_tests() {
    rm -rf "$test_temp_dir" 2>/dev/null || true
}

trap cleanup_tests EXIT

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
            echo -e "  ${YELLOW}Details${NC}: $details"
        fi
        ((failed_count++))
    fi
}

# Test hook with interruption simulation
test_hook_with_interruption() {
    local temp_dir="$1"
    local input_json="$2"
    local expected_behavior="$3"
    
    # Set temp directory override
    export CLAUDE_AUTO_TEE_TEMP_DIR="$temp_dir"
    export CLAUDE_AUTO_TEE_VERBOSE=true
    
    # Create a background process that will be interrupted
    local output_file="$test_output_dir/interrupt_test_$$_$RANDOM.log"
    local pid_file="$test_output_dir/pid_$$_$RANDOM.txt"
    
    # Start the hook in the background with a long-running command
    local long_command='{"tool":{"name":"Bash","input":{"command":"sleep 10 | head -1"}},"timeout":null}'
    
    # Run hook in background and capture PID
    (
        echo "$long_command" | "$HOOK_SCRIPT" > "$output_file" 2>&1
    ) &
    local hook_pid=$!
    echo "$hook_pid" > "$pid_file"
    
    # Give it time to create temp files
    sleep 0.5
    
    # Count temp files before interruption
    local temp_files_before=$(find "$temp_dir" -name "claude-*" 2>/dev/null | wc -l)
    
    # Interrupt the process
    if kill -INT "$hook_pid" 2>/dev/null; then
        # Wait a bit for cleanup
        sleep 0.5
        
        # Check if temp files were cleaned up
        local temp_files_after=$(find "$temp_dir" -name "claude-*" 2>/dev/null | wc -l)
        
        if [[ $temp_files_after -lt $temp_files_before ]]; then
            echo "cleanup_detected"
        else
            echo "cleanup_failed"
        fi
    else
        echo "interrupt_failed"
    fi
    
    # Clean up
    unset CLAUDE_AUTO_TEE_TEMP_DIR CLAUDE_AUTO_TEE_VERBOSE
    rm -f "$output_file" "$pid_file"
}

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Cleanup on Interruption Test Suite (P1.T014)${NC}"
echo -e "${BLUE}=========================================${NC}"
echo
echo "Platform: $(uname -s 2>/dev/null || echo Unknown)"
echo "Test temp directory: $test_temp_dir"
echo

echo "Setting up test environments..."
user_test_dir="$test_temp_dir/user"
mkdir -p "$user_test_dir"
echo "✓ Created user test directory: $user_test_dir"

echo
echo -e "${BLUE}=== Test 1: Basic Interruption Cleanup ===${NC}"

# Test basic interruption cleanup
result=$(test_hook_with_interruption "$user_test_dir" "" "cleanup_detected")
if [[ "$result" == "cleanup_detected" ]]; then
    print_test_result "Basic interruption cleanup" "PASS"
else
    print_test_result "Basic interruption cleanup" "FAIL" "Expected cleanup detection but got: $result"
fi

echo
echo -e "${BLUE}=== Test 2: Signal Handler Registration ===${NC}"

# Test that signal handlers are properly registered
input_json='{"tool":{"name":"Bash","input":{"command":"echo test | head -1"}},"timeout":null}'
CLAUDE_AUTO_TEE_VERBOSE=true output=$(echo "$input_json" | timeout 2s "$HOOK_SCRIPT" 2>&1 || true)

if echo "$output" | grep -q "trap.*cleanup_on_interruption"; then
    print_test_result "Signal handler registration" "FAIL" "Signal handler should not be visible in output"
elif echo "$output" | grep -q "Registered files for cleanup"; then
    print_test_result "Signal handler registration" "PASS"
else
    print_test_result "Signal handler registration" "FAIL" "Expected cleanup registration message not found"
fi

echo
echo -e "${BLUE}=== Test 3: Cleanup Script and Temp File Registration ===${NC}"

# Test that both temp files and cleanup scripts are registered
CLAUDE_AUTO_TEE_VERBOSE=true CLAUDE_AUTO_TEE_TEMP_DIR="$user_test_dir" output=$(echo "$input_json" | "$HOOK_SCRIPT" 2>&1)

if echo "$output" | grep -q "Registered files for cleanup on interruption"; then
    print_test_result "File registration for cleanup" "PASS"
else
    print_test_result "File registration for cleanup" "FAIL" "Expected registration message not found"
fi

echo
echo -e "${BLUE}=== Test 4: Normal Exit Doesn't Interfere ===${NC}"

# Test that normal execution isn't affected by cleanup handlers
CLAUDE_AUTO_TEE_TEMP_DIR="$user_test_dir" output=$(echo "$input_json" | "$HOOK_SCRIPT" 2>&1)

if echo "$output" | grep -q '"command".*"echo test.*head -1"'; then
    print_test_result "Normal execution with cleanup handlers" "PASS"
else
    print_test_result "Normal execution with cleanup handlers" "FAIL" "Command not properly processed"
fi

echo
echo -e "${BLUE}=== Final Results ===${NC}"
echo "Tests run: $test_count"
echo -e "Passed: ${GREEN}$passed_count${NC}"
echo -e "Failed: ${RED}$failed_count${NC}"
echo

if [[ $failed_count -eq 0 ]]; then
    echo -e "${GREEN}✓ All cleanup on interruption tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some cleanup on interruption tests failed.${NC}"
    exit 1
fi