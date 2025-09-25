#!/usr/bin/env bash
# Path Handling Test Suite
# P1.T007 - Validate path handling (forward/backward slashes)

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly HOOK_SCRIPT="$PROJECT_ROOT/src/claude-auto-tee.sh"
readonly PATH_UTILS="$PROJECT_ROOT/src/path-utils.sh"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Test tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

print_test_result() {
    local test_name="$1"
    local result="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "$result" == "0" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

run_path_utils_test() {
    local test_function="$1"
    local expected_output="$2"
    shift 2
    
    # Source path utilities
    if ! source "$PATH_UTILS" 2>/dev/null; then
        return 1
    fi
    
    # Run function and capture output
    local actual_output
    if actual_output=$($test_function "$@" 2>/dev/null); then
        if [[ "$actual_output" == "$expected_output" ]]; then
            return 0
        fi
    fi
    return 1
}

test_hook_with_path() {
    local input_json="$1"
    local expected_path_pattern="$2"
    
    local output
    if output=$(echo "$input_json" | bash "$HOOK_SCRIPT" 2>&1); then
        if echo "$output" | grep -q "$expected_path_pattern"; then
            # Also check JSON structure
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        else
            return 1
        fi
    else
        return 1
    fi
}

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}Path Handling Test Suite${NC}"
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}Platform: $(uname -s)${NC}"
echo -e "${BLUE}Shell: $BASH_VERSION${NC}"
echo ""

# ==========================================
# Path Utilities Tests
# ==========================================

echo -e "${YELLOW}=== Path Utilities Tests ===${NC}"

test_normalize_path_unix() {
    if [[ "$(uname -s)" =~ ^(CYGWIN|MINGW|MSYS) ]]; then
        return 0  # Skip on Windows-like systems
    fi
    
    run_path_utils_test "normalize_path" "/tmp/test/path" "/tmp//test\\path/"
}
print_test_result "Normalize path (Unix)" "$?"

test_normalize_path_windows() {
    if [[ ! "$(uname -s)" =~ ^(CYGWIN|MINGW|MSYS) ]]; then
        # Test basic normalization even on non-Windows
        run_path_utils_test "normalize_path" "/tmp/test/path" "/tmp//test/path/"
        return $?
    fi
    
    run_path_utils_test "normalize_path" "C:\\tmp\\test\\path" "C:/tmp//test\\path\\"
}
print_test_result "Normalize path (Windows)" "$?"

test_join_path() {
    local expected_result
    case "$(uname -s)" in
        CYGWIN*|MINGW*|MSYS*)
            expected_result="C:\\temp\\test\\file.log"
            ;;
        *)
            expected_result="/tmp/test/file.log"
            ;;
    esac
    
    case "$(uname -s)" in
        CYGWIN*|MINGW*|MSYS*)
            run_path_utils_test "join_path" "$expected_result" "C:\\temp" "test" "file.log"
            ;;
        *)
            run_path_utils_test "join_path" "$expected_result" "/tmp" "test" "file.log"
            ;;
    esac
}
print_test_result "Join path components" "$?"

test_is_absolute_path() {
    source "$PATH_UTILS" 2>/dev/null || return 1
    
    # Test Unix absolute path
    if is_absolute_path "/tmp/test"; then
        local unix_result=0
    else
        local unix_result=1
    fi
    
    # Test relative path
    if is_absolute_path "relative/path"; then
        local relative_result=1
    else
        local relative_result=0
    fi
    
    # Test Windows paths if applicable
    local windows_result=0
    if [[ "$(uname -s)" =~ ^(CYGWIN|MINGW|MSYS) ]]; then
        if is_absolute_path "C:\\Windows"; then
            windows_result=0
        else
            windows_result=1
        fi
    fi
    
    if [[ $unix_result -eq 0 ]] && [[ $relative_result -eq 0 ]] && [[ $windows_result -eq 0 ]]; then
        return 0
    fi
    return 1
}
print_test_result "Detect absolute paths" "$?"

