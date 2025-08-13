#!/usr/bin/env bash
# Comprehensive Edge Case Test Suite for Pipe Injection Logic
# Tests critical vulnerabilities and edge cases in claude-auto-tee pipe splitting

set -euo pipefail
IFS=$'\n\t'

# Colors for test output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m' # No Color

# Test counters
test_count=0
passed_count=0
failed_count=0
security_issues=0

# Test configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly HOOK_SCRIPT="$PROJECT_ROOT/src/claude-auto-tee.sh"

# Test utilities
print_test_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_test_result() {
    local test_name="$1"
    local result="$2"
    local details="${3:-}"
    local is_security="${4:-false}"
    
    ((test_count++))
    
    if [[ "$result" == "PASS" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        ((passed_count++))
    elif [[ "$result" == "SECURITY_ISSUE" ]]; then
        echo -e "${RED}🚨 SECURITY ISSUE${NC}: $test_name"
        if [[ -n "$details" ]]; then
            echo -e "  ${YELLOW}Details:${NC} $details"
        fi
        ((failed_count++))
        ((security_issues++))
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        if [[ -n "$details" ]]; then
            echo -e "  ${YELLOW}Details:${NC} $details"
        fi
        ((failed_count++))
    fi
}

# Test helper function
test_pipe_injection() {
    local test_name="$1"
    local command="$2"
    local expected_behavior="$3"  # "SHOULD_SPLIT", "SHOULD_NOT_SPLIT", "SHOULD_PASSTHROUGH"
    local security_check="${4:-false}"
    
    local input_json="{\"tool\":{\"name\":\"Bash\",\"input\":{\"command\":\"$command\"}},\"timeout\":null}"
    
    # Escape the input JSON properly
    local temp_input=$(mktemp)
    echo "$input_json" > "$temp_input"
    
    local temp_output=$(mktemp)
    local temp_error=$(mktemp)
    
    local exit_code=0
    if timeout 10 bash "$HOOK_SCRIPT" < "$temp_input" > "$temp_output" 2> "$temp_error"; then
        exit_code=0
    else
        exit_code=$?
    fi
    
    local output=$(cat "$temp_output" 2>/dev/null || echo "")
    local errors=$(cat "$temp_error" 2>/dev/null || echo "")
    
    # Clean up temp files
    rm -f "$temp_input" "$temp_output" "$temp_error"
    
    # Analyze results
    local has_tee=false
    local has_claude_temp=false
    local is_valid_json=false
    local syntax_error=false
    
    if echo "$output" | grep -q "tee.*claude-"; then
        has_tee=true
        has_claude_temp=true
    elif echo "$output" | grep -q "tee"; then
        has_tee=true
    fi
    
    if echo "$output" | python3 -m json.tool >/dev/null 2>&1; then
        is_valid_json=true
    fi
    
    if echo "$errors" | grep -qi "syntax error\|command not found\|unexpected token"; then
        syntax_error=true
    fi
    
    # Determine test result
    case "$expected_behavior" in
        "SHOULD_SPLIT")
            if [[ "$has_claude_temp" == "true" ]] && [[ "$is_valid_json" == "true" ]] && [[ "$syntax_error" == "false" ]]; then
                print_test_result "$test_name" "PASS"
            else
                local details="has_tee=$has_tee, has_claude_temp=$has_claude_temp, valid_json=$is_valid_json, syntax_error=$syntax_error"
                if [[ "$security_check" == "true" ]]; then
                    print_test_result "$test_name" "SECURITY_ISSUE" "$details"
                else
                    print_test_result "$test_name" "FAIL" "$details"
                fi
            fi
            ;;
        "SHOULD_NOT_SPLIT")
            if [[ "$has_claude_temp" == "false" ]] && [[ "$is_valid_json" == "true" ]] && [[ "$syntax_error" == "false" ]]; then
                print_test_result "$test_name" "PASS"
            else
                local details="Should not inject tee but did: has_claude_temp=$has_claude_temp, syntax_error=$syntax_error"
                if [[ "$security_check" == "true" ]]; then
                    print_test_result "$test_name" "SECURITY_ISSUE" "$details"
                else
                    print_test_result "$test_name" "FAIL" "$details"
                fi
            fi
            ;;
        "SHOULD_PASSTHROUGH")
            if [[ "$output" == "$input_json" ]]; then
                print_test_result "$test_name" "PASS"
            else
                print_test_result "$test_name" "FAIL" "Output should match input exactly"
            fi
            ;;
        "EXPECT_ERROR")
            if [[ "$exit_code" -ne 0 ]] || [[ "$syntax_error" == "true" ]]; then
                print_test_result "$test_name" "PASS" "Expected error occurred"
            else
                print_test_result "$test_name" "FAIL" "Expected error but command succeeded"
            fi
            ;;
    esac
    
    # Additional security checks
    if [[ "$security_check" == "true" ]]; then
        # Check for potential command injection
        if echo "$output" | grep -q "; rm \|&& rm \|| rm \|; cat /etc\|; wget \|; curl "; then
            print_test_result "$test_name (Command Injection Check)" "SECURITY_ISSUE" "Potential command injection detected in output"
        fi
        
        # Check for shell metacharacter issues
        if echo "$output" | grep -q '\\$\\|\\`\\|$('; then
            print_test_result "$test_name (Shell Metachar Check)" "SECURITY_ISSUE" "Unescaped shell metacharacters detected"
        fi
    fi
    
    # Print debug info for failed tests
    if [[ "$expected_behavior" != "SHOULD_PASSTHROUGH" ]] && [[ "$syntax_error" == "true" || "$is_valid_json" == "false" ]]; then
        echo -e "  ${PURPLE}Debug Output:${NC} $output"
        if [[ -n "$errors" ]]; then
            echo -e "  ${PURPLE}Debug Errors:${NC} $errors"
        fi
    fi
}

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE} Comprehensive Pipe Injection Edge Case Tests   ${NC}"
echo -e "${BLUE}=================================================${NC}"
echo "Platform: $(uname -s 2>/dev/null || echo Unknown)"
echo "Testing hook: $HOOK_SCRIPT"
echo

