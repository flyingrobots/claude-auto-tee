#!/usr/bin/env bash
# Comprehensive test suite for age-based orphaned file cleanup (P1.T015)

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
readonly HOOK_SCRIPT="$PROJECT_ROOT/src/claude-auto-tee.sh"

# Create a temp directory for our tests
readonly TEST_TEMP_DIR="/tmp/claude-cleanup-test-$$-$RANDOM"

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
            echo -e "  ${YELLOW}Details:${NC} $details"
        fi
        ((failed_count++))
    fi
}

# Helper function to create test temp files with specific ages
create_test_file() {
    local filename="$1"
    local age_hours="$2"
    local content="${3:-test content}"
    
    # Create the file
    echo "$content" > "$TEST_TEMP_DIR/$filename"
    
    # Set the modification time to simulate age
    local target_time
    target_time=$(date -d "$age_hours hours ago" +%s 2>/dev/null || date -r $(($(date +%s) - age_hours * 3600)) +%s 2>/dev/null || echo "0")
    
    # Use touch to set the modification time
    if [[ "$target_time" != "0" ]]; then
        if touch -t "$(date -d "@$target_time" +%Y%m%d%H%M.%S 2>/dev/null)" "$TEST_TEMP_DIR/$filename" 2>/dev/null; then
            return 0
        elif touch -r <(date -d "@$target_time" 2>/dev/null) "$TEST_TEMP_DIR/$filename" 2>/dev/null; then
            return 0  
        fi
    fi
    
    # If we can't set the time precisely, just create the file
    # Some tests may need manual validation
    return 0
}

# Helper function to test the hook with cleanup configuration
test_cleanup_with_config() {
    local enable_cleanup="$1"
    local cleanup_age_hours="$2"
    local temp_dir="$3"
    local input_json="${4:-}"
    
    # Default input if not provided
    if [[ -z "$input_json" ]]; then
        input_json='{"tool":{"name":"Bash","input":{"command":"echo test | cat"}},"timeout":null}'
    fi
    
    local temp_output
    temp_output=$(mktemp)
    
    # Run the hook with specific cleanup configuration
    local result=0
    if env -i bash -c "
        export CLAUDE_AUTO_TEE_ENABLE_AGE_CLEANUP='$enable_cleanup'
        export CLAUDE_AUTO_TEE_CLEANUP_AGE_HOURS='$cleanup_age_hours'
        export CLAUDE_AUTO_TEE_TEMP_DIR='$temp_dir'
        export CLAUDE_AUTO_TEE_VERBOSE=true
        '$HOOK_SCRIPT'
    " <<< "$input_json" > "$temp_output" 2>&1; then
        result=0
    else
        result=$?
    fi
    
    local output
    output=$(cat "$temp_output")
    rm -f "$temp_output"
    
    echo "$output"
    return $result
}

# Setup function
setup_test_environment() {
    echo -e "${BLUE}Setting up test environment...${NC}"
    
    # Create test temp directory
    mkdir -p "$TEST_TEMP_DIR"
    
    # Verify hook script exists
    if [[ ! -f "$HOOK_SCRIPT" ]]; then
        echo -e "${RED}ERROR: Hook script not found at $HOOK_SCRIPT${NC}"
        exit 1
    fi
    
    echo "Test temp directory: $TEST_TEMP_DIR"
}

