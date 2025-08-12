#!/usr/bin/env bash
# Claude Auto-Tee System Diagnostic Tool
# Automatically diagnose common issues and suggest fixes

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

print_header() {
    echo -e "${BOLD}${BLUE}🔍 Claude Auto-Tee System Diagnostic${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo ""
}

print_result() {
    local status="$1"
    local message="$2"
    local fix="${3:-}"
    
    case "$status" in
        "PASS") echo -e "${GREEN}✅ $message${NC}" ;;
        "WARN") 
            echo -e "${YELLOW}⚠️  $message${NC}"
            if [[ -n "$fix" ]]; then
                echo -e "${YELLOW}   Fix: $fix${NC}"
            fi
            ;;
        "FAIL") 
            echo -e "${RED}❌ $message${NC}"
            if [[ -n "$fix" ]]; then
                echo -e "${RED}   Fix: $fix${NC}"
            fi
            ;;
        "INFO") echo -e "${BLUE}ℹ️  $message${NC}" ;;
    esac
}

check_system_requirements() {
    echo -e "${BOLD}System Requirements${NC}"
    echo "-------------------"
    
    # Check bash version
    local bash_version
    bash_version=$(bash --version | head -1 | grep -o '[0-9]\+\.[0-9]\+' | head -1)
    local bash_major
    bash_major=$(echo "$bash_version" | cut -d. -f1)
    
    if [[ $bash_major -ge 3 ]]; then
        print_result "PASS" "Bash version: $bash_version (requirement: 3.0+)"
    else
        print_result "FAIL" "Bash version: $bash_version (requirement: 3.0+)" "Upgrade bash: brew install bash (macOS) or apt install bash (Linux)"
    fi
    
    # Check tee command
    if command -v tee >/dev/null 2>&1; then
        print_result "PASS" "tee command available"
    else
        print_result "FAIL" "tee command not found" "Install coreutils package"
    fi
    
    # Check mktemp command
    if command -v mktemp >/dev/null 2>&1; then
        print_result "PASS" "mktemp command available"
    else
        print_result "FAIL" "mktemp command not found" "Install coreutils package"
    fi
    
    echo ""
}

check_temp_directory() {
    echo -e "${BOLD}Temp Directory Configuration${NC}"
    echo "----------------------------"
    
    # Check TMPDIR environment variable
    local tmpdir="${TMPDIR:-/tmp}"
    print_result "INFO" "Temp directory: $tmpdir"
    
    # Check if temp directory exists
    if [[ -d "$tmpdir" ]]; then
        print_result "PASS" "Temp directory exists"
    else
        print_result "FAIL" "Temp directory does not exist" "mkdir -p \"$tmpdir\""
    fi
    
    # Check if temp directory is writable
    if [[ -w "$tmpdir" ]]; then
        print_result "PASS" "Temp directory is writable"
    else
        print_result "FAIL" "Temp directory is not writable" "chmod 755 \"$tmpdir\" or sudo chown \$USER \"$tmpdir\""
    fi
    
    # Check available space
    if command -v df >/dev/null 2>&1; then
        local available
        available=$(df -h "$tmpdir" | awk 'NR==2 {print $4}')
        print_result "INFO" "Available space in temp directory: $available"
        
        # Warn if less than 100MB available
        local available_mb
        if [[ "$available" =~ ([0-9]+)M ]]; then
            available_mb="${BASH_REMATCH[1]}"
            if [[ $available_mb -lt 100 ]]; then
                print_result "WARN" "Low disk space in temp directory" "Free up space: rm -rf /tmp/claude-* or use different TMPDIR"
            fi
        elif [[ "$available" =~ ([0-9]+)G ]]; then
            print_result "PASS" "Sufficient disk space available"
        else
            print_result "WARN" "Could not determine available space"
        fi
    fi
    
    echo ""
}

