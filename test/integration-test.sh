#!/usr/bin/env bash
# Integration Test Suite
# Tests complete end-to-end functionality across platforms

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly HOOK_SCRIPT="$PROJECT_ROOT/src/claude-auto-tee.sh"

# Test results tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

run_integration_test() {
    local test_name="$1"
    local input_json="$2"
    local validation_func="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Run the hook with the input
    local output
    if output=$(echo "$input_json" | bash "$HOOK_SCRIPT" 2>&1); then
        if $validation_func "$output"; then
            echo "✓ $test_name"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo "✗ $test_name - Validation failed"
            echo "  Output: $output"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        echo "✗ $test_name - Hook execution failed"
        echo "  Error: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Validation functions
validate_pipe_injection() {
    local output="$1"
    echo "$output" | grep -q "tee.*claude-.*log" && echo "$output" | grep -q "Full output saved to"
}

validate_passthrough() {
    local input="$1"
    local output="$2"
    # For passthrough, output should be identical to input
    [[ "$output" == "$input" ]]
}

validate_json_structure() {
    local output="$1"
    # Validate that output is valid JSON
    echo "$output" | python3 -m json.tool >/dev/null 2>&1
}

validate_no_tee_duplication() {
    local output="$1"
    # Count occurrences of "tee" - should be exactly 1
    local tee_count
    tee_count=$(echo "$output" | grep -o "tee" | wc -l)
    [[ $tee_count -eq 1 ]]
}

echo "======================================="
echo "Integration Test Suite"
echo "======================================="
echo "Platform: $(uname -s 2>/dev/null || echo Unknown)"
echo "Bash Version: $BASH_VERSION"
echo ""

echo "=== Test 1: Basic Pipe Command Integration ==="
input1='{"tool":{"name":"Bash","input":{"command":"echo hello world | head -1"}},"timeout":null}'
run_integration_test "Basic pipe command should inject tee" "$input1" validate_pipe_injection

echo "=== Test 2: Non-pipe Command Passthrough ==="
input2='{"tool":{"name":"Bash","input":{"command":"echo hello world"}},"timeout":null}'
validate_passthrough_test2() {
    local output="$1"
    validate_json_structure "$output" && echo "$output" | grep -q '"command":"echo hello world"'
}
run_integration_test "Non-pipe command should pass through unchanged" "$input2" validate_passthrough_test2

echo "=== Test 3: Existing Tee Command Preservation ==="
input3='{"tool":{"name":"Bash","input":{"command":"echo test | tee output.log"}},"timeout":null}'
validate_existing_tee() {
    local output="$1"
    validate_json_structure "$output" && ! echo "$output" | grep -q "claude-.*log"
}
run_integration_test "Commands with existing tee should be preserved" "$input3" validate_existing_tee

echo "=== Test 4: Complex Pipeline Integration ==="
input4='{"tool":{"name":"Bash","input":{"command":"ls -la | grep test | head -5"}},"timeout":null}'
validate_complex_pipeline() {
    local output="$1"
    validate_json_structure "$output" && 
    echo "$output" | grep -q "ls -la 2>&1.*tee.*claude-.*log.*grep test.*head -5"
}
run_integration_test "Complex pipeline should inject tee correctly" "$input4" validate_complex_pipeline

echo "=== Test 5: Non-bash Tool Passthrough ==="
input5='{"tool":{"name":"Read","input":{"file_path":"test.txt"}},"timeout":null}'
validate_non_bash_passthrough() {
    local output="$1"
    validate_json_structure "$output" && echo "$output" | grep -q '"name":"Read"'
}
run_integration_test "Non-bash tools should pass through unchanged" "$input5" validate_non_bash_passthrough

echo "=== Test 6: Error Handling Integration ==="
input6='{"invalid":"json"'  # Malformed JSON
validate_error_handling() {
    local output="$1"
    # Should either return valid JSON passthrough or handle gracefully
    echo "$output" | python3 -m json.tool >/dev/null 2>&1 || [[ -n "$output" ]]
}
run_integration_test "Malformed input should be handled gracefully" "$input6" validate_error_handling

echo "=== Test 7: Large Command Integration ==="
# Test with a reasonably long command
long_command="find /usr/bin -type f -exec basename {} \\; | sort | uniq -c | sort -nr | head -20"
input7="{\"tool\":{\"name\":\"Bash\",\"input\":{\"command\":\"$long_command\"}},\"timeout\":null}"
validate_large_command() {
    local output="$1"
    validate_json_structure "$output" && echo "$output" | grep -q "tee.*claude-.*log"
}
run_integration_test "Large command should be processed correctly" "$input7" validate_large_command

echo "=== Test 8: Special Character Handling ==="
input8='{"tool":{"name":"Bash","input":{"command":"echo \"test with spaces and $symbols\" | cat"}},"timeout":null}'
validate_special_chars() {
    local output="$1"
    validate_json_structure "$output" && echo "$output" | grep -q '\$symbols'
}
run_integration_test "Special characters should be preserved" "$input8" validate_special_chars

echo "=== Test 9: Multiple Pipe Integration ==="
input9='{"tool":{"name":"Bash","input":{"command":"ps aux | grep bash | grep -v grep | awk \"{print $2}\""}},"timeout":null}'
validate_multiple_pipes() {
    local output="$1"
    validate_json_structure "$output" && 
    echo "$output" | grep -q "ps aux 2>&1.*tee.*claude-.*log.*grep bash.*grep -v grep"
}
run_integration_test "Multiple pipes should be handled correctly" "$input9" validate_multiple_pipes

echo "=== Test 10: Temp File Path Validation ==="
input10='{"tool":{"name":"Bash","input":{"command":"echo test | wc -l"}},"timeout":null}'
validate_temp_path() {
    local output="$1"
    if validate_json_structure "$output"; then
        # Extract the temp file path and validate it looks correct
        local temp_path
        temp_path=$(echo "$output" | grep -o '/tmp/claude-[^"]*\.log' || echo "")
        if [[ -n "$temp_path" && "$temp_path" =~ ^/tmp/claude-[0-9]+\.log$ ]]; then
            return 0
        fi
        
        # Windows/alternative temp directory patterns
        if echo "$output" | grep -q "claude-.*\.log"; then
            return 0
        fi
    fi
    return 1
}
run_integration_test "Temp file paths should follow expected patterns" "$input10" validate_temp_path

echo "=== Test 11: Cross-platform Temp Directory Handling ==="
# Test that platform-appropriate temp directories are used
platform_test() {
    local output="$1"
    if validate_json_structure "$output"; then
        case "$(uname -s 2>/dev/null || echo Unknown)" in
            "Darwin"|"Linux")
                echo "$output" | grep -q "/tmp/claude-" && return 0
                ;;
            *)
                # Windows or other - just check for claude- pattern
                echo "$output" | grep -q "claude-.*\.log" && return 0
                ;;
        esac
    fi
    return 1
}
input11='{"tool":{"name":"Bash","input":{"command":"ls | head -3"}},"timeout":null}'
run_integration_test "Platform-appropriate temp directories should be used" "$input11" platform_test