test_create_safe_temp_path() {
    source "$PATH_UTILS" 2>/dev/null || return 1
    
    local temp_path
    if temp_path=$(create_safe_temp_path "/tmp" "test-prefix" ".log"); then
        # Check that path follows expected pattern
        case "$(uname -s)" in
            CYGWIN*|MINGW*|MSYS*)
                echo "$temp_path" | grep -q "test-prefix.*\.log"
                ;;
            *)
                echo "$temp_path" | grep -q "/tmp/test-prefix.*\.log"
                ;;
        esac
    else
        return 1
    fi
}
print_test_result "Create safe temp path" "$?"

test_path_security_validation() {
    source "$PATH_UTILS" 2>/dev/null || return 1
    
    # Test safe path
    if validate_path_security "/tmp/safe/path"; then
        local safe_result=0
    else
        local safe_result=1
    fi
    
    # Test dangerous path (parent traversal)
    if validate_path_security "/tmp/../etc/passwd"; then
        local dangerous_result=1
    else
        local dangerous_result=0
    fi
    
    if [[ $safe_result -eq 0 ]] && [[ $dangerous_result -eq 0 ]]; then
        return 0
    fi
    return 1
}
print_test_result "Path security validation" "$?"

# ==========================================
# Hook Integration Tests
# ==========================================

echo -e "${YELLOW}=== Hook Integration Tests ===${NC}"

test_temp_path_with_forward_slashes() {
    # Set temp directory with forward slashes
    local old_tmpdir="${TMPDIR:-}"
    export TMPDIR="/tmp/claude-test-forward"
    
    # Create test directory
    mkdir -p "/tmp/claude-test-forward" 2>/dev/null || true
    
    local input='{"tool":{"name":"Bash","input":{"command":"echo forward-slash-test | head -1"}},"timeout":null}'
    local result
    
    if test_hook_with_path "$input" "claude-.*\.log"; then
        result=0
    else
        result=1
    fi
    
    # Cleanup
    rm -rf "/tmp/claude-test-forward" 2>/dev/null || true
    if [[ -n "$old_tmpdir" ]]; then
        export TMPDIR="$old_tmpdir"
    else
        unset TMPDIR 2>/dev/null || true
    fi
    
    return $result
}
print_test_result "Temp path with forward slashes" "$?"

test_temp_path_with_backward_slashes() {
    # Only test on Windows-like systems
    if [[ ! "$(uname -s)" =~ ^(CYGWIN|MINGW|MSYS) ]]; then
        return 0  # Skip on non-Windows
    fi
    
    # Set temp directory with backward slashes
    local old_tmpdir="${TMPDIR:-}"
    export TMPDIR="C:\\temp\\claude-test-backward"
    
    # Create test directory
    mkdir -p "C:\\temp\\claude-test-backward" 2>/dev/null || true
    
    local input='{"tool":{"name":"Bash","input":{"command":"echo backward-slash-test | head -1"}},"timeout":null}'
    local result
    
    if test_hook_with_path "$input" "claude-.*\.log"; then
        result=0
    else
        result=1
    fi
    
    # Cleanup
    rm -rf "C:\\temp\\claude-test-backward" 2>/dev/null || true
    if [[ -n "$old_tmpdir" ]]; then
        export TMPDIR="$old_tmpdir"
    else
        unset TMPDIR 2>/dev/null || true
    fi
    
    return $result
}
print_test_result "Temp path with backward slashes (Windows)" "$?"

test_mixed_slash_scenarios() {
    # Test mixed slash scenarios
    local old_claude_temp="${CLAUDE_AUTO_TEE_TEMP_DIR:-}"
    
    case "$(uname -s)" in
        CYGWIN*|MINGW*|MSYS*)
            export CLAUDE_AUTO_TEE_TEMP_DIR="C:/temp\\mixed/slashes"
            mkdir -p "C:/temp/mixed/slashes" 2>/dev/null || true
            ;;
        *)
            export CLAUDE_AUTO_TEE_TEMP_DIR="/tmp/mixed\\forward/slashes"
            mkdir -p "/tmp/mixed/forward/slashes" 2>/dev/null || true
            ;;
    esac
    
    local input='{"tool":{"name":"Bash","input":{"command":"echo mixed-slash-test | head -1"}},"timeout":null}'
    local result
    
    if test_hook_with_path "$input" "claude-.*\.log"; then
        result=0
    else
        result=1
    fi
    
    # Cleanup
    case "$(uname -s)" in
        CYGWIN*|MINGW*|MSYS*)
            rm -rf "C:/temp/mixed" 2>/dev/null || true
            ;;
        *)
            rm -rf "/tmp/mixed" 2>/dev/null || true
            ;;
    esac
    
    if [[ -n "$old_claude_temp" ]]; then
        export CLAUDE_AUTO_TEE_TEMP_DIR="$old_claude_temp"
    else
        unset CLAUDE_AUTO_TEE_TEMP_DIR 2>/dev/null || true
    fi
    
    return $result
}
print_test_result "Mixed slash scenarios" "$?"