check_file_permissions() {
    echo -e "${BOLD}File Permissions${NC}"
    echo "----------------"
    
    # Check claude-auto-tee script permissions
    local main_script="$PROJECT_ROOT/src/claude-auto-tee.sh"
    if [[ -f "$main_script" ]]; then
        if [[ -x "$main_script" ]]; then
            print_result "PASS" "claude-auto-tee.sh is executable"
        else
            print_result "FAIL" "claude-auto-tee.sh is not executable" "chmod +x \"$main_script\""
        fi
    else
        print_result "WARN" "claude-auto-tee.sh not found at expected location"
    fi
    
    # Test temp file creation
    local test_file
    test_file=$(mktemp "${tmpdir:-/tmp}/claude-diagnostic-XXXXXX" 2>/dev/null) || {
        print_result "FAIL" "Cannot create temp files" "Check temp directory permissions"
        return 1
    }
    
    # Test temp file write
    if echo "test" > "$test_file" 2>/dev/null; then
        print_result "PASS" "Can create and write temp files"
    else
        print_result "FAIL" "Cannot write to temp files" "Check temp directory permissions"
    fi
    
    # Test temp file read
    if [[ -r "$test_file" ]]; then
        print_result "PASS" "Can read temp files"
    else
        print_result "FAIL" "Cannot read temp files" "Check file permissions"
    fi
    
    # Cleanup test file
    rm -f "$test_file" 2>/dev/null || print_result "WARN" "Could not clean up test file"
    
    echo ""
}

check_platform_specific() {
    echo -e "${BOLD}Platform-Specific Checks${NC}"
    echo "------------------------"
    
    local platform
    platform=$(uname -s)
    print_result "INFO" "Platform: $platform"
    
    case "$platform" in
        "Darwin")
            # macOS specific checks
            print_result "INFO" "macOS detected"
            
            # Check SIP status
            if command -v csrutil >/dev/null 2>&1; then
                local sip_status
                sip_status=$(csrutil status 2>/dev/null | grep -o "enabled\|disabled" || echo "unknown")
                print_result "INFO" "System Integrity Protection: $sip_status"
                
                if [[ "$sip_status" == "enabled" ]]; then
                    print_result "INFO" "SIP is enabled - some system directories may be protected"
                fi
            fi
            
            # Check Homebrew PATH
            if [[ ":$PATH:" == *":/opt/homebrew/bin:"* ]] || [[ ":$PATH:" == *":/usr/local/bin:"* ]]; then
                print_result "PASS" "Homebrew paths in PATH"
            else
                print_result "WARN" "Homebrew paths missing from PATH" "export PATH=\"/opt/homebrew/bin:/usr/local/bin:\$PATH\""
            fi
            ;;
            
        "Linux")
            print_result "INFO" "Linux detected"
            
            # Check SELinux if available
            if command -v getenforce >/dev/null 2>&1; then
                local selinux_status
                selinux_status=$(getenforce 2>/dev/null || echo "not available")
                print_result "INFO" "SELinux status: $selinux_status"
                
                if [[ "$selinux_status" == "Enforcing" ]]; then
                    print_result "WARN" "SELinux is enforcing - may restrict temp file operations"
                fi
            fi
            
            # Check for WSL
            if grep -qi microsoft /proc/version 2>/dev/null; then
                print_result "INFO" "Windows Subsystem for Linux detected"
                
                # Check for Windows temp directory access
                if [[ -d "/mnt/c" ]]; then
                    print_result "PASS" "Windows filesystem accessible"
                else
                    print_result "WARN" "Windows filesystem not mounted"
                fi
            fi
            ;;
    esac
    
    echo ""
}

