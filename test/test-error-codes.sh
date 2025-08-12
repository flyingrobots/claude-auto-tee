#!/usr/bin/env bash
# Test Error Codes System
# P1.T024: Create comprehensive error codes/categories

set -euo pipefail
IFS=$'\n\t'

# Source the error codes system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../src" && pwd)"
source "$SCRIPT_DIR/error-codes.sh"

echo "🧪 Testing Error Codes System"
echo ""

# Test 1: Error code constants
echo "=== Test 1: Error Code Constants ==="
if [[ $ERR_INVALID_INPUT -eq 1 ]]; then
    echo "✅ Error constants defined correctly"
else 
    echo "❌ Error constants not working"
    exit 1
fi

# Test 2: Error message retrieval
echo "=== Test 2: Error Message Retrieval ==="
message=$(get_error_message $ERR_INVALID_INPUT)
if [[ "$message" == "Invalid input provided" ]]; then
    echo "✅ Error message retrieval works"
else
    echo "❌ Error message retrieval failed: $message"
    exit 1
fi

# Test 3: Error category retrieval
echo "=== Test 3: Error Category Retrieval ==="
category=$(get_error_category $ERR_INVALID_INPUT)
if [[ "$category" == "input" ]]; then
    echo "✅ Error category retrieval works"
else
    echo "❌ Error category retrieval failed: $category"
    exit 1
fi

# Test 4: Error severity retrieval
echo "=== Test 4: Error Severity Retrieval ==="
severity=$(get_error_severity $ERR_INVALID_INPUT)
if [[ "$severity" == "error" ]]; then
    echo "✅ Error severity retrieval works"
else
    echo "❌ Error severity retrieval failed: $severity"
    exit 1
fi

# Test 5: Error validation
echo "=== Test 5: Error Code Validation ==="
if is_valid_error_code $ERR_INVALID_INPUT; then
    echo "✅ Error code validation works"
else
    echo "❌ Error code validation failed"
    exit 1
fi

# Test 6: Warning reporting (non-fatal)
echo "=== Test 6: Warning Reporting ==="
echo "Testing warning report (should see warning message):"
report_warning $ERR_INSUFFICIENT_SPACE "Test warning context"
echo "✅ Warning reporting completed"

# Test 7: Context management
echo "=== Test 7: Error Context Management ==="
set_error_context "Test context"
if [[ "$ERROR_CONTEXT" == "Test context" ]]; then
    echo "✅ Error context setting works"
else
    echo "❌ Error context setting failed"
    exit 1
fi
clear_error_context
if [[ -z "$ERROR_CONTEXT" ]]; then
    echo "✅ Error context clearing works"
else
    echo "❌ Error context clearing failed"
    exit 1
fi

# Test 8: List error codes (sample)
echo "=== Test 8: Error Code Listing ==="
echo "Sample error codes for 'input' category:"
list_error_codes "input" | head -3
echo "✅ Error code listing works"

echo ""
echo "🎉 All error code tests passed!"