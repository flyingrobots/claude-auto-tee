#!/usr/bin/env bash
# Claude Auto-Tee Hook - Minimal Implementation
# Automatically injects tee for pipe commands to save full output

set -euo pipefail
IFS=$'\n\t'

# Source disk space checking functions
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/disk-space-check.sh"

# Check for verbose mode (P1.T021)
readonly VERBOSE_MODE="${CLAUDE_AUTO_TEE_VERBOSE:-false}"

# Verbose logging function
log_verbose() {
    if [[ "$VERBOSE_MODE" == "true" ]]; then
        echo "[CLAUDE-AUTO-TEE] $1" >&2
    fi
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
    echo "Error: No writable temporary directory found" >&2
    return 1
}

# Read Claude Code hook input
input=$(cat)

# Extract command from JSON (handle escaped quotes)
command_escaped=$(echo "$input" | sed -n 's/.*"command":"\([^"]*\(\\"[^"]*\)*\)".*/\1/p' | tr -d '\n')
command=$(echo "$command_escaped" | sed 's/\\"/"/g')

# Check if command contains pipe and doesn't already have tee  
if echo "$command" | grep -q " | "; then
    if echo "$command" | grep -q "tee "; then
        # Skip - already has tee
        echo "$input"
        exit 0
    fi
    # Process - has pipe but no tee
    log_verbose "Pipe command detected: $command"
    
    # Get suitable temp directory
    log_verbose "Detecting suitable temp directory..."
    temp_dir=$(get_temp_dir)
    if [[ $? -ne 0 ]]; then
        log_verbose "No suitable temp directory found - passing through unchanged"
        # Fallback: pass through unchanged if no temp directory available
        echo "$input"
        exit 0
    fi
    log_verbose "Selected temp directory: $temp_dir"
    
    # Check disk space before proceeding (P1.T017)
    log_verbose "Checking disk space for command execution..."
    if ! check_temp_space_for_command "$temp_dir" "$command" "$VERBOSE_MODE"; then
        log_verbose "Insufficient disk space - passing through unchanged"
        # Insufficient space: pass through unchanged to avoid failures
        echo "$input"
        exit 0
    fi
    log_verbose "Disk space check passed"
    
    # Generate unique temp file
    temp_file="${temp_dir}/claude-$(date +%s%N | cut -b1-13).log"
    log_verbose "Generated temp file: $temp_file"
    
    # Find first pipe and split command
    before_pipe="${command%% | *}"
    after_pipe="${command#* | }"
    log_verbose "Split command - before pipe: $before_pipe"
    log_verbose "Split command - after pipe: $after_pipe"
    
    # Construct modified command with tee
    # Only add 2>&1 if not already present
    if echo "$before_pipe" | grep -q "2>&1"; then
        modified_command="$before_pipe | tee \"$temp_file\" | $after_pipe"
        log_verbose "Command already has 2>&1, tee injection: $modified_command"
    else
        modified_command="$before_pipe 2>&1 | tee \"$temp_file\" | $after_pipe"
        log_verbose "Added 2>&1 and tee injection: $modified_command"
    fi
    
    # Build new JSON - simpler approach using printf with proper escaping
    # Escape the command properly for JSON
    modified_with_echo="$modified_command ; echo \"Full output saved to: $temp_file\""
    # Escape quotes and backslashes for JSON
    escaped_command=$(printf '%s' "$modified_with_echo" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    
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