test_complex_nested_paths() {
    # Test complex nested paths
    local old_claude_temp="${CLAUDE_AUTO_TEE_TEMP_DIR:-}"
    local test_path="/tmp/very/deep/nested/directory/structure/for/testing/paths"
    
    export CLAUDE_AUTO_TEE_TEMP_DIR="$test_path"
    mkdir -p "$test_path" 2>/dev/null || true
    
    local input='{"tool":{"name":"Bash","input":{"command":"echo nested-path-test | head -1"}},"timeout":null}'
    local result
    
    if test_hook_with_path "$input" "claude-.*\.log"; then
        result=0
    else
        result=1
    fi
    
    # Cleanup
    rm -rf "/tmp/very" 2>/dev/null || true
    if [[ -n "$old_claude_temp" ]]; then
        export CLAUDE_AUTO_TEE_TEMP_DIR="$old_claude_temp"
    else
        unset CLAUDE_AUTO_TEE_TEMP_DIR 2>/dev/null || true
    fi
    
    return $result
}
print_test_result "Complex nested paths" "$?"

# ==========================================
# WSL-Specific Tests
# ==========================================

echo -e "${YELLOW}=== WSL-Specific Tests ===${NC}"

test_wsl_path_conversion() {
    # Only test in WSL environment
    if [[ -z "${WSL_DISTRO_NAME:-}" ]] && ! grep -qi "microsoft\|wsl" /proc/version 2>/dev/null; then
        return 0  # Skip if not WSL
    fi
    
    source "$PATH_UTILS" 2>/dev/null || return 1
    
    # Test WSL path conversion
    local unix_path="/mnt/c/temp"
    local windows_path
    
    if windows_path=$(convert_wsl_path "$unix_path" "windows" 2>/dev/null); then
        if [[ "$windows_path" =~ ^[Cc]: ]]; then
            return 0
        fi
    fi
    return 1
}
print_test_result "WSL path conversion" "$?"

test_wsl_temp_directory_access() {
    # Only test in WSL environment
    if [[ -z "${WSL_DISTRO_NAME:-}" ]] && ! grep -qi "microsoft\|wsl" /proc/version 2>/dev/null; then
        return 0  # Skip if not WSL
    fi
    
    # Test Windows filesystem access in WSL
    if [[ -d "/mnt/c" ]]; then
        local old_tmpdir="${TMPDIR:-}"
        export TMPDIR="/mnt/c/temp/claude-wsl-test"
        
        # Try to create directory
        if mkdir -p "/mnt/c/temp/claude-wsl-test" 2>/dev/null; then
            local input='{"tool":{"name":"Bash","input":{"command":"echo wsl-temp-test | head -1"}},"timeout":null}'
            local result
            
            if test_hook_with_path "$input" "claude-.*\.log"; then
                result=0
            else
                result=1
            fi
            
            # Cleanup
            rm -rf "/mnt/c/temp/claude-wsl-test" 2>/dev/null || true
            if [[ -n "$old_tmpdir" ]]; then
                export TMPDIR="$old_tmpdir"
            else
                unset TMPDIR 2>/dev/null || true
            fi
            
            return $result
        fi
    fi
    
    return 0  # Skip if Windows filesystem not available
}
print_test_result "WSL Windows filesystem temp directory" "$?"

# ==========================================
# UNC Path Tests (Windows)
# ==========================================

