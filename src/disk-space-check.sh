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

# Generate meaningful error message for space issues (P1.T019)
generate_space_error_message() {
    local error_code="$1"
    local dir_path="$2"
    local required_mb="${3:-}"
    local command="${4:-}"
    
    local base_message=""
    local suggestions=()
    local available_info=""
    
    # Get current space information if possible
    if command -v df >/dev/null 2>&1 && [[ -d "$dir_path" ]]; then
        local df_output
        if df_output=$(df -h "$dir_path" 2>/dev/null); then
            local available_space
            available_space=$(echo "$df_output" | awk 'NR==2 {print $4}')
            available_info=" (${available_space} available)"
        fi
    fi
    
    # Generate specific message based on error code
    case "$error_code" in
        20) # ERR_INSUFFICIENT_SPACE
            base_message="Insufficient disk space in ${dir_path}${available_info}"
            if [[ -n "$required_mb" ]]; then
                base_message+=". Need at least ${required_mb}MB for safe operation"
            fi
            suggestions=(
                "Free up disk space: rm -f ${dir_path}/claude-*.log"
                "Use alternative temp directory: export TMPDIR=/path/with/more/space"
                "Clean system temp files: rm -rf \${TMPDIR:-/tmp}/*"
                "Check disk usage: df -h ${dir_path}"
            )
            ;;
        21) # ERR_DISK_FULL
            base_message="Disk is completely full at ${dir_path}${available_info}"
            suggestions=(
                "Immediately free critical space: rm -f ${dir_path}/claude-*.log"
                "Clean large temporary files: find ${dir_path} -name '*.tmp' -size +10M -delete"
                "Move to different filesystem: export TMPDIR=/mnt/other/filesystem"
                "Check what's using space: du -sh ${dir_path}/* | sort -hr"
            )
            ;;
        22) # ERR_QUOTA_EXCEEDED
            base_message="Disk quota exceeded for ${dir_path}${available_info}"
            suggestions=(
                "Clean your temporary files: rm -f ${dir_path}/claude-*.log"
                "Use system temp directory: export TMPDIR=/tmp"
                "Check quota usage: quota -u \$USER"
                "Contact system administrator for quota increase"
            )
            ;;
        23) # ERR_SPACE_CHECK_FAILED
            base_message="Unable to determine disk space for ${dir_path}"
            suggestions=(
                "Verify directory exists and is accessible: ls -la ${dir_path}"
                "Check filesystem health: fsck ${dir_path}"
                "Try alternative temp location: export TMPDIR=/tmp"
                "Check system tools availability: which df stat"
            )
            ;;
        *)
            base_message="Space-related error in ${dir_path}${available_info}"
            suggestions=(
                "Check available space: df -h ${dir_path}"
                "Clean temporary files: rm -f ${dir_path}/claude-*.log"
                "Use alternative temp directory: export TMPDIR=/alternative/path"
            )
            ;;
    esac
    
    # Add command-specific suggestions
    if [[ -n "$command" ]]; then
        case "$command" in
            *"build"*|*"compile"*|*"make"*)
                suggestions+=("For build commands, consider using: export CLAUDE_AUTO_TEE_MAX_SIZE=52428800")
                ;;
            *"find"*|*"grep -r"*)
                suggestions+=("For large searches, consider: command | head -1000")
                ;;
            *"npm "*|*"yarn "*)
                suggestions+=("Clear package manager cache: npm cache clean --force")
                ;;
        esac
    fi
    
    # Format the complete error message
    echo "$base_message"
    echo ""
    echo "💡 Suggested solutions (try in order):"
    local count=1
    for suggestion in "${suggestions[@]}"; do
        echo "   $count. $suggestion"
        ((count++))
    done
    
    # Add general tip
    echo ""
    echo "ℹ️  Tip: Use 'export CLAUDE_AUTO_TEE_VERBOSE=true' for detailed space checking info"
}

# Enhanced space error reporting function
report_space_error() {
    local error_code="$1"
    local dir_path="$2"
    local required_mb="${3:-}"
    local command="${4:-}"
    
    # Generate detailed error message
    local detailed_message
    detailed_message=$(generate_space_error_message "$error_code" "$dir_path" "$required_mb" "$command")
    
    echo "❌ Space Issue Detected:" >&2
    echo "$detailed_message" >&2
}

# Check if we have enough space and provide meaningful feedback
check_space_with_detailed_errors() {
    local dir_path="$1"
    local command="$2"
    local verbose="${3:-false}"
    
    # Estimate required space
    local estimated_size
    estimated_size=$(estimate_command_output_size "$command")
    local estimated_mb=$((estimated_size / 1024 / 1024))
    
    if [[ "$verbose" == "true" ]]; then
        echo "Estimated command output size: ${estimated_mb}MB" >&2
    fi
    
    # Check basic directory existence and permissions
    if [[ ! -d "$dir_path" ]]; then
        report_space_error 23 "$dir_path" "" "$command"
        return 23
    fi
    
    if [[ ! -w "$dir_path" ]]; then
        report_space_error 23 "$dir_path" "" "$command"
        return 23  
    fi
    
    # Check available space with detailed error reporting
    local available_bytes
    if available_bytes=$(get_space_with_df "$dir_path") && [[ -n "$available_bytes" ]] && [[ "$available_bytes" -gt 0 ]]; then
        local available_mb=$((available_bytes / 1024 / 1024))
        local required_space=$((estimated_size + 50 * 1024 * 1024))  # Add 50MB buffer
        local required_mb=$((required_space / 1024 / 1024))
        
        if [[ "$verbose" == "true" ]]; then
            echo "Available space: ${available_mb}MB, Required: ${required_mb}MB" >&2
        fi
        
        if [[ "$available_bytes" -lt "$required_space" ]]; then
            if [[ "$available_mb" -lt 10 ]]; then
                # Nearly full disk
                report_space_error 21 "$dir_path" "$required_mb" "$command"
                return 21
            else
                # Insufficient but not critical
                report_space_error 20 "$dir_path" "$required_mb" "$command"
                return 20
            fi
        fi
        
        # Space check passed
        if [[ "$verbose" == "true" ]]; then
            echo "✓ Sufficient space available (${available_mb}MB)" >&2
        fi
        return 0
    else
        # Unable to determine space
        report_space_error 23 "$dir_path" "$estimated_mb" "$command"
        return 23
    fi
}

# Example usage and testing
if [[ "${BASH_SOURCE[0]:-}" == "${0:-}" ]]; then
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
    
    # Test meaningful error message generation
    echo ""
    echo "Testing meaningful error messages:"
    echo "--- ERR_INSUFFICIENT_SPACE ---"
    generate_space_error_message 20 "/tmp" "100" "npm run build"
    echo ""
    echo "--- ERR_DISK_FULL ---"
    generate_space_error_message 21 "/tmp" "" "find . -name '*.js'"
fi