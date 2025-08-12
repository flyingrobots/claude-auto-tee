#!/usr/bin/env bash
# Disk Space Checking Functions for Claude Auto-Tee
# P1.T017: Check available disk space before creating temp files

set -euo pipefail
IFS=$'\n\t'

# Minimum required space in bytes (default 100MB)
readonly DEFAULT_MIN_SPACE_BYTES=$((100 * 1024 * 1024))

# Check available disk space in a directory
# Args: directory_path [min_required_bytes]
# Returns: 0 if sufficient space, 1 if insufficient, 2 if unable to determine
check_disk_space() {
    local dir_path="${1:-}"
    local min_bytes="${2:-$DEFAULT_MIN_SPACE_BYTES}"
    
    if [[ -z "$dir_path" ]]; then
        echo "Error: Directory path required" >&2
        return 2
    fi
    
    if [[ ! -d "$dir_path" ]]; then
        echo "Error: Directory does not exist: $dir_path" >&2
        return 2
    fi
    
    local available_bytes
    
    # Try different methods to get disk space
    if command -v df >/dev/null 2>&1; then
        # Use df command (most portable)
        available_bytes=$(get_space_with_df "$dir_path")
    elif command -v stat >/dev/null 2>&1; then
        # Fallback to stat (less portable)
        available_bytes=$(get_space_with_stat "$dir_path")
    else
        echo "Error: No disk space checking tools available (df, stat)" >&2
        return 2
    fi
    
    if [[ -z "$available_bytes" ]] || [[ "$available_bytes" -eq 0 ]]; then
        echo "Error: Could not determine available disk space" >&2
        return 2
    fi
    
    # Compare available space with minimum requirement
    if [[ "$available_bytes" -ge "$min_bytes" ]]; then
        return 0  # Sufficient space
    else
        # Format sizes for error message
        local available_mb=$((available_bytes / 1024 / 1024))
        local required_mb=$((min_bytes / 1024 / 1024))
        echo "Error: Insufficient disk space. Available: ${available_mb}MB, Required: ${required_mb}MB" >&2
        return 1  # Insufficient space
    fi
}

# Get available space using df command
get_space_with_df() {
    local dir_path="$1"
    local df_output
    
    # Use df with POSIX output format for portability
    if df_output=$(df -P "$dir_path" 2>/dev/null); then
        # Extract available bytes from df output
        # df -P format: Filesystem 1K-blocks Used Available Use% Mounted-on
        local available_kb
        available_kb=$(echo "$df_output" | awk 'NR==2 {print $4}')
        
        if [[ -n "$available_kb" ]] && [[ "$available_kb" =~ ^[0-9]+$ ]]; then
            echo $((available_kb * 1024))  # Convert KB to bytes
        else
            echo ""
        fi
    else
        echo ""
    fi
}

# Get available space using stat command (fallback)
get_space_with_stat() {
    local dir_path="$1"
    
    # This is less portable and may not work on all systems
    if command -v stat >/dev/null 2>&1; then
        # Try different stat formats based on platform
        case "$(uname -s)" in
            Darwin*)
                # macOS stat format
                if stat -f '%a*%S' "$dir_path" 2>/dev/null | bc 2>/dev/null; then
                    return
                fi
                ;;
            Linux*)
                # Linux stat format
                if stat -f '%a*%S' "$dir_path" 2>/dev/null | bc 2>/dev/null; then
                    return
                fi
                ;;
        esac
    fi
    
    # If all methods fail
    echo ""
}

# Check if directory has enough space for estimated file size
# Args: directory_path estimated_size_bytes
check_space_for_file() {
    local dir_path="$1"
    local estimated_size="${2:-0}"
    
    # Add buffer (20% or minimum 50MB, whichever is larger)
    local buffer_size=$((estimated_size / 5))
    local min_buffer=$((50 * 1024 * 1024))  # 50MB
    
    if [[ $buffer_size -lt $min_buffer ]]; then
        buffer_size=$min_buffer
    fi
    
    local required_space=$((estimated_size + buffer_size))
    
    check_disk_space "$dir_path" "$required_space"
}

# Get human-readable disk space information
get_disk_space_info() {
    local dir_path="${1:-}"
    
    if [[ -z "$dir_path" ]] || [[ ! -d "$dir_path" ]]; then
        echo "Invalid directory path" >&2
        return 1
    fi
    
    if command -v df >/dev/null 2>&1; then
        local df_output
        if df_output=$(df -h "$dir_path" 2>/dev/null); then
            echo "Disk space for $dir_path:"
            echo "$df_output"
            return 0
        fi
    fi
    
    echo "Unable to retrieve disk space information for $dir_path" >&2
    return 1
}

# Estimate command output size based on command type
# This is a heuristic - actual output may vary significantly
estimate_command_output_size() {
    local command="$1"
    
    # Default conservative estimate: 10MB
    local default_size=$((10 * 1024 * 1024))
    
    # Analyze command patterns for size estimation
    case "$command" in
        *"find "*" -name "*|*"ls -la "*|*"ls -R "*)
            # Directory listings can be large
            echo $((50 * 1024 * 1024))  # 50MB
            ;;
        *"grep "*" -r "*|*"grep "*" --recursive "*)
            # Recursive grep can produce lots of output
            echo $((100 * 1024 * 1024))  # 100MB
            ;;
        *"cat "*|*"head "*|*"tail "*)
            # File operations - moderate size
            echo $((20 * 1024 * 1024))  # 20MB
            ;;
        *"npm "*" build"*|*"yarn "*" build"*|*"make "*|*"gcc "*|*"clang "*)
            # Build commands can be verbose
            echo $((200 * 1024 * 1024))  # 200MB
            ;;
        *"test"*|*"spec"*|*"jest"*|*"mocha"*)
            # Test commands with detailed output
            echo $((30 * 1024 * 1024))  # 30MB
            ;;
        *)
            # Default for unknown commands
            echo $default_size
            ;;
    esac
}

# Main function to check if temp directory has sufficient space
check_temp_space_for_command() {
    local temp_dir="$1"
    local command="$2"
    local verbose="${3:-false}"
    
    # Estimate required space
    local estimated_size
    estimated_size=$(estimate_command_output_size "$command")
    
    if [[ "$verbose" == "true" ]]; then
        local estimated_mb=$((estimated_size / 1024 / 1024))
        echo "Estimated command output size: ${estimated_mb}MB" >&2
        get_disk_space_info "$temp_dir" >&2
    fi
    
    # Check if directory has sufficient space
    if check_space_for_file "$temp_dir" "$estimated_size"; then
        if [[ "$verbose" == "true" ]]; then
            echo "Disk space check: PASSED" >&2
        fi
        return 0
    else
        if [[ "$verbose" == "true" ]]; then
            echo "Disk space check: FAILED" >&2
        fi
        return 1
    fi
}

# Example usage and testing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Test the functions if script is run directly
    echo "Testing disk space checking functions..."
    
    # Test current directory
    if check_disk_space "."; then
        echo "✓ Current directory has sufficient space"
    else
        echo "✗ Current directory lacks sufficient space"
    fi
    
    # Show disk space info
    echo ""
    get_disk_space_info "."
    
    # Test command estimation
    echo ""
    echo "Command size estimations:"
    echo "ls -la: $(estimate_command_output_size "ls -la") bytes"
    echo "npm run build: $(estimate_command_output_size "npm run build") bytes"
    echo "find . -name '*.js': $(estimate_command_output_size "find . -name '*.js'") bytes"
fi