# Cleanup function
cleanup_test_environment() {
    echo -e "${BLUE}Cleaning up test environment...${NC}"
    
    # Remove test temp directory and all contents
    if [[ -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
        echo "Removed test temp directory: $TEST_TEMP_DIR"
    fi
}

# Trap to ensure cleanup on script exit
trap cleanup_test_environment EXIT

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}Age-Based Cleanup Test Suite (P1.T015)${NC}"
echo -e "${BLUE}=====================================${NC}"
echo
echo "Platform: $(uname -s 2>/dev/null || echo Unknown)"
echo

# Setup test environment
setup_test_environment

# Test 1: Verify cleanup is enabled by default
echo -e "${BLUE}=== Test 1: Default Cleanup Configuration ===${NC}"
output=$(test_cleanup_with_config "" "" "$TEST_TEMP_DIR")

if echo "$output" | grep -q "Running startup orphaned file cleanup"; then
    print_test_result "Age-based cleanup enabled by default" "PASS"
else
    print_test_result "Age-based cleanup enabled by default" "FAIL" "Startup cleanup not detected"
fi

# Test 2: Verify cleanup can be disabled
echo
echo -e "${BLUE}=== Test 2: Disable Age-Based Cleanup ===${NC}"
output=$(test_cleanup_with_config "false" "" "$TEST_TEMP_DIR")

if echo "$output" | grep -q "Age-based cleanup disabled"; then
    print_test_result "Age-based cleanup can be disabled" "PASS"
else
    print_test_result "Age-based cleanup can be disabled" "FAIL" "Cleanup disable not detected"
fi

# Test 3: Create old files and verify they get cleaned up
echo
echo -e "${BLUE}=== Test 3: Cleanup of Old Files ===${NC}"

# Create test files with different ages
create_test_file "claude-old1.log" -50 "old file 1"      # 50 hours ago (should be cleaned)
create_test_file "claude-old2.log" -25 "recent file"     # 25 hours ago (should NOT be cleaned)
create_test_file "other-old.log" -100 "other old file"   # 100 hours ago but wrong prefix (should NOT be cleaned)

# Count files before cleanup
files_before=$(find "$TEST_TEMP_DIR" -name "*.log" | wc -l)

# Run cleanup with default 48-hour threshold
output=$(test_cleanup_with_config "true" "48" "$TEST_TEMP_DIR")

# Count files after cleanup
files_after=$(find "$TEST_TEMP_DIR" -name "*.log" | wc -l)

# Verify expected files remain
if [[ -f "$TEST_TEMP_DIR/claude-old2.log" ]] && [[ -f "$TEST_TEMP_DIR/other-old.log" ]] && [[ ! -f "$TEST_TEMP_DIR/claude-old1.log" ]]; then
    print_test_result "Old files cleaned up correctly" "PASS" "Files before: $files_before, after: $files_after"
else
    print_test_result "Old files cleaned up correctly" "FAIL" "Unexpected file cleanup results"
    # Show what files remain for debugging
    echo -e "  ${YELLOW}Remaining files:${NC}"
    find "$TEST_TEMP_DIR" -name "*.log" -exec echo "    {}" \; 2>/dev/null || echo "    (none)"
fi

# Test 4: Custom age threshold
echo
echo -e "${BLUE}=== Test 4: Custom Age Threshold ===${NC}"

# Clean up previous test files
rm -f "$TEST_TEMP_DIR"/*.log

# Create files with specific ages for 24-hour threshold test
create_test_file "claude-25hours.log" -25 "25 hour old file"   # Should be cleaned with 24h threshold
create_test_file "claude-20hours.log" -20 "20 hour old file"   # Should NOT be cleaned with 24h threshold

# Run cleanup with 24-hour threshold
output=$(test_cleanup_with_config "true" "24" "$TEST_TEMP_DIR")

# Check results
if echo "$output" | grep -q "age threshold: 24h"; then
    if [[ ! -f "$TEST_TEMP_DIR/claude-25hours.log" ]] && [[ -f "$TEST_TEMP_DIR/claude-20hours.log" ]]; then
        print_test_result "Custom age threshold (24h) works correctly" "PASS"
    else
        print_test_result "Custom age threshold (24h) works correctly" "FAIL" "Files not cleaned according to 24h threshold"
    fi
else
    print_test_result "Custom age threshold (24h) works correctly" "FAIL" "24h threshold not detected in output"
fi

# Test 5: Invalid age threshold handling
echo
echo -e "${BLUE}=== Test 5: Invalid Age Threshold Handling ===${NC}"
output=$(test_cleanup_with_config "true" "invalid" "$TEST_TEMP_DIR")

if echo "$output" | grep -q "Invalid age hours for cleanup.*using default: 48"; then
    print_test_result "Invalid age threshold falls back to default" "PASS"
else
    print_test_result "Invalid age threshold falls back to default" "FAIL" "Default fallback not detected"
fi

# Test 6: Empty temp directory handling
echo
echo -e "${BLUE}=== Test 6: Empty Temp Directory Handling ===${NC}"

# Clean up all test files
rm -f "$TEST_TEMP_DIR"/*.log

output=$(test_cleanup_with_config "true" "48" "$TEST_TEMP_DIR")

if echo "$output" | grep -q "No orphaned files found for cleanup"; then
    print_test_result "Empty temp directory handled correctly" "PASS"
else
    print_test_result "Empty temp directory handled correctly" "FAIL" "Empty directory message not found"
fi

# Test 7: Multiple temp directories
echo
echo -e "${BLUE}=== Test 7: Multiple Temp Directory Cleanup ===${NC}"

# Create another temp directory to test multiple directory cleanup
readonly TEST_TEMP_DIR2="/tmp/claude-cleanup-test2-$$-$RANDOM"
mkdir -p "$TEST_TEMP_DIR2"

# Create old files in both directories
create_test_file "claude-multi1.log" -50 "multi dir file 1"
echo "multi dir file 2" > "$TEST_TEMP_DIR2/claude-multi2.log"

# Set old timestamp on the second file manually (simplified)
touch -t "$(date -d '50 hours ago' +%Y%m%d%H%M.%S 2>/dev/null || date +%Y%m%d%H%M.%S)" "$TEST_TEMP_DIR2/claude-multi2.log" 2>/dev/null || true

# Run cleanup - it should check standard temp directories
output=$(test_cleanup_with_config "true" "48" "$TEST_TEMP_DIR")

if echo "$output" | grep -q "Checking.*temp directories for orphaned files"; then
    print_test_result "Multiple temp directories are checked" "PASS"
else
    print_test_result "Multiple temp directories are checked" "FAIL" "Multiple directory checking not detected"
fi

# Clean up second test directory
rm -rf "$TEST_TEMP_DIR2" 2>/dev/null || true

# Test 8: Verbose logging during cleanup
echo
echo -e "${BLUE}=== Test 8: Verbose Logging During Cleanup ===${NC}"

# Create a file that should be cleaned up
create_test_file "claude-verbose.log" -50 "verbose test file"

output=$(test_cleanup_with_config "true" "48" "$TEST_TEMP_DIR")

if echo "$output" | grep -q "Starting orphaned file cleanup" && echo "$output" | grep -q "Cleanup cutoff time"; then
    print_test_result "Verbose logging shows cleanup details" "PASS"
else
    print_test_result "Verbose logging shows cleanup details" "FAIL" "Verbose cleanup details not found"
fi

# Test 9: File safety checks (basic)
echo
echo -e "${BLUE}=== Test 9: File Safety Checks ===${NC}"

# Create a very recent file (should not be cleaned due to safety)
echo "recent file" > "$TEST_TEMP_DIR/claude-recent.log"
# This file will have current timestamp, so should be considered "too recent"

output=$(test_cleanup_with_config "true" "1" "$TEST_TEMP_DIR")  # Very aggressive 1-hour cleanup

if [[ -f "$TEST_TEMP_DIR/claude-recent.log" ]]; then
    print_test_result "Recent files protected from cleanup" "PASS" "Recent file correctly preserved"
else
    print_test_result "Recent files protected from cleanup" "FAIL" "Recent file was incorrectly removed"
fi

# Test 10: Configuration validation
echo
echo -e "${BLUE}=== Test 10: Configuration Validation ===${NC}"

# Test various configuration combinations
test_configs=(
    "true:48:should work"
    "false:24:should disable"
    "true:0:should use default"
    "invalid:48:should enable with default age"
)

all_validation_passed=true

for config in "${test_configs[@]}"; do
    IFS=':' read -r enable_val age_val expected <<< "$config"
    
    output=$(test_cleanup_with_config "$enable_val" "$age_val" "$TEST_TEMP_DIR")
    
    case "$expected" in
        "should work")
            if echo "$output" | grep -q "Running startup orphaned file cleanup" && echo "$output" | grep -q "age threshold: 48h"; then
                continue  # Pass
            else
                all_validation_passed=false
                break
            fi
            ;;
        "should disable")
            if echo "$output" | grep -q "Age-based cleanup disabled"; then
                continue  # Pass
            else
                all_validation_passed=false
                break
            fi
            ;;
        "should use default")
            if echo "$output" | grep -q "using default: 48"; then
                continue  # Pass
            else
                all_validation_passed=false
                break
            fi
            ;;
        "should enable with default age")
            if echo "$output" | grep -q "Running startup orphaned file cleanup"; then
                continue  # Pass
            else
                all_validation_passed=false
                break
            fi
            ;;
    esac
done

if [[ "$all_validation_passed" == "true" ]]; then
    print_test_result "Configuration validation works correctly" "PASS"
else
    print_test_result "Configuration validation works correctly" "FAIL" "Some configuration combinations failed"
fi

# Final results
echo
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}Age-Based Cleanup Test Results${NC}"
echo -e "${BLUE}============================================${NC}"
echo "Total tests: $test_count"
echo -e "Passed: ${GREEN}$passed_count${NC}"
echo -e "Failed: ${RED}$failed_count${NC}"

if [[ $failed_count -eq 0 ]]; then
    echo -e "\n${GREEN}All age-based cleanup tests passed!${NC}"
    echo -e "${GREEN}P1.T015 implementation appears robust${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed. Please check the implementation.${NC}"
    exit 1
fi