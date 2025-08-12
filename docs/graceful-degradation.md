# Graceful Degradation Strategy

**Implementation plan for P1.T028 - Define graceful degradation for common failures**

## Philosophy: Fail-Safe vs Fail-Fast

### Core Principle
**Primary Goal**: Never break the user's original command execution
**Secondary Goal**: Provide claude-auto-tee functionality when possible
**Fallback**: Pass through original command unchanged when enhancement impossible

### Decision Matrix

| Error Category | Strategy | Rationale |
|---|---|---|
| Input/Config | Fail-Fast | User can fix immediately |
| Filesystem | Fail-Safe | Environment issues, pass through |
| Resource | Fail-Safe | Temporary constraints, retry possible |
| Execution | Fail-Safe | Don't break original command |
| Output | Fail-Safe | Partial functionality better than none |
| Permission | Fail-Safe | Environment restrictions, pass through |
| Platform | Fail-Safe | Environment compatibility, pass through |

## Graceful Degradation Scenarios

### 1. Temp Directory Failures

**Scenario**: No suitable temp directory found
**Current Risk**: Script exits with error, user command never runs
**Graceful Response**:
```bash
handle_temp_dir_failure() {
    report_warning $ERR_NO_TEMP_DIR "Falling back to pass-through mode"
    echo "WARNING: claude-auto-tee disabled - no temp directory available" >&2
    echo "Original command will execute without output capture" >&2
    # Pass through original input unchanged
    echo "$input"
    exit 0
}
```

### 2. Disk Space Insufficient

**Scenario**: Not enough space for estimated temp file size
**Current Risk**: Command fails mid-execution when disk fills
**Graceful Response**:
```bash
handle_insufficient_space() {
    local required="$1"
    local available="$2"
    
    # Try smaller estimation
    local min_space=$((1024 * 1024))  # 1MB minimum
    if [ "$available" -gt "$min_space" ]; then
        report_warning $ERR_INSUFFICIENT_SPACE "Proceeding with limited space"
        return 0
    fi
    
    # Fall back to pass-through
    report_warning $ERR_INSUFFICIENT_SPACE "Disabling output capture due to space constraints"
    echo "WARNING: Command will execute without output capture" >&2
    echo "$input"
    exit 0
}
```

### 3. Temp File Creation Failure

**Scenario**: Cannot create temp file (permissions, corruption, etc.)
**Current Risk**: Script fails, user command never executes
**Graceful Response**:
```bash
handle_temp_file_failure() {
    local temp_file="$1"
    report_warning $ERR_TEMP_FILE_CREATE_FAILED "Cannot create temp file"
    
    # Try alternative temp location
    for alt_dir in "$HOME/tmp" "$HOME" "."; do
        local alt_file="$alt_dir/claude-fallback-$$"
        if touch "$alt_file" 2>/dev/null; then
            rm -f "$alt_file"
            verbose_log "Using fallback temp location: $alt_dir"
            echo "$alt_dir/claude-$(date +%s%N | cut -b1-13).log"
            return 0
        fi
    done
    
    # Complete fallback - pass through
    echo "WARNING: Cannot create temp files, passing through original command" >&2
    echo "$input"
    exit 0
}
```

### 4. Command Execution Issues

**Scenario**: Modified command fails, but original might succeed
**Current Risk**: User gets confusing error from modified command
**Graceful Response**:
```bash
handle_execution_failure() {
    local exit_code="$1"
    local modified_command="$2"
    local original_command="$3"
    
    if [ $exit_code -ne 0 ]; then
        report_warning $ERR_EXECUTION_FAILED "Modified command failed (exit $exit_code)"
        
        # If this was due to tee injection, try without tee
        if echo "$modified_command" | grep -q "tee"; then
            echo "WARNING: Retrying original command without output capture" >&2
            # Execute original command directly
            eval "$original_command"
            exit $?
        fi
    fi
    
    # Pass through the failure
    exit $exit_code
}
```

### 5. Output Processing Failures