# ================================================================
# CATEGORY 1: MULTIPLE PIPE VULNERABILITIES
# ================================================================
print_test_header "Category 1: Multiple Pipe Handling Vulnerabilities"

test_pipe_injection \
    "Multiple pipes - basic chain" \
    "echo test | grep test | head -1" \
    "SHOULD_SPLIT" \
    "true"

test_pipe_injection \
    "Multiple pipes - complex chain" \
    "cat /etc/passwd | grep root | cut -d: -f1 | sort | head -5" \
    "SHOULD_SPLIT" \
    "true"

test_pipe_injection \
    "Multiple pipes with stderr redirect" \
    "find /etc 2>/dev/null | grep conf | head -10 | wc -l" \
    "SHOULD_SPLIT" \
    "true"

# ================================================================
# CATEGORY 2: QUOTED PIPE VULNERABILITIES  
# ================================================================
print_test_header "Category 2: Quoted Pipe Content Vulnerabilities"

test_pipe_injection \
    "Pipe in quoted string" \
    "echo \"data | more data\" | head" \
    "SHOULD_SPLIT" \
    "true"

test_pipe_injection \
    "Pipe in single quotes" \
    "echo 'pipe | symbol here' | cat" \
    "SHOULD_SPLIT" \
    "true"

test_pipe_injection \
    "Mixed quotes with pipes" \
    "echo \"test | 'nested' | stuff\" | grep test" \
    "SHOULD_SPLIT" \
    "true"

test_pipe_injection \
    "Escaped quotes with pipes" \
    "echo \\\"data | pipe\\\" | head" \
    "SHOULD_SPLIT" \
    "true"

# ================================================================
# CATEGORY 3: ESCAPED AND SPECIAL CHARACTER PIPES
# ================================================================
print_test_header "Category 3: Escaped and Special Character Handling"

test_pipe_injection \
    "Escaped pipe character" \
    "echo pipe\\| symbol | cat" \
    "SHOULD_SPLIT" \
    "false"

test_pipe_injection \
    "Pipe in variable expansion" \
    "echo \${PATH} | tr ':' '\\n' | head -3" \
    "SHOULD_SPLIT" \
    "false"

test_pipe_injection \
    "Pipe with unicode lookalikes" \
    "echo test ︱ fake | head" \
    "SHOULD_NOT_SPLIT" \
    "false"

# ================================================================
# CATEGORY 4: COMPLEX COMMAND STRUCTURES
# ================================================================
print_test_header "Category 4: Complex Command Structure Vulnerabilities"

test_pipe_injection \
    "Command substitution with pipes" \
    "echo \$(echo test | head) | cat" \
    "SHOULD_SPLIT" \
    "true"

test_pipe_injection \
    "Subshell with pipes" \
    "(echo test | head) | cat" \
    "SHOULD_SPLIT" \
    "true"

test_pipe_injection \
    "Conditional with pipes in condition" \
    "if echo test | grep -q test; then echo ok; fi | cat" \
    "SHOULD_SPLIT" \
    "true"

test_pipe_injection \
    "Loop with pipes" \
    "for i in 1 2 3; do echo \$i; done | head -2" \
    "SHOULD_SPLIT" \
    "false"

test_pipe_injection \
    "Function call with pipes" \
    "{ echo start; echo end; } | grep start" \
    "SHOULD_SPLIT" \
    "false"

# ================================================================
# CATEGORY 5: SECURITY INJECTION TESTS
# ================================================================
print_test_header "Category 5: Security Injection Vulnerabilities"

test_pipe_injection \
    "Command injection attempt via pipe" \
    "echo test | head; rm -rf /tmp/test" \
    "SHOULD_SPLIT" \
    "true"

test_pipe_injection \
    "Command injection with && operator" \
    "echo test | head && rm -rf /tmp/test" \
    "SHOULD_SPLIT" \
    "true"

test_pipe_injection \
    "Command injection with || operator" \
    "echo test | head || rm -rf /tmp/test" \
    "SHOULD_SPLIT" \
    "true"

