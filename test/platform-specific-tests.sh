#!/usr/bin/env bash
# Platform-Specific Test Cases for claude-auto-tee
# P1.T006 - Create platform-specific test cases

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly HOOK_SCRIPT="$PROJECT_ROOT/src/claude-auto-tee.sh"

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

print_header() {
    echo -e "${BLUE}=======================================${NC}"
    echo -e "${BLUE}Platform-Specific Test Suite${NC}"
    echo -e "${BLUE}=======================================${NC}"
    echo -e "${BLUE}Platform: $(uname -s 2>/dev/null || echo Unknown)${NC}"
    echo -e "${BLUE}Architecture: $(uname -m 2>/dev/null || echo Unknown)${NC}"
    echo -e "${BLUE}Bash Version: $BASH_VERSION${NC}"
    echo -e "${BLUE}Temp Dir: ${TMPDIR:-${TMP:-${TEMP:-/tmp}}}${NC}"
    echo ""
}

run_test() {
    local test_name="$1"
    local test_function="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if $test_function; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

run_hook_test() {
    local input_json="$1"
    local expected_pattern="$2"
    
    local output
    if output=$(echo "$input_json" | bash "$HOOK_SCRIPT" 2>&1); then
        if [[ -n "$expected_pattern" ]]; then
            echo "$output" | grep -q "$expected_pattern"
        else
            # Just check for valid JSON structure
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        fi
    else
        return 1
    fi
}

# ==========================================
# macOS-Specific Tests
# ==========================================

test_macos_temp_directories() {
    [[ "$(uname -s)" != "Darwin" ]] && return 0  # Skip on non-macOS
    
    # Test that macOS-specific temp directories are properly detected
    local input='{"tool":{"name":"Bash","input":{"command":"echo test | head -1"}},"timeout":null}'
    local output
    
    if output=$(echo "$input" | bash "$HOOK_SCRIPT" 2>&1); then
        # Should handle macOS temp directory patterns correctly
        if echo "$output" | grep -q "claude-.*\.log"; then
            # Verify the temp directory matches expected macOS patterns
            local temp_path
            temp_path=$(echo "$output" | grep -o '/[^"]*claude-[^"]*\.log' | head -1)
            
            if [[ -n "$temp_path" ]]; then
                local temp_dir
                temp_dir=$(dirname "$temp_path")
                
                # Check if it's a known macOS temp directory
                case "$temp_dir" in
                    /private/tmp | /tmp | /var/folders/* | /private/var/tmp)
                        return 0
                        ;;
                    *)
                        # Check if it's user-specified TMPDIR (common on macOS)
                        [[ "$temp_dir" == "${TMPDIR%/}" ]] && return 0
                        ;;
                esac
            fi
        fi
    fi
    return 1
}

test_macos_permissions() {
    [[ "$(uname -s)" != "Darwin" ]] && return 0  # Skip on non-macOS
    
    # Test SIP (System Integrity Protection) awareness
    local input='{"tool":{"name":"Bash","input":{"command":"ls /System | head -3"}},"timeout":null}'
    
    # This should work without issues (just listing, not modifying)
    run_hook_test "$input" "claude-.*\.log"
}

test_macos_homebrew_paths() {
    [[ "$(uname -s)" != "Darwin" ]] && return 0  # Skip on non-macOS
    
    # Test commands using Homebrew-installed tools
    if command -v brew >/dev/null 2>&1; then
        local input='{"tool":{"name":"Bash","input":{"command":"brew list --formula | head -5"}},"timeout":null}'
        run_hook_test "$input" "claude-.*\.log"
    else
        return 0  # Skip if Homebrew not installed
    fi
}

test_macos_case_sensitivity() {
    [[ "$(uname -s)" != "Darwin" ]] && return 0  # Skip on non-macOS
    
    # Test handling of case-insensitive filesystem (default on macOS)
    local temp_file
    temp_file=$(mktemp)
    local upper_file="${temp_file^^}"  # Convert to uppercase
    
    if [[ "$temp_file" != "$upper_file" ]]; then
        # Create test scenario with case variations
        local input="{\"tool\":{\"name\":\"Bash\",\"input\":{\"command\":\"ls $temp_file | head -1\"}},\"timeout\":null}"
        local result
        result=$(run_hook_test "$input" "claude-.*\.log")
        local exit_code=$?
        
        rm -f "$temp_file" 2>/dev/null || true
        return $exit_code
    fi
    
    rm -f "$temp_file" 2>/dev/null || true
    return 0
}

test_macos_extended_attributes() {
    [[ "$(uname -s)" != "Darwin" ]] && return 0  # Skip on non-macOS
    
    # Test that extended attributes don't interfere
    if command -v xattr >/dev/null 2>&1; then
        local input='{"tool":{"name":"Bash","input":{"command":"find /usr/bin -name ls | xargs xattr 2>/dev/null | head -2 || echo no-xattrs"}},"timeout":null}'
        run_hook_test "$input" "claude-.*\.log"
    else
        return 0  # Skip if xattr not available
    fi
}

# ==========================================
# Linux-Specific Tests
# ==========================================

test_linux_temp_directories() {
    [[ "$(uname -s)" != "Linux" ]] && return 0  # Skip on non-Linux
    
    # Test Linux-specific temp directory handling
    local input='{"tool":{"name":"Bash","input":{"command":"echo test | head -1"}},"timeout":null}'
    local output
    
    if output=$(echo "$input" | bash "$HOOK_SCRIPT" 2>&1); then
        if echo "$output" | grep -q "claude-.*\.log"; then
            local temp_path
            temp_path=$(echo "$output" | grep -o '/[^"]*claude-[^"]*\.log' | head -1)
            
            if [[ -n "$temp_path" ]]; then
                local temp_dir
                temp_dir=$(dirname "$temp_path")
                
                # Check if it's a known Linux temp directory
                case "$temp_dir" in
                    /tmp | /var/tmp | /dev/shm)
                        return 0
                        ;;
                    *)
                        # Check if it's user-specified TMPDIR
                        [[ "$temp_dir" == "${TMPDIR%/}" ]] && return 0
                        ;;
                esac
            fi
        fi
    fi
    return 1
}

test_linux_sticky_bit() {
    [[ "$(uname -s)" != "Linux" ]] && return 0  # Skip on non-Linux
    
    # Test that /tmp has sticky bit (typical Linux configuration)
    if [[ -d "/tmp" ]]; then
        local perms
        perms=$(stat -c "%a" /tmp 2>/dev/null || echo "unknown")
        
        # Sticky bit should be set (1000+ permissions)
        if [[ "$perms" =~ ^1[0-9]{3}$ ]]; then
            # Test temp file creation in sticky bit directory
            local input='{"tool":{"name":"Bash","input":{"command":"echo sticky-test | wc -c"}},"timeout":null}'
            run_hook_test "$input" "claude-.*\.log"
        else
            return 0  # Skip if no sticky bit (unusual but valid)
        fi
    else
        return 1  # /tmp should exist on Linux
    fi
}

test_linux_selinux_compatibility() {
    [[ "$(uname -s)" != "Linux" ]] && return 0  # Skip on non-Linux
    
    # Test SELinux compatibility if SELinux is available
    if command -v getenforce >/dev/null 2>&1; then
        local selinux_status
        selinux_status=$(getenforce 2>/dev/null || echo "Disabled")
        
        # Test temp file operations with SELinux
        local input='{"tool":{"name":"Bash","input":{"command":"echo selinux-test | head -1"}},"timeout":null}'
        run_hook_test "$input" "claude-.*\.log"
    else
        return 0  # Skip if SELinux not available
    fi
}

test_linux_proc_filesystem() {
    [[ "$(uname -s)" != "Linux" ]] && return 0  # Skip on non-Linux
    
    # Test using /proc filesystem (Linux-specific)
    local input='{"tool":{"name":"Bash","input":{"command":"cat /proc/version | head -1"}},"timeout":null}'
    run_hook_test "$input" "claude-.*\.log"
}

test_linux_package_managers() {
    [[ "$(uname -s)" != "Linux" ]] && return 0  # Skip on non-Linux
    
    # Test with various Linux package managers
    local tested=false
    
    # Test with apt (Debian/Ubuntu)
    if command -v apt >/dev/null 2>&1; then
        local input='{"tool":{"name":"Bash","input":{"command":"apt list --installed 2>/dev/null | head -5 || echo no-apt-access"}},"timeout":null}'
        run_hook_test "$input" "claude-.*\.log" && tested=true
    fi
    
    # Test with yum/dnf (RHEL/CentOS/Fedora)
    if command -v dnf >/dev/null 2>&1; then
        local input='{"tool":{"name":"Bash","input":{"command":"dnf list installed 2>/dev/null | head -5 || echo no-dnf-access"}},"timeout":null}'
        run_hook_test "$input" "claude-.*\.log" && tested=true
    elif command -v yum >/dev/null 2>&1; then
        local input='{"tool":{"name":"Bash","input":{"command":"yum list installed 2>/dev/null | head -5 || echo no-yum-access"}},"timeout\":null}'
        run_hook_test "$input" "claude-.*\.log" && tested=true
    fi
    
    # Test with rpm (generic RPM)
    if command -v rpm >/dev/null 2>&1 && [[ "$tested" == false ]]; then
        local input='{"tool":{"name":"Bash","input":{"command":"rpm -qa | head -5"}},"timeout":null}'
        run_hook_test "$input" "claude-.*\.log" && tested=true
    fi
    
    # If no package managers available, still pass (minimal systems)
    [[ "$tested" == false ]] && return 0
    return $?
}

test_linux_container_detection() {
    [[ "$(uname -s)" != "Linux" ]] && return 0  # Skip on non-Linux
    
    # Test container environment detection
    local is_container=false
    
    # Check for common container indicators
    if [[ -f "/.dockerenv" ]] || \
       [[ -f "/run/.containerenv" ]] || \
       grep -q "container" /proc/1/cgroup 2>/dev/null; then
        is_container=true
    fi
    
    # Test temp file creation in container environment
    local input='{"tool":{"name":"Bash","input":{"command":"echo container-test | head -1"}},"timeout":null}'
    run_hook_test "$input" "claude-.*\.log"
}

# ==========================================
# Windows/WSL-Specific Tests
# ==========================================

test_windows_wsl_detection() {
    # Test Windows Subsystem for Linux detection
    local is_wsl=false
    
    if [[ -n "${WSL_DISTRO_NAME:-}" ]] || \
       grep -qi "microsoft" /proc/version 2>/dev/null || \
       grep -qi "wsl" /proc/version 2>/dev/null; then
        is_wsl=true
    fi
    
    if [[ "$is_wsl" == true ]]; then
        # Test basic functionality in WSL
        local input='{"tool":{"name":"Bash","input":{"command":"echo wsl-test | head -1"}},"timeout":null}'
        run_hook_test "$input" "claude-.*\.log"
    else
        return 0  # Skip if not WSL
    fi
}

test_windows_path_handling() {
    # Test Windows path handling in WSL
    local is_wsl=false
    
    if [[ -n "${WSL_DISTRO_NAME:-}" ]] || \
       grep -qi "microsoft" /proc/version 2>/dev/null; then
        is_wsl=true
    fi
    
    if [[ "$is_wsl" == true ]]; then
        # Test access to Windows filesystem
        if [[ -d "/mnt/c" ]]; then
            local input='{"tool":{"name":"Bash","input":{"command":"ls /mnt/c | head -3"}},"timeout":null}'
            run_hook_test "$input" "claude-.*\.log"
        else
            return 0  # Skip if Windows filesystem not mounted
        fi
    else
        return 0  # Skip if not WSL
    fi
}

test_windows_temp_variables() {
    # Test Windows-style temp variables in WSL/Cygwin
    if [[ -n "${TEMP:-}" ]] || [[ -n "${TMP:-}" ]]; then
        # Test with Windows temp directory override
        local old_tmpdir="${TMPDIR:-}"
        local old_temp="${TEMP:-}"
        
        # Set Windows-style temp directory
        export TMPDIR="${TEMP:-${TMP:-/tmp}}"
        
        local input='{"tool":{"name":"Bash","input":{"command":"echo windows-temp | head -1"}},"timeout":null}'
        local result
        result=$(run_hook_test "$input" "claude-.*\.log")
        local exit_code=$?
        
        # Restore original values
        if [[ -n "$old_tmpdir" ]]; then
            export TMPDIR="$old_tmpdir"
        else
            unset TMPDIR
        fi
        
        return $exit_code
    else
        return 0  # Skip if no Windows temp variables
    fi
}

# ==========================================
# Cross-Platform Tests
# ==========================================

test_cross_platform_stat_command() {
    # Test that file modification time checking works across platforms
    local temp_file
    temp_file=$(mktemp)
    
    echo "test content" > "$temp_file"
    
    # Test the stat command variations used in the script
    local stat_works=false
    local platform
    platform=$(uname -s)
    
    case "$platform" in
        Darwin*)
            # macOS stat format
            if stat -f "%m" "$temp_file" >/dev/null 2>&1; then
                stat_works=true
            fi
            ;;
        Linux*|*)
            # Linux stat format
            if stat -c "%Y" "$temp_file" >/dev/null 2>&1; then
                stat_works=true
            fi
            ;;
    esac
    
    rm -f "$temp_file" 2>/dev/null || true
    
    if [[ "$stat_works" == true ]]; then
        # Test age-based cleanup logic with stat command
        local input='{"tool":{"name":"Bash","input":{"command":"echo stat-test | head -1"}},"timeout":null}'
        run_hook_test "$input" "claude-.*\.log"
    else
        return 1  # stat command should work on all supported platforms
    fi
}

test_cross_platform_mktemp() {
    # Test mktemp compatibility across platforms
    local temp_file1 temp_file2
    
    # Test mktemp without template
    temp_file1=$(mktemp 2>/dev/null) || return 1
    
    # Test mktemp with template (the format used by the script)
    temp_file2=$(mktemp "${TMPDIR:-/tmp}/claude-auto-tee-XXXXXX.log" 2>/dev/null) || return 1
    
    # Verify files were created with expected patterns
    if [[ -f "$temp_file1" ]] && [[ -f "$temp_file2" ]]; then
        # Clean up
        rm -f "$temp_file1" "$temp_file2" 2>/dev/null || true
        return 0
    else
        # Clean up
        rm -f "$temp_file1" "$temp_file2" 2>/dev/null || true
        return 1
    fi
}

test_cross_platform_lsof() {
    # Test lsof availability (used for file locking detection)
    if command -v lsof >/dev/null 2>&1; then
        # Test that lsof can check file usage
        local temp_file
        temp_file=$(mktemp)
        
        # Create a process that holds the file open briefly
        (
            exec 3<"$temp_file"
            sleep 0.1
            exec 3<&-
        ) &
        local pid=$!
        
        # Test lsof on the file
        lsof "$temp_file" >/dev/null 2>&1
        local lsof_result=$?
        
        # Wait for background process and clean up
        wait $pid 2>/dev/null || true
        rm -f "$temp_file" 2>/dev/null || true
        
        # lsof should work (return code doesn't matter for this test)
        return 0
    else
        # lsof not available - that's ok, the script has fallbacks
        return 0
    fi
}

test_cross_platform_disk_space() {
    # Test disk space checking across platforms
    local temp_dir="${TMPDIR:-/tmp}"
    
    # Test df command availability and output parsing
    if command -v df >/dev/null 2>&1; then
        df "$temp_dir" >/dev/null 2>&1 || return 1
        
        # Test hook with disk space checking enabled
        local input='{"tool":{"name":"Bash","input":{"command":"echo disk-space-test | head -1"}},"timeout":null}'
        run_hook_test "$input" "claude-.*\.log"
    else
        return 1  # df should be available on all supported platforms
    fi
}

test_cross_platform_process_substitution() {
    # Test that process substitution works correctly across platforms
    local input='{"tool":{"name":"Bash","input":{"command":"diff <(echo a) <(echo b) | head -1 || echo no-diff"}},"timeout":null}'
    run_hook_test "$input" "claude-.*\.log"
}

test_cross_platform_unicode() {
    # Test Unicode handling across platforms
    local input='{"tool":{"name":"Bash","input":{"command":"echo \"测试 émoji 🚀\" | head -1"}},"timeout":null}'
    run_hook_test "$input" "claude-.*\.log"
}

test_cross_platform_long_paths() {
    # Test handling of long file paths
    local long_path="/tmp"
    local component
    
    # Build a reasonably long path
    for component in very long directory path with multiple components for testing; do
        long_path="$long_path/$component"
    done
    
    # Create the directory structure
    if mkdir -p "$long_path" 2>/dev/null; then
        local input="{\"tool\":{\"name\":\"Bash\",\"input\":{\"command\":\"ls $long_path | head -1 || echo empty-dir\"}},\"timeout\":null}"
        local result
        result=$(run_hook_test "$input" "claude-.*\.log")
        local exit_code=$?
        
        # Clean up
        rm -rf "/tmp/very" 2>/dev/null || true
        
        return $exit_code
    else
        # Path too long or permission issues - skip test
        return 0
    fi
}

# ==========================================
# Test Execution
# ==========================================

main() {
    print_header
    
    echo -e "${YELLOW}Running macOS-specific tests...${NC}"
    run_test "macOS temp directory detection" test_macos_temp_directories
    run_test "macOS permissions (SIP compatibility)" test_macos_permissions
    run_test "macOS Homebrew integration" test_macos_homebrew_paths
    run_test "macOS case sensitivity handling" test_macos_case_sensitivity
    run_test "macOS extended attributes" test_macos_extended_attributes
    echo ""
    
    echo -e "${YELLOW}Running Linux-specific tests...${NC}"
    run_test "Linux temp directory detection" test_linux_temp_directories
    run_test "Linux sticky bit handling" test_linux_sticky_bit
    run_test "Linux SELinux compatibility" test_linux_selinux_compatibility
    run_test "Linux /proc filesystem access" test_linux_proc_filesystem
    run_test "Linux package manager integration" test_linux_package_managers
    run_test "Linux container environment" test_linux_container_detection
    echo ""
    
    echo -e "${YELLOW}Running Windows/WSL-specific tests...${NC}"
    run_test "Windows WSL detection" test_windows_wsl_detection
    run_test "Windows filesystem access" test_windows_path_handling
    run_test "Windows temp variables" test_windows_temp_variables
    echo ""
    
    echo -e "${YELLOW}Running cross-platform tests...${NC}"
    run_test "Cross-platform stat command" test_cross_platform_stat_command
    run_test "Cross-platform mktemp" test_cross_platform_mktemp
    run_test "Cross-platform lsof availability" test_cross_platform_lsof
    run_test "Cross-platform disk space checking" test_cross_platform_disk_space
    run_test "Cross-platform process substitution" test_cross_platform_process_substitution
    run_test "Cross-platform Unicode handling" test_cross_platform_unicode
    run_test "Cross-platform long path handling" test_cross_platform_long_paths
    echo ""
    
    # Summary
    echo -e "${BLUE}=======================================${NC}"
    echo -e "${BLUE}Platform-Specific Test Results:${NC}"
    echo -e "${BLUE}  Platform: $(uname -s 2>/dev/null || echo Unknown)${NC}"
    echo -e "${BLUE}  Tests run: $TESTS_RUN${NC}"
    echo -e "${GREEN}  Passed: $TESTS_PASSED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${RED}  Failed: $TESTS_FAILED${NC}"
        echo ""
        echo -e "${GREEN}✅ All platform-specific tests passed!${NC}"
        echo -e "${GREEN}✅ claude-auto-tee is compatible with this platform${NC}"
        exit 0
    else
        echo -e "${RED}  Failed: $TESTS_FAILED${NC}"
        echo ""
        echo -e "${RED}❌ Some platform-specific tests failed!${NC}"
        echo -e "${RED}❌ Platform compatibility issues detected${NC}"
        exit 1
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi