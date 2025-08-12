#!/usr/bin/env bash
# Claude Auto-Tee Hook - Minimal Implementation
# Automatically injects tee for pipe commands to save full output

set -euo pipefail
IFS=$'\n\t'

# Source required modules
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/error-codes.sh"
source "${SCRIPT_DIR}/disk-space-check.sh"

# Environment variable overrides (P1.T003)
readonly VERBOSE_MODE="${CLAUDE_AUTO_TEE_VERBOSE:-false}"
readonly CLEANUP_ON_SUCCESS="${CLAUDE_AUTO_TEE_CLEANUP_ON_SUCCESS:-true}"
readonly TEMP_FILE_PREFIX="${CLAUDE_AUTO_TEE_TEMP_PREFIX:-claude}"
# Default size limit: 100MB (100 * 1024 * 1024 = 104857600 bytes)
readonly DEFAULT_MAX_TEMP_FILE_SIZE=104857600
readonly MAX_TEMP_FILE_SIZE="${CLAUDE_AUTO_TEE_MAX_SIZE:-$DEFAULT_MAX_TEMP_FILE_SIZE}"

# Age-based cleanup configuration (P1.T015)
readonly CLEANUP_AGE_HOURS="${CLAUDE_AUTO_TEE_CLEANUP_AGE_HOURS:-48}"   # Default: 48 hours
readonly ENABLE_AGE_CLEANUP="${CLAUDE_AUTO_TEE_ENABLE_AGE_CLEANUP:-true}"

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

# Global variables for cleanup on interruption (P1.T014)
CURRENT_TEMP_FILE=""
CURRENT_CLEANUP_SCRIPT=""
MONITOR_PID=""

# Cleanup function for script interruption (P1.T014)
cleanup_on_interruption() {
    local signal="${1:-UNKNOWN}"
    log_verbose "Received signal $signal - performing cleanup"
    
    # Kill background monitoring process if running (for future size limit monitoring)
    if [[ -n "$MONITOR_PID" ]]; then
        kill "$MONITOR_PID" 2>/dev/null || true
        log_verbose "Killed background monitoring process (PID: $MONITOR_PID)"
    fi
    
    # Clean up temp files
    if [[ -n "$CURRENT_TEMP_FILE" ]] && [[ -f "$CURRENT_TEMP_FILE" ]]; then
        rm -f "$CURRENT_TEMP_FILE" 2>/dev/null || true
        log_verbose "Cleaned up temp file: $CURRENT_TEMP_FILE"
    fi
    
    # Clean up cleanup script
    if [[ -n "$CURRENT_CLEANUP_SCRIPT" ]] && [[ -f "$CURRENT_CLEANUP_SCRIPT" ]]; then
        rm -f "$CURRENT_CLEANUP_SCRIPT" 2>/dev/null || true
        log_verbose "Cleaned up cleanup script: $CURRENT_CLEANUP_SCRIPT"
    fi
    
    # Exit with appropriate code
    if [[ "$signal" == "EXIT" ]]; then
        exit 0
    else
        exit 130  # Standard exit code for script interrupted by Ctrl+C
    fi
}

# Set up signal handlers for interruption cleanup (P1.T014)
trap 'cleanup_on_interruption INT' INT     # Ctrl+C
trap 'cleanup_on_interruption TERM' TERM  # Termination signal
trap 'cleanup_on_interruption EXIT' EXIT  # Normal exit
trap 'cleanup_on_interruption HUP' HUP    # Hangup signal
log_verbose "Signal handlers installed for cleanup on interruption"

