#!/usr/bin/env bash
# Test script for PreToolUse markers functionality
# Validates marker injection, parsing, and edge case handling

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly MARKERS_SCRIPT="$PROJECT_ROOT/src/markers/pretooluse-markers.sh"

# Test configuration
readonly TEST_TEMP_DIR="${TMPDIR:-/tmp}/claude-marker-tests-$$"
readonly VERBOSE_MODE="${CLAUDE_AUTO_TEE_VERBOSE:-false}"

# Colors for output
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup test environment
setup_tests() {
    echo -e "${BLUE}Setting up marker tests...${NC}"
    
    # Create test temp directory
    mkdir -p "$TEST_TEMP_DIR"
    
    # Verify markers script exists and is executable
    if [[ ! -f "$MARKERS_SCRIPT" ]]; then
        echo -e "${RED}ERROR: Markers script not found at $MARKERS_SCRIPT${NC}" >&2
        exit 1
    fi
    
    if [[ ! -x "$MARKERS_SCRIPT" ]]; then
        echo -e "${RED}ERROR: Markers script is not executable${NC}" >&2
        exit 1
    fi
    
    echo -e "${GREEN}✓ Test environment setup complete${NC}"
}

# Cleanup test environment
cleanup_tests() {
    echo -e "${BLUE}Cleaning up test environment...${NC}"
    rm -rf "$TEST_TEMP_DIR"
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Test helper functions
run_test() {
    local test_name="$1"
    shift
    
    ((TESTS_RUN++))
    
    echo -e "${BLUE}Running test: $test_name${NC}"
    
    if "$@"; then
        echo -e "${GREEN}✓ PASS: $test_name${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL: $test_name${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test 1: Basic marker format validation
test_basic_marker_format() {
    local test_path="/tmp/test-file.log"
    local expected_start="###CLAUDE-CAPTURE-START### $test_path ###CLAUDE-CAPTURE-END###"
    local expected_end="###CLAUDE-CAPTURE-END### $test_path ###CLAUDE-CAPTURE-START###"
    
    # Test start marker validation
    if ! "$MARKERS_SCRIPT" validate "$expected_start" >/dev/null 2>&1; then
        echo "Start marker validation failed"
        return 1
    fi
    
    # Test end marker validation
    if ! "$MARKERS_SCRIPT" validate "$expected_end" >/dev/null 2>&1; then
        echo "End marker validation failed"
        return 1
    fi
    
    return 0
}

# Test 2: Path extraction from markers
test_path_extraction() {
    local test_path="/tmp/test-extraction.log"
    local start_marker="###CLAUDE-CAPTURE-START### $test_path ###CLAUDE-CAPTURE-END###"
    local end_marker="###CLAUDE-CAPTURE-END### $test_path ###CLAUDE-CAPTURE-START###"
    
    # Test extracting path from start marker
    local extracted_start
    if ! extracted_start=$("$MARKERS_SCRIPT" parse "$start_marker" 2>/dev/null); then
        echo "Failed to extract path from start marker"
        return 1
    fi
    
    if [[ "$extracted_start" != "$test_path" ]]; then
        echo "Start marker path extraction mismatch: expected '$test_path', got '$extracted_start'"
        return 1
    fi
    
    # Test extracting path from end marker
    local extracted_end
    if ! extracted_end=$("$MARKERS_SCRIPT" parse "$end_marker" 2>/dev/null); then
        echo "Failed to extract path from end marker"
        return 1
    fi
    
    if [[ "$extracted_end" != "$test_path" ]]; then
        echo "End marker path extraction mismatch: expected '$test_path', got '$extracted_end'"
        return 1
    fi
    
    return 0
}

# Test 3: Marker injection functionality
test_marker_injection() {
    local test_path="$TEST_TEMP_DIR/injection-test.log"
    
    # Create test file
    touch "$test_path"
    
    # Test start marker injection - capture stderr
    local start_output
    start_output=$("$MARKERS_SCRIPT" inject "$test_path" start 2>&1 >/dev/null)
    
    # Validate the injected marker
    if ! echo "$start_output" | grep -q "###CLAUDE-CAPTURE-START###"; then
        echo "Start marker not found in injection output"
        return 1
    fi
    
    # Test end marker injection - capture stderr
    local end_output
    end_output=$("$MARKERS_SCRIPT" inject "$test_path" end 2>&1 >/dev/null)
    
    # Validate the injected marker
    if ! echo "$end_output" | grep -q "###CLAUDE-CAPTURE-END###"; then
        echo "End marker not found in injection output"
        return 1
    fi
    
    return 0
}

# Test 4: Marker extraction from text
test_marker_extraction() {
    local test_path="/tmp/extract-test.log"
    local test_text="Some output before
###CLAUDE-CAPTURE-START### $test_path ###CLAUDE-CAPTURE-END###
Command output here
###CLAUDE-CAPTURE-END### $test_path ###CLAUDE-CAPTURE-START###
More output after"
    
    # Test marker extraction
    local extracted_markers
    extracted_markers=$(echo "$test_text" | "$MARKERS_SCRIPT" extract)
    
    # Should find both start and end markers
    local marker_count
    marker_count=$(echo "$extracted_markers" | wc -l | tr -d ' ')
    
    if [[ "$marker_count" -ne 2 ]]; then
        echo "Expected 2 markers, found $marker_count"
        echo "Extracted markers:"
        echo "$extracted_markers"
        return 1
    fi
    
    return 0
}

# Test 5: Unicode path handling
test_unicode_paths() {
    local unicode_path="$TEST_TEMP_DIR/测试文件-тест-🔥.log"
    
    # Create unicode test file
    mkdir -p "$(dirname "$unicode_path")"
    touch "$unicode_path" 2>/dev/null || {
        echo "Skipping unicode test - filesystem doesn't support unicode filenames"
        return 0
    }
    
    # Test marker injection with unicode path
    local marker_output
    marker_output=$("$MARKERS_SCRIPT" inject "$unicode_path" start 2>&1 >/dev/null)
    
    # Validate marker contains the unicode path
    if ! echo "$marker_output" | grep -q "测试文件-тест-🔥"; then
        echo "Unicode characters not preserved in marker"
        return 1
    fi
    
    # Test path extraction with unicode
    local extracted_path
    local raw_extracted_path
    local first_marker
    first_marker=$(echo "$marker_output" | "$MARKERS_SCRIPT" extract | head -1)
    raw_extracted_path=$("$MARKERS_SCRIPT" parse "$first_marker" 2>/dev/null)
    extracted_path=$("$MARKERS_SCRIPT" clean-path "$raw_extracted_path" 2>/dev/null || echo "$raw_extracted_path")
    
    if [[ "$extracted_path" != "$unicode_path" ]]; then
        echo "Unicode path extraction failed: expected '$unicode_path', got '$extracted_path' (raw: '$raw_extracted_path')"
        return 1
    fi
    
    return 0
}

# Test 6: Concurrent execution safety
test_concurrent_execution() {
    local test_path="$TEST_TEMP_DIR/concurrent-test.log"
    local concurrent_outputs=()
    local pids=()
    
    # Launch multiple concurrent marker injections
    for i in {1..5}; do
        {
            "$MARKERS_SCRIPT" inject "$test_path-$i" start 2>&1
            sleep 0.1
            "$MARKERS_SCRIPT" inject "$test_path-$i" end 2>&1
        } &
        pids+=($!)
    done
    
    # Wait for all processes to complete and collect outputs
    for pid in "${pids[@]}"; do
        if wait "$pid"; then
            :  # Process completed successfully
        else
            echo "Concurrent process $pid failed"
            return 1
        fi
    done
    
    return 0
}

# Test 7: Path cleaning functionality
test_path_cleaning() {
    local base_path="/tmp/test-file.log"
    local enriched_path="${base_path}#12345#1609459200000000000"
    
    local cleaned_path
    cleaned_path=$("$MARKERS_SCRIPT" clean-path "$enriched_path")
    
    if [[ "$cleaned_path" != "$base_path" ]]; then
        echo "Path cleaning failed: expected '$base_path', got '$cleaned_path'"
        return 1
    fi
    
    return 0
}

# Test 8: Edge cases and error handling
test_edge_cases() {
    # Test with empty path
    if "$MARKERS_SCRIPT" inject "" start >/dev/null 2>&1; then
        echo "Should have failed with empty path"
        return 1
    fi
    
    # Test with invalid marker format
    if "$MARKERS_SCRIPT" validate "invalid-marker-format" >/dev/null 2>&1; then
        echo "Should have failed with invalid marker format"
        return 1
    fi
    
    # Test path extraction from invalid marker
    if "$MARKERS_SCRIPT" parse "invalid-marker" >/dev/null 2>&1; then
        echo "Should have failed to parse invalid marker"
        return 1
    fi
    
    return 0
}

# Test 9: Marker disable functionality
test_marker_disable() {
    local test_path="$TEST_TEMP_DIR/disable-test.log"
    
    # Disable markers via environment variable
    local output
    output=$(CLAUDE_AUTO_TEE_ENABLE_MARKERS=false "$MARKERS_SCRIPT" inject "$test_path" start 2>&1 >/dev/null)
    
    # Should produce no output when disabled
    if [[ -n "$output" ]] && echo "$output" | grep -q "###CLAUDE-CAPTURE"; then
        echo "Markers were not properly disabled"
        return 1
    fi
    
    return 0
}

# Test 10: Integration test with realistic paths
test_realistic_paths() {
    local realistic_paths=(
        "/Users/john/Documents/project/output.log"
        "/home/user/.cache/claude/temp-12345.log"
        "/tmp/claude-auto-tee-987654321.log"
        "./relative/path/file.log"
        "../parent/directory/file.log"
    )
    
    for path in "${realistic_paths[@]}"; do
        # Test marker creation and validation
        local marker
        marker=$("$MARKERS_SCRIPT" inject "$path" start 2>&1 >/dev/null)
        
        # Validate marker format
        if ! echo "$marker" | "$MARKERS_SCRIPT" extract | head -1 | xargs "$MARKERS_SCRIPT" validate >/dev/null 2>&1; then
            echo "Realistic path test failed for: $path"
            return 1
        fi
        
        # Test path extraction
        local extracted
        extracted=$(echo "$marker" | "$MARKERS_SCRIPT" extract | head -1 | "$MARKERS_SCRIPT" parse /dev/stdin 2>/dev/null)
        
        # Paths should match (allowing for normalization)
        if [[ -z "$extracted" ]]; then
            echo "Path extraction failed for: $path"
            return 1
        fi
    done
    
    return 0
}

# Run all tests
run_all_tests() {
    echo -e "${BLUE}=== Claude Auto-Tee Marker Tests ===${NC}"
    echo ""
    
    setup_tests
    
    # Run individual tests
    run_test "Basic marker format validation" test_basic_marker_format
    run_test "Path extraction from markers" test_path_extraction  
    run_test "Marker injection functionality" test_marker_injection
    run_test "Marker extraction from text" test_marker_extraction
    run_test "Unicode path handling" test_unicode_paths
    run_test "Concurrent execution safety" test_concurrent_execution
    run_test "Path cleaning functionality" test_path_cleaning
    run_test "Edge cases and error handling" test_edge_cases
    run_test "Marker disable functionality" test_marker_disable
    run_test "Integration test with realistic paths" test_realistic_paths
    
    cleanup_tests
    
    # Print summary
    echo ""
    echo -e "${BLUE}=== Test Summary ===${NC}"
    echo -e "Tests run: $TESTS_RUN"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        return 1
    fi
}

# Main execution
main() {
    local command="${1:-run}"
    
    case "$command" in
        run)
            run_all_tests
            ;;
        setup)
            setup_tests
            ;;
        cleanup)
            cleanup_tests
            ;;
        single)
            local test_name="$2"
            setup_tests
            case "$test_name" in
                basic) run_test "Basic marker format validation" test_basic_marker_format ;;
                extraction) run_test "Path extraction from markers" test_path_extraction ;;
                injection) run_test "Marker injection functionality" test_marker_injection ;;
                text) run_test "Marker extraction from text" test_marker_extraction ;;
                unicode) run_test "Unicode path handling" test_unicode_paths ;;
                concurrent) run_test "Concurrent execution safety" test_concurrent_execution ;;
                cleaning) run_test "Path cleaning functionality" test_path_cleaning ;;
                edge) run_test "Edge cases and error handling" test_edge_cases ;;
                disable) run_test "Marker disable functionality" test_marker_disable ;;
                realistic) run_test "Integration test with realistic paths" test_realistic_paths ;;
                *) echo "Unknown test: $test_name" >&2; return 1 ;;
            esac
            cleanup_tests
            ;;
        *)
            echo "Usage: $0 [run|setup|cleanup|single <test_name>]" >&2
            echo "" >&2
            echo "Commands:" >&2
            echo "  run      - Run all tests (default)" >&2
            echo "  setup    - Setup test environment only" >&2
            echo "  cleanup  - Cleanup test environment only" >&2
            echo "  single   - Run a single test by name" >&2
            echo "" >&2
            echo "Available tests for 'single' command:" >&2
            echo "  basic, extraction, injection, text, unicode, concurrent," >&2
            echo "  cleaning, edge, disable, realistic" >&2
            return 1
            ;;
    esac
}

# Trap to ensure cleanup on exit
trap cleanup_tests EXIT

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi