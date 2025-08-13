#!/usr/bin/env bash
# PreToolUse Markers - Inject structured markers for PostToolUse hook
# Format: '###CLAUDE-CAPTURE-START### PATH ###CLAUDE-CAPTURE-END###'

set -euo pipefail
IFS=$'\n\t'

# Environment variable configuration (define early) - avoid conflicts
if [[ -z "${ENABLE_MARKERS:-}" ]]; then
    readonly ENABLE_MARKERS="${CLAUDE_AUTO_TEE_ENABLE_MARKERS:-true}"
fi
# Note: VERBOSE_MODE will be set by main script - don't define as readonly here
if [[ -z "${VERBOSE_MODE:-}" ]]; then
    VERBOSE_MODE="${CLAUDE_AUTO_TEE_VERBOSE:-false}"
fi

# Verbose logging function (define early for use in sourcing)
log_verbose() {
    if [[ "$VERBOSE_MODE" == "true" ]] || [[ "${CLAUDE_AUTO_TEE_VERBOSE:-false}" == "true" ]]; then
        echo "[CLAUDE-MARKERS] $1" >&2
    fi
}

# Source required modules
if [[ -z "${SCRIPT_DIR:-}" ]]; then
    readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Source required modules with conflict protection
if [[ -z "${ERR_INVALID_INPUT:-}" ]]; then
    # Only source if not already loaded
    if [[ -f "${SCRIPT_DIR}/../error-codes.sh" ]]; then
        source "${SCRIPT_DIR}/../error-codes.sh" 2>/dev/null || true
    elif [[ -f "${SCRIPT_DIR}/error-codes.sh" ]]; then
        source "${SCRIPT_DIR}/error-codes.sh" 2>/dev/null || true
    fi
fi

if ! command -v normalize_path >/dev/null 2>&1; then
    # Only source path-utils if normalize_path function is not available
    if [[ -f "${SCRIPT_DIR}/../path-utils.sh" ]]; then
        source "${SCRIPT_DIR}/../path-utils.sh" 2>/dev/null || true
    elif [[ -f "${SCRIPT_DIR}/path-utils.sh" ]]; then
        source "${SCRIPT_DIR}/path-utils.sh" 2>/dev/null || true
    fi
fi

# Source env-exporter context for capture path prediction
if [[ -z "${ENV_EXPORTER_AVAILABLE:-}" ]]; then
    if [[ -x "${SCRIPT_DIR}/../env/environment-exporter.js" ]]; then
        readonly ENV_EXPORTER_AVAILABLE=true
        log_verbose "Environment exporter available for context"
    else
        readonly ENV_EXPORTER_AVAILABLE=false
        log_verbose "Environment exporter not available - using fallback path prediction"
    fi
fi

# Marker format constants - Task specification format (avoid conflicts)
if [[ -z "${MARKER_FORMAT:-}" ]]; then
    MARKER_FORMAT="# CAPTURE_START:"
fi
if [[ -z "${MARKER_END_FORMAT:-}" ]]; then
    MARKER_END_FORMAT="# CAPTURE_END:"
fi
if [[ -z "${MARKER_SEPARATOR:-}" ]]; then
    MARKER_SEPARATOR=" "
fi

# Legacy marker constants for backward compatibility (avoid conflicts)
if [[ -z "${LEGACY_MARKER_START:-}" ]]; then
    LEGACY_MARKER_START="###CLAUDE-CAPTURE-START###"
fi
if [[ -z "${LEGACY_MARKER_END:-}" ]]; then
    LEGACY_MARKER_END="###CLAUDE-CAPTURE-END###"
fi

# Predict capture path using the same logic as main script
predict_capture_path() {
    local temp_dir="$1"
    local temp_file_prefix="${2:-claude}"
    
    if [[ -z "$temp_dir" ]]; then
        log_verbose "Warning: No temp directory provided for path prediction"
        return 1
    fi
    
    # Use the same timestamp-based path generation as claude-auto-tee.sh
    local predicted_path="${temp_dir}/${temp_file_prefix}-$(date +%s%N | cut -b1-13).log"
    
    # Normalize path for consistency
    if command -v normalize_path >/dev/null 2>&1; then
        if normalized_path=$(normalize_path "$predicted_path" 2>/dev/null); then
            predicted_path="$normalized_path"
        fi
    fi
    
    echo "$predicted_path"
    return 0
}

