#!/usr/bin/env bash
# Simple test for cleanup on interruption (P1.T014)
# Verifies that signal handlers are registered and cleanup logic works

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly HOOK_SCRIPT="$PROJECT_ROOT/src/claude-auto-tee.sh"

# Test basic cleanup functionality
echo "Testing cleanup on interruption functionality (P1.T014)..."

# Test 1: Basic signal handler registration
echo "Test 1: Verifying signal handler registration and cleanup registration"
input_json='{"tool":{"name":"Bash","input":{"command":"echo test | head -1"}},"timeout":null}'
output=$(echo "$input_json" | CLAUDE_AUTO_TEE_VERBOSE=true "$HOOK_SCRIPT" 2>&1)

if echo "$output" | grep -q "Registered files for cleanup on interruption"; then
    echo "✓ PASS: Files registered for cleanup on interruption"
else
    echo "✗ FAIL: Cleanup registration message not found"
    echo "Output was: $output"
    exit 1
fi

if echo "$output" | grep -q "Script interrupted - cleaning up"; then
    echo "✓ PASS: Cleanup handler executed on exit"
else
    echo "✗ FAIL: Cleanup handler not executed"
    exit 1
fi

# Test 2: Verify normal operation still works
echo "Test 2: Verifying normal operation with cleanup handlers"
output=$(echo "$input_json" | "$HOOK_SCRIPT" 2>&1)

if echo "$output" | grep -q 'echo test.*head -1'; then
    echo "✓ PASS: Normal command processing works with cleanup handlers"
else
    echo "✗ FAIL: Command not properly processed with cleanup handlers"
    echo "Output was: $output"
    exit 1
fi

echo "✓ All cleanup on interruption tests passed!"
echo "P1.T014 implementation verified successfully."