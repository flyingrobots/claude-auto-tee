#!/usr/bin/env bash
# Simple integration test for meaningful space error messages (P1.T019)

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Testing meaningful space error messages (P1.T019)..."

# Test 1: Verify enhanced error functions exist
echo "Test 1: Checking enhanced error functions are defined"
if bash -c "source '$PROJECT_ROOT/src/disk-space-check.sh' && type generate_space_error_message >/dev/null 2>&1"; then
    echo "✓ PASS: generate_space_error_message function exists"
else
    echo "✗ FAIL: generate_space_error_message function missing"
    exit 1
fi

if bash -c "source '$PROJECT_ROOT/src/disk-space-check.sh' && type check_space_with_detailed_errors >/dev/null 2>&1"; then
    echo "✓ PASS: check_space_with_detailed_errors function exists"
else
    echo "✗ FAIL: check_space_with_detailed_errors function missing"
    exit 1
fi

# Test 2: Verify error message contains meaningful content
echo "Test 2: Checking error message content quality"
error_output=$(bash -c "source '$PROJECT_ROOT/src/disk-space-check.sh' && generate_space_error_message 20 '/tmp' '100' 'test'" 2>/dev/null)

if echo "$error_output" | grep -q "💡 Suggested solutions"; then
    echo "✓ PASS: Error message contains suggested solutions"
else
    echo "✗ FAIL: Error message missing suggested solutions"
    exit 1
fi

if echo "$error_output" | grep -q "Tip: Use.*VERBOSE"; then
    echo "✓ PASS: Error message contains verbose tip"
else
    echo "✗ FAIL: Error message missing verbose tip"
    exit 1
fi

# Test 3: Verify main script uses enhanced error checking
echo "Test 3: Checking main script integration"
if grep -q "check_space_with_detailed_errors" "$PROJECT_ROOT/src/claude-auto-tee.sh"; then
    echo "✓ PASS: Main script uses enhanced error checking function"
else
    echo "✗ FAIL: Main script not using enhanced error checking"
    exit 1
fi

if grep -q "P1.T019" "$PROJECT_ROOT/src/claude-auto-tee.sh"; then
    echo "✓ PASS: Main script references P1.T019 task"
else
    echo "✗ FAIL: Main script missing P1.T019 reference"
    exit 1
fi

# Test 4: Verify different error codes produce different messages
echo "Test 4: Checking error code differentiation"
error_20=$(bash -c "source '$PROJECT_ROOT/src/disk-space-check.sh' && generate_space_error_message 20 '/tmp' '' ''" 2>/dev/null)
error_21=$(bash -c "source '$PROJECT_ROOT/src/disk-space-check.sh' && generate_space_error_message 21 '/tmp' '' ''" 2>/dev/null)

if [[ "$error_20" != "$error_21" ]]; then
    echo "✓ PASS: Different error codes produce different messages"
else
    echo "✗ FAIL: Error codes produce identical messages"
    exit 1
fi

echo
echo "✓ All meaningful space error message tests passed!"
echo "P1.T019 implementation verified successfully."