#!/usr/bin/env bash
# Claude Auto-Tee Hook - Minimal Implementation
# Automatically injects tee for pipe commands to save full output

set -euo pipefail
IFS=$'\n\t'

# Source disk space checking functions
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/disk-space-check.sh"

# Get temp directory with fallback hierarchy based on research (P1.T001)
get_temp_dir() {
    local dir
    
    # Test candidates in priority order
    # 1. Environment variables (cross-platform)
    if [[ -n "${TMPDIR:-}" ]]; then
        dir="${TMPDIR%/}"  # Remove trailing slash
        if [[ -d "$dir" && -w "$dir" && -x "$dir" ]]; then
            echo "$dir"
            return 0
        fi
    fi
    
    if [[ -n "${TMP:-}" ]]; then
        dir="${TMP%/}"
        if [[ -d "$dir" && -w "$dir" && -x "$dir" ]]; then
            echo "$dir"
            return 0
        fi
    fi
    
    if [[ -n "${TEMP:-}" ]]; then
        dir="${TEMP%/}"
        if [[ -d "$dir" && -w "$dir" && -x "$dir" ]]; then
            echo "$dir"
            return 0
        fi
    fi
    
    # 2. Platform-specific defaults
    case "$(uname -s)" in
        Darwin*)
            for dir in "/private/var/tmp" "/tmp"; do
                if [[ -d "$dir" && -w "$dir" && -x "$dir" ]]; then
                    echo "$dir"
                    return 0
                fi
            done
            ;;
        Linux*)
            for dir in "/var/tmp" "/tmp"; do
                if [[ -d "$dir" && -w "$dir" && -x "$dir" ]]; then
                    echo "$dir"
                    return 0
                fi
            done
            ;;
        CYGWIN*|MINGW*|MSYS*)
            for dir in "/tmp" "/var/tmp"; do
                if [[ -d "$dir" && -w "$dir" && -x "$dir" ]]; then
                    echo "$dir"
                    return 0
                fi
            done
            ;;
        *)
            for dir in "/var/tmp" "/tmp"; do
                if [[ -d "$dir" && -w "$dir" && -x "$dir" ]]; then
                    echo "$dir"
                    return 0
                fi
            done
            ;;
    esac
    
    # 3. Last resort fallbacks
    for dir in "${HOME}/.tmp" "${HOME}/tmp" "."; do
        if [[ -d "$dir" && -w "$dir" && -x "$dir" ]]; then
            echo "$dir"
            return 0
        fi
    done
    
    # No suitable directory found
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
    # Get suitable temp directory
    temp_dir=$(get_temp_dir)
    if [[ $? -ne 0 ]]; then
        # Fallback: pass through unchanged if no temp directory available
        echo "$input"
        exit 0
    fi
    
    # Check disk space before proceeding (P1.T017)
    if ! check_temp_space_for_command "$temp_dir" "$command"; then
        # Insufficient space: pass through unchanged to avoid failures
        echo "$input"
        exit 0
    fi
    
    # Generate unique temp file
    temp_file="${temp_dir}/claude-$(date +%s%N | cut -b1-13).log"
    
    # Find first pipe and split command
    before_pipe="${command%% | *}"
    after_pipe="${command#* | }"
    
    # Construct modified command with tee
    # Only add 2>&1 if not already present
    if echo "$before_pipe" | grep -q "2>&1"; then
        modified_command="$before_pipe | tee \"$temp_file\" | $after_pipe"
    else
        modified_command="$before_pipe 2>&1 | tee \"$temp_file\" | $after_pipe"
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