# Age-based cleanup for orphaned files (P1.T015)
cleanup_orphaned_files() {
    local temp_dir="$1"
    local age_hours="${CLEANUP_AGE_HOURS}"
    
    # Validate inputs
    if [[ ! -d "$temp_dir" ]]; then
        log_verbose "Temp directory doesn't exist for orphaned cleanup: $temp_dir"
        return 0
    fi
    
    if [[ -z "$age_hours" ]] || [[ ! "$age_hours" =~ ^[0-9]+$ ]]; then
        log_verbose "Invalid age hours for cleanup: '$age_hours', using default: 48"
        age_hours=48
    fi
    
    log_verbose "Starting orphaned file cleanup in $temp_dir (age threshold: ${age_hours}h)"
    
    # Find files older than the threshold
    local cleanup_count=0
    local error_count=0
    
    # Use find with -mtime for age detection (convert hours to days for find)
    # find -mtime +n finds files modified more than n*24 hours ago
    # For hours, we need to be more precise, so we'll use a different approach
    local age_minutes=$((age_hours * 60))
    
    # Find claude-auto-tee temp files older than threshold
    # Use a more portable approach that works across platforms
    local current_time
    current_time=$(date +%s)
    local cutoff_time=$((current_time - age_hours * 3600))
    
    log_verbose "Cleanup cutoff time: $(date -r "$cutoff_time" 2>/dev/null || date -d "@$cutoff_time" 2>/dev/null || echo "unknown")"
    
    # Find files matching our pattern
    local temp_pattern="${temp_dir}/${TEMP_FILE_PREFIX}-*"
    
    # Use find if available, otherwise fall back to ls-based approach
    if command -v find >/dev/null 2>&1; then
        # Find files matching our pattern that are older than cutoff time
        while IFS= read -r -d '' file; do
            if [[ -f "$file" ]]; then
                # Check if file is safe to delete (not currently in use)
                if is_file_safe_to_delete "$file"; then
                    local file_time
                    # Get file modification time (cross-platform)
                    if stat -c %Y "$file" >/dev/null 2>&1; then
                        # GNU stat (Linux)
                        file_time=$(stat -c %Y "$file")
                    elif stat -f %m "$file" >/dev/null 2>&1; then
                        # BSD stat (macOS)
                        file_time=$(stat -f %m "$file")
                    else
                        # Fallback - assume file is old enough if we can't check
                        log_verbose "Cannot determine file age for $file, skipping"
                        continue
                    fi
                    
                    # Check if file is old enough
                    if [[ "$file_time" -lt "$cutoff_time" ]]; then
                        if rm -f "$file" 2>/dev/null; then
                            ((cleanup_count++))
                            log_verbose "Removed orphaned file: $file (age: $(( (current_time - file_time) / 3600 ))h)"
                        else
                            log_verbose "Failed to remove orphaned file: $file"
                            ((error_count++))
                        fi
                    fi
                else
                    log_verbose "File appears to be in use, skipping: $file"
                fi
            fi
        done < <(find "$temp_dir" -name "${TEMP_FILE_PREFIX}-*" -type f -print0 2>/dev/null || true)
    else
        # Fallback for systems without find
        log_verbose "find command not available, using fallback cleanup method"
        # This is less precise but still functional
        local pattern="${temp_dir}/${TEMP_FILE_PREFIX}-*"
        for file in $pattern; do
            # Check if the glob pattern matched any files
            if [[ -f "$file" ]] && is_file_safe_to_delete "$file"; then
                # Simple age check - if file exists, try to remove if older than threshold
                # This is a simplified version without precise time checking
                log_verbose "Attempting to remove potentially orphaned file: $file"
                if rm -f "$file" 2>/dev/null; then
                    ((cleanup_count++))
                else
                    ((error_count++))
                fi
            fi
        done
    fi
    
    if [[ "$cleanup_count" -gt 0 ]] || [[ "$error_count" -gt 0 ]]; then
        log_verbose "Orphaned file cleanup completed: $cleanup_count removed, $error_count errors"
    else
        log_verbose "No orphaned files found for cleanup"
    fi
    
    return 0
}

