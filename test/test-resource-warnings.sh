#!/usr/bin/env bash
# Test Resource Usage Warnings (P1.T022)
# Tests the resource monitoring and warning functionality

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

test_resource_warnings_enabled() {
    # Test with resource warnings enabled
    local input='{\"tool\":{\"name\":\"Bash\",\"input\":{\"command\":\"echo test | head -1\"}},\"timeout\":null}'
    local output
    
    # Enable resource warnings and verbose mode
    export CLAUDE_AUTO_TEE_ENABLE_RESOURCE_WARNINGS=true
    export CLAUDE_AUTO_TEE_VERBOSE=true
    
    if output=$(echo "$input" | bash "$HOOK_SCRIPT" 2>&1); then
        # Check that resource usage monitoring message appears
        if echo "$output" | grep -q "Resource usage warnings: true"; then
            return 0
        fi
    fi
    
    return 1
}

test_resource_warnings_disabled() {
    # Test with resource warnings disabled
    local input='{\"tool\":{\"name\":\"Bash\",\"input\":{\"command\":\"echo test | head -1\"}},\"timeout\":null}'
    local output
    
    # Disable resource warnings but enable verbose mode to see the log
    export CLAUDE_AUTO_TEE_ENABLE_RESOURCE_WARNINGS=false
    export CLAUDE_AUTO_TEE_VERBOSE=true
    
    if output=$(echo "$input" | bash "$HOOK_SCRIPT" 2>&1); then
        # Check that resource usage warnings are disabled
        if echo "$output" | grep -q "Resource usage warnings: false"; then
            return 0
        fi
    fi
    
    return 1
}

test_disk_space_warning_threshold() {
    # Test disk space warning with very high threshold (should trigger warning)
    local input='{\"tool\":{\"name\":\"Bash\",\"input\":{\"command\":\"echo test | head -1\"}},\"timeout\":null}'
    local output
    
    # Set very high disk space threshold to trigger warning
    export CLAUDE_AUTO_TEE_ENABLE_RESOURCE_WARNINGS=true
    export CLAUDE_AUTO_TEE_SPACE_WARNING_THRESHOLD_MB=999999  # 999GB - should be above any system
    export CLAUDE_AUTO_TEE_VERBOSE=true
    
    if output=$(echo "$input" | bash "$HOOK_SCRIPT" 2>&1); then
        # Check for disk space warning
        if echo "$output" | grep -q "RESOURCE WARNING.*Low disk space"; then
            return 0
        fi
    fi
    
    return 1
}

test_temp_file_count_warnings() {
    # Create multiple temp files to trigger count warning
    local temp_dir="${TMPDIR:-/tmp}"
    local input='{\"tool\":{\"name\":\"Bash\",\"input\":{\"command\":\"echo test | head -1\"}},\"timeout\":null}'
    local output
    
    # Create many temp files to trigger warning
    for i in {1..25}; do
        touch "${temp_dir}/claude-${i}-$$-test.log" 2>/dev/null || true
    done
    
    # Set low threshold for temp file count
    export CLAUDE_AUTO_TEE_ENABLE_RESOURCE_WARNINGS=true
    export CLAUDE_AUTO_TEE_MAX_TEMP_FILES_WARNING=5
    export CLAUDE_AUTO_TEE_VERBOSE=true
    
    if output=$(echo "$input" | bash "$HOOK_SCRIPT" 2>&1); then
        # Check for temp file count warning
        local result
        if echo "$output" | grep -q "RESOURCE WARNING.*High number of temp files"; then
            result=0
        else
            result=1
        fi
        
        # Cleanup temp files
        rm -f "${temp_dir}/claude-"*"-$$-test.log" 2>/dev/null || true
        
        return $result
    fi
    
    # Cleanup on failure
    rm -f "${temp_dir}/claude-"*"-$$-test.log" 2>/dev/null || true
    return 1
}

