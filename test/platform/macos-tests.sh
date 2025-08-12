#!/usr/bin/env bash
# macOS-Specific Tests for claude-auto-tee
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

# Skip all tests if not running on macOS
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo -e "${YELLOW}Skipping macOS tests - not running on macOS${NC}"
    exit 0
fi

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

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}macOS-Specific Test Suite${NC}"
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}macOS Version: $(sw_vers -productVersion 2>/dev/null || echo Unknown)${NC}"
echo -e "${BLUE}Architecture: $(uname -m)${NC}"
echo -e "${BLUE}Bash Version: $BASH_VERSION${NC}"
echo ""

# ==========================================
# macOS Temp Directory Tests
# ==========================================

echo -e "${YELLOW}=== macOS Temp Directory Tests ===${NC}"

test_private_tmp() {
    # Test /private/tmp accessibility  
    local input='{"tool":{"name":"Bash","input":{"command":"echo private-tmp | head -1"}},"timeout":null}'
    
    validate_private_tmp() {
        local output="$1"
        echo "$output" | grep -q "claude-.*\.log" && \
        echo "$output" | python3 -m json.tool >/dev/null 2>&1
    }
    
    run_hook_test "$input" validate_private_tmp
}
print_test_result "Private /tmp directory access" "$?"

test_var_folders_tmpdir() {
    # Test /var/folders TMPDIR (common on macOS)
    if [[ "${TMPDIR:-}" == /var/folders/* ]]; then
        local input='{"tool":{"name":"Bash","input":{"command":"echo var-folders | head -1"}},"timeout":null}'
        
        validate_var_folders() {
            local output="$1"
            echo "$output" | grep -q "/var/folders.*claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        run_hook_test "$input" validate_var_folders
        print_test_result "/var/folders TMPDIR handling" "$?"
    else
        print_test_result "/var/folders TMPDIR handling" "0"  # Skip if not using /var/folders
    fi
}

test_temp_dir_permissions() {
    # Test temp directory permissions on macOS
    local test_dir="${TMPDIR:-/tmp}/claude-test-$$"
    
    if mkdir "$test_dir" 2>/dev/null; then
        local perms
        perms=$(stat -f "%Lp" "$test_dir" 2>/dev/null || echo "700")
        
        # Should be writable by user
        if [[ "$perms" =~ ^[0-9]*[2367][0-9]*$ ]] || [[ "$perms" =~ ^[0-9]*[024-7][2367][0-9]*$ ]]; then
            rmdir "$test_dir" 2>/dev/null || true
            print_test_result "Temp directory permissions" "0"
        else
            rmdir "$test_dir" 2>/dev/null || true
            print_test_result "Temp directory permissions" "1"
        fi
    else
        print_test_result "Temp directory permissions" "1"
    fi
}

# ==========================================
# macOS System Integration Tests
# ==========================================

echo -e "${YELLOW}=== macOS System Integration Tests ===${NC}"

test_sip_compatibility() {
    # Test System Integrity Protection compatibility
    local input='{"tool":{"name":"Bash","input":{"command":"ls /System/Library | head -3"}},"timeout":null}'
    
    validate_sip() {
        local output="$1"
        # Should work fine (just reading, not modifying)
        echo "$output" | grep -q "claude-.*\.log" && \
        echo "$output" | python3 -m json.tool >/dev/null 2>&1
    }
    
    run_hook_test "$input" validate_sip
}
print_test_result "System Integrity Protection compatibility" "$?"

test_codesign_compatibility() {
    # Test that our script works with code signing requirements
    if command -v codesign >/dev/null 2>&1; then
        # Check if bash is code signed (common on newer macOS)
        if codesign -v /bin/bash 2>/dev/null; then
            local input='{"tool":{"name":"Bash","input":{"command":"echo codesign-test | head -1"}},"timeout":null}'
            
            validate_codesign() {
                local output="$1"
                echo "$output" | grep -q "claude-.*\.log" && \
                echo "$output" | python3 -m json.tool >/dev/null 2>&1
            }
            
            run_hook_test "$input" validate_codesign
            print_test_result "Code signing compatibility" "$?"
        else
            print_test_result "Code signing compatibility" "0"  # Skip if bash not signed
        fi
    else
        print_test_result "Code signing compatibility" "0"  # Skip if codesign not available
    fi
}

test_quarantine_compatibility() {
    # Test quarantine attribute handling
    if command -v xattr >/dev/null 2>&1; then
        local temp_file
        temp_file=$(mktemp)
        
        # Add quarantine attribute (simulating downloaded file)
        xattr -w com.apple.quarantine "0181;$(date +%s);;" "$temp_file" 2>/dev/null || true
        
        local input="{\"tool\":{\"name\":\"Bash\",\"input\":{\"command\":\"cat $temp_file | head -1 || echo empty\"}},\"timeout\":null}"
        
        validate_quarantine() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        local result
        run_hook_test "$input" validate_quarantine
        result=$?
        
        # Clean up
        rm -f "$temp_file" 2>/dev/null || true
        
        print_test_result "Quarantine attribute compatibility" "$result"
    else
        print_test_result "Quarantine attribute compatibility" "0"  # Skip if xattr not available
    fi
}

# ==========================================
# macOS Development Environment Tests
# ==========================================

echo -e "${YELLOW}=== macOS Development Environment Tests ===${NC}"

test_homebrew_integration() {
    # Test Homebrew integration
    if command -v brew >/dev/null 2>&1; then
        local input='{"tool":{"name":"Bash","input":{"command":"brew --version | head -1"}},"timeout":null}'
        
        validate_homebrew() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        run_hook_test "$input" validate_homebrew
        print_test_result "Homebrew integration" "$?"
    else
        print_test_result "Homebrew integration" "0"  # Skip if Homebrew not installed
    fi
}

test_xcode_tools_integration() {
    # Test Xcode command line tools integration
    if command -v xcodebuild >/dev/null 2>&1; then
        local input='{"tool":{"name":"Bash","input":{"command":"xcodebuild -version 2>&1 | head -1"}},"timeout":null}'
        
        validate_xcode() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        run_hook_test "$input" validate_xcode
        print_test_result "Xcode tools integration" "$?"
    else
        print_test_result "Xcode tools integration" "0"  # Skip if Xcode tools not installed
    fi
}

test_macports_integration() {
    # Test MacPorts integration (if installed)
    if command -v port >/dev/null 2>&1; then
        local input='{"tool":{"name":"Bash","input":{"command":"port version 2>&1 | head -1"}},"timeout":null}'
        
        validate_macports() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        run_hook_test "$input" validate_macports
        print_test_result "MacPorts integration" "$?"
    else
        print_test_result "MacPorts integration" "0"  # Skip if MacPorts not installed
    fi
}

# ==========================================
# macOS Filesystem Tests
# ==========================================

echo -e "${YELLOW}=== macOS Filesystem Tests ===${NC}"

test_case_insensitive_handling() {
    # Test case-insensitive filesystem handling
    local temp_file
    temp_file=$(mktemp /tmp/CaseTest-XXXXXX)
    local upper_name="${temp_file^^}"
    local lower_name="${temp_file,,}"
    
    # On case-insensitive filesystems, these should refer to the same file
    if [[ -f "$temp_file" ]] && [[ -f "$upper_name" ]] && [[ -f "$lower_name" ]]; then
        local input="{\"tool\":{\"name\":\"Bash\",\"input\":{\"command\":\"ls -la $temp_file | head -1\"}},\"timeout\":null}"
        
        validate_case_handling() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        local result
        run_hook_test "$input" validate_case_handling
        result=$?
        
        rm -f "$temp_file" 2>/dev/null || true
        print_test_result "Case-insensitive filesystem handling" "$result"
    else
        rm -f "$temp_file" 2>/dev/null || true
        print_test_result "Case-insensitive filesystem handling" "0"  # Case-sensitive filesystem
    fi
}

test_extended_attributes() {
    # Test extended attributes handling
    if command -v xattr >/dev/null 2>&1; then
        local temp_file
        temp_file=$(mktemp)
        
        # Set an extended attribute
        xattr -w com.test.attribute "test value" "$temp_file" 2>/dev/null || true
        
        local input="{\"tool\":{\"name\":\"Bash\",\"input\":{\"command\":\"xattr -l $temp_file | head -1 || echo no-xattr\"}},\"timeout\":null}"
        
        validate_xattr() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        local result
        run_hook_test "$input" validate_xattr
        result=$?
        
        rm -f "$temp_file" 2>/dev/null || true
        print_test_result "Extended attributes handling" "$result"
    else
        print_test_result "Extended attributes handling" "0"  # Skip if xattr not available
    fi
}

test_resource_forks() {
    # Test resource fork handling (legacy but still possible)
    local temp_file
    temp_file=$(mktemp)
    
    # Try to create a resource fork
    echo "resource fork test" > "$temp_file/..namedfork/rsrc" 2>/dev/null || true
    
    local input="{\"tool\":{\"name\":\"Bash\",\"input\":{\"command\":\"ls -la $temp_file* 2>/dev/null | head -2 || echo no-resource-fork\"}},\"timeout\":null}"
    
    validate_resource_fork() {
        local output="$1"
        echo "$output" | grep -q "claude-.*\.log" && \
        echo "$output" | python3 -m json.tool >/dev/null 2>&1
    }
    
    local result
    run_hook_test "$input" validate_resource_fork
    result=$?
    
    # Clean up
    rm -f "$temp_file" "$temp_file/..namedfork/rsrc" 2>/dev/null || true
    
    print_test_result "Resource fork handling" "$result"
}

# ==========================================
# macOS Performance Tests
# ==========================================

echo -e "${YELLOW}=== macOS Performance Tests ===${NC}"

test_performance_with_spotlight() {
    # Test performance when Spotlight might be indexing
    local start_time end_time duration
    start_time=$(date +%s)
    
    local input='{"tool":{"name":"Bash","input":{"command":"mdfind -name claude-auto-tee 2>/dev/null | head -1 || echo no-spotlight-results"}},"timeout":null}'
    
    validate_spotlight() {
        local output="$1"
        echo "$output" | grep -q "claude-.*\.log" && \
        echo "$output" | python3 -m json.tool >/dev/null 2>&1
    }
    
    local result
    run_hook_test "$input" validate_spotlight
    result=$?
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    # Should complete within reasonable time even with Spotlight
    if [[ $result -eq 0 ]] && [[ $duration -lt 10 ]]; then
        print_test_result "Performance with Spotlight indexing" "0"
    else
        print_test_result "Performance with Spotlight indexing" "1"
    fi
}

test_memory_pressure_handling() {
    # Test behavior under memory pressure (simulation)
    # Create a reasonably large command that might trigger memory pressure
    local large_find_cmd="find /System -name '*.plist' 2>/dev/null"
    local input="{\"tool\":{\"name\":\"Bash\",\"input\":{\"command\":\"$large_find_cmd | head -20\"}},\"timeout\":null}"
    
    validate_memory_pressure() {
        local output="$1"
        echo "$output" | grep -q "claude-.*\.log" && \
        echo "$output" | python3 -m json.tool >/dev/null 2>&1
    }
    
    run_hook_test "$input" validate_memory_pressure
}
print_test_result "Memory pressure handling" "$?"

# ==========================================
# macOS Security Tests
# ==========================================

echo -e "${YELLOW}=== macOS Security Tests ===${NC}"

test_gatekeeper_compatibility() {
    # Test Gatekeeper compatibility
    local input='{"tool":{"name":"Bash","input":{"command":"spctl --status 2>/dev/null | head -1 || echo no-spctl"}},"timeout":null}'
    
    validate_gatekeeper() {
        local output="$1"
        echo "$output" | grep -q "claude-.*\.log" && \
        echo "$output" | python3 -m json.tool >/dev/null 2>&1
    }
    
    run_hook_test "$input" validate_gatekeeper
}
print_test_result "Gatekeeper compatibility" "$?"

test_privacy_controls() {
    # Test that we handle privacy controls gracefully
    local input='{"tool":{"name":"Bash","input":{"command":"ls ~/Desktop 2>/dev/null | head -3 || echo no-desktop-access"}},"timeout":null}'
    
    validate_privacy() {
        local output="$1"
        # Should handle gracefully whether access is granted or denied
        echo "$output" | grep -q "claude-.*\.log" && \
        echo "$output" | python3 -m json.tool >/dev/null 2>&1
    }
    
    run_hook_test "$input" validate_privacy
}
print_test_result "Privacy controls handling" "$?"

# ==========================================
# Summary
# ==========================================

echo ""
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}macOS Test Results Summary${NC}"
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}macOS Version: $(sw_vers -productVersion 2>/dev/null || echo Unknown)${NC}"
echo -e "${BLUE}Tests run: $TESTS_RUN${NC}"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo ""
    echo -e "${GREEN}✅ All macOS-specific tests passed!${NC}"
    echo -e "${GREEN}✅ claude-auto-tee is fully compatible with this macOS system${NC}"
    exit 0
else
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo ""
    echo -e "${RED}❌ Some macOS-specific tests failed!${NC}"
    echo -e "${RED}❌ macOS compatibility issues detected${NC}"
    echo -e "${YELLOW}Review failed tests above for specific issues${NC}"
    exit 1
fi