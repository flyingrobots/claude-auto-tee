#!/usr/bin/env bash
# Claude Auto-Tee Hook - Minimal Implementation
# Automatically injects tee for pipe commands to save full output

set -euo pipefail
IFS=$'\n\t'

# Source required modules
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/error-codes.sh"
source "${SCRIPT_DIR}/disk-space-check.sh"

# Check for verbose mode (P1.T021)
readonly VERBOSE_MODE="${CLAUDE_AUTO_TEE_VERBOSE:-false}"

# Verbose logging function
log_verbose() {
    if [[ "$VERBOSE_MODE" == "true" ]]; then
        echo "[CLAUDE-AUTO-TEE] $1" >&2
    fi
}

# Check if verbose mode is enabled (for error reporting)
is_verbose_mode() {
    [[ "$VERBOSE_MODE" == "true" ]]
}

# Create cleanup function script (P1.T013)
create_cleanup_function() {
    local temp_dir="$1"
    local cleanup_script="${temp_dir}/claude-cleanup-$$-$RANDOM.sh"
    
    cat > "$cleanup_script" << 'EOF'
#!/usr/bin/env bash
# Cleanup function for claude-auto-tee temp files
cleanup_temp_file() {
    local file_path="$1"
    if [[ -n "$file_path" ]] && [[ -f "$file_path" ]]; then
        if rm -f "$file_path" 2>/dev/null; then
            if [[ "${CLAUDE_AUTO_TEE_VERBOSE:-false}" == "true" ]]; then
                echo "[CLAUDE-AUTO-TEE] Cleaned up temp file: $file_path" >&2
            fi
        else
            echo "[CLAUDE-AUTO-TEE] Warning: Could not clean up temp file: $file_path" >&2
        fi
    fi
}
EOF
    
    chmod +x "$cleanup_script" 2>/dev/null || true
    echo "$cleanup_script"
}

# Initial verbose mode detection
log_verbose "Verbose mode enabled (CLAUDE_AUTO_TEE_VERBOSE=$VERBOSE_MODE)"

# Get temp directory with fallback hierarchy based on research (P1.T001)
get_temp_dir() {
    local dir
    
    # Test candidates in priority order
    # 1. Environment variables (cross-platform)
    if [[ -n "${TMPDIR:-}" ]]; then
        dir="${TMPDIR%/}"  # Remove trailing slash
        log_verbose "Testing TMPDIR: $dir"
        if [[ -d "$dir" && -w "$dir" && -x "$dir" ]]; then
            log_verbose "Using TMPDIR: $dir"
            echo "$dir"
            return 0
        fi
        log_verbose "TMPDIR not suitable: $dir"
    fi
    
    if [[ -n "${TMP:-}" ]]; then
        dir="${TMP%/}"
        log_verbose "Testing TMP: $dir"
        if [[ -d "$dir" && -w "$dir" && -x "$dir" ]]; then
            log_verbose "Using TMP: $dir"
            echo "$dir"
            return 0
        fi
        log_verbose "TMP not suitable: $dir"
    fi
    
    if [[ -n "${TEMP:-}" ]]; then
        dir="${TEMP%/}"
        log_verbose "Testing TEMP: $dir"
        if [[ -d "$dir" && -w "$dir" && -x "$dir" ]]; then
            log_verbose "Using TEMP: $dir"
            echo "$dir"
            return 0
        fi
        log_verbose "TEMP not suitable: $dir"
    fi
    
    # 2. Platform-specific defaults
    local platform
    platform="$(uname -s)"
    log_verbose "Platform detected: $platform"
    
    case "$platform" in
        Darwin*)
            log_verbose "Using macOS temp directory fallbacks"
            for dir in "/private/var/tmp" "/tmp"; do
                log_verbose "Testing platform fallback: $dir"
                if [[ -d "$dir" && -w "$dir" && -x "$dir" ]]; then
                    log_verbose "Using platform fallback: $dir"
                    echo "$dir"
                    return 0
                fi
            done
            ;;
        Linux*)
            log_verbose "Using Linux temp directory fallbacks"
            for dir in "/var/tmp" "/tmp"; do
                log_verbose "Testing platform fallback: $dir"
                if [[ -d "$dir" && -w "$dir" && -x "$dir" ]]; then
                    log_verbose "Using platform fallback: $dir"
                    echo "$dir"
                    return 0
                fi
            done
            ;;
        CYGWIN*|MINGW*|MSYS*)
            log_verbose "Using Windows/Cygwin temp directory fallbacks"
            for dir in "/tmp" "/var/tmp"; do
                log_verbose "Testing platform fallback: $dir"
                if [[ -d "$dir" && -w "$dir" && -x "$dir" ]]; then
                    log_verbose "Using platform fallback: $dir"
                    echo "$dir"
                    return 0
                fi
            done
            ;;
        *)
            log_verbose "Using generic Unix temp directory fallbacks"
            for dir in "/var/tmp" "/tmp"; do
                log_verbose "Testing platform fallback: $dir"
                if [[ -d "$dir" && -w "$dir" && -x "$dir" ]]; then
                    log_verbose "Using platform fallback: $dir"
                    echo "$dir"
                    return 0
                fi
            done
            ;;
    esac
    
    # 3. Last resort fallbacks
    log_verbose "Trying last resort fallbacks"
    for dir in "${HOME}/.tmp" "${HOME}/tmp" "."; do
        log_verbose "Testing last resort: $dir"
        if [[ -d "$dir" && -w "$dir" && -x "$dir" ]]; then
            log_verbose "Using last resort: $dir"
            echo "$dir"
            return 0
        fi
    done
    
    # No suitable directory found
    log_verbose "No suitable temp directory found after exhaustive search"
    report_error $ERR_NO_TEMP_DIR "No writable temporary directory found after exhaustive search" false
    return $ERR_NO_TEMP_DIR
}