# Inject capture start marker to stderr with task-specified format
inject_capture_start_marker() {
    local temp_file_path="$1"
    
    if [[ "$ENABLE_MARKERS" != "true" ]]; then
        log_verbose "Markers disabled - skipping injection"
        return 0
    fi
    
    # Validate path parameter
    if [[ -z "$temp_file_path" ]]; then
        log_verbose "Warning: No temp file path provided to marker injection"
        return 1
    fi
    
    # Normalize path to ensure consistent format across platforms
    local normalized_path
    if normalized_path=$(normalize_path "$temp_file_path" 2>/dev/null); then
        temp_file_path="$normalized_path"
    fi
    
    # Construct marker with task-specified format: "# CAPTURE_START: <predicted_path>"
    local marker="${MARKER_FORMAT} ${temp_file_path}"
    
    # Inject marker to stderr in a way that doesn't interfere with command execution
    # Use a background process to avoid blocking the main command
    echo "$marker" >&2 &
    
    log_verbose "Injected capture start marker: $marker"
    return 0
}

# Inject capture end marker to stderr with task-specified format
inject_capture_end_marker() {
    local temp_file_path="$1"
    
    if [[ "$ENABLE_MARKERS" != "true" ]]; then
        log_verbose "Markers disabled - skipping injection"
        return 0
    fi
    
    # Validate path parameter
    if [[ -z "$temp_file_path" ]]; then
        log_verbose "Warning: No temp file path provided to marker injection"
        return 1
    fi
    
    # Normalize path to ensure consistent format
    local normalized_path
    if normalized_path=$(normalize_path "$temp_file_path" 2>/dev/null); then
        temp_file_path="$normalized_path"
    fi
    
    # Construct end marker with task-specified format: "# CAPTURE_END: <path>"
    local marker="${MARKER_END_FORMAT} ${temp_file_path}"
    
    # Inject marker to stderr in background
    echo "$marker" >&2 &
    
    log_verbose "Injected capture end marker: $marker"
    return 0
}

# Extract markers from stderr for testing/validation (supports both formats)
extract_markers_from_text() {
    local text="$1"
    local marker_type="${2:-all}"
    
    case "$marker_type" in
        start)
            # Extract task-specified format first, then legacy format
            {
                echo "$text" | grep -oE "${MARKER_FORMAT} [^\r\n]+" || true
                echo "$text" | grep -oE "${LEGACY_MARKER_START}${MARKER_SEPARATOR}[^${MARKER_SEPARATOR}]+${MARKER_SEPARATOR}${LEGACY_MARKER_END}" || true
            }
            ;;
        end)
            # Extract task-specified format first, then legacy format
            {
                echo "$text" | grep -oE "${MARKER_END_FORMAT} [^\r\n]+" || true
                echo "$text" | grep -oE "${LEGACY_MARKER_END}${MARKER_SEPARATOR}[^${MARKER_SEPARATOR}]+${MARKER_SEPARATOR}${LEGACY_MARKER_START}" || true
            }
            ;;
        all|*)
            # Extract all markers
            {
                extract_markers_from_text "$text" "start"
                extract_markers_from_text "$text" "end"
            }
            ;;
    esac
}

# Parse path from marker (supports both task-specified and legacy formats)
parse_path_from_marker() {
    local marker="$1"
    
    # Extract path from task-specified start marker format: "# CAPTURE_START: <path>"
    if echo "$marker" | grep -qE "^${MARKER_FORMAT} "; then
        echo "$marker" | sed -E "s/^${MARKER_FORMAT} (.+)$/\1/"
        return 0
    fi
    
    # Extract path from task-specified end marker format: "# CAPTURE_END: <path>"
    if echo "$marker" | grep -qE "^${MARKER_END_FORMAT} "; then
        echo "$marker" | sed -E "s/^${MARKER_END_FORMAT} (.+)$/\1/"
        return 0
    fi
    
    # Extract path from legacy start marker format
    if echo "$marker" | grep -qE "^${LEGACY_MARKER_START}${MARKER_SEPARATOR}"; then
        echo "$marker" | sed -E "s/^${LEGACY_MARKER_START}${MARKER_SEPARATOR}(.+)${MARKER_SEPARATOR}${LEGACY_MARKER_END}$/\1/"
        return 0
    fi
    
    # Extract path from legacy end marker format
    if echo "$marker" | grep -qE "^${LEGACY_MARKER_END}${MARKER_SEPARATOR}"; then
        echo "$marker" | sed -E "s/^${LEGACY_MARKER_END}${MARKER_SEPARATOR}(.+)${MARKER_SEPARATOR}${LEGACY_MARKER_START}$/\1/"
        return 0
    fi
    
    return 1
}

# Validate marker format (supports both task-specified and legacy formats)
validate_marker_format() {
    local marker="$1"
    
    # Check task-specified start marker format: "# CAPTURE_START: <path>"
    if echo "$marker" | grep -qE "^${MARKER_FORMAT} .+$"; then
        return 0
    fi
    
    # Check task-specified end marker format: "# CAPTURE_END: <path>"
    if echo "$marker" | grep -qE "^${MARKER_END_FORMAT} .+$"; then
        return 0
    fi
    
    # Check legacy start marker format
    if echo "$marker" | grep -qE "^${LEGACY_MARKER_START}${MARKER_SEPARATOR}.+${MARKER_SEPARATOR}${LEGACY_MARKER_END}$"; then
        return 0
    fi
    
    # Check legacy end marker format
    if echo "$marker" | grep -qE "^${LEGACY_MARKER_END}${MARKER_SEPARATOR}.+${MARKER_SEPARATOR}${LEGACY_MARKER_START}$"; then
        return 0
    fi
    
    return 1
}

# Main function for PreToolUse hook - injects markers with pipe detection
inject_pretooluse_marker() {
    local command="$1"
    local temp_dir="$2"
    local temp_file_prefix="${3:-claude}"
    
    if [[ "$ENABLE_MARKERS" != "true" ]]; then
        log_verbose "PreToolUse markers disabled - skipping injection"
        return 0
    fi
    
    # Validate required parameters
    if [[ -z "$command" ]]; then
        log_verbose "Warning: No command provided to PreToolUse marker injection"
        return 1
    fi
    
    if [[ -z "$temp_dir" ]]; then
        log_verbose "Warning: No temp directory provided to PreToolUse marker injection"
        return 1
    fi
    
    # Detect if command has pipes (same logic as main script)
    local pipe_count
    if ! pipe_count=$(detect_safe_pipes_in_command "$command" 2>/dev/null); then
        log_verbose "Failed to detect pipes in command - skipping marker injection"
        return 1
    fi
    
    # Only inject markers for commands with pipes (where tee will be injected)
    if [[ "$pipe_count" -eq 0 ]]; then
        log_verbose "No pipes detected in command - skipping PreToolUse marker injection"
        return 0
    fi
    
    if [[ "$pipe_count" -ne 1 ]]; then
        log_verbose "Multiple pipes detected ($pipe_count) - skipping PreToolUse marker injection for security"
        return 0
    fi
    
    # Check if command already has tee (same logic as main script)
    if echo "$command" | grep -q "tee "; then
        log_verbose "Command already contains tee - skipping PreToolUse marker injection"
        return 0
    fi
    
    # Predict the capture path using same logic as main script
    local predicted_path
    if ! predicted_path=$(predict_capture_path "$temp_dir" "$temp_file_prefix"); then
        log_verbose "Failed to predict capture path - skipping marker injection"
        return 1
    fi
    
    # Inject the capture start marker
    log_verbose "Injecting PreToolUse capture marker for pipe command: $command"
    inject_capture_start_marker "$predicted_path"
    
    return 0
}

# Safe pipe detection for PreToolUse (simplified version of main script logic)
detect_safe_pipes_in_command() {
    local cmd="$1"
    local in_single_quote=false
    local in_double_quote=false
    local escaped=false
    local pipe_count=0
    local i=0
    
    while [[ $i -lt ${#cmd} ]]; do
        local char="${cmd:$i:1}"
        local next_char="${cmd:$((i+1)):1}"
        local prev_char="${cmd:$((i-1)):1}"
        
        if [[ "$escaped" == "true" ]]; then
            escaped=false
            ((i++))
            continue
        fi
        
        case "$char" in
            '\\')
                escaped=true
                ;;
            "'")
                if [[ "$in_double_quote" == "false" ]]; then
                    in_single_quote=$([[ "$in_single_quote" == "true" ]] && echo "false" || echo "true")
                fi
                ;;
            '"')
                if [[ "$in_single_quote" == "false" ]]; then
                    in_double_quote=$([[ "$in_double_quote" == "true" ]] && echo "false" || echo "true")
                fi
                ;;
            '|')
                if [[ "$in_single_quote" == "false" ]] && [[ "$in_double_quote" == "false" ]]; then
                    # Check for proper pipe with spaces
                    if [[ "$prev_char" == " " ]] && [[ "$next_char" == " " ]]; then
                        ((pipe_count++))
                    fi
                fi
                ;;
        esac
        
        ((i++))
    done
    
    echo "$pipe_count"
    return 0
}

# Enhanced marker injection that handles concurrent execution
inject_concurrent_safe_marker() {
    local temp_file_path="$1"
    local marker_type="${2:-start}"
    local process_id="$$"
    local timestamp="$(date +%s%N)"
    
    if [[ "$ENABLE_MARKERS" != "true" ]]; then
        return 0
    fi
    
    # Add process ID and timestamp for concurrent safety
    local enriched_path="${temp_file_path}#${process_id}#${timestamp}"
    
    case "$marker_type" in
        start)
            inject_capture_start_marker "$enriched_path"
            ;;
        end)
            inject_capture_end_marker "$enriched_path"
            ;;
        *)
            log_verbose "Warning: Unknown marker type '$marker_type'"
            return 1
            ;;
    esac
}