# Check if a file is safe to delete (not actively in use)
is_file_safe_to_delete() {
    local file="$1"
    
    # Basic safety checks
    if [[ ! -f "$file" ]]; then
        return 1  # File doesn't exist
    fi
    
    # Check if file is currently being written to by checking for file locks
    # This is platform-dependent and best-effort
    
    # Method 1: Check if file is open (Linux with lsof)
    if command -v lsof >/dev/null 2>&1; then
        if lsof "$file" >/dev/null 2>&1; then
            log_verbose "File appears to be open: $file"
            return 1  # File is in use
        fi
    fi
    
    # Method 2: Try to get exclusive lock (portable but may not work on all systems)
    # Use flock if available
    if command -v flock >/dev/null 2>&1; then
        if ! flock -n 9 2>/dev/null 9<"$file"; then
            log_verbose "File appears to be locked: $file"
            return 1  # File is locked
        fi
        # Close the file descriptor
        exec 9<&-
    fi
    
    # Method 3: Check file age vs process lifetime (conservative approach)
    # If file was created very recently (within last 5 minutes), be cautious
    local current_time
    current_time=$(date +%s)
    local file_time
    
    if stat -c %Y "$file" >/dev/null 2>&1; then
        file_time=$(stat -c %Y "$file")
    elif stat -f %m "$file" >/dev/null 2>&1; then
        file_time=$(stat -f %m "$file")
    else
        # Cannot determine file age, err on side of caution for very recently created files
        # Use file creation time heuristic from filename if possible
        local filename
        filename=$(basename "$file")
        if [[ "$filename" =~ ${TEMP_FILE_PREFIX}-([0-9]+)\.log ]]; then
            local file_timestamp="${BASH_REMATCH[1]}"
            # This is a nanosecond timestamp truncated to 13 digits
            # Convert to seconds (first 10 digits)
            file_time="${file_timestamp:0:10}"
        else
            # Cannot determine age, assume it's safe after 5 minutes of existence
            # This is a fallback - in practice, this shouldn't happen often
            log_verbose "Cannot determine file creation time for $file, assuming safe"
            return 0
        fi
    fi
    
    # If file is very recent (less than 5 minutes old), be cautious
    local age_seconds=$((current_time - file_time))
    if [[ "$age_seconds" -lt 300 ]]; then  # 5 minutes
        log_verbose "File too recent for safe deletion: $file (${age_seconds}s old)"
        return 1
    fi
    
    # File appears safe to delete
    return 0
}

# Run age-based cleanup during initialization (P1.T015)
run_startup_cleanup() {
    if [[ "$ENABLE_AGE_CLEANUP" != "true" ]]; then
        log_verbose "Age-based cleanup disabled (CLAUDE_AUTO_TEE_ENABLE_AGE_CLEANUP=$ENABLE_AGE_CLEANUP)"
        return 0
    fi
    
    log_verbose "Running startup orphaned file cleanup"
    
    # Get list of potential temp directories to clean
    local temp_dirs_to_clean=()
    
    # Add the current temp directory
    local current_temp_dir
    current_temp_dir=$(get_temp_dir 2>/dev/null || echo "")
    if [[ -n "$current_temp_dir" ]] && [[ -d "$current_temp_dir" ]]; then
        temp_dirs_to_clean+=("$current_temp_dir")
    fi
    
    # Add standard temp directories if different from current
    for std_temp_dir in "/tmp" "/var/tmp" "${HOME}/tmp" "${HOME}/.tmp"; do
        if [[ -d "$std_temp_dir" ]] && [[ "$std_temp_dir" != "$current_temp_dir" ]]; then
            temp_dirs_to_clean+=("$std_temp_dir")
        fi
    done
    
    # Add environment variable temp directories
    for env_temp_dir in "${TMPDIR:-}" "${TMP:-}" "${TEMP:-}" "${CLAUDE_AUTO_TEE_TEMP_DIR:-}"; do
        if [[ -n "$env_temp_dir" ]] && [[ -d "$env_temp_dir" ]]; then
            local clean_dir="${env_temp_dir%/}"  # Remove trailing slash
            # Check if not already in list
            local already_added=false
            for existing_dir in "${temp_dirs_to_clean[@]}"; do
                if [[ "$clean_dir" == "$existing_dir" ]]; then
                    already_added=true
                    break
                fi
            done
            if [[ "$already_added" == "false" ]]; then
                temp_dirs_to_clean+=("$clean_dir")
            fi
        fi
    done
    
    if [[ "${#temp_dirs_to_clean[@]}" -eq 0 ]]; then
        log_verbose "No suitable temp directories found for cleanup"
        return 0
    fi
    
    log_verbose "Checking ${#temp_dirs_to_clean[@]} temp directories for orphaned files"
    
    # Clean each temp directory
    for temp_dir in "${temp_dirs_to_clean[@]}"; do
        cleanup_orphaned_files "$temp_dir"
    done
    
    log_verbose "Startup orphaned file cleanup completed"
}

# Run startup cleanup during initialization (P1.T015)
run_startup_cleanup

# Enhanced environment detection functions (P1.T004)
detect_container_environment() {
    # Container/sandbox detection
    if [[ -f /.dockerenv ]] || [[ -f /proc/1/cgroup ]] && grep -q docker /proc/1/cgroup 2>/dev/null; then
        log_verbose "Docker container environment detected"
        return 0
    fi
    
    # Check for other container indicators
    if [[ -n "${container:-}" ]] || [[ -n "${CONTAINER:-}" ]]; then
        log_verbose "Container environment detected via environment variables"
        return 0
    fi
    
    # Check for common container/sandbox patterns
    if [[ "$(id -u 2>/dev/null || echo 0)" == "0" ]] && [[ ! -w "/" ]]; then
        log_verbose "Read-only root filesystem detected (likely containerized)"
        return 0
    fi
    
    return 1
}

detect_readonly_filesystem() {
    local test_dir="$1"
    
    if [[ ! -d "$test_dir" ]]; then
        return 1  # Directory doesn't exist, not our concern here
    fi
    
    # Test if filesystem is read-only
    local test_file="${test_dir}/.claude-write-test-$$"
    if ! touch "$test_file" 2>/dev/null; then
        log_verbose "Directory $test_dir appears to be on read-only filesystem"
        return 0
    fi
    
    # Clean up test file
    rm -f "$test_file" 2>/dev/null || true
    return 1
}

attempt_directory_creation() {
    local dir="$1"
    
    # Don't try to create system directories that should already exist
    if [[ "$dir" == "/tmp" ]] || [[ "$dir" == "/var/tmp" ]] || [[ "$dir" == "/private/var/tmp" ]]; then
        return 1
    fi
    
    # Don't try to create paths that look dangerous (avoid root filesystem modifications)
    if [[ "$dir" == "/" ]] || [[ "$dir" == "/usr"* ]] || [[ "$dir" == "/etc"* ]] || [[ "$dir" == "/bin"* ]] || [[ "$dir" == "/sbin"* ]]; then
        return 1
    fi
    
    # Allow creation for user-controlled paths and reasonable temp paths
    if [[ "$dir" == "${HOME}/"* ]] || [[ "$dir" == "."* ]] || [[ "$dir" == "/tmp/"* ]] || [[ "$dir" == "/var/tmp/"* ]]; then
        log_verbose "Attempting to create missing directory: $dir"
        if mkdir -p "$dir" 2>/dev/null; then
            log_verbose "Successfully created directory: $dir"
            return 0
        fi
        log_verbose "Failed to create directory: $dir"
    else
        log_verbose "Directory path not suitable for creation: $dir"
    fi
    
    return 1
}

test_temp_directory_suitability() {
    local dir="$1"
    local context="${2:-unknown}"
    
    # Basic existence check
    if [[ ! -d "$dir" ]]; then
        log_verbose "Directory does not exist: $dir (context: $context)"
        return 1
    fi
    
    # Permission checks
    if [[ ! -w "$dir" ]]; then
        if detect_readonly_filesystem "$dir"; then
            log_verbose "Directory $dir is on read-only filesystem (context: $context)"
            return 1
        fi
        log_verbose "Directory not writable: $dir (context: $context)"
        return 1
    fi
    
    if [[ ! -x "$dir" ]]; then
        log_verbose "Directory not executable: $dir (context: $context)"
        return 1
    fi
    
    # Test actual file creation
    local test_file="${dir}/.claude-temp-test-$$-$RANDOM"
    if ! touch "$test_file" 2>/dev/null; then
        log_verbose "Cannot create test file in directory: $dir (context: $context)"
        return 1
    fi
    
    # Clean up test file
    rm -f "$test_file" 2>/dev/null || true
    
    log_verbose "Directory is suitable: $dir (context: $context)"
    return 0
}

# Get temp directory with fallback hierarchy and enhanced edge case handling (P1.T001, P1.T004)
get_temp_dir() {
    local dir
    local is_container=false
    
    # Detect environment characteristics
    if detect_container_environment; then
        is_container=true
        log_verbose "Container/sandbox environment detected - using enhanced fallback strategies"
    fi
    
    # Test candidates in priority order
    # 1. Claude Auto-Tee specific override (P1.T003)
    if [[ -n "${CLAUDE_AUTO_TEE_TEMP_DIR:-}" ]]; then
        dir="${CLAUDE_AUTO_TEE_TEMP_DIR%/}"  # Remove trailing slash
        log_verbose "Testing CLAUDE_AUTO_TEE_TEMP_DIR override: $dir"
        
        # Try to create directory if it doesn't exist
        if [[ ! -d "$dir" ]]; then
            log_verbose "CLAUDE_AUTO_TEE_TEMP_DIR override does not exist: $dir"
            if attempt_directory_creation "$dir"; then
                log_verbose "Created CLAUDE_AUTO_TEE_TEMP_DIR override: $dir"
            else
                log_verbose "Failed to create CLAUDE_AUTO_TEE_TEMP_DIR override: $dir"
            fi
        fi
        
        if test_temp_directory_suitability "$dir" "CLAUDE_AUTO_TEE_TEMP_DIR override"; then
            log_verbose "Using CLAUDE_AUTO_TEE_TEMP_DIR override: $dir"
            echo "$dir"
            return 0
        fi
        log_verbose "CLAUDE_AUTO_TEE_TEMP_DIR override not suitable: $dir"
        # Continue with fallback chain instead of failing immediately
    fi
    
    # 2. Standard environment variables (cross-platform)
    if [[ -n "${TMPDIR:-}" ]]; then
        dir="${TMPDIR%/}"  # Remove trailing slash
        log_verbose "Testing TMPDIR: $dir"
        if test_temp_directory_suitability "$dir" "TMPDIR"; then
            log_verbose "Using TMPDIR: $dir"
            echo "$dir"
            return 0
        fi
        log_verbose "TMPDIR not suitable: $dir"
    fi
    
    if [[ -n "${TMP:-}" ]]; then
        dir="${TMP%/}"
        log_verbose "Testing TMP: $dir"
        if test_temp_directory_suitability "$dir" "TMP"; then
            log_verbose "Using TMP: $dir"
            echo "$dir"
            return 0
        fi
        log_verbose "TMP not suitable: $dir"
    fi
    
    if [[ -n "${TEMP:-}" ]]; then
        dir="${TEMP%/}"
        log_verbose "Testing TEMP: $dir"
        if test_temp_directory_suitability "$dir" "TEMP"; then
            log_verbose "Using TEMP: $dir"
            echo "$dir"
            return 0
        fi
        log_verbose "TEMP not suitable: $dir"
    fi
    
    # 3. Platform-specific defaults with enhanced edge case handling
    local platform
    platform="$(uname -s)"
    log_verbose "Platform detected: $platform"
    
    case "$platform" in
        Darwin*)
            log_verbose "Using macOS temp directory fallbacks"
            for dir in "/private/var/tmp" "/tmp"; do
                log_verbose "Testing platform fallback: $dir"
                if test_temp_directory_suitability "$dir" "macOS platform fallback"; then
                    log_verbose "Using platform fallback: $dir"
                    echo "$dir"
                    return 0
                fi
            done
            ;;
        Linux*)
            log_verbose "Using Linux temp directory fallbacks"
            # In containers, try additional locations
            local linux_candidates=("/var/tmp" "/tmp")
            if [[ "$is_container" == "true" ]]; then
                linux_candidates+=("/dev/shm" "/run/user/$(id -u 2>/dev/null || echo 0)")
                log_verbose "Container detected - expanded Linux temp directory candidates"
            fi
            
            for dir in "${linux_candidates[@]}"; do
                log_verbose "Testing platform fallback: $dir"
                if test_temp_directory_suitability "$dir" "Linux platform fallback"; then
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
                if test_temp_directory_suitability "$dir" "Windows platform fallback"; then
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
                if test_temp_directory_suitability "$dir" "generic platform fallback"; then
                    log_verbose "Using platform fallback: $dir"
                    echo "$dir"
                    return 0
                fi
            done
            ;;
    esac
    
    # 4. Last resort fallbacks with creation attempts
    log_verbose "Trying last resort fallbacks"
    
    # Enhanced fallback list for different environments
    local fallback_candidates=("${HOME}/.tmp" "${HOME}/tmp" ".")
    
    # In container environments, try additional locations
    if [[ "$is_container" == "true" ]]; then
        fallback_candidates+=("${HOME}/.cache/tmp" "/tmp/user-$(id -u 2>/dev/null || echo 0)")
        log_verbose "Container detected - expanded last resort candidates"
    fi
    
    for dir in "${fallback_candidates[@]}"; do
        log_verbose "Testing last resort: $dir"
        
        # Try to create directory if it doesn't exist
        if [[ ! -d "$dir" ]]; then
            if attempt_directory_creation "$dir"; then
                log_verbose "Created last resort directory: $dir"
            fi
        fi
        
        if test_temp_directory_suitability "$dir" "last resort fallback"; then
            log_verbose "Using last resort: $dir"
            echo "$dir"
            return 0
        fi
    done
    
    # Generate detailed error message with actionable guidance (P1.T004)
    log_verbose "No suitable temp directory found after exhaustive search"
    
    # Build environment-specific guidance
    local error_context="No writable temporary directory found after exhaustive search."
    local guidance="\n\nTroubleshooting steps:\n"
    guidance+="1. Check if you have write access to any temp directory:\n"
    guidance+="   ls -ld /tmp /var/tmp \${HOME}/tmp 2>/dev/null\n\n"
    
    if [[ "$is_container" == "true" ]]; then
        guidance+="2. Container environment detected. Try mounting a writable volume:\n"
        guidance+="   docker run -v /host/tmp:/tmp your-image\n"
        guidance+="   Or set CLAUDE_AUTO_TEE_TEMP_DIR to a writable path\n\n"
    fi
    
    guidance+="3. Create a user temp directory:\n"
    guidance+="   mkdir -p \${HOME}/tmp && export CLAUDE_AUTO_TEE_TEMP_DIR=\${HOME}/tmp\n\n"
    guidance+="4. Check filesystem mount status:\n"
    guidance+="   mount | grep -E '(tmp|ro)'\n\n"
    guidance+="5. For read-only root filesystems, ensure a writable volume is mounted\n"
    
    report_error $ERR_NO_TEMP_DIR "${error_context}${guidance}" false
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
        log_verbose "Input does not appear to be valid tool JSON - passing through unchanged"
        report_warning $ERR_MALFORMED_JSON "Malformed JSON input - graceful passthrough"
        echo "$input"
        exit 0
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
    
    # Check disk space before proceeding (P1.T017, P1.T019)
    set_error_context "Checking disk space for command execution"
    log_verbose "Checking disk space for command execution..."
    
    # Use enhanced space checking with meaningful error messages (P1.T019)
    space_check_result=""
    if ! check_space_with_detailed_errors "$temp_dir" "$command" "$VERBOSE_MODE"; then
        space_check_result=$?
        clear_error_context
        log_verbose "Space check failed with code $space_check_result - enabling graceful degradation"
        
        # Different handling based on space error severity
        case $space_check_result in
            21) # ERR_DISK_FULL - critical, must fallback
                report_warning $ERR_DISK_FULL "Critical disk space issue - falling back to pass-through mode"
                ;;
            22) # ERR_QUOTA_EXCEEDED - user issue, fallback recommended
                report_warning $ERR_QUOTA_EXCEEDED "Quota exceeded - falling back to pass-through mode"
                ;;
            20) # ERR_INSUFFICIENT_SPACE - warning, but can try to continue
                report_warning $ERR_INSUFFICIENT_SPACE "Limited disk space - falling back to pass-through mode"
                ;;
            *) # Other space-related issues
                report_warning $ERR_SPACE_CHECK_FAILED "Space check failed - falling back to pass-through mode"
                ;;
        esac
        
        echo "$input"
        exit 0
    fi
    log_verbose "Disk space check passed"
    clear_error_context
    
    # Validate and apply MAX_TEMP_FILE_SIZE limit (P1.T018)
    if [[ "$MAX_TEMP_FILE_SIZE" =~ ^[0-9]+$ ]]; then
        if [[ "$MAX_TEMP_FILE_SIZE" -gt 0 ]]; then
            log_verbose "Max temp file size limit: ${MAX_TEMP_FILE_SIZE} bytes ($(($MAX_TEMP_FILE_SIZE / 1024 / 1024))MB)"
            # Size limit will be enforced during command execution
        else
            log_verbose "Warning: MAX_TEMP_FILE_SIZE must be greater than 0, using default: $DEFAULT_MAX_TEMP_FILE_SIZE bytes"
            MAX_TEMP_FILE_SIZE="$DEFAULT_MAX_TEMP_FILE_SIZE"
        fi
    elif [[ -n "$MAX_TEMP_FILE_SIZE" ]]; then
        log_verbose "Warning: Invalid MAX_TEMP_FILE_SIZE value '$MAX_TEMP_FILE_SIZE', using default: $DEFAULT_MAX_TEMP_FILE_SIZE bytes"
        MAX_TEMP_FILE_SIZE="$DEFAULT_MAX_TEMP_FILE_SIZE"
    fi
    
    # Generate unique temp file and cleanup script (P1.T013)
    set_error_context "Creating temp file and cleanup script"
    temp_file="${temp_dir}/${TEMP_FILE_PREFIX}-$(date +%s%N | cut -b1-13).log"
    
    # Set global variables for interruption cleanup (P1.T014)
    CURRENT_TEMP_FILE="$temp_file"
    
    # Validate temp file path
    if [[ ! -w "$temp_dir" ]]; then
        report_warning $ERR_TEMP_DIR_NOT_WRITABLE "Temp directory not writable: $temp_dir"
        echo "$input"
        exit 0
    fi
    
    # Create cleanup script
    cleanup_script=$(create_cleanup_function "$temp_dir")
    CURRENT_CLEANUP_SCRIPT="$cleanup_script"
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
    
    # Construct modified command with tee, size limits, and cleanup (P1.T013, P1.T018)
    # Only add 2>&1 if not already present
    if echo "$before_pipe" | grep -q "2>&1"; then
        base_tee_command="$before_pipe | head -c $MAX_TEMP_FILE_SIZE | tee \"$temp_file\""
        log_verbose "Command already has 2>&1, tee with size limit: $base_tee_command"
    else
        base_tee_command="$before_pipe 2>&1 | head -c $MAX_TEMP_FILE_SIZE | tee \"$temp_file\""
        log_verbose "Added 2>&1 and tee with size limit: $base_tee_command"
    fi
    
    # Add size warning when truncation occurs
    modified_command="{ $base_tee_command; SIZE_CHECK=\$(wc -c < \"$temp_file\" 2>/dev/null || echo 0); if [[ \$SIZE_CHECK -ge $MAX_TEMP_FILE_SIZE ]]; then echo \"[CLAUDE-AUTO-TEE] WARNING: Output truncated at $((MAX_TEMP_FILE_SIZE / 1024 / 1024))MB limit\" >&2; fi; } | $after_pipe"
    log_verbose "Added size monitoring and truncation warning: $modified_command"
    
    # Add cleanup on successful completion (P1.T013)
    # Use CLEANUP_ON_SUCCESS environment variable override (P1.T003)
    if [[ "$CLEANUP_ON_SUCCESS" == "true" ]] && [[ -n "$cleanup_script" ]] && [[ -f "$cleanup_script" ]]; then
        cleanup_command="source \"$cleanup_script\" && { $modified_command; } && { echo \"Full output saved to: $temp_file\"; cleanup_temp_file \"$temp_file\"; rm -f \"$cleanup_script\" 2>/dev/null || true; } || { echo \"Command failed - temp file preserved: $temp_file\"; rm -f \"$cleanup_script\" 2>/dev/null || true; }"
        log_verbose "Added cleanup logic for successful completion (CLEANUP_ON_SUCCESS=$CLEANUP_ON_SUCCESS)"
    else
        # No cleanup or cleanup disabled - preserve temp file
        cleanup_command="{ $modified_command; } && echo \"Full output saved to: $temp_file\" || echo \"Command failed - temp file preserved: $temp_file\""
        if [[ "$CLEANUP_ON_SUCCESS" != "true" ]]; then
            log_verbose "Cleanup disabled via CLAUDE_AUTO_TEE_CLEANUP_ON_SUCCESS=$CLEANUP_ON_SUCCESS"
        else
            log_verbose "Running without cleanup script (cleanup script creation failed)"
        fi
        # Clean up the cleanup script itself if it exists
        if [[ -n "$cleanup_script" ]] && [[ -f "$cleanup_script" ]]; then
            rm -f "$cleanup_script" 2>/dev/null || true
        fi
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