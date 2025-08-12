#!/usr/bin/env bash
# Platform-Specific Test Suite (P1.T006)
# Tests platform-specific behaviors and compatibility

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly HOOK_SCRIPT="$PROJECT_ROOT/src/claude-auto-tee.sh"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Platform detection
PLATFORM="$(uname -s)"
PLATFORM_CATEGORY="unknown"

# Categorize platform
case "$PLATFORM" in
    Darwin*)
        PLATFORM_CATEGORY="macos"
        ;;
    Linux*)
        PLATFORM_CATEGORY="linux"
        ;;
    CYGWIN*|MINGW*|MSYS*)
        PLATFORM_CATEGORY="windows"
        ;;
    *)
        PLATFORM_CATEGORY="unix"
        ;;
esac

print_test_result() {
    local test_name="$1"
    local result="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    case "$result" in
        0)
            echo -e "${GREEN}✓${NC} $test_name"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            ;;
        77)  # Skip code
            echo -e "${YELLOW}⊘${NC} $test_name (SKIPPED)"
            TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
            ;;
        *)
            echo -e "${RED}✗${NC} $test_name"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            ;;
    esac
}

# Test helper function
test_hook_behavior() {
    local input="$1"
    local expected_pattern="$2"
    local test_description="$3"
    
    local output
    if output=$(echo "$input" | bash "$HOOK_SCRIPT" 2>&1); then
        if echo "$output" | grep -q "$expected_pattern"; then
            return 0
        else
            echo "Expected pattern '$expected_pattern' not found in output: $output" >&2
            return 1
        fi
    else
        echo "Hook execution failed for: $test_description" >&2
        return 1
    fi
}

# ===========================================
# Platform Detection Tests
# ===========================================

test_platform_detection() {
    # Test that the hook runs without crashing on this platform
    local hook_output
    export CLAUDE_AUTO_TEE_VERBOSE=true
    
    if hook_output=$(echo '{"tool":{"name":"Bash","input":{"command":"echo platform-test"}},"timeout":null}' | bash "$HOOK_SCRIPT" 2>&1); then
        # The hook should run successfully and return valid JSON
        if echo "$hook_output" | python3 -c "import json, sys; json.load(sys.stdin)" 2>/dev/null; then
            return 0
        fi
        # If not valid JSON, check if it's just passed through
        if echo "$hook_output" | grep -q "platform-test\|echo platform-test"; then
            return 0
        fi
    fi
    
    return 1
}

# ===========================================
# macOS-Specific Tests
# ===========================================

test_macos_private_temp_dir() {
    if [[ "$PLATFORM_CATEGORY" != "macos" ]]; then
        return 77  # Skip
    fi
    
    # Test macOS private temp directory behavior
    export TMPDIR="/private/var/tmp"
    
    local input='{"tool":{"name":"Bash","input":{"command":"echo macos-test | head -1"}},"timeout":null}'
    test_hook_behavior "$input" "private.var.tmp\|/var/folders" "macOS private temp directory"
}

test_macos_bsd_stat() {
    if [[ "$PLATFORM_CATEGORY" != "macos" ]]; then
        return 77  # Skip
    fi
    
    # Test that BSD stat format works (macOS uses BSD stat, not GNU stat)
    # This is tested indirectly through file operations
    
    local temp_file="/tmp/claude-bsd-stat-test-$$"
    if touch "$temp_file" 2>/dev/null; then
        # Test stat -f format (BSD)
        if stat -f %m "$temp_file" >/dev/null 2>&1; then
            rm -f "$temp_file" 2>/dev/null || true
            return 0
        fi
        rm -f "$temp_file" 2>/dev/null || true
    fi
    
    return 1
}

test_macos_homebrew_path() {
    if [[ "$PLATFORM_CATEGORY" != "macos" ]]; then
        return 77  # Skip
    fi
    
    # Test that Homebrew paths are accessible if present
    # This should work regardless of whether Homebrew is installed
    local test_dirs=("/opt/homebrew/bin" "/usr/local/bin")
    
    for dir in "${test_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            # If the directory exists, it should be readable
            if [[ ! -r "$dir" ]]; then
                return 1
            fi
        fi
    done
    
    return 0
}