test_pipe_injection \
    "Background command injection" \
    "echo test | head & rm -rf /tmp/test" \
    "SHOULD_SPLIT" \
    "true"

test_pipe_injection \
    "Redirection manipulation" \
    "echo test | head > /etc/passwd" \
    "SHOULD_SPLIT" \
    "true"

# ================================================================
# CATEGORY 6: EDGE CASE BOUNDARY CONDITIONS
# ================================================================
print_test_header "Category 6: Boundary Condition Edge Cases"

test_pipe_injection \
    "Pipe at start of command" \
    "| head -1" \
    "EXPECT_ERROR" \
    "false"

test_pipe_injection \
    "Pipe at end of command" \
    "echo test |" \
    "EXPECT_ERROR" \
    "false"

test_pipe_injection \
    "Multiple consecutive pipes" \
    "echo test || head" \
    "SHOULD_NOT_SPLIT" \
    "false"

test_pipe_injection \
    "Empty command with pipe" \
    " | " \
    "EXPECT_ERROR" \
    "false"

test_pipe_injection \
    "Very long command with pipes" \
    "$(printf 'echo %s | ' {1..100})head" \
    "SHOULD_SPLIT" \
    "true"

# ================================================================
# CATEGORY 7: WHITESPACE AND FORMATTING EDGE CASES
# ================================================================
print_test_header "Category 7: Whitespace and Formatting Edge Cases"

test_pipe_injection \
    "No spaces around pipe" \
    "echo test|head" \
    "SHOULD_NOT_SPLIT" \
    "false"

test_pipe_injection \
    "Extra spaces around pipe" \
    "echo test  |  head" \
    "SHOULD_NOT_SPLIT" \
    "false"

test_pipe_injection \
    "Tab characters around pipe" \
    "echo test	|	head" \
    "SHOULD_NOT_SPLIT" \
    "false"

test_pipe_injection \
    "Newline in pipe command" \
    "echo test |\nhead" \
    "SHOULD_SPLIT" \
    "false"

# ================================================================
# CATEGORY 8: EXISTING TEE DETECTION EDGE CASES
# ================================================================
print_test_header "Category 8: Existing Tee Detection Edge Cases"

test_pipe_injection \
    "Tee in quoted string" \
    "echo \"tee is a command\" | head" \
    "SHOULD_SPLIT" \
    "false"

test_pipe_injection \
    "Tee as part of filename" \
    "cat tee_file.txt | head" \
    "SHOULD_SPLIT" \
    "false"

test_pipe_injection \
    "Multiple tee commands" \
    "echo test | tee file1 | tee file2" \
    "SHOULD_NOT_SPLIT" \
    "false"

test_pipe_injection \
    "Tee with options" \
    "echo test | tee -a logfile | head" \
    "SHOULD_NOT_SPLIT" \
    "false"

# ================================================================
# CATEGORY 9: JSON INJECTION AND ESCAPING TESTS
# ================================================================
print_test_header "Category 9: JSON Injection and Escaping Vulnerabilities"

test_pipe_injection \
    "Double quotes in command" \
    "echo \\\"test\\\" | head" \
    "SHOULD_SPLIT" \
    "true"

test_pipe_injection \
    "Backslashes in command" \
    "echo \\\\test\\\\ | head" \
    "SHOULD_SPLIT" \
    "true"

test_pipe_injection \
    "JSON control characters" \
    "echo $'\\n\\r\\t' | head" \
    "SHOULD_SPLIT" \
    "true"

# ================================================================
# CATEGORY 10: PLATFORM-SPECIFIC EDGE CASES
# ================================================================
print_test_header "Category 10: Platform-Specific Edge Cases"

case "$(uname -s)" in
    Darwin*)
        test_pipe_injection \
            "macOS specific path with pipes" \
            "find /System/Library | head -10" \
            "SHOULD_SPLIT" \
            "false"
        ;;
    Linux*)
        test_pipe_injection \
            "Linux specific path with pipes" \
            "find /sys | head -10" \
            "SHOULD_SPLIT" \
            "false"
        ;;
esac

# ================================================================
# RESULTS SUMMARY
# ================================================================
echo
echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}         COMPREHENSIVE TEST RESULTS            ${NC}"
echo -e "${BLUE}===============================================${NC}"
echo "Total tests: $test_count"
echo -e "Passed: ${GREEN}$passed_count${NC}"
echo -e "Failed: ${RED}$failed_count${NC}"
echo -e "Security issues: ${RED}$security_issues${NC}"

if [[ $security_issues -gt 0 ]]; then
    echo
    echo -e "${RED}🚨 CRITICAL: $security_issues security vulnerabilities detected!${NC}"
    echo -e "${RED}The pipe injection logic has serious security flaws that need immediate attention.${NC}"
fi

if [[ $failed_count -eq 0 ]] && [[ $security_issues -eq 0 ]]; then
    echo -e "\n${GREEN}All tests passed! Pipe injection logic appears robust.${NC}"
    exit 0
else
    echo -e "\n${RED}Tests revealed vulnerabilities in the pipe injection logic.${NC}"
    echo -e "${YELLOW}See detailed recommendations below.${NC}"
    exit 1
fi