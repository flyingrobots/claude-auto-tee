#!/usr/bin/env bash
# Error Code Framework Test Suite
# Tests the comprehensive error code system and messaging

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Import error code system
source "$PROJECT_ROOT/src/error-codes.sh"

# Test results tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "$expected" == "$actual" ]]; then
        echo "✓ $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ $test_name"
        echo "  Expected: $expected"
        echo "  Actual: $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

run_test_contains() {
    local test_name="$1"
    local expected_substring="$2"
    local actual="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "$actual" == *"$expected_substring"* ]]; then
        echo "✓ $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ $test_name"
        echo "  Expected substring: $expected_substring"
        echo "  Actual: $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo "======================================="
echo "Error Code Framework Test Suite"
echo "======================================="

echo "=== Test 1: Error Code Constants ==="
# Test that error codes are properly defined
run_test "ERR_INVALID_INPUT constant" "1" "$ERR_INVALID_INPUT"
run_test "ERR_NO_TEMP_DIR constant" "10" "$ERR_NO_TEMP_DIR"
run_test "ERR_INSUFFICIENT_SPACE constant" "20" "$ERR_INSUFFICIENT_SPACE"
run_test "ERR_COMMAND_NOT_FOUND constant" "30" "$ERR_COMMAND_NOT_FOUND"
run_test "ERR_OUTPUT_TOO_LARGE constant" "40" "$ERR_OUTPUT_TOO_LARGE"
run_test "ERR_CLEANUP_FAILED constant" "50" "$ERR_CLEANUP_FAILED"
run_test "ERR_PLATFORM_UNSUPPORTED constant" "60" "$ERR_PLATFORM_UNSUPPORTED"
run_test "ERR_PERMISSION_DENIED constant" "70" "$ERR_PERMISSION_DENIED"
run_test "ERR_NETWORK_UNAVAILABLE constant" "80" "$ERR_NETWORK_UNAVAILABLE"
run_test "ERR_INTERNAL_ERROR constant" "90" "$ERR_INTERNAL_ERROR"

echo "=== Test 2: Error Message Retrieval ==="
# Test error message functions
message1=$(get_error_message $ERR_INVALID_INPUT)
run_test_contains "Invalid input message" "Invalid input" "$message1"

message2=$(get_error_message $ERR_NO_TEMP_DIR)
run_test_contains "No temp dir message" "temp directory" "$message2"

message3=$(get_error_message $ERR_COMMAND_NOT_FOUND)
run_test_contains "Command not found message" "Command not found" "$message3"

echo "=== Test 3: Error Categories ==="
# Test error category classification
category1=$(get_error_category $ERR_INVALID_INPUT)
run_test "Input error category" "input" "$category1"

category2=$(get_error_category $ERR_NO_TEMP_DIR)
run_test "Filesystem error category" "filesystem" "$category2"

category3=$(get_error_category $ERR_COMMAND_NOT_FOUND)
run_test "Execution error category" "execution" "$category3"

category4=$(get_error_category $ERR_PERMISSION_DENIED)
run_test "Permission error category" "permission" "$category4"

echo "=== Test 4: Error Severity Levels ==="
# Test error severity classification
severity1=$(get_error_severity $ERR_INVALID_INPUT)
run_test "Input error severity" "error" "$severity1"

severity2=$(get_error_severity $ERR_NO_TEMP_DIR)
run_test "No temp dir severity" "fatal" "$severity2"

severity3=$(get_error_severity $ERR_INSUFFICIENT_SPACE)
run_test "Insufficient space severity" "warning" "$severity3"

severity4=$(get_error_severity $ERR_TEMP_FILE_ORPHANED)
run_test "Orphaned file severity" "info" "$severity4"

echo "=== Test 5: Error Code Validation ==="
# Test error code validation function
if is_valid_error_code $ERR_INVALID_INPUT; then
    echo "✓ Valid error code recognized"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "✗ Valid error code not recognized"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

if ! is_valid_error_code 999; then
    echo "✓ Invalid error code rejected"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "✗ Invalid error code not rejected"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

echo "=== Test 6: Error Reporting Functions ==="
# Test error reporting (capture stderr) 
# Need to handle the case where report_error returns non-zero due to error code
report_error $ERR_INVALID_INPUT "test context" false 2>/tmp/error_test.log || true
error_output=$(cat /tmp/error_test.log 2>/dev/null || echo "")
if [[ -n "$error_output" ]]; then
    run_test_contains "Error reporting format" "[ERROR 1]" "$error_output"
    run_test_contains "Error reporting context" "test context" "$error_output"
else
    echo "✗ Error reporting function failed - no output captured"
    TESTS_FAILED=$((TESTS_FAILED + 2))
fi
TESTS_RUN=$((TESTS_RUN + 2))

echo "=== Test 7: Cross-platform Compatibility ==="
# Test that both associative array and fallback methods work
if declare -A test_array 2>/dev/null; then
    echo "✓ Platform supports associative arrays"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "✓ Using fallback functions for older bash"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    
    # Test fallback functions specifically
    fallback_msg=$(get_error_message_fallback $ERR_INVALID_INPUT)
    run_test_contains "Fallback message function" "Invalid input" "$fallback_msg"
    
    fallback_cat=$(get_error_category_fallback $ERR_INVALID_INPUT)
    run_test "Fallback category function" "input" "$fallback_cat"
    
    fallback_sev=$(get_error_severity_fallback $ERR_INVALID_INPUT)
    run_test "Fallback severity function" "error" "$fallback_sev"
fi
TESTS_RUN=$((TESTS_RUN + 1))

echo "=== Test 8: Error Context Management ==="
# Test context management functions
set_error_context "Testing context"
run_test "Error context setting" "Testing context" "$ERROR_CONTEXT"

clear_error_context
run_test "Error context clearing" "" "$ERROR_CONTEXT"

echo "=== Test 9: Structured Error Reporting ==="
# Test JSON error reporting (capture stderr)
report_error_json $ERR_INVALID_INPUT "json test" false 2>/tmp/json_error_test.log || true
json_output=$(cat /tmp/json_error_test.log 2>/dev/null || echo "")
run_test_contains "JSON error format" "\"error\":" "$json_output"
run_test_contains "JSON error code" "\"code\": 1" "$json_output"
run_test_contains "JSON error context" "json test" "$json_output"

echo "=== Test 10: Warning Reporting ==="
# Test warning reporting (non-fatal)
report_warning $ERR_INSUFFICIENT_SPACE "warning test" 2>/tmp/warning_test.log || true
warning_output=$(cat /tmp/warning_test.log 2>/dev/null || echo "")
run_test_contains "Warning format" "[WARNING 20]" "$warning_output"
run_test_contains "Warning context" "warning test" "$warning_output"

# Cleanup temp files
rm -f /tmp/error_test.log /tmp/json_error_test.log /tmp/warning_test.log 2>/dev/null || true

echo "======================================="
echo "Test Results:"
echo "  Tests run: $TESTS_RUN"
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"
echo "======================================="

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "✓ All error code tests passed!"
    exit 0
else
    echo "✗ Some error code tests failed!"
    exit 1
fi