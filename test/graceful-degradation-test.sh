#!/usr/bin/env bash
# Test suite for graceful degradation functionality

# Setup test environment
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(dirname "$TEST_DIR")/src"

# Source the modules
source "$SRC_DIR/error-codes.sh"
source "$SRC_DIR/graceful-degradation.sh"

# Test framework
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test utilities
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"
    
    if [ "$expected" = "$actual" ]; then
        echo "✓ $message"
        ((TESTS_PASSED++))
    else
        echo "✗ $message: expected '$expected', got '$actual'"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

assert_contains() {
    local text="$1"
    local pattern="$2"
    local message="${3:-Text should contain pattern}"
    
    if echo "$text" | grep -q "$pattern"; then
        echo "✓ $message"
        ((TESTS_PASSED++))
    else
        echo "✗ $message: '$text' should contain '$pattern'"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Exit code assertion}"
    
    if [ "$expected" -eq "$actual" ]; then
        echo "✓ $message (exit code $actual)"
        ((TESTS_PASSED++))
    else
        echo "✗ $message: expected exit code $expected, got $actual"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# Mock test input
TEST_INPUT='{"tool":{"name":"Bash","input":{"command":"echo test | cat"}},"timeout":null}'

# Test 1: Initialization
test_degradation_initialization() {
    echo "=== Test 1: Degradation Initialization ==="
    
    initialize_degradation "$TEST_INPUT"
    assert_equals "$TEST_INPUT" "$ORIGINAL_INPUT" "Original input should be stored"
    assert_equals "false" "$DEGRADATION_ACTIVE" "Degradation should not be active initially"
    
    cleanup_degradation
}

# Test 2: Configuration modes
test_configuration_modes() {
    echo "=== Test 2: Configuration Modes ==="
    
    # Test strict mode
    export CLAUDE_DEGRADATION_MODE=strict
    configure_degradation_behavior
    assert_equals "true" "$CLAUDE_FAIL_FAST" "Strict mode should enable fail-fast"
    assert_equals "0" "$CLAUDE_RETRY_ATTEMPTS" "Strict mode should disable retries"
    
    # Test permissive mode
    export CLAUDE_DEGRADATION_MODE=permissive
    configure_degradation_behavior
    assert_equals "5" "$CLAUDE_RETRY_ATTEMPTS" "Permissive mode should enable more retries"
    
    # Reset
    export CLAUDE_DEGRADATION_MODE=auto
    configure_degradation_behavior
}

# Test 3: Error category routing
test_error_category_routing() {
    echo "=== Test 3: Error Category Routing ==="
    
    # Mock fail-fast for input errors (should not reach pass-through)
    export CLAUDE_FAIL_FAST=false
    initialize_degradation "$TEST_INPUT"
    
    # Test filesystem error (should trigger pass-through)
    local output
    output=$(handle_failure_gracefully $ERR_NO_TEMP_DIR "Test filesystem error" "$TEST_INPUT" 2>/dev/null)
    assert_contains "$output" "command.*echo test" "Filesystem error should pass through original command"
    
    # Test input error with fail-fast disabled (should still fail for input errors)
    # This test expects the function to exit, so we run it in a subshell
    (
        set +e
        handle_failure_gracefully $ERR_INVALID_INPUT "Test input error" "$TEST_INPUT" 2>/dev/null
        local exit_code=$?
        # This should exit with the error code, not return
        exit $exit_code
    )
    local result=$?
    assert_equals "$ERR_INVALID_INPUT" "$result" "Input errors should fail-fast even with fail-fast disabled"
    
    cleanup_degradation
}

# Test 4: Pass-through mode
test_passthrough_mode() {
    echo "=== Test 4: Pass-through Mode ==="
    
    initialize_degradation "$TEST_INPUT"
    
    # Capture pass-through output with test mode enabled
    local output_file="$TEST_DIR/test_output_$$"
    initiate_passthrough_mode $ERR_NO_TEMP_DIR "Test pass-through" "$TEST_INPUT" "true" > "$output_file" 2>/dev/null
    local output=$(cat "$output_file")
    rm -f "$output_file"
    
    assert_contains "$output" "echo test" "Pass-through should contain original command"
    assert_equals "true" "$DEGRADATION_ACTIVE" "Degradation should be marked as active"
    
    cleanup_degradation
}

# Test 5: Recovery mechanisms - alternative temp location
test_alternative_temp_location() {
    echo "=== Test 5: Alternative Temp Location Recovery ==="
    
    # Create a writable test directory
    local test_temp_dir="$TEST_DIR/temp_test_$$"
    mkdir -p "$test_temp_dir"
    
    # Override HOME to point to our test directory
    local original_home="$HOME"
    export HOME="$test_temp_dir"
    
    # Test recovery
    if attempt_alternative_temp_location; then
        assert_contains "$CLAUDE_TEMP_DIR_OVERRIDE" "$test_temp_dir" "Should find alternative temp location"
        echo "✓ Alternative temp location recovery works"
        ((TESTS_PASSED++))
    else
        echo "✗ Alternative temp location recovery failed"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
    
    # Cleanup
    export HOME="$original_home"
    rm -rf "$test_temp_dir"
    unset CLAUDE_TEMP_DIR_OVERRIDE
}

# Test 6: Smart retry mechanism  
test_smart_retry() {
    echo "=== Test 6: Smart Retry Mechanism ==="
    
    # Test successful retry
    local retry_count=0
    test_operation_success() {
        ((retry_count++))
        [ $retry_count -ge 2 ]  # Succeed on second attempt
    }
    
    export CLAUDE_RETRY_ATTEMPTS=3
    export CLAUDE_RETRY_DELAY=0.1  # Fast retry for testing
    
    retry_count=0
    if smart_retry test_operation_success; then
        assert_equals "2" "$retry_count" "Should succeed on second attempt"
        echo "✓ Smart retry works for transient failures"
        ((TESTS_PASSED++))
    else
        echo "✗ Smart retry failed when it should have succeeded"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
    
    # Test failed retry (all attempts fail)
    test_operation_fail() {
        false  # Always fail
    }
    
    if smart_retry test_operation_fail; then
        echo "✗ Smart retry should have failed after all attempts"
        ((TESTS_FAILED++))
    else
        echo "✓ Smart retry correctly fails after all attempts exhausted"
        ((TESTS_PASSED++))
    fi
    ((TESTS_RUN++))
}

# Test 7: Safe operation wrapper
test_safe_operation() {
    echo "=== Test 7: Safe Operation Wrapper ==="
    
    initialize_degradation "$TEST_INPUT"
    
    # Test successful operation
    test_safe_success() {
        true
    }
    
    if safe_operation test_safe_success $ERR_INTERNAL_ERROR "Test operation"; then
        echo "✓ Safe operation succeeds with successful operation"
        ((TESTS_PASSED++))
    else
        echo "✗ Safe operation should succeed with successful operation"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
    
    cleanup_degradation
}

# Test 8: User messaging
test_user_messaging() {
    echo "=== Test 8: User Messaging ==="
    
    # Test degradation message
    local message_output
    message_output=$(show_degradation_message $ERR_NO_TEMP_DIR "Test action" 2>&1)
    
    assert_contains "$message_output" "Functionality Temporarily Disabled" "Should show degradation header"
    assert_contains "$message_output" "No suitable temp directory found" "Should show error message"
    assert_contains "$message_output" "Test action" "Should show user action when provided"
}

# Test 9: Metrics logging  
test_metrics_logging() {
    echo "=== Test 9: Metrics Logging ==="
    
    local test_log="$TEST_DIR/test_metrics_$$.log"
    export CLAUDE_METRICS_LOG="$test_log"
    
    # Log a test event
    log_degradation_event $ERR_NO_TEMP_DIR "test_event"
    
    if [ -f "$test_log" ]; then
        local log_content
        log_content=$(cat "$test_log")
        assert_contains "$log_content" "degradation" "Log should contain degradation event"
        assert_contains "$log_content" "$ERR_NO_TEMP_DIR" "Log should contain error code"
        assert_contains "$log_content" "test_event" "Log should contain event type"
        
        rm -f "$test_log"
    else
        echo "✗ Metrics log file was not created"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
    fi
    
    unset CLAUDE_METRICS_LOG
}