test_basic_functionality() {
    echo -e "${BOLD}Basic Functionality Test${NC}"
    echo "-----------------------"
    
    # Test tee functionality
    local test_output
    test_output=$(echo "test command" | tee /dev/null 2>&1) || {
        print_result "FAIL" "Basic tee functionality failed"
        return 1
    }
    
    if [[ "$test_output" == "test command" ]]; then
        print_result "PASS" "Basic tee functionality works"
    else
        print_result "FAIL" "Tee output unexpected: $test_output"
    fi
    
    # Test temp file creation with specific naming
    local temp_file
    temp_file=$(mktemp "${TMPDIR:-/tmp}/claude-test-XXXXXX" 2>/dev/null) || {
        print_result "FAIL" "Cannot create claude-style temp files"
        return 1
    }
    
    print_result "PASS" "Can create temp files with claude naming pattern"
    
    # Test pipe + tee combination
    if echo "pipe test" | tee "$temp_file" > /dev/null 2>&1; then
        local file_content
        file_content=$(cat "$temp_file" 2>/dev/null || echo "")
        if [[ "$file_content" == "pipe test" ]]; then
            print_result "PASS" "Pipe + tee combination works"
        else
            print_result "FAIL" "Pipe + tee produced wrong output: $file_content"
        fi
    else
        print_result "FAIL" "Pipe + tee combination failed"
    fi
    
    # Cleanup
    rm -f "$temp_file" 2>/dev/null
    
    echo ""
}

check_existing_processes() {
    echo -e "${BOLD}Existing Processes${NC}"
    echo "------------------"
    
    # Check for existing claude processes
    local claude_processes
    claude_processes=$(pgrep -f "claude" 2>/dev/null | wc -l)
    if [[ $claude_processes -gt 0 ]]; then
        print_result "INFO" "Found $claude_processes claude-related processes"
        print_result "INFO" "This is normal if you're running Claude Code or other Claude tools"
    fi
    
    # Check for leftover temp files
    local temp_files
    temp_files=$(find "${TMPDIR:-/tmp}" -name "claude-*" 2>/dev/null | wc -l)
    if [[ $temp_files -gt 0 ]]; then
        print_result "INFO" "Found $temp_files leftover claude temp files"
        if [[ $temp_files -gt 10 ]]; then
            print_result "WARN" "Many leftover temp files found" "Consider cleaning: rm -rf \${TMPDIR:-/tmp}/claude-*"
        fi
    else
        print_result "PASS" "No leftover temp files found"
    fi
    
    echo ""
}

provide_recommendations() {
    echo -e "${BOLD}Recommendations${NC}"
    echo "---------------"
    
    # Environment setup recommendations
    echo -e "${BLUE}Environment Setup:${NC}"
    echo "export TMPDIR=\"\${TMPDIR:-/tmp}\""
    echo "export PATH=\"/opt/homebrew/bin:/usr/local/bin:\$PATH\"  # macOS"
    echo ""
    
    # Debug mode information
    echo -e "${BLUE}Debug Mode (if issues persist):${NC}"
    echo "export CLAUDE_AUTO_TEE_DEBUG=1"
    echo "echo \"your command\" | claude-auto-tee"
    echo ""
    
    # Common fixes
    echo -e "${BLUE}Common Fixes:${NC}"
    echo "# Reset temp directory"
    echo "unset TMPDIR && export TMPDIR=/tmp"
    echo ""
    echo "# Clean leftover files"
    echo "rm -rf \${TMPDIR:-/tmp}/claude-*"
    echo ""
    echo "# Test basic functionality"
    echo "echo \"pwd\" | tee /tmp/test.log && cat /tmp/test.log"
    echo ""
}

main() {
    print_header
    
    local exit_code=0
    
    check_system_requirements
    check_temp_directory  
    check_file_permissions || exit_code=1
    check_platform_specific
    test_basic_functionality || exit_code=1
    check_existing_processes
    provide_recommendations
    
    echo -e "${BOLD}Diagnostic Summary${NC}"
    echo "------------------"
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}✅ System appears ready for claude-auto-tee${NC}"
        echo -e "${GREEN}If you still encounter issues, enable debug mode:${NC}"
        echo -e "${GREEN}export CLAUDE_AUTO_TEE_DEBUG=1${NC}"
    else
        echo -e "${RED}❌ Issues detected - please address the failures above${NC}"
        echo -e "${RED}Refer to TROUBLESHOOTING.md for detailed solutions${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}For more help: https://github.com/flyingrobots/claude-auto-tee/blob/main/TROUBLESHOOTING.md${NC}"
    
    return $exit_code
}

# Run diagnostic if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi