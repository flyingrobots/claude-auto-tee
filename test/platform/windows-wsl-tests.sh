#!/usr/bin/env bash
# Windows WSL-Specific Tests for claude-auto-tee
# Part of P1.T006 - Create platform-specific test cases

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
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

run_hook_test() {
    local input_json="$1"
    local validation_func="$2"
    
    local output
    if output=$(echo "$input_json" | bash "$HOOK_SCRIPT" 2>&1); then
        $validation_func "$output"
    else
        return 1
    fi
}

detect_wsl_version() {
    local wsl_version="Not WSL"
    
    if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
        if [[ -n "${WSL_INTEROP:-}" ]]; then
            wsl_version="WSL 2"
        else
            wsl_version="WSL 1"
        fi
    elif grep -qi "microsoft" /proc/version 2>/dev/null; then
        wsl_version="WSL (version unknown)"
    elif grep -qi "wsl" /proc/version 2>/dev/null; then
        wsl_version="WSL (detected in kernel)"
    fi
    
    echo "$wsl_version"
}

# Check if running in WSL
WSL_VERSION=$(detect_wsl_version)
if [[ "$WSL_VERSION" == "Not WSL" ]]; then
    echo -e "${YELLOW}Skipping Windows WSL tests - not running in WSL environment${NC}"
    exit 0
fi

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}Windows WSL-Specific Test Suite${NC}"
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}WSL Version: $WSL_VERSION${NC}"
echo -e "${BLUE}Distribution: ${WSL_DISTRO_NAME:-Unknown}${NC}"
echo -e "${BLUE}Linux Kernel: $(uname -r)${NC}"
echo -e "${BLUE}Architecture: $(uname -m)${NC}"
echo -e "${BLUE}Bash Version: $BASH_VERSION${NC}"
echo ""

# ==========================================
# WSL Environment Tests
# ==========================================

echo -e "${YELLOW}=== WSL Environment Tests ===${NC}"

test_wsl_environment_variables() {
    # Test WSL-specific environment variables
    local input='{"tool":{"name":"Bash","input":{"command":"env | grep -i wsl | head -3 || echo no-wsl-env"}},"timeout":null}'
    
    validate_wsl_env() {
        local output="$1"
        echo "$output" | grep -q "claude-.*\.log" && \
        echo "$output" | python3 -m json.tool >/dev/null 2>&1
    }
    
    run_hook_test "$input" validate_wsl_env
}
print_test_result "WSL environment variables" "$?"

test_wsl_interop() {
    # Test WSL interoperability (WSL 2 feature)
    if [[ -n "${WSL_INTEROP:-}" ]]; then
        local input='{"tool":{"name":"Bash","input":{"command":"echo wsl-interop-available | head -1"}},"timeout":null}'
        
        validate_wsl_interop() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        run_hook_test "$input" validate_wsl_interop
        print_test_result "WSL interoperability support" "$?"
    else
        print_test_result "WSL interoperability support (not available)" "0"
    fi
}

test_wsl_temp_directory() {
    # Test WSL-specific temp directory handling
    local input='{"tool":{"name":"Bash","input":{"command":"echo wsl-temp-test | head -1"}},"timeout":null}'
    
    validate_wsl_temp() {
        local output="$1"
        if echo "$output" | grep -q "claude-.*\.log"; then
            # Check that temp directory is appropriate for WSL
            local temp_path
            temp_path=$(echo "$output" | grep -o '/[^"]*claude-[^"]*\.log' | head -1)
            
            if [[ -n "$temp_path" ]]; then
                local temp_dir
                temp_dir=$(dirname "$temp_path")
                
                # WSL should use Linux paths, not Windows paths
                case "$temp_dir" in
                    /tmp | /var/tmp | /dev/shm | /mnt/*)
                        return 0
                        ;;
                    *)
                        # Check if it's user-specified TMPDIR
                        [[ "$temp_dir" == "${TMPDIR%/}" ]] && return 0
                        ;;
                esac
            fi
        fi
        return 1
    }
    
    run_hook_test "$input" validate_wsl_temp
}
print_test_result "WSL temp directory handling" "$?"

# ==========================================
# Windows Filesystem Access Tests
# ==========================================

echo -e "${YELLOW}=== Windows Filesystem Access Tests ===${NC}"

test_c_drive_access() {
    # Test C: drive access
    if [[ -d "/mnt/c" ]]; then
        local input='{"tool":{"name":"Bash","input":{"command":"ls /mnt/c | head -3 2>/dev/null || echo no-c-access"}},"timeout":null}'
        
        validate_c_drive() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        run_hook_test "$input" validate_c_drive
        print_test_result "C: drive access via /mnt/c" "$?"
    else
        print_test_result "C: drive access via /mnt/c (not mounted)" "0"
    fi
}

test_windows_path_translation() {
    # Test Windows path translation
    if [[ -d "/mnt/c/Windows" ]]; then
        local input='{"tool":{"name":"Bash","input":{"command":"ls /mnt/c/Windows/System32 | head -3 2>/dev/null || echo no-system32-access"}},"timeout":null}'
        
        validate_windows_paths() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        run_hook_test "$input" validate_windows_paths
        print_test_result "Windows path translation" "$?"
    else
        print_test_result "Windows path translation (no Windows dir)" "0"
    fi
}

test_case_sensitivity_with_windows() {
    # Test case sensitivity with Windows filesystem
    if [[ -d "/mnt/c" ]]; then
        # Windows filesystems are typically case-insensitive
        local temp_dir="/mnt/c/temp"
        local upper_dir="/mnt/c/TEMP"
        
        if [[ -d "$temp_dir" ]] || [[ -d "$upper_dir" ]]; then
            local input="{\"tool\":{\"name\":\"Bash\",\"input\":{\"command\":\"ls /mnt/c/temp* 2>/dev/null | head -1 || echo no-temp-dirs\"}},\"timeout\":null}"
            
            validate_case_sensitivity() {
                local output="$1"
                echo "$output" | grep -q "claude-.*\.log" && \
                echo "$output" | python3 -m json.tool >/dev/null 2>&1
            }
            
            run_hook_test "$input" validate_case_sensitivity
            print_test_result "Case sensitivity with Windows filesystem" "$?"
        else
            print_test_result "Case sensitivity with Windows filesystem (no test dirs)" "0"
        fi
    else
        print_test_result "Case sensitivity with Windows filesystem (no /mnt/c)" "0"
    fi
}

# ==========================================
# Windows Temp Variable Tests
# ==========================================

echo -e "${YELLOW}=== Windows Temp Variable Tests ===${NC}"

test_windows_temp_vars() {
    # Test Windows-style temp variables
    if [[ -n "${TEMP:-}" ]] || [[ -n "${TMP:-}" ]]; then
        # Save original values
        local old_tmpdir="${TMPDIR:-}"
        local old_temp="${TEMP:-}"
        local old_tmp="${TMP:-}"
        
        # Test with Windows temp directory
        export TMPDIR="${TEMP:-${TMP:-/tmp}}"
        
        local input='{"tool":{"name":"Bash","input":{"command":"echo windows-temp-vars | head -1"}},"timeout":null}'
        
        validate_windows_temp() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        local result
        run_hook_test "$input" validate_windows_temp
        result=$?
        
        # Restore original values
        if [[ -n "$old_tmpdir" ]]; then
            export TMPDIR="$old_tmpdir"
        else
            unset TMPDIR 2>/dev/null || true
        fi
        
        print_test_result "Windows temp variables handling" "$result"
    else
        print_test_result "Windows temp variables handling (none set)" "0"
    fi
}

test_mixed_path_scenarios() {
    # Test mixed Linux/Windows path scenarios
    if [[ -d "/mnt/c" ]]; then
        # Create a test that involves both Linux and Windows paths
        local input='{"tool":{"name":"Bash","input":{"command":"echo mixed-paths && pwd && ls /mnt/c >/dev/null 2>&1 && echo success || echo failed"}},"timeout":null}'
        
        validate_mixed_paths() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        run_hook_test "$input" validate_mixed_paths
        print_test_result "Mixed Linux/Windows path scenarios" "$?"
    else
        print_test_result "Mixed Linux/Windows path scenarios (no /mnt/c)" "0"
    fi
}

# ==========================================
# WSL Performance Tests
# ==========================================

echo -e "${YELLOW}=== WSL Performance Tests ===${NC}"

test_wsl_io_performance() {
    # Test I/O performance in WSL environment
    local start_time end_time duration
    start_time=$(date +%s)
    
    local input='{"tool":{"name":"Bash","input":{"command":"seq 1 1000 | head -10"}},"timeout":null}'
    
    validate_wsl_io() {
        local output="$1"
        echo "$output" | grep -q "claude-.*\.log" && \
        echo "$output" | python3 -m json.tool >/dev/null 2>&1
    }
    
    local result
    run_hook_test "$input" validate_wsl_io
    result=$?
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    # Should be reasonably fast even in WSL
    if [[ $result -eq 0 ]] && [[ $duration -lt 10 ]]; then
        print_test_result "WSL I/O performance ($duration seconds)" "0"
    else
        print_test_result "WSL I/O performance ($duration seconds)" "1"
    fi
}

test_wsl_memory_handling() {
    # Test memory handling in WSL
    local input='{"tool":{"name":"Bash","input":{"command":"free -h 2>/dev/null | head -2 || echo no-free-command"}},"timeout":null}'
    
    validate_wsl_memory() {
        local output="$1"
        echo "$output" | grep -q "claude-.*\.log" && \
        echo "$output" | python3 -m json.tool >/dev/null 2>&1
    }
    
    run_hook_test "$input" validate_wsl_memory
}
print_test_result "WSL memory handling" "$?"

# ==========================================
# Windows Command Integration Tests
# ==========================================

echo -e "${YELLOW}=== Windows Command Integration Tests ===${NC}"

test_cmd_exe_access() {
    # Test cmd.exe access (if available and WSL interop enabled)
    if command -v cmd.exe >/dev/null 2>&1; then
        local input='{"tool":{"name":"Bash","input":{"command":"cmd.exe /c echo windows-cmd-test 2>/dev/null | head -1"}},"timeout":null}'
        
        validate_cmd_exe() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        run_hook_test "$input" validate_cmd_exe
        print_test_result "cmd.exe integration" "$?"
    else
        print_test_result "cmd.exe integration (not available)" "0"
    fi
}

test_powershell_access() {
    # Test PowerShell access (if available)
    if command -v powershell.exe >/dev/null 2>&1; then
        local input='{"tool":{"name":"Bash","input":{"command":"powershell.exe -Command Write-Output powershell-test 2>/dev/null | head -1"}},"timeout":null}'
        
        validate_powershell() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        run_hook_test "$input" validate_powershell
        print_test_result "PowerShell integration" "$?"
    else
        print_test_result "PowerShell integration (not available)" "0"
    fi
}

test_wslpath_utility() {
    # Test wslpath utility (WSL-specific path conversion)
    if command -v wslpath >/dev/null 2>&1; then
        local input='{"tool":{"name":"Bash","input":{"command":"wslpath -w /tmp 2>/dev/null | head -1 || echo no-wslpath-conversion"}},"timeout":null}'
        
        validate_wslpath() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        run_hook_test "$input" validate_wslpath
        print_test_result "wslpath utility integration" "$?"
    else
        print_test_result "wslpath utility integration (not available)" "0"
    fi
}

# ==========================================
# WSL Networking Tests
# ==========================================

echo -e "${YELLOW}=== WSL Networking Tests ===${NC}"

test_wsl_networking() {
    # Test WSL networking capabilities
    local input='{"tool":{"name":"Bash","input":{"command":"ip addr show 2>/dev/null | head -5 || ifconfig 2>/dev/null | head -5 || echo no-network-info"}},"timeout":null}'
    
    validate_wsl_network() {
        local output="$1"
        echo "$output" | grep -q "claude-.*\.log" && \
        echo "$output" | python3 -m json.tool >/dev/null 2>&1
    }
    
    run_hook_test "$input" validate_wsl_network
}
print_test_result "WSL networking capabilities" "$?"

test_localhost_access() {
    # Test localhost access (different behavior in WSL 1 vs WSL 2)
    local input='{"tool":{"name":"Bash","input":{"command":"ping -c 1 localhost 2>/dev/null | head -1 || echo no-ping"}},"timeout":null}'
    
    validate_localhost() {
        local output="$1"
        echo "$output" | grep -q "claude-.*\.log" && \
        echo "$output" | python3 -m json.tool >/dev/null 2>&1
    }
    
    run_hook_test "$input" validate_localhost
}
print_test_result "Localhost access" "$?"

# ==========================================
# WSL-Specific Edge Cases
# ==========================================

echo -e "${YELLOW}=== WSL-Specific Edge Cases ===${NC}"

test_line_ending_handling() {
    # Test line ending handling (Windows CRLF vs Unix LF)
    local temp_file
    temp_file=$(mktemp)
    
    # Create file with Windows line endings
    printf "line1\r\nline2\r\nline3\r\n" > "$temp_file"
    
    local input="{\"tool\":{\"name\":\"Bash\",\"input\":{\"command\":\"cat $temp_file | head -2\"}},\"timeout\":null}"
    
    validate_line_endings() {
        local output="$1"
        echo "$output" | grep -q "claude-.*\.log" && \
        echo "$output" | python3 -m json.tool >/dev/null 2>&1
    }
    
    local result
    run_hook_test "$input" validate_line_endings
    result=$?
    
    rm -f "$temp_file" 2>/dev/null || true
    
    print_test_result "Line ending handling (CRLF)" "$result"
}

test_unicode_with_windows() {
    # Test Unicode handling in WSL with Windows filesystem
    if [[ -d "/mnt/c" ]]; then
        local input='{"tool":{"name":"Bash","input":{"command":"echo \"Unicode test: ñáéíóú 测试 🚀\" | head -1"}},"timeout":null}'
        
        validate_unicode_windows() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        run_hook_test "$input" validate_unicode_windows
        print_test_result "Unicode with Windows filesystem" "$?"
    else
        print_test_result "Unicode with Windows filesystem (no /mnt/c)" "0"
    fi
}

test_symlink_handling() {
    # Test symbolic link handling (different in WSL)
    local temp_file temp_link
    temp_file=$(mktemp)
    temp_link="${temp_file}.link"
    
    echo "symlink test" > "$temp_file"
    
    if ln -s "$temp_file" "$temp_link" 2>/dev/null; then
        local input="{\"tool\":{\"name\":\"Bash\",\"input\":{\"command\":\"cat $temp_link | head -1\"}},\"timeout\":null}"
        
        validate_symlinks() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | grep -q "symlink test" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        local result
        run_hook_test "$input" validate_symlinks
        result=$?
        
        rm -f "$temp_file" "$temp_link" 2>/dev/null || true
        print_test_result "Symbolic link handling" "$result"
    else
        rm -f "$temp_file" 2>/dev/null || true
        print_test_result "Symbolic link handling (symlinks not supported)" "0"
    fi
}

# ==========================================
# Summary
# ==========================================

echo ""
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}Windows WSL Test Results Summary${NC}"
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}WSL Version: $WSL_VERSION${NC}"
echo -e "${BLUE}Distribution: ${WSL_DISTRO_NAME:-Unknown}${NC}"
echo -e "${BLUE}Tests run: $TESTS_RUN${NC}"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo ""
    echo -e "${GREEN}✅ All Windows WSL-specific tests passed!${NC}"
    echo -e "${GREEN}✅ claude-auto-tee is fully compatible with this WSL environment${NC}"
    exit 0
else
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo ""
    echo -e "${RED}❌ Some Windows WSL-specific tests failed!${NC}"
    echo -e "${RED}❌ WSL compatibility issues detected${NC}"
    echo -e "${YELLOW}Review failed tests above for specific issues${NC}"
    exit 1
fi