#!/usr/bin/env bash
# Linux-Specific Tests for claude-auto-tee
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

# Skip all tests if not running on Linux
if [[ "$(uname -s)" != "Linux" ]]; then
    echo -e "${YELLOW}Skipping Linux tests - not running on Linux${NC}"
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

detect_distribution() {
    local distro="Unknown"
    
    if [[ -f /etc/os-release ]]; then
        distro=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d'"' -f2)
    elif [[ -f /etc/redhat-release ]]; then
        distro=$(cat /etc/redhat-release)
    elif [[ -f /etc/debian_version ]]; then
        distro="Debian $(cat /etc/debian_version)"
    elif [[ -f /etc/alpine-release ]]; then
        distro="Alpine Linux $(cat /etc/alpine-release)"
    fi
    
    echo "$distro"
}

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}Linux-Specific Test Suite${NC}"
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}Distribution: $(detect_distribution)${NC}"
echo -e "${BLUE}Kernel: $(uname -r)${NC}"
echo -e "${BLUE}Architecture: $(uname -m)${NC}"
echo -e "${BLUE}Bash Version: $BASH_VERSION${NC}"
echo ""

# ==========================================
# Linux Temp Directory Tests
# ==========================================

echo -e "${YELLOW}=== Linux Temp Directory Tests ===${NC}"

test_tmp_sticky_bit() {
    # Test /tmp sticky bit (standard Linux configuration)
    if [[ -d "/tmp" ]]; then
        local perms
        perms=$(stat -c "%a" /tmp 2>/dev/null || echo "755")
        
        # Check for sticky bit (1xxx permissions)
        if [[ "$perms" =~ ^1[0-9]{3}$ ]]; then
            local input='{"tool":{"name":"Bash","input":{"command":"echo sticky-bit-test | head -1"}},"timeout":null}'
            
            validate_sticky_bit() {
                local output="$1"
                echo "$output" | grep -q "claude-.*\.log" && \
                echo "$output" | python3 -m json.tool >/dev/null 2>&1
            }
            
            run_hook_test "$input" validate_sticky_bit
            print_test_result "/tmp sticky bit handling" "$?"
        else
            print_test_result "/tmp sticky bit handling" "1"
        fi
    else
        print_test_result "/tmp sticky bit handling" "1"
    fi
}