# Test 10: Configuration validation
test_configuration_validation() {
    echo "=== Test 10: Configuration Validation ==="
    
    # Test invalid degradation mode (should default to auto)
    export CLAUDE_DEGRADATION_MODE=invalid
    configure_degradation_behavior
    # Should use default values without crashing
    echo "✓ Invalid degradation mode handled gracefully"
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
    
    # Test numeric configuration
    export CLAUDE_RETRY_ATTEMPTS=5
    export CLAUDE_RETRY_DELAY=2
    configure_degradation_behavior
    assert_equals "5" "$CLAUDE_RETRY_ATTEMPTS" "Retry attempts should be configurable"
    assert_equals "2" "$CLAUDE_RETRY_DELAY" "Retry delay should be configurable"
    
    # Reset to defaults
    export CLAUDE_DEGRADATION_MODE=auto
    unset CLAUDE_RETRY_ATTEMPTS CLAUDE_RETRY_DELAY
}

# Integration test: Full degradation scenario
test_full_degradation_scenario() {
    echo "=== Integration Test: Full Degradation Scenario ==="
    
    initialize_degradation "$TEST_INPUT"
    
    # Test degradation activation by calling initiate_passthrough_mode directly in test mode
    local output_file="$TEST_DIR/test_integration_output_$$"
    initiate_passthrough_mode $ERR_NO_TEMP_DIR "Simulated filesystem error" "$TEST_INPUT" "true" > "$output_file" 2>/dev/null
    local output=$(cat "$output_file")
    rm -f "$output_file"
    
    assert_contains "$output" "echo test" "Should pass through original command"
    assert_equals "true" "$DEGRADATION_ACTIVE" "Should activate degradation mode"
    
    cleanup_degradation
    assert_equals "false" "$DEGRADATION_ACTIVE" "Cleanup should deactivate degradation"
}

# Run all tests
run_all_tests() {
    echo "======================================="
    echo "Graceful Degradation Test Suite"
    echo "======================================="
    
    # Create test results directory for CI (cross-platform)
    if [ -n "${GITHUB_ACTIONS}" ]; then
        # In GitHub Actions
        if [ -d "/tmp" ]; then
            mkdir -p /tmp/test-results
        elif [ -n "${TEMP}" ]; then
            # Windows
            mkdir -p "${TEMP}/test-results"
        else
            # Fallback
            mkdir -p ./test-results
        fi
    else
        mkdir -p /tmp/test-results 2>/dev/null || mkdir -p ./test-results
    fi
    
    # Set up test environment
    export CLAUDE_AUTO_TEE_VERBOSE=1  # Enable verbose mode for testing
    
    test_degradation_initialization
    test_configuration_modes
    test_error_category_routing  
    test_passthrough_mode
    test_alternative_temp_location
    test_smart_retry
    test_safe_operation
    test_user_messaging
    test_metrics_logging
    test_configuration_validation
    test_full_degradation_scenario
    
    echo "======================================="
    echo "Test Results:"
    echo "  Tests run: $TESTS_RUN"
    echo "  Passed: $TESTS_PASSED"
    echo "  Failed: $TESTS_FAILED"
    echo "======================================="
    
    # Write test results for CI (cross-platform)
    local test_results_dir
    if [ -n "${GITHUB_ACTIONS}" ]; then
        if [ -d "/tmp" ]; then
            test_results_dir="/tmp/test-results"
        elif [ -n "${TEMP}" ]; then
            test_results_dir="${TEMP}/test-results"
        else
            test_results_dir="./test-results"
        fi
    else
        test_results_dir="/tmp/test-results"
        [ ! -d "/tmp/test-results" ] && test_results_dir="./test-results"
    fi
    
    {
        echo "# Graceful Degradation Test Results"
        echo ""
        echo "## Summary"
        echo "- Tests run: $TESTS_RUN"
        echo "- Passed: $TESTS_PASSED"
        echo "- Failed: $TESTS_FAILED"
        echo "- Success rate: $(( (TESTS_PASSED * 100) / TESTS_RUN ))%"
        echo ""
        echo "## Status"
        if [ $TESTS_FAILED -eq 0 ]; then
            echo "✅ All tests passed!"
        else
            echo "❌ Some tests failed"
        fi
        echo ""
        echo "Generated at: $(date)"
        echo "Platform: $(uname -s 2>/dev/null || echo 'Unknown')"
        echo "Results dir: $test_results_dir"
    } > "$test_results_dir/test-summary.md"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo "✓ All tests passed!"
        return 0
    else
        echo "✗ Some tests failed"
        return 1
    fi
}

# Check if we're being run directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    run_all_tests
    exit $?
fi