echo -e "${YELLOW}=== UNC Path Tests (Windows) ===${NC}"

test_unc_path_handling() {
    if [[ ! "$(uname -s)" =~ ^(CYGWIN|MINGW|MSYS) ]]; then
        return 0  # Skip on non-Windows
    fi
    
    source "$PATH_UTILS" 2>/dev/null || return 1
    
    # Test UNC path handling
    local unc_input="//server/share/path"
    local unc_output
    
    if unc_output=$(handle_unc_path "$unc_input"); then
        if [[ "$unc_output" =~ ^\\\\\\ ]]; then
            return 0
        fi
    fi
    return 1
}
print_test_result "UNC path handling (Windows)" "$?"

# ==========================================
# Edge Cases
# ==========================================

echo -e "${YELLOW}=== Edge Case Tests ===${NC}"

test_empty_path_handling() {
    source "$PATH_UTILS" 2>/dev/null || return 1
    
    # Test empty path normalization
    local result
    result=$(normalize_path "")
    
    if [[ -z "$result" ]]; then
        return 0
    fi
    return 1
}
print_test_result "Empty path handling" "$?"

test_path_security_traversal() {
    source "$PATH_UTILS" 2>/dev/null || return 1
    
    # Test that dangerous paths are rejected
    if ! validate_path_security "/tmp/../../../etc/passwd"; then
        return 0
    fi
    return 1
}
print_test_result "Path traversal security check" "$?"

test_extremely_long_paths() {
    source "$PATH_UTILS" 2>/dev/null || return 1
    
    # Create an extremely long path
    local long_path="/tmp"
    for ((i=1; i<=100; i++)); do
        long_path="${long_path}/very-long-directory-name-component-$i"
    done
    
    # Test that extremely long paths are rejected
    if ! validate_path_security "$long_path"; then
        return 0
    fi
    return 1
}
print_test_result "Extremely long path rejection" "$?"

test_special_characters_in_paths() {
    # Test paths with special characters
    local test_dir="/tmp/claude-test-special-chars-!@#$%^&*()"
    
    # Only test if we can create the directory
    if mkdir -p "$test_dir" 2>/dev/null; then
        local old_tmpdir="${TMPDIR:-}"
        export TMPDIR="$test_dir"
        
        local input='{"tool":{"name":"Bash","input":{"command":"echo special-chars-test | head -1"}},"timeout":null}'
        local result
        
        if test_hook_with_path "$input" "claude-.*\.log"; then
            result=0
        else
            result=1
        fi
        
        # Cleanup
        rm -rf "$test_dir" 2>/dev/null || true
        if [[ -n "$old_tmpdir" ]]; then
            export TMPDIR="$old_tmpdir"
        else
            unset TMPDIR 2>/dev/null || true
        fi
        
        return $result
    else
        return 0  # Skip if can't create directory with special chars
    fi
}
print_test_result "Special characters in paths" "$?"

# ==========================================
# Performance Tests
# ==========================================

echo -e "${YELLOW}=== Performance Tests ===${NC}"

test_path_normalization_performance() {
    source "$PATH_UTILS" 2>/dev/null || return 1
    
    # Test path normalization performance
    local start_time end_time
    start_time=$(date +%s)
    
    # Normalize many paths
    for ((i=1; i<=100; i++)); do
        normalize_path "/tmp/test/path/number/$i//with//double//slashes/" >/dev/null
    done
    
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Should complete within reasonable time (5 seconds)
    if [[ $duration -lt 5 ]]; then
        return 0
    fi
    return 1
}
print_test_result "Path normalization performance" "$?"

# ==========================================
# Summary
# ==========================================

echo ""
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}Path Handling Test Results${NC}"
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}Platform: $(uname -s)${NC}"
echo -e "${BLUE}Tests run: $TESTS_RUN${NC}"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo ""
    echo -e "${GREEN}✅ All path handling tests passed!${NC}"
    echo -e "${GREEN}✅ Path normalization and validation working correctly${NC}"
    exit 0
else
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo ""
    echo -e "${RED}❌ Some path handling tests failed!${NC}"
    echo -e "${RED}❌ Path handling issues detected${NC}"
    exit 1
fi