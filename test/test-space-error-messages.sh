#!/usr/bin/env bash
# Test suite for meaningful space error messages (P1.T019)
# Verifies that space-related errors provide actionable, user-friendly guidance

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
readonly SPACE_FUNCTIONS="$PROJECT_ROOT/src/disk-space-check.sh"

# Test helper function that calls the space functions
call_generate_space_error_message() {
    local error_code="$1"
    local dir_path="$2"
    local required_mb="$3"
    local command="$4"
    
    # Use a subshell to avoid sourcing issues
    bash -c "source '$SPACE_FUNCTIONS' && generate_space_error_message '$error_code' '$dir_path' '$required_mb' '$command'" 2>/dev/null
}

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

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Meaningful Space Error Messages Test Suite (P1.T019)${NC}"
echo -e "${BLUE}=========================================${NC}"
echo

echo "Testing enhanced space error message generation..."

echo -e "${BLUE}=== Test 1: ERR_INSUFFICIENT_SPACE Message Generation ===${NC}"

# Test insufficient space error message
error_msg=$(call_generate_space_error_message 20 "/tmp" "150" "npm run build")
if echo "$error_msg" | grep -q "Insufficient disk space in /tmp"; then
    if echo "$error_msg" | grep -q "Need at least 150MB"; then
        if echo "$error_msg" | grep -q "💡 Suggested solutions"; then
            if echo "$error_msg" | grep -q "rm -f /tmp/claude-*.log"; then
                print_test_result "ERR_INSUFFICIENT_SPACE message format" "PASS"
            else
                print_test_result "ERR_INSUFFICIENT_SPACE message format" "FAIL" "Missing cleanup suggestion"
            fi
        else
            print_test_result "ERR_INSUFFICIENT_SPACE message format" "FAIL" "Missing suggestions section"
        fi
    else
        print_test_result "ERR_INSUFFICIENT_SPACE message format" "FAIL" "Missing required space info"
    fi
else
    print_test_result "ERR_INSUFFICIENT_SPACE message format" "FAIL" "Missing base error message"
fi

echo -e "${BLUE}=== Test 2: ERR_DISK_FULL Message Generation ===${NC}"

# Test disk full error message
error_msg=$(call_generate_space_error_message 21 "/var/tmp" "" "find . -name '*.js'")
if echo "$error_msg" | grep -q "Disk is completely full"; then
    if echo "$error_msg" | grep -q "Immediately free critical space"; then
        if echo "$error_msg" | grep -q "find .* -name '\\*\\.tmp' -size"; then
            print_test_result "ERR_DISK_FULL message format" "PASS"
        else
            print_test_result "ERR_DISK_FULL message format" "FAIL" "Missing temp file cleanup suggestion"
        fi
    else
        print_test_result "ERR_DISK_FULL message format" "FAIL" "Missing critical space suggestion"
    fi
else
    print_test_result "ERR_DISK_FULL message format" "FAIL" "Missing base error message"
fi

echo -e "${BLUE}=== Test 3: ERR_QUOTA_EXCEEDED Message Generation ===${NC}"

# Test quota exceeded error message
error_msg=$(call_generate_space_error_message 22 "/home/user" "" "")
if echo "$error_msg" | grep -q "Disk quota exceeded"; then
    if echo "$error_msg" | grep -q "quota -u"; then
        if echo "$error_msg" | grep -q "Contact system administrator"; then
            print_test_result "ERR_QUOTA_EXCEEDED message format" "PASS"
        else
            print_test_result "ERR_QUOTA_EXCEEDED message format" "FAIL" "Missing admin contact suggestion"
        fi
    else
        print_test_result "ERR_QUOTA_EXCEEDED message format" "FAIL" "Missing quota check suggestion"
    fi
else
    print_test_result "ERR_QUOTA_EXCEEDED message format" "FAIL" "Missing base error message"
fi

echo -e "${BLUE}=== Test 4: Command-Specific Suggestions ===${NC}"

# Test build command suggestions
error_msg=$(call_generate_space_error_message 20 "/tmp" "100" "npm run build")
if echo "$error_msg" | grep -q "CLAUDE_AUTO_TEE_MAX_SIZE"; then
    print_test_result "Build command specific suggestions" "PASS"
else
    print_test_result "Build command specific suggestions" "FAIL" "Missing MAX_SIZE suggestion for build"
fi

# Test search command suggestions
error_msg=$(call_generate_space_error_message 20 "/tmp" "100" "find . -name '*.log'")
if echo "$error_msg" | grep -q "head -1000"; then
    print_test_result "Search command specific suggestions" "PASS"
else
    print_test_result "Search command specific suggestions" "FAIL" "Missing head limitation suggestion"
fi

echo -e "${BLUE}=== Test 5: General Tips and Formatting ===${NC}"

# Test that all messages include general tips and proper formatting
error_msg=$(call_generate_space_error_message 20 "/tmp" "50" "test command")
if echo "$error_msg" | grep -q "ℹ️  Tip: Use"; then
    if echo "$error_msg" | grep -q "CLAUDE_AUTO_TEE_VERBOSE=true"; then
        print_test_result "General tips and formatting" "PASS"
    else
        print_test_result "General tips and formatting" "FAIL" "Missing verbose mode tip"
    fi
else
    print_test_result "General tips and formatting" "FAIL" "Missing general tip section"
fi

echo -e "${BLUE}=== Test 6: report_space_error Function ===${NC}"

# Test that report_space_error function works correctly
output_file="/tmp/space_error_test_$$"
(source "$SPACE_FUNCTIONS" && report_space_error 20 "/tmp" "75" "yarn build") 2>"$output_file"
if [[ -f "$output_file" ]]; then
    if grep -q "❌ Space Issue Detected:" "$output_file"; then
        if grep -q "Insufficient disk space" "$output_file"; then
            print_test_result "report_space_error function" "PASS"
        else
            print_test_result "report_space_error function" "FAIL" "Missing space error content"
        fi
    else
        print_test_result "report_space_error function" "FAIL" "Missing error header"
    fi
    rm -f "$output_file"
else
    print_test_result "report_space_error function" "FAIL" "No error output generated"
fi

echo -e "${BLUE}=== Test 7: Error Code Coverage ===${NC}"

# Test all space-related error codes
all_codes_work=true
for code in 20 21 22 23; do
    error_msg=$(call_generate_space_error_message "$code" "/test" "" "")
    if [[ -z "$error_msg" ]] || ! echo "$error_msg" | grep -q "💡 Suggested solutions"; then
        all_codes_work=false
        break
    fi
done

if $all_codes_work; then
    print_test_result "All space error codes supported" "PASS"
else
    print_test_result "All space error codes supported" "FAIL" "Some error codes not properly handled"
fi

echo
echo -e "${BLUE}=== Final Results ===${NC}"
echo "Tests run: $test_count"
echo -e "Passed: ${GREEN}$passed_count${NC}"
echo -e "Failed: ${RED}$failed_count${NC}"

if [[ $failed_count -eq 0 ]]; then
    echo
    echo -e "${GREEN}✓ All meaningful space error message tests passed!${NC}"
    echo "P1.T019 implementation verified successfully."
    exit 0
else
    echo
    echo -e "${RED}✗ Some meaningful space error message tests failed.${NC}"
    exit 1
fi