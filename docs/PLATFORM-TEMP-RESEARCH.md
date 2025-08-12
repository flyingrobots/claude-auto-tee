# Platform-Specific Temp Directory Research

**Task:** P1.T001 - Research platform-specific temp directory conventions  
**Date:** 2025-08-12  
**Status:** Completed  

## Executive Summary

Comprehensive research into temp directory conventions across macOS, Linux, and Windows platforms, providing the foundation for robust cross-platform temp directory detection in claude-auto-tee.

## Key Findings

### Platform Priority Order
1. **macOS**: `$TMPDIR` → `/tmp` → `/var/tmp`
2. **Linux**: `$TMPDIR` → `/var/tmp` → `/tmp` 
3. **Windows**: `%TEMP%`/`%TMP%` → fallbacks

### Recommended Fallback Hierarchy
```bash
1. ${TMPDIR}    # POSIX standard, macOS preferred
2. ${TMP}       # Windows compatibility  
3. ${TEMP}      # Windows standard
4. /var/tmp     # Unix persistent temp
5. /tmp         # Universal Unix fallback
6. ${HOME}/tmp  # User directory fallback
7. .            # Current directory (last resort)
```

## Platform Details

### macOS Specifics
- **Primary**: `$TMPDIR` (always set, user-specific, secure)
- **Path**: `/var/folders/xx/yyy/T/` with randomized components
- **Permissions**: 0700 (user-only access)
- **Cleanup**: Daily at 3:35 AM, 3+ day old files deleted
- **SIP**: Not protected, always writable

### Linux Specifics  
- **Standard**: `/tmp` (often tmpfs), `/var/tmp` (persistent)
- **Permissions**: 1777 (world-writable + sticky bit)
- **Cleanup**: systemd-tmpfiles (10 days /tmp, 30 days /var/tmp)
- **Security**: PrivateTmp, polyinstantiation available

### Windows Specifics
- **Variables**: `%TEMP%` and `%TMP%` (identical)
- **Path**: `C:\Users\{user}\AppData\Local\Temp`
- **WSL Issues**: Windows executables can't access WSL `/tmp`
- **No auto-cleanup**: Manual tools required

## Security Considerations

1. **Use mktemp when available** for cryptographically secure names
2. **Proper permissions**: 0600 files, 0700 directories  
3. **Avoid predictable names**: Never use PID/timestamp alone
4. **Atomic creation**: Prevent race conditions
5. **Always cleanup**: Temporary files are application responsibility

## Edge Cases Identified

1. **Read-only filesystems**: Corporate/security restrictions
2. **Missing directories**: Minimal/container environments  
3. **Permission denied**: SELinux, AppArmor, corporate policies
4. **Container environments**: Docker, limited filesystem access
5. **Network filesystems**: NFS-mounted temp with different permissions

## Implementation Requirements

Based on this research, the temp directory detection system must:

1. **Test each candidate** for existence, writability, executability
2. **Handle missing directories** gracefully with fallbacks
3. **Provide meaningful errors** when no suitable directory found
4. **Support environment variable override** (CLAUDE_AUTO_TEE_TMPDIR)
5. **Work in containers** with restricted filesystem access
6. **Be secure by default** with proper permission handling

## Next Steps

This research enables implementation of:
- **P1.T002**: Implement fallback hierarchy for temp directory detection
- **P1.T003**: Add environment variable override support  
- **P1.T004**: Handle edge cases (read-only filesystems, missing directories)

## References

- POSIX standards for temporary directory handling
- Platform-specific documentation (macOS, Linux, Windows)
- Container and security framework considerations
- Cross-platform bash scripting best practices

---
*Research completed for claude-auto-tee Phase 1 implementation*