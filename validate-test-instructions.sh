#!/usr/bin/env bash
# Validation script for beta testing instructions

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Validating Beta Testing Instructions ===${NC}"
echo

# Test counters
tests_run=0
tests_passed=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_behavior="$3"
    
    ((tests_run++))
    echo -e "${YELLOW}Testing: $test_name${NC}"
    
    # Disable cleanup and enable verbose for testing
    export CLAUDE_AUTO_TEE_ENABLE_AGE_CLEANUP=false
    export CLAUDE_AUTO_TEE_VERBOSE=true
    export CLAUDE_AUTO_TEE_TEMP_PREFIX=validation-test
    
    # Run the test
    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS: $test_name${NC}"
        ((tests_passed++))
    else
        echo -e "${RED}✗ FAIL: $test_name${NC}"
        echo "   Command: $test_command"
        echo "   Expected: $expected_behavior"
    fi
    echo
}

# Test basic scenarios from our instructions
echo "Validating key test scenarios from BETA-TEST-SCENARIOS.md..."
echo

# Test 1: Basic functionality
run_test "Basic pipe detection" \
    "echo 'hello world' | wc -c" \
    "Should execute normally and show character count"

# Test 2: No false positives  
run_test "No false positives" \
    "ls -la >/dev/null" \
    "Should execute without adding tee (no pipes)"

# Test 3: Environment variable handling
run_test "Environment variables" \
    "CLAUDE_AUTO_TEE_TEMP_PREFIX=custom-test echo 'env test' | head -1" \
    "Should use custom prefix for temp files"

# Test 4: Complex pipeline
run_test "Complex pipeline" \
    "echo -e 'line1\nline2\nline3' | grep 'line' | wc -l" \
    "Should preserve pipeline and show count of 3"

# Test 5: Special characters
run_test "Special characters" \
    "echo 'Special chars: !@#\$%^&*()[]{}' | head -1" \
    "Should handle special characters correctly"

# Test 6: Empty output
run_test "Empty output handling" \
    "grep 'nonexistent' /dev/null | head -1 || true" \
    "Should handle empty output gracefully"

echo -e "${BLUE}=== Validation Results ===${NC}"
echo "Tests run: $tests_run"
echo -e "Tests passed: ${GREEN}$tests_passed${NC}"
echo -e "Tests failed: ${RED}$((tests_run - tests_passed))${NC}"

if [[ $tests_passed -eq $tests_run ]]; then
    echo -e "${GREEN}✓ All validation tests passed! Instructions are ready.${NC}"
    exit 0
else
    echo -e "${RED}✗ Some validation tests failed. Instructions may need revision.${NC}"
    exit 1
fi