echo "=== Test 12: Performance Integration ==="
# Test that the hook processes quickly
start_time=$(date +%s)
input12='{"tool":{"name":"Bash","input":{"command":"echo performance test | cat"}},"timeout":null}'
output12=$(echo "$input12" | bash "$HOOK_SCRIPT" 2>&1)
end_time=$(date +%s)

validate_performance() {
    local output="$1"
    local duration="$2"
    # Should be reasonably fast (less than 5 seconds)
    [[ $duration -lt 5 ]] && validate_json_structure "$output"
}

duration=$((end_time - start_time))
TESTS_RUN=$((TESTS_RUN + 1))
if validate_performance "$output12" "$duration"; then
    echo "✓ Performance test - Hook execution is fast ($duration seconds)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "✗ Performance test - Hook execution too slow ($duration seconds) or invalid output"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo "=== Test 13: Complete Workflow Integration ==="
# Test a complete realistic workflow
workflow_input='{"tool":{"name":"Bash","input":{"command":"npm run build 2>&1 | tail -20"}},"timeout":null}'
validate_workflow() {
    local output="$1"
    validate_json_structure "$output" &&
    echo "$output" | grep -q "npm run build 2>&1.*tee.*claude-.*log.*tail -20" &&
    echo "$output" | grep -q "Full output saved to:"
}
run_integration_test "Complete workflow should work end-to-end" "$workflow_input" validate_workflow

# Summary
echo "======================================="
echo "Test Results:"
echo "  Tests run: $TESTS_RUN"
echo "  Passed: $TESTS_PASSED"  
echo "  Failed: $TESTS_FAILED"
echo "======================================="

echo ""
echo "Platform Information:"
echo "  OS: $(uname -s 2>/dev/null || echo Unknown)"
echo "  Platform: $(uname -m 2>/dev/null || echo Unknown)"
echo "  Bash: $BASH_VERSION"
echo "  Temp Dir: ${TMPDIR:-/tmp}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo ""
    echo "✅ All integration tests passed!"
    echo "✅ claude-auto-tee is working correctly on this platform"
    exit 0
else
    echo ""
    echo "❌ Some integration tests failed!"
    echo "❌ Issues detected that need attention"
    exit 1
fi