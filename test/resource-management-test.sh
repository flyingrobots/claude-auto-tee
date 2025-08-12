#!/usr/bin/env bash
# Resource Management Test Suite
# Tests temp directory handling, cleanup, and resource monitoring

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Test results tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if eval "$test_command"; then
        echo "✓ $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

run_test_file_exists() {
    local test_name="$1"
    local file_path="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ -f "$file_path" ]]; then
        echo "✓ $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ $test_name - File does not exist: $file_path"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

run_test_dir_exists() {
    local test_name="$1"
    local dir_path="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ -d "$dir_path" ]]; then
        echo "✓ $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ $test_name - Directory does not exist: $dir_path"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo "======================================="
echo "Resource Management Test Suite"
echo "======================================="

echo "=== Test 1: Temp Directory Detection ==="
# Test that the system can find suitable temp directories
if [[ -d "/tmp" ]]; then
    run_test_dir_exists "System /tmp directory exists" "/tmp"
elif [[ -n "${TEMP:-}" && -d "$TEMP" ]]; then
    run_test_dir_exists "Windows TEMP directory exists" "$TEMP"
elif [[ -n "${TMPDIR:-}" && -d "$TMPDIR" ]]; then
    run_test_dir_exists "TMPDIR environment variable directory exists" "$TMPDIR"
else
    echo "✗ No suitable temp directory found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
fi

echo "=== Test 2: Temp File Creation ==="
# Test temp file creation capabilities
temp_file=$(mktemp "${TMPDIR:-/tmp}/claude-resource-test-XXXXXX" 2>/dev/null || echo "")
if [[ -n "$temp_file" && -f "$temp_file" ]]; then
    echo "✓ Can create temp files with claude naming pattern"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    
    # Test writing to temp file
    if echo "test content" > "$temp_file" 2>/dev/null; then
        echo "✓ Can write to temp files"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        
        # Test reading from temp file
        if [[ "$(cat "$temp_file" 2>/dev/null)" == "test content" ]]; then
            echo "✓ Can read from temp files"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo "✗ Cannot read from temp files"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        echo "✗ Cannot write to temp files"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    # Test cleanup
    if rm "$temp_file" 2>/dev/null; then
        echo "✓ Can cleanup temp files"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ Cannot cleanup temp files"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    echo "✗ Cannot create temp files"
    TESTS_FAILED=$((TESTS_FAILED + 4))  # Failed creation cascades to other failures
fi
TESTS_RUN=$((TESTS_RUN + 4))

echo "=== Test 3: Disk Space Checking ==="
# Test disk space availability checking
temp_dir="${TMPDIR:-/tmp}"
if command -v df >/dev/null 2>&1; then
    space_info=$(df -h "$temp_dir" 2>/dev/null | tail -1 || echo "")
    if [[ -n "$space_info" ]]; then
        echo "✓ Can check disk space availability"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        
        # Extract available space (4th column)
        available_space=$(echo "$space_info" | awk '{print $4}')
        if [[ -n "$available_space" && "$available_space" != "0" ]]; then
            echo "✓ Temp directory has available space: $available_space"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo "✗ Temp directory appears to have no available space"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        echo "✗ Cannot get disk space information"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    echo "✗ df command not available for disk space checking"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 2))

echo "=== Test 4: Permission Validation ==="
# Test directory and file permissions
temp_dir="${TMPDIR:-/tmp}"
if [[ -w "$temp_dir" ]]; then
    echo "✓ Temp directory is writable"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "✗ Temp directory is not writable"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

if [[ -r "$temp_dir" ]]; then
    echo "✓ Temp directory is readable"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "✗ Temp directory is not readable"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 2))

echo "=== Test 5: Alternative Temp Location Fallback ==="
# Test finding alternative temp locations when primary fails
alternative_locations=(
    "$HOME/tmp"
    "$HOME/.cache/tmp"
    "./tmp"
    "$PWD/tmp"
)

found_alternative=false
for location in "${alternative_locations[@]}"; do
    if mkdir -p "$location" 2>/dev/null && [[ -w "$location" ]]; then
        echo "✓ Alternative temp location available: $location"
        found_alternative=true
        rmdir "$location" 2>/dev/null || true  # Cleanup if we created it
        break
    fi