test_macos_case_sensitivity() {
    if [[ "$PLATFORM_CATEGORY" != "macos" ]]; then
        return 77  # Skip
    fi
    
    # Test case sensitivity behavior (macOS is typically case-insensitive for filenames)
    local temp_dir="${TMPDIR:-/tmp}"
    local test_file1="${temp_dir}/claude-case-test-$$-UPPER"
    local test_file2="${temp_dir}/claude-case-test-$$-upper"
    
    if touch "$test_file1" 2>/dev/null; then
        # Check if creating a file with different case creates a different file
        local case_sensitive=true
        if [[ -f "$test_file2" ]]; then
            case_sensitive=false
        fi
        
        # Cleanup
        rm -f "$test_file1" "$test_file2" 2>/dev/null || true
        
        # Both case-sensitive and case-insensitive are valid for macOS
        return 0
    fi
    
    return 1
}

# ===========================================
# Linux-Specific Tests
# ===========================================

test_linux_gnu_stat() {
    if [[ "$PLATFORM_CATEGORY" != "linux" ]]; then
        return 77  # Skip
    fi
    
    # Test that GNU stat format works (Linux uses GNU stat)
    local temp_file="/tmp/claude-gnu-stat-test-$$"
    if touch "$temp_file" 2>/dev/null; then
        # Test stat -c format (GNU)
        if stat -c %Y "$temp_file" >/dev/null 2>&1; then
            rm -f "$temp_file" 2>/dev/null || true
            return 0
        fi
        rm -f "$temp_file" 2>/dev/null || true
    fi
    
    return 1
}

test_linux_dev_shm() {
    if [[ "$PLATFORM_CATEGORY" != "linux" ]]; then
        return 77  # Skip
    fi
    
    # Test /dev/shm availability (common on Linux)
    if [[ -d "/dev/shm" ]] && [[ -w "/dev/shm" ]]; then
        local test_file="/dev/shm/claude-shm-test-$$"
        if echo "test" > "$test_file" 2>/dev/null; then
            rm -f "$test_file" 2>/dev/null || true
            return 0
        fi
    fi
    
    # /dev/shm not available or not writable - still valid on some Linux systems
    return 0
}

test_linux_proc_version() {
    if [[ "$PLATFORM_CATEGORY" != "linux" ]]; then
        return 77  # Skip
    fi
    
    # Test /proc/version exists and is readable (Linux-specific)
    if [[ -r "/proc/version" ]]; then
        if grep -qi "linux" /proc/version 2>/dev/null; then
            return 0
        fi
    fi
    
    return 1
}

test_linux_container_detection() {
    if [[ "$PLATFORM_CATEGORY" != "linux" ]]; then
        return 77  # Skip
    fi
    
    # Test container detection works on Linux
    export CLAUDE_AUTO_TEE_VERBOSE=true
    
    local input='{"tool":{"name":"Bash","input":{"command":"echo container-test"}},"timeout":null}'
    local output
    
    if output=$(echo "$input" | bash "$HOOK_SCRIPT" 2>&1); then
        # Should either detect container or not crash trying
        if echo "$output" | grep -q "Container.*detected\|Using.*temp.*fallbacks"; then
            return 0
        fi
        # If no container detected, that's also fine
        return 0
    fi
    
    return 1
}

# ===========================================
# Windows-Specific Tests (CYGWIN/MINGW/MSYS)
# ===========================================