**Scenario**: Tee command fails, pipe breaks, output corruption
**Current Risk**: User loses command output entirely
**Graceful Response**:
```bash
handle_output_failure() {
    local failure_type="$1"
    
    case "$failure_type" in
        "tee_failed")
            report_warning $ERR_TEE_FAILED "Output capture failed, but command completed"
            echo "WARNING: Full output capture failed, but command executed successfully" >&2
            ;;
        "pipe_broken")
            report_warning $ERR_PIPE_BROKEN "Pipe interrupted, partial output captured"
            echo "WARNING: Output may be incomplete due to pipe failure" >&2
            ;;
        "output_too_large")
            report_warning $ERR_OUTPUT_TOO_LARGE "Output truncated due to size limits"
            echo "WARNING: Output was truncated, check temp file for complete output" >&2
            ;;
    esac
    
    # Continue with partial success
    return 0
}
```

## Implementation Strategy

### Core Degradation Function
```bash
# Main degradation decision point
handle_failure_gracefully() {
    local error_code="$1"
    local context="$2"
    local original_input="$3"
    
    # Get error category
    local category=$(get_error_category "$error_code")
    
    case "$category" in
        "input"|"internal")
            # Fail-fast scenarios
            report_error "$error_code" "$context" true
            ;;
        "filesystem"|"resource"|"platform"|"permission")
            # Fail-safe scenarios - pass through
            report_warning "$error_code" "$context"
            echo "WARNING: claude-auto-tee functionality disabled due to: $(get_error_message "$error_code")" >&2
            echo "Original command will execute normally" >&2
            echo "$original_input"
            exit 0
            ;;
        "execution"|"output")
            # Fail-safe with recovery attempt
            attempt_recovery "$error_code" "$context" "$original_input"
            ;;
        *)
            # Unknown category - be conservative, pass through
            report_warning $ERR_UNEXPECTED_CONDITION "Unknown error category: $category"
            echo "$original_input"
            exit 0
            ;;
    esac
}
```

### Recovery Mechanisms

#### Progressive Fallback
```bash
# Try increasingly simpler approaches
attempt_progressive_fallback() {
    local original_command="$1"
    
    # Level 1: Try different temp directory
    if temp_dir=$(find_alternative_temp_dir); then
        verbose_log "Attempting fallback with alternative temp directory: $temp_dir"
        return 0
    fi
    
    # Level 2: Try minimal functionality (no 2>&1)
    if attempt_minimal_tee "$original_command"; then
        verbose_log "Attempting minimal tee functionality"
        return 0
    fi
    
    # Level 3: Complete pass-through
    echo "Falling back to pass-through mode" >&2
    echo "$input"
    exit 0
}
```

#### Smart Retry Logic
```bash
# Retry with backoff for transient failures
smart_retry() {
    local operation="$1"
    local max_attempts=3
    local delay=1
    
    for attempt in $(seq 1 $max_attempts); do
        if eval "$operation"; then
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            verbose_log "Retry attempt $attempt failed, waiting ${delay}s"
            sleep $delay
            delay=$((delay * 2))
        fi
    done
    
    return 1
}
```

## User Experience During Degradation

### Messaging Strategy
```bash
# Clear, actionable user messages
show_degradation_message() {
    local error_code="$1"
    local user_action="$2"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "  claude-auto-tee: Functionality Temporarily Disabled" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "  Issue: $(get_error_message "$error_code")" >&2
    echo "  Impact: Your command will execute normally without output capture" >&2
    if [ -n "$user_action" ]; then
        echo "  Action: $user_action" >&2
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
}
```

### Verbose Mode Enhancement
```bash
# Extra information in verbose mode
show_degradation_details() {
    if is_verbose_mode; then
        echo "[VERBOSE] Degradation analysis:" >&2
        echo "[VERBOSE] - Error category: $(get_error_category "$error_code")" >&2
        echo "[VERBOSE] - Severity: $(get_error_severity "$error_code")" >&2
        echo "[VERBOSE] - Fallback strategy: Pass-through mode" >&2
        echo "[VERBOSE] - Recovery attempts made: $recovery_attempts" >&2
    fi
}
```

## Configuration Options