done

if $found_alternative; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "✗ No alternative temp locations available"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

echo "=== Test 6: Cleanup Pattern Testing ==="
# Test that cleanup patterns work correctly
test_cleanup_dir="${TMPDIR:-/tmp}/claude-cleanup-test-$$"
mkdir -p "$test_cleanup_dir" || true

if [[ -d "$test_cleanup_dir" ]]; then
    # Create some test files
    touch "$test_cleanup_dir/test1.txt" "$test_cleanup_dir/test2.log" 2>/dev/null || true
    
    # Test selective cleanup (remove .log files)
    find "$test_cleanup_dir" -name "*.log" -delete 2>/dev/null || true
    
    if [[ -f "$test_cleanup_dir/test1.txt" && ! -f "$test_cleanup_dir/test2.log" ]]; then
        echo "✓ Selective cleanup works correctly"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ Selective cleanup failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    # Full cleanup
    rm -rf "$test_cleanup_dir" 2>/dev/null || true
    if [[ ! -d "$test_cleanup_dir" ]]; then
        echo "✓ Full cleanup works correctly"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ Full cleanup failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    echo "✗ Cannot create test cleanup directory"
    TESTS_FAILED=$((TESTS_FAILED + 2))
fi
TESTS_RUN=$((TESTS_RUN + 2))

echo "=== Test 7: Resource Usage Monitoring ==="
# Test resource usage detection capabilities
if command -v du >/dev/null 2>&1; then
    temp_usage=$(du -sh "${TMPDIR:-/tmp}" 2>/dev/null | awk '{print $1}' || echo "unknown")
    if [[ -n "$temp_usage" && "$temp_usage" != "unknown" ]]; then
        echo "✓ Can monitor temp directory usage: $temp_usage"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ Cannot monitor temp directory usage"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    echo "✗ du command not available for usage monitoring"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

echo "=== Test 8: Large File Handling Preparation ==="
# Test system's capability to handle potentially large files
large_file_test="${TMPDIR:-/tmp}/claude-large-test-$$"
if dd if=/dev/zero of="$large_file_test" bs=1024 count=1024 2>/dev/null; then
    echo "✓ Can create 1MB test files"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    
    # Test file size detection
    if [[ -f "$large_file_test" ]]; then
        file_size=$(wc -c < "$large_file_test" 2>/dev/null || echo "0")
        if [[ "$file_size" -eq 1048576 ]]; then  # 1MB = 1048576 bytes
            echo "✓ File size detection accurate"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo "✗ File size detection inaccurate (got $file_size, expected 1048576)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        echo "✗ Large test file was not created"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    # Cleanup
    rm -f "$large_file_test" 2>/dev/null || true
else
    echo "✗ Cannot create large test files - may indicate resource constraints"
    TESTS_FAILED=$((TESTS_FAILED + 2))
fi
TESTS_RUN=$((TESTS_RUN + 2))

echo "=== Test 9: Platform-Specific Temp Handling ==="
# Test platform-specific temp directory behavior
platform=$(uname -s 2>/dev/null || echo "Unknown")
echo "✓ Platform detected: $platform"
TESTS_PASSED=$((TESTS_PASSED + 1))

case "$platform" in
    "Darwin")  # macOS
        if [[ -d "/private/tmp" ]]; then
            echo "✓ macOS private temp directory exists"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo "✗ macOS private temp directory missing"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
        ;;
    "Linux")
        if [[ -d "/tmp" && -k "/tmp" ]]; then  # Check for sticky bit
            echo "✓ Linux /tmp has sticky bit set"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo "✗ Linux /tmp missing or no sticky bit"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
        ;;
    *)
        echo "✓ Unknown/Other platform temp handling (basic validation passed)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        ;;
esac
TESTS_RUN=$((TESTS_RUN + 2))

echo "======================================="
echo "Test Results:"
echo "  Tests run: $TESTS_RUN"
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"
echo "======================================="

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "✓ All resource management tests passed!"
    exit 0
else
    echo "✗ Some resource management tests failed!"
    exit 1
fi