# Read Claude Code hook input with error handling
set_error_context "Reading hook input"
input=$(cat 2>/dev/null) || {
    report_error $ERR_INVALID_INPUT "Failed to read input from stdin" true
}

# Validate input is not empty
if [[ -z "$input" ]]; then
    report_error $ERR_INVALID_INPUT "Empty input received" true
fi

# Extract command from JSON (handle escaped quotes)
set_error_context "Parsing JSON input"
command_escaped=$(echo "$input" | sed -n 's/.*"command":"\([^"]*\(\\"[^"]*\)*\)".*/\1/p' | tr -d '\n')
if [[ -z "$command_escaped" ]]; then
    log_verbose "No command found in JSON, checking for malformed JSON"
    if ! echo "$input" | grep -q '"tool"'; then
        report_error $ERR_MALFORMED_JSON "Input does not appear to be valid tool JSON" true
    fi
    # Not a bash command, pass through unchanged
    echo "$input"
    exit 0
fi

command=$(echo "$command_escaped" | sed 's/\\"/"/g')
if [[ -z "$command" ]]; then
    report_error $ERR_MISSING_COMMAND "Command field is empty" true
fi

clear_error_context

# Check if command contains pipe and doesn't already have tee  
if echo "$command" | grep -q " | "; then
    if echo "$command" | grep -q "tee "; then
        # Skip - already has tee
        echo "$input"
        exit 0
    fi
    # Process - has pipe but no tee
    log_verbose "Pipe command detected: $command"
    
    # Get suitable temp directory with error context
    set_error_context "Detecting suitable temp directory"
    log_verbose "Detecting suitable temp directory..."
    temp_dir=$(get_temp_dir)
    temp_dir_status=$?
    if [[ $temp_dir_status -ne 0 ]]; then
        clear_error_context
        log_verbose "No suitable temp directory found - passing through unchanged"
        # Graceful degradation: pass through unchanged if no temp directory available
        report_warning $ERR_NO_TEMP_DIR "Falling back to pass-through mode"
        echo "$input"
        exit 0
    fi
    clear_error_context
    log_verbose "Selected temp directory: $temp_dir"
    
    # Check disk space before proceeding (P1.T017)
    set_error_context "Checking disk space for command execution"
    log_verbose "Checking disk space for command execution..."
    if ! check_temp_space_for_command "$temp_dir" "$command" "$VERBOSE_MODE"; then
        clear_error_context
        log_verbose "Insufficient disk space - passing through unchanged"
        # Graceful degradation: pass through unchanged to avoid failures
        report_warning $ERR_INSUFFICIENT_SPACE "Falling back to pass-through mode due to insufficient space"
        echo "$input"
        exit 0
    fi
    log_verbose "Disk space check passed"
    clear_error_context
    
    # Generate unique temp file and cleanup script (P1.T013)
    set_error_context "Creating temp file and cleanup script"
    temp_file="${temp_dir}/claude-$(date +%s%N | cut -b1-13).log"
    
    # Validate temp file path
    if [[ ! -w "$temp_dir" ]]; then
        report_warning $ERR_TEMP_DIR_NOT_WRITABLE "Temp directory not writable: $temp_dir"
        echo "$input"
        exit 0
    fi
    
    # Create cleanup script
    cleanup_script=$(create_cleanup_function "$temp_dir")
    if [[ -z "$cleanup_script" ]] || [[ ! -f "$cleanup_script" ]]; then
        report_warning $ERR_TEMP_FILE_CREATE_FAILED "Failed to create cleanup script, proceeding without cleanup"
        cleanup_script=""
    fi
    
    log_verbose "Generated temp file: $temp_file"
    log_verbose "Generated cleanup script: $cleanup_script"
    clear_error_context
    
    # Find first pipe and split command
    before_pipe="${command%% | *}"
    after_pipe="${command#* | }"
    log_verbose "Split command - before pipe: $before_pipe"
    log_verbose "Split command - after pipe: $after_pipe"
    
    # Construct modified command with tee and cleanup (P1.T013)
    # Only add 2>&1 if not already present
    if echo "$before_pipe" | grep -q "2>&1"; then
        modified_command="$before_pipe | tee \"$temp_file\" | $after_pipe"
        log_verbose "Command already has 2>&1, tee injection: $modified_command"
    else
        modified_command="$before_pipe 2>&1 | tee \"$temp_file\" | $after_pipe"
        log_verbose "Added 2>&1 and tee injection: $modified_command"
    fi
    
    # Add cleanup on successful completion (P1.T013)
    # Use a compound command with conditional cleanup
    if [[ -n "$cleanup_script" ]] && [[ -f "$cleanup_script" ]]; then
        cleanup_command="source \"$cleanup_script\" && { $modified_command; } && { echo \"Full output saved to: $temp_file\"; cleanup_temp_file \"$temp_file\"; rm -f \"$cleanup_script\" 2>/dev/null || true; } || { echo \"Command failed - temp file preserved: $temp_file\"; rm -f \"$cleanup_script\" 2>/dev/null || true; }"
        log_verbose "Added cleanup logic for successful completion"
    else
        # No cleanup script available - just run command with preservation message
        cleanup_command="{ $modified_command; } && echo \"Full output saved to: $temp_file\" || echo \"Command failed - temp file preserved: $temp_file\""
        log_verbose "Running without cleanup script (cleanup script creation failed)"
    fi
    
    # Build new JSON - simpler approach using printf with proper escaping
    # Escape the command properly for JSON
    escaped_command=$(printf '%s' "$cleanup_command" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    
    # Use a more robust approach to reconstruct JSON
    # First extract the timeout value
    timeout_value=$(echo "$input" | sed -n 's/.*"timeout":\([^,}]*\).*/\1/p')
    if [ -z "$timeout_value" ]; then
        timeout_value="null"
    fi
    
    # Output properly formatted JSON
    printf '{"tool":{"name":"Bash","input":{"command":"%s"}},"timeout":%s}\n' \
        "$escaped_command" "$timeout_value"
    
else
    # Pass through unchanged
    echo "$input"
fi