### Degradation Behavior Control
```bash
# Environment variables for user control
CLAUDE_DEGRADATION_MODE=${CLAUDE_DEGRADATION_MODE:-auto}    # auto|strict|permissive
CLAUDE_RETRY_ATTEMPTS=${CLAUDE_RETRY_ATTEMPTS:-3}           # number of retry attempts
CLAUDE_RETRY_DELAY=${CLAUDE_RETRY_DELAY:-1}                # initial retry delay
CLAUDE_FAIL_FAST=${CLAUDE_FAIL_FAST:-false}                # override fail-safe behavior
```

### Degradation Modes
```bash
configure_degradation_behavior() {
    case "$CLAUDE_DEGRADATION_MODE" in
        "strict")
            # Fail fast on any error - for debugging
            CLAUDE_FAIL_FAST=true
            CLAUDE_RETRY_ATTEMPTS=0
            ;;
        "permissive")  
            # Maximum tolerance - almost always pass through
            CLAUDE_RETRY_ATTEMPTS=5
            CLAUDE_RETRY_DELAY=0.5
            ;;
        "auto"|*)
            # Default balanced approach
            # Use built-in logic based on error category
            ;;
    esac
}
```

## Integration Points

### Main Script Integration
```bash
# Early in claude-auto-tee.sh, after input parsing
source "$(dirname "$0")/error-codes.sh"
configure_degradation_behavior

# Store original input for fallback
ORIGINAL_INPUT="$input"

# Wrap critical operations with graceful handling
trap 'handle_failure_gracefully $ERR_UNEXPECTED_CONDITION "Script interrupted" "$ORIGINAL_INPUT"' INT TERM

# Before each major operation
set_error_context "Detecting temp directory"
if ! temp_dir=$(detect_temp_directory 2>/dev/null); then
    handle_failure_gracefully $ERR_NO_TEMP_DIR "No suitable temp directory" "$ORIGINAL_INPUT"
fi

set_error_context "Checking disk space"
if ! check_disk_space "$temp_dir" "$required_space"; then
    handle_insufficient_space "$required_space" "$(get_available_space "$temp_dir")"
fi
```

## Testing Graceful Degradation

### Test Scenarios
```bash
# Test each degradation path
test_temp_dir_failure() {
    export TMPDIR=/nonexistent
    export TMP=/nonexistent  
    export TEMP=/nonexistent
    chmod 000 /tmp 2>/dev/null || true
    
    result=$(run_claude_auto_tee "echo test | cat")
    assert_contains "$result" "WARNING.*disabled"
    assert_exit_code 0
}

test_disk_space_failure() {
    mock_df_output "0"  # No space available
    
    result=$(run_claude_auto_tee "echo test | cat")
    assert_contains "$result" "space constraints"
    assert_exit_code 0
}
```

### Mock Testing Framework
```bash
# Mock failure conditions for testing
mock_failure_condition() {
    local condition="$1"
    
    case "$condition" in
        "no_temp_dir")
            export CLAUDE_TEST_NO_TEMP_DIR=1
            ;;
        "no_space")
            export CLAUDE_TEST_NO_SPACE=1
            ;;
        "temp_file_fail")
            export CLAUDE_TEST_TEMP_FILE_FAIL=1
            ;;
    esac
}
```

## Success Metrics

### Degradation Quality Indicators
1. **Pass-through Success Rate**: Commands should succeed even when claude-auto-tee fails
2. **User Confusion Minimization**: Clear messaging about what happened  
3. **Recovery Attempt Success**: How often retry mechanisms work
4. **False Positive Rate**: How often degradation happens unnecessarily

### Monitoring Points
```bash
# Log degradation events for analysis
log_degradation_event() {
    local error_code="$1"
    local degradation_type="$2"
    
    if [ -n "$CLAUDE_METRICS_LOG" ]; then
        echo "$(date -u +%Y-%m-%dT%H:%M:%SZ),degradation,$error_code,$degradation_type" >> "$CLAUDE_METRICS_LOG"
    fi
}
```

## Current Implementation Status

The existing claude-auto-tee.sh has no graceful degradation:
- Script exits on any error, preventing user command execution
- No fallback mechanisms for common failure scenarios  
- No user messaging about what went wrong
- Creates poor user experience when environment issues occur

**Impact**: Users experience broken command execution when claude-auto-tee encounters any problem, violating the principle that the tool should enhance rather than interfere with normal command execution.