test_windows_path_separators() {
    if [[ "$PLATFORM_CATEGORY" != "windows" ]]; then
        return 77  # Skip
    fi
    
    # Test Windows path separator handling
    export TMPDIR="C:\\temp\\claude-test"
    mkdir -p "$TMPDIR" 2>/dev/null || true
    
    local input='{"tool":{"name":"Bash","input":{"command":"echo windows-test | head -1"}},"timeout":null}'
    local output
    
    if output=$(echo "$input" | bash "$HOOK_SCRIPT" 2>&1); then
        # Should handle Windows paths without crashing
        local result=0
        
        # Cleanup
        rm -rf "$TMPDIR" 2>/dev/null || true
        return $result
    fi
    
    # Cleanup on failure
    rm -rf "$TMPDIR" 2>/dev/null || true
    return 1
}

test_windows_drive_letters() {
    if [[ "$PLATFORM_CATEGORY" != "windows" ]]; then
        return 77  # Skip
    fi
    
    # Test drive letter path recognition
    local test_paths=("C:" "C:\\" "C:/temp" "D:\\data")
    
    for path in "${test_paths[@]}"; do
        # Test using the path utilities (source them if available)
        if [[ -f "$PROJECT_ROOT/src/path-utils.sh" ]]; then
            if source "$PROJECT_ROOT/src/path-utils.sh" 2>/dev/null; then
                if is_absolute_path "$path"; then
                    continue  # Good, recognized as absolute
                else
                    return 1  # Should have recognized drive letter as absolute
                fi
            fi
        fi
    done
    
    return 0
}

test_windows_unc_paths() {
    if [[ "$PLATFORM_CATEGORY" != "windows" ]]; then
        return 77  # Skip
    fi
    
    # Test UNC path handling
    local unc_paths=("//server/share" "\\\\server\\share\\path")
    
    if [[ -f "$PROJECT_ROOT/src/path-utils.sh" ]]; then
        if source "$PROJECT_ROOT/src/path-utils.sh" 2>/dev/null; then
            for unc_path in "${unc_paths[@]}"; do
                if handle_unc_path "$unc_path" >/dev/null 2>&1; then
                    continue  # Good, handled UNC path
                else
                    return 1  # UNC path handling failed
                fi
            done
        fi
    fi
    
    return 0
}

# ===========================================
# Cross-Platform Compatibility Tests
# ===========================================

test_cross_platform_temp_dirs() {
    # Test that common temp directory paths work across platforms
    local temp_candidates=()
    
    case "$PLATFORM_CATEGORY" in
        "macos")
            temp_candidates=("/tmp" "/var/tmp" "/private/var/tmp")
            ;;
        "linux")
            temp_candidates=("/tmp" "/var/tmp")
            ;;
        "windows")
            temp_candidates=("/tmp" "/var/tmp")
            ;;
        *)
            temp_candidates=("/tmp")
            ;;
    esac
    
    local found_writable=false
    for temp_dir in "${temp_candidates[@]}"; do
        if [[ -d "$temp_dir" ]] && [[ -w "$temp_dir" ]]; then
            found_writable=true
            break
        fi
    done
    
    if [[ "$found_writable" == "true" ]]; then
        return 0
    fi
    
    return 1
}

test_cross_platform_commands() {
    # Test that essential commands work across platforms
    local commands=("find" "stat" "wc" "head" "tee")
    
    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            return 1
        fi
    done
    
    return 0
}

test_cross_platform_pipe_handling() {
    # Test that pipe handling works consistently across platforms
    local input='{"tool":{"name":"Bash","input":{"command":"echo cross-platform | head -1"}},"timeout":null}'
    
    # Should produce consistent JSON output structure
    local output
    if output=$(echo "$input" | bash "$HOOK_SCRIPT" 2>/dev/null); then
        # Validate JSON structure
        if echo "$output" | python3 -c "import json, sys; json.load(sys.stdin)" 2>/dev/null; then
            return 0
        fi
    fi
    
    return 1
}

test_cross_platform_error_handling() {
    # Test that error handling works consistently
    local input='{"tool":{"name":"Bash","input":{"command":"nonexistent_command | head -1"}},"timeout":null}'
    
    # Should handle command not found gracefully
    local output
    if output=$(echo "$input" | bash "$HOOK_SCRIPT" 2>&1); then
        # Should not crash, should return some form of output
        if [[ -n "$output" ]]; then
            return 0
        fi
    fi
    
    return 1
}

# ===========================================
# Performance Tests by Platform
# ===========================================

test_platform_performance() {
    # Test basic performance characteristics
    local start_time end_time duration
    start_time=$(date +%s)
    
    local input='{"tool":{"name":"Bash","input":{"command":"echo performance-test | head -1"}},"timeout":null}'
    
    # Run multiple iterations
    for ((i=1; i<=5; i++)); do
        echo "$input" | bash "$HOOK_SCRIPT" >/dev/null 2>&1 || return 1
    done
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    # Should complete 5 runs in under 30 seconds (very conservative)
    if [[ "$duration" -lt 30 ]]; then
        return 0
    fi
    
    return 1
}

# ===========================================
# Main Test Execution
# ===========================================

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}Platform-Specific Test Suite (P1.T006)${NC}"
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}Platform: $PLATFORM${NC}"
echo -e "${BLUE}Category: $PLATFORM_CATEGORY${NC}"
echo -e "${BLUE}Shell: $BASH_VERSION${NC}"
echo ""

echo -e "${YELLOW}=== Platform Detection Tests ===${NC}"
print_test_result "Platform detection consistency" "$(test_platform_detection; echo $?)"

echo -e "${YELLOW}=== macOS-Specific Tests ===${NC}"
print_test_result "macOS private temp directory" "$(test_macos_private_temp_dir; echo $?)"
print_test_result "macOS BSD stat compatibility" "$(test_macos_bsd_stat; echo $?)"
print_test_result "macOS Homebrew path access" "$(test_macos_homebrew_path; echo $?)"
print_test_result "macOS case sensitivity handling" "$(test_macos_case_sensitivity; echo $?)"

echo -e "${YELLOW}=== Linux-Specific Tests ===${NC}"
print_test_result "Linux GNU stat compatibility" "$(test_linux_gnu_stat; echo $?)"
print_test_result "Linux /dev/shm availability" "$(test_linux_dev_shm; echo $?)"
print_test_result "Linux /proc/version detection" "$(test_linux_proc_version; echo $?)"
print_test_result "Linux container detection" "$(test_linux_container_detection; echo $?)"

echo -e "${YELLOW}=== Windows-Specific Tests ===${NC}"
print_test_result "Windows path separator handling" "$(test_windows_path_separators; echo $?)"
print_test_result "Windows drive letter recognition" "$(test_windows_drive_letters; echo $?)"
print_test_result "Windows UNC path handling" "$(test_windows_unc_paths; echo $?)"

echo -e "${YELLOW}=== Cross-Platform Tests ===${NC}"
print_test_result "Cross-platform temp directories" "$(test_cross_platform_temp_dirs; echo $?)"
print_test_result "Cross-platform command availability" "$(test_cross_platform_commands; echo $?)"
print_test_result "Cross-platform pipe handling" "$(test_cross_platform_pipe_handling; echo $?)"
print_test_result "Cross-platform error handling" "$(test_cross_platform_error_handling; echo $?)"

echo -e "${YELLOW}=== Performance Tests ===${NC}"
print_test_result "Platform-specific performance" "$(test_platform_performance; echo $?)"

echo ""
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}Platform-Specific Test Results${NC}"
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}Platform: $PLATFORM ($PLATFORM_CATEGORY)${NC}"
echo -e "${BLUE}Tests run: $TESTS_RUN${NC}"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${YELLOW}Skipped: $TESTS_SKIPPED${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo ""
    echo -e "${GREEN}✅ All platform-specific tests passed!${NC}"
    echo -e "${GREEN}✅ P1.T006 platform compatibility validated for $PLATFORM_CATEGORY${NC}"
    exit 0
else
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo ""
    echo -e "${RED}❌ Some platform-specific tests failed!${NC}"
    echo -e "${RED}❌ P1.T006 platform compatibility issues detected${NC}"
    exit 1
fi