# Clean path from concurrent markers (remove process ID and timestamp)
clean_concurrent_path() {
    local enriched_path="$1"
    
    # Remove #processid#timestamp suffix
    echo "$enriched_path" | sed -E 's/#[0-9]+#[0-9]+$//'
}

# Test function for marker functionality
test_marker_functionality() {
    log_verbose "Testing marker functionality..."
    
    local test_path="/tmp/test-marker-file.log"
    local marker_output
    
    # Test start marker injection
    marker_output=$(inject_capture_start_marker "$test_path" 2>&1)
    if validate_marker_format "$marker_output"; then
        log_verbose "✓ Start marker format validation passed"
    else
        log_verbose "✗ Start marker format validation failed"
        return 1
    fi
    
    # Test end marker injection
    marker_output=$(inject_capture_end_marker "$test_path" 2>&1)
    if validate_marker_format "$marker_output"; then
        log_verbose "✓ End marker format validation passed"
    else
        log_verbose "✗ End marker format validation failed"
        return 1
    fi
    
    # Test path extraction
    local test_marker="${MARKER_FORMAT} ${test_path}"
    local extracted_path
    if extracted_path=$(parse_path_from_marker "$test_marker"); then
        if [[ "$extracted_path" == "$test_path" ]]; then
            log_verbose "✓ Path extraction test passed"
        else
            log_verbose "✗ Path extraction test failed: expected '$test_path', got '$extracted_path'"
            return 1
        fi
    else
        log_verbose "✗ Path extraction test failed: could not extract path"
        return 1
    fi
    
    log_verbose "All marker tests passed"
    return 0
}

# Command line interface
main() {
    local action="${1:-}"
    local path="${2:-}"
    local marker_type="${3:-start}"
    
    case "$action" in
        inject)
            if [[ -z "$path" ]]; then
                echo "Usage: $0 inject <path> [start|end]" >&2
                return 1
            fi
            inject_concurrent_safe_marker "$path" "$marker_type"
            ;;
        pretooluse)
            # New command for PreToolUse hook integration
            local command="$path"
            local temp_dir="$marker_type"
            local temp_prefix="${4:-claude}"
            if [[ -z "$command" ]] || [[ -z "$temp_dir" ]]; then
                echo "Usage: $0 pretooluse <command> <temp_dir> [temp_prefix]" >&2
                return 1
            fi
            inject_pretooluse_marker "$command" "$temp_dir" "$temp_prefix"
            ;;
        extract)
            local text="${path:-$(cat)}"
            extract_markers_from_text "$text"
            ;;
        parse)
            if [[ -z "$path" ]]; then
                echo "Usage: $0 parse <marker>" >&2
                return 1
            fi
            parse_path_from_marker "$path"
            ;;
        validate)
            if [[ -z "$path" ]]; then
                echo "Usage: $0 validate <marker>" >&2
                return 1
            fi
            if validate_marker_format "$path"; then
                echo "Valid marker format"
                return 0
            else
                echo "Invalid marker format"
                return 1
            fi
            ;;
        test)
            test_marker_functionality
            ;;
        clean-path)
            if [[ -z "$path" ]]; then
                echo "Usage: $0 clean-path <enriched_path>" >&2
                return 1
            fi
            clean_concurrent_path "$path"
            ;;
        *)
            echo "Usage: $0 {inject|pretooluse|extract|parse|validate|test|clean-path} [arguments...]" >&2
            echo "" >&2
            echo "Commands:" >&2
            echo "  inject <path> [start|end]       - Inject capture marker for path" >&2
            echo "  pretooluse <cmd> <dir> [prefix] - PreToolUse hook marker injection" >&2
            echo "  extract [text]                  - Extract markers from text or stdin" >&2
            echo "  parse <marker>                  - Parse path from marker" >&2
            echo "  validate <marker>               - Validate marker format" >&2
            echo "  test                            - Run marker functionality tests" >&2
            echo "  clean-path <path>               - Clean concurrent enriched path" >&2
            echo "" >&2
            echo "Environment variables:" >&2
            echo "  CLAUDE_AUTO_TEE_ENABLE_MARKERS - Enable/disable markers (default: true)" >&2
            echo "  CLAUDE_AUTO_TEE_VERBOSE        - Enable verbose logging (default: false)" >&2
            return 1
            ;;
    esac
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi