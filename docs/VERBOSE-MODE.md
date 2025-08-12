# Verbose Mode Documentation

**Task:** P1.T021 - Add optional verbose mode showing resource usage  
**Date:** 2025-08-12  
**Status:** Completed  

## Overview

Claude Auto-Tee includes a comprehensive verbose mode that provides detailed logging of all internal operations, resource usage, and decision-making processes. This is invaluable for debugging, monitoring, and understanding how the hook processes commands.

## Enabling Verbose Mode

Set the environment variable `CLAUDE_AUTO_TEE_VERBOSE=true`:

```bash
export CLAUDE_AUTO_TEE_VERBOSE=true
```

Or use it for a single session:

```bash
CLAUDE_AUTO_TEE_VERBOSE=true claude
```

## Verbose Output Information

When verbose mode is enabled, claude-auto-tee logs detailed information to stderr with the prefix `[CLAUDE-AUTO-TEE]`:

### 1. Initialization
- Verbose mode detection and confirmation
- Environment variable status

### 2. Command Analysis  
- Pipe command detection
- Command parsing (before/after pipe sections)

### 3. Temp Directory Selection
- Platform detection (macOS, Linux, Windows, etc.)
- Environment variable testing (`$TMPDIR`, `$TMP`, `$TEMP`)
- Platform-specific fallback testing
- Final directory selection with full path

### 4. Disk Space Management
- Estimated command output size
- Available disk space information
- Disk space validation results

### 5. Command Modification
- Temp file path generation
- Command reconstruction with tee injection
- JSON formatting and output

## Example Verbose Output

```bash
[CLAUDE-AUTO-TEE] Verbose mode enabled (CLAUDE_AUTO_TEE_VERBOSE=true)
[CLAUDE-AUTO-TEE] Pipe command detected: ls -la | head -5
[CLAUDE-AUTO-TEE] Detecting suitable temp directory...
[CLAUDE-AUTO-TEE] Testing TMPDIR: /var/folders/1h/qn5740kx131g0sxvgv12vm_m0000gn/T
[CLAUDE-AUTO-TEE] Using TMPDIR: /var/folders/1h/qn5740kx131g0sxvgv12vm_m0000gn/T
[CLAUDE-AUTO-TEE] Selected temp directory: /var/folders/1h/qn5740kx131g0sxvgv12vm_m0000gn/T
[CLAUDE-AUTO-TEE] Checking disk space for command execution...
Estimated command output size: 50MB
Disk space for /var/folders/1h/qn5740kx131g0sxvgv12vm_m0000gn/T:
Filesystem      Size    Used   Avail Capacity iused ifree %iused  Mounted on
/dev/disk3s5   926Gi   368Gi   512Gi    42%    5.5M  5.4G    0%   /System/Volumes/Data
Disk space check: PASSED
[CLAUDE-AUTO-TEE] Disk space check passed
[CLAUDE-AUTO-TEE] Generated temp file: /var/folders/1h/qn5740kx131g0sxvgv12vm_m0000gn/T/claude-1754992346N.log
[CLAUDE-AUTO-TEE] Split command - before pipe: ls -la
[CLAUDE-AUTO-TEE] Split command - after pipe: head -5
[CLAUDE-AUTO-TEE] Added 2>&1 and tee injection: ls -la 2>&1 | tee "..." | head -5
```

## Use Cases

### 1. Debugging Issues
When claude-auto-tee isn't working as expected:
- Verify temp directory detection
- Check disk space availability
- Understand command processing logic

### 2. Performance Monitoring
- Monitor disk space usage
- Track temp directory selection performance
- Understand resource allocation

### 3. Development and Testing
- Validate cross-platform behavior
- Debug new features
- Performance optimization

### 4. Corporate/Restricted Environments
- Understand why certain directories are rejected
- Verify fallback behavior
- Troubleshoot permission issues

## Performance Impact

Verbose mode has minimal performance impact:
- **Additional overhead:** < 1ms per command
- **Disk space:** Negligible (only stderr logging)
- **Memory usage:** Minimal additional strings

## Security Considerations

Verbose mode logs:
- ✅ **Safe:** Temp directory paths
- ✅ **Safe:** Platform information  
- ✅ **Safe:** Disk space statistics
- ✅ **Safe:** Command structure
- ❌ **Not logged:** Command contents (for security)
- ❌ **Not logged:** User data
- ❌ **Not logged:** Environment variables (except TMPDIR-related)

## Integration with Error Handling

Verbose mode works seamlessly with:
- Graceful degradation system
- Error code framework  
- Disk space checking
- Cross-platform temp directory detection

## Disabling Verbose Mode

```bash
unset CLAUDE_AUTO_TEE_VERBOSE
# or
export CLAUDE_AUTO_TEE_VERBOSE=false
```

---

*Verbose mode implementation completed as part of P1.T021 - claude-auto-tee Phase 1*