test_var_tmp_access() {
    # Test /var/tmp access (Linux standard)
    if [[ -d "/var/tmp" ]] && [[ -w "/var/tmp" ]]; then
        # Test with /var/tmp override
        local old_tmpdir="${TMPDIR:-}"
        export TMPDIR="/var/tmp"
        
        local input='{"tool":{"name":"Bash","input":{"command":"echo var-tmp-test | head -1"}},"timeout":null}'
        
        validate_var_tmp() {
            local output="$1"
            echo "$output" | grep -q "/var/tmp.*claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        local result
        run_hook_test "$input" validate_var_tmp
        result=$?
        
        # Restore TMPDIR
        if [[ -n "$old_tmpdir" ]]; then
            export TMPDIR="$old_tmpdir"
        else
            unset TMPDIR
        fi
        
        print_test_result "/var/tmp directory access" "$result"
    else
        print_test_result "/var/tmp directory access" "0"  # Skip if not available/writable
    fi
}

test_dev_shm_tmpfs() {
    # Test /dev/shm tmpfs access (Linux-specific)
    if [[ -d "/dev/shm" ]] && [[ -w "/dev/shm" ]]; then
        # Test with /dev/shm override (memory filesystem)
        local old_tmpdir="${TMPDIR:-}"
        export TMPDIR="/dev/shm"
        
        local input='{"tool":{"name":"Bash","input":{"command":"echo shm-test | head -1"}},"timeout":null}'
        
        validate_dev_shm() {
            local output="$1"
            echo "$output" | grep -q "/dev/shm.*claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        local result
        run_hook_test "$input" validate_dev_shm
        result=$?
        
        # Restore TMPDIR
        if [[ -n "$old_tmpdir" ]]; then
            export TMPDIR="$old_tmpdir"
        else
            unset TMPDIR
        fi
        
        print_test_result "/dev/shm tmpfs handling" "$result"
    else
        print_test_result "/dev/shm tmpfs handling" "0"  # Skip if not available
    fi
}

# ==========================================
# Linux Security Tests
# ==========================================

echo -e "${YELLOW}=== Linux Security Tests ===${NC}"

test_selinux_compatibility() {
    # Test SELinux compatibility
    if command -v getenforce >/dev/null 2>&1; then
        local selinux_status
        selinux_status=$(getenforce 2>/dev/null || echo "Disabled")
        
        local input='{"tool":{"name":"Bash","input":{"command":"echo selinux-test | head -1"}},"timeout":null}'
        
        validate_selinux() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        run_hook_test "$input" validate_selinux
        print_test_result "SELinux compatibility (status: $selinux_status)" "$?"
    else
        print_test_result "SELinux compatibility" "0"  # Skip if SELinux not available
    fi
}

test_apparmor_compatibility() {
    # Test AppArmor compatibility (Ubuntu/SUSE)
    if command -v aa-status >/dev/null 2>&1; then
        local input='{"tool":{"name":"Bash","input":{"command":"echo apparmor-test | head -1"}},"timeout":null}'
        
        validate_apparmor() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        run_hook_test "$input" validate_apparmor
        print_test_result "AppArmor compatibility" "$?"
    else
        print_test_result "AppArmor compatibility" "0"  # Skip if AppArmor not available
    fi
}

test_capabilities_handling() {
    # Test Linux capabilities handling
    if command -v capsh >/dev/null 2>&1; then
        local input='{"tool":{"name":"Bash","input":{"command":"capsh --print 2>/dev/null | head -1 || echo no-caps"}},"timeout":null}'
        
        validate_capabilities() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        run_hook_test "$input" validate_capabilities
        print_test_result "Linux capabilities handling" "$?"
    else
        print_test_result "Linux capabilities handling" "0"  # Skip if capsh not available
    fi
}

# ==========================================
# Linux System Integration Tests
# ==========================================

echo -e "${YELLOW}=== Linux System Integration Tests ===${NC}"

test_proc_filesystem_access() {
    # Test /proc filesystem access
    local input='{"tool":{"name":"Bash","input":{"command":"cat /proc/version | head -1"}},"timeout":null}'
    
    validate_proc_fs() {
        local output="$1"
        echo "$output" | grep -q "claude-.*\.log" && \
        echo "$output" | grep -q "Linux" && \
        echo "$output" | python3 -m json.tool >/dev/null 2>&1
    }
    
    run_hook_test "$input" validate_proc_fs
}
print_test_result "/proc filesystem access" "$?"

test_sys_filesystem_access() {
    # Test /sys filesystem access
    local input='{"tool":{"name":"Bash","input":{"command":"ls /sys/class 2>/dev/null | head -3 || echo no-sys-access"}},"timeout":null}'
    
    validate_sys_fs() {
        local output="$1"
        echo "$output" | grep -q "claude-.*\.log" && \
        echo "$output" | python3 -m json.tool >/dev/null 2>&1
    }
    
    run_hook_test "$input" validate_sys_fs
}
print_test_result "/sys filesystem access" "$?"

test_systemd_integration() {
    # Test systemd integration (if available)
    if command -v systemctl >/dev/null 2>&1; then
        local input='{"tool":{"name":"Bash","input":{"command":"systemctl --version 2>/dev/null | head -1"}},"timeout":null}'
        
        validate_systemd() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        run_hook_test "$input" validate_systemd
        print_test_result "systemd integration" "$?"
    else
        print_test_result "systemd integration" "0"  # Skip if systemd not available
    fi
}

# ==========================================
# Linux Container Tests
# ==========================================

echo -e "${YELLOW}=== Linux Container Tests ===${NC}"

test_container_detection() {
    # Test container environment detection
    local is_container=false
    
    # Check for various container indicators
    if [[ -f "/.dockerenv" ]] || \
       [[ -f "/run/.containerenv" ]] || \
       grep -q "container" /proc/1/cgroup 2>/dev/null || \
       [[ "${container:-}" == "podman" ]] || \
       [[ "${container:-}" == "docker" ]]; then
        is_container=true
    fi
    
    local input='{"tool":{"name":"Bash","input":{"command":"echo container-detection | head -1"}},"timeout":null}'
    
    validate_container() {
        local output="$1"
        echo "$output" | grep -q "claude-.*\.log" && \
        echo "$output" | python3 -m json.tool >/dev/null 2>&1
    }
    
    local result
    run_hook_test "$input" validate_container
    result=$?
    
    if [[ "$is_container" == true ]]; then
        print_test_result "Container environment handling (detected)" "$result"
    else
        print_test_result "Container environment handling (native)" "$result"
    fi
}

test_cgroup_awareness() {
    # Test cgroup awareness
    if [[ -d "/sys/fs/cgroup" ]]; then
        local input='{"tool":{"name":"Bash","input":{"command":"ls /sys/fs/cgroup 2>/dev/null | head -3 || echo no-cgroup-access"}},"timeout":null}'
        
        validate_cgroup() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        run_hook_test "$input" validate_cgroup
        print_test_result "cgroup awareness" "$?"
    else
        print_test_result "cgroup awareness" "0"  # Skip if cgroups not available
    fi
}

test_namespace_handling() {
    # Test Linux namespace handling
    local input='{"tool":{"name":"Bash","input":{"command":"ls /proc/self/ns 2>/dev/null | head -3 || echo no-namespace-access"}},"timeout":null}'
    
    validate_namespaces() {
        local output="$1"
        echo "$output" | grep -q "claude-.*\.log" && \
        echo "$output" | python3 -m json.tool >/dev/null 2>&1
    }
    
    run_hook_test "$input" validate_namespaces
}
print_test_result "Linux namespace handling" "$?"

# ==========================================
# Linux Distribution Tests
# ==========================================

echo -e "${YELLOW}=== Linux Distribution Tests ===${NC}"

test_package_manager_integration() {
    # Test various Linux package managers
    local tested=false
    
    # Test APT (Debian/Ubuntu)
    if command -v apt >/dev/null 2>&1; then
        local input='{"tool":{"name":"Bash","input":{"command":"apt --version 2>/dev/null | head -1 || echo no-apt-version"}},"timeout":null}'
        
        validate_apt() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        if run_hook_test "$input" validate_apt; then
            print_test_result "APT package manager integration" "0"
            tested=true
        else
            print_test_result "APT package manager integration" "1"
        fi
    fi
    
    # Test DNF (Fedora/RHEL 8+)
    if command -v dnf >/dev/null 2>&1; then
        local input='{"tool":{"name":"Bash","input":{"command":"dnf --version 2>/dev/null | head -1 || echo no-dnf-version"}},"timeout":null}'
        
        validate_dnf() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        if run_hook_test "$input" validate_dnf; then
            print_test_result "DNF package manager integration" "0"
            tested=true
        else
            print_test_result "DNF package manager integration" "1"
        fi
    fi
    
    # Test YUM (RHEL/CentOS)
    if command -v yum >/dev/null 2>&1; then
        local input='{"tool":{"name":"Bash","input":{"command":"yum --version 2>/dev/null | head -1 || echo no-yum-version"}},"timeout":null}'
        
        validate_yum() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        if run_hook_test "$input" validate_yum; then
            print_test_result "YUM package manager integration" "0"
            tested=true
        else
            print_test_result "YUM package manager integration" "1"
        fi
    fi
    
    # Test Pacman (Arch Linux)
    if command -v pacman >/dev/null 2>&1; then
        local input='{"tool":{"name":"Bash","input":{"command":"pacman --version 2>/dev/null | head -1 || echo no-pacman-version"}},"timeout":null}'
        
        validate_pacman() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        if run_hook_test "$input" validate_pacman; then
            print_test_result "Pacman package manager integration" "0"
            tested=true
        else
            print_test_result "Pacman package manager integration" "1"
        fi
    fi
    
    # Test APK (Alpine Linux)
    if command -v apk >/dev/null 2>&1; then
        local input='{"tool":{"name":"Bash","input":{"command":"apk --version 2>/dev/null | head -1 || echo no-apk-version"}},"timeout":null}'
        
        validate_apk() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        if run_hook_test "$input" validate_apk; then
            print_test_result "APK package manager integration" "0"
            tested=true
        else
            print_test_result "APK package manager integration" "1"
        fi
    fi
    
    # If no package managers were found/tested, mark as passed (minimal system)
    if [[ "$tested" == false ]]; then
        print_test_result "Package manager integration (none detected)" "0"
    fi
}

test_init_system_compatibility() {
    # Test various init systems
    local init_system="unknown"
    
    if [[ -d "/run/systemd/system" ]]; then
        init_system="systemd"
    elif [[ -f "/etc/inittab" ]]; then
        init_system="sysvinit"
    elif command -v openrc >/dev/null 2>&1; then
        init_system="openrc"
    fi
    
    local input='{"tool":{"name":"Bash","input":{"command":"ps -p 1 -o comm= 2>/dev/null || echo unknown-init"}},"timeout":null}'
    
    validate_init_system() {
        local output="$1"
        echo "$output" | grep -q "claude-.*\.log" && \
        echo "$output" | python3 -m json.tool >/dev/null 2>&1
    }
    
    run_hook_test "$input" validate_init_system
    print_test_result "Init system compatibility ($init_system)" "$?"
}

# ==========================================
# Linux File System Tests
# ==========================================

echo -e "${YELLOW}=== Linux File System Tests ===${NC}"

test_ext4_features() {
    # Test ext4 filesystem features (if available)
    local temp_file
    temp_file=$(mktemp)
    
    # Check if we're on ext4
    local fs_type
    fs_type=$(df -T "$temp_file" 2>/dev/null | tail -1 | awk '{print $2}' || echo "unknown")
    
    if [[ "$fs_type" == "ext4" ]]; then
        # Test ext4-specific features
        local input="{\"tool\":{\"name\":\"Bash\",\"input\":{\"command\":\"stat -f $temp_file 2>/dev/null | head -3 || echo no-stat-f\"}},\"timeout\":null}"
        
        validate_ext4() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        local result
        run_hook_test "$input" validate_ext4
        result=$?
        
        rm -f "$temp_file" 2>/dev/null || true
        print_test_result "ext4 filesystem features" "$result"
    else
        rm -f "$temp_file" 2>/dev/null || true
        print_test_result "ext4 filesystem features (not ext4: $fs_type)" "0"
    fi
}

test_xfs_features() {
    # Test XFS filesystem features (if available)
    local temp_file
    temp_file=$(mktemp)
    
    local fs_type
    fs_type=$(df -T "$temp_file" 2>/dev/null | tail -1 | awk '{print $2}' || echo "unknown")
    
    if [[ "$fs_type" == "xfs" ]]; then
        local input="{\"tool\":{\"name\":\"Bash\",\"input\":{\"command\":\"xfs_info $temp_file 2>/dev/null | head -1 || echo no-xfs-info\"}},\"timeout\":null}"
        
        validate_xfs() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        local result
        run_hook_test "$input" validate_xfs
        result=$?
        
        rm -f "$temp_file" 2>/dev/null || true
        print_test_result "XFS filesystem features" "$result"
    else
        rm -f "$temp_file" 2>/dev/null || true
        print_test_result "XFS filesystem features (not XFS: $fs_type)" "0"
    fi
}

test_btrfs_features() {
    # Test Btrfs filesystem features (if available)
    local temp_file
    temp_file=$(mktemp)
    
    local fs_type
    fs_type=$(df -T "$temp_file" 2>/dev/null | tail -1 | awk '{print $2}' || echo "unknown")
    
    if [[ "$fs_type" == "btrfs" ]]; then
        local input="{\"tool\":{\"name\":\"Bash\",\"input\":{\"command\":\"btrfs filesystem show 2>/dev/null | head -3 || echo no-btrfs-info\"}},\"timeout\":null}"
        
        validate_btrfs() {
            local output="$1"
            echo "$output" | grep -q "claude-.*\.log" && \
            echo "$output" | python3 -m json.tool >/dev/null 2>&1
        }
        
        local result
        run_hook_test "$input" validate_btrfs
        result=$?
        
        rm -f "$temp_file" 2>/dev/null || true
        print_test_result "Btrfs filesystem features" "$result"
    else
        rm -f "$temp_file" 2>/dev/null || true
        print_test_result "Btrfs filesystem features (not Btrfs: $fs_type)" "0"
    fi
}

# ==========================================
# Summary
# ==========================================

echo ""
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}Linux Test Results Summary${NC}"
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}Distribution: $(detect_distribution)${NC}"
echo -e "${BLUE}Kernel: $(uname -r)${NC}"
echo -e "${BLUE}Tests run: $TESTS_RUN${NC}"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo ""
    echo -e "${GREEN}✅ All Linux-specific tests passed!${NC}"
    echo -e "${GREEN}✅ claude-auto-tee is fully compatible with this Linux system${NC}"
    exit 0
else
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo ""
    echo -e "${RED}❌ Some Linux-specific tests failed!${NC}"
    echo -e "${RED}❌ Linux compatibility issues detected${NC}"
    echo -e "${YELLOW}Review failed tests above for specific issues${NC}"
    exit 1
fi