test_large_file_size_warning() {
    # Test large file size warning by creating a large output
    local input='{\"tool\":{\"name\":\"Bash\",\"input\":{\"command\":\"head -c 1048576 /dev/zero | head -1\"}},\"timeout\":null}'
    local output
    
    # Set very low file size threshold to trigger warning
    export CLAUDE_AUTO_TEE_ENABLE_RESOURCE_WARNINGS=true
    export CLAUDE_AUTO_TEE_TEMP_FILE_WARNING_SIZE_MB=0  # Any file should trigger warning
    export CLAUDE_AUTO_TEE_VERBOSE=true
    export CLAUDE_AUTO_TEE_CLEANUP_ON_SUCCESS=false  # Don't clean up so we can check warnings
    
    if output=$(echo "$input" | bash "$HOOK_SCRIPT" 2>&1); then
        # Check for large file warning
        if echo "$output" | grep -q "RESOURCE WARNING.*Large temp file"; then
            return 0
        fi
    fi
    
    return 1
}

test_warning_configuration_validation() {
    # Test that warning configuration is properly validated
    local input='{\"tool\":{\"name\":\"Bash\",\"input\":{\"command\":\"echo test | head -1\"}},\"timeout\":null}'
    local output
    
    # Test with various configuration values
    export CLAUDE_AUTO_TEE_ENABLE_RESOURCE_WARNINGS=true
    export CLAUDE_AUTO_TEE_SPACE_WARNING_THRESHOLD_MB=100
    export CLAUDE_AUTO_TEE_TEMP_FILE_WARNING_SIZE_MB=10
    export CLAUDE_AUTO_TEE_MAX_TEMP_FILES_WARNING=5
    export CLAUDE_AUTO_TEE_VERBOSE=true
    
    if output=$(echo "$input" | bash "$HOOK_SCRIPT" 2>&1); then
        # Check that configuration values are reflected in verbose output
        if echo "$output" | grep -q "disk space threshold: 100MB, file size threshold: 10MB"; then
            return 0
        fi
    fi
    
    return 1
}

# Cleanup function
cleanup_test_environment() {
    # Reset environment variables
    unset CLAUDE_AUTO_TEE_ENABLE_RESOURCE_WARNINGS 2>/dev/null || true
    unset CLAUDE_AUTO_TEE_SPACE_WARNING_THRESHOLD_MB 2>/dev/null || true
    unset CLAUDE_AUTO_TEE_TEMP_FILE_WARNING_SIZE_MB 2>/dev/null || true
    unset CLAUDE_AUTO_TEE_MAX_TEMP_FILES_WARNING 2>/dev/null || true
    unset CLAUDE_AUTO_TEE_VERBOSE 2>/dev/null || true
    unset CLAUDE_AUTO_TEE_CLEANUP_ON_SUCCESS 2>/dev/null || true
    
    # Clean up any leftover temp files
    local temp_dir="${TMPDIR:-/tmp}"
    rm -f "${temp_dir}/claude-"*"-$$-test.log" 2>/dev/null || true
}

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}Resource Usage Warnings Test Suite${NC}"
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}Platform: $(uname -s)${NC}"
echo ""

# Run tests
print_test_result "Resource warnings enabled detection" "$(test_resource_warnings_enabled; echo $?)"
cleanup_test_environment

print_test_result "Resource warnings disabled detection" "$(test_resource_warnings_disabled; echo $?)"
cleanup_test_environment

print_test_result "Disk space warning threshold" "$(test_disk_space_warning_threshold; echo $?)"
cleanup_test_environment

print_test_result "Temp file count warnings" "$(test_temp_file_count_warnings; echo $?)"
cleanup_test_environment

print_test_result "Large file size warning" "$(test_large_file_size_warning; echo $?)"
cleanup_test_environment

print_test_result "Warning configuration validation" "$(test_warning_configuration_validation; echo $?)"
cleanup_test_environment

# Final cleanup
cleanup_test_environment

echo ""
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}Resource Warnings Test Results${NC}"
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}Tests run: $TESTS_RUN${NC}"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo ""
    echo -e "${GREEN}✅ All resource usage warning tests passed!${NC}"
    echo -e "${GREEN}✅ P1.T022 resource monitoring implementation validated${NC}"
    exit 0
else
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo ""
    echo -e "${RED}❌ Some resource usage warning tests failed!${NC}"
    echo -e "${RED}❌ P1.T022 implementation has issues${NC}"
    exit 1
fi