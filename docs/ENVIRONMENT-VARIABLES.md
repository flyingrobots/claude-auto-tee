# Environment Variable Overrides

This document describes the environment variables that can be used to customize claude-auto-tee behavior (P1.T003).

## Overview

Claude Auto-Tee supports several environment variables that allow users to override default behavior without modifying configuration files. These variables provide fine-grained control over temp directory selection, file naming, cleanup behavior, and debugging output.

## Available Environment Variables

### Core Functionality Overrides

#### `CLAUDE_AUTO_TEE_TEMP_DIR`
**Purpose**: Override the temp directory detection chain  
**Default**: Uses platform-specific temp directory hierarchy  
**Example**: `export CLAUDE_AUTO_TEE_TEMP_DIR=/custom/temp/path`

Forces claude-auto-tee to use a specific directory for temp files, bypassing the standard temp directory detection chain. The directory must exist and be writable.

**Priority**: Highest (checked before TMPDIR, TMP, TEMP)

#### `CLAUDE_AUTO_TEE_VERBOSE`
**Purpose**: Enable verbose logging output  
**Default**: `false`  
**Values**: `true`, `false`  
**Example**: `export CLAUDE_AUTO_TEE_VERBOSE=true`

When enabled, outputs detailed logging information to stderr showing temp directory detection, disk space checks, and command processing steps.

#### `CLAUDE_AUTO_TEE_CLEANUP_ON_SUCCESS`
**Purpose**: Control automatic cleanup of temp files on successful command completion  
**Default**: `true`  
**Values**: `true`, `false`  
**Example**: `export CLAUDE_AUTO_TEE_CLEANUP_ON_SUCCESS=false`

When `true`, successfully completed commands will automatically clean up their temp files. When `false`, all temp files are preserved for manual inspection.

### File Management Overrides

#### `CLAUDE_AUTO_TEE_TEMP_PREFIX`
**Purpose**: Customize the prefix used for temp file names  
**Default**: `claude`  
**Example**: `export CLAUDE_AUTO_TEE_TEMP_PREFIX=mytool`

Changes the temp file naming pattern from `claude-{timestamp}.log` to `{prefix}-{timestamp}.log`.

#### `CLAUDE_AUTO_TEE_MAX_SIZE`
**Purpose**: Set maximum size limit for temp files  
**Default**: 104857600 (100MB)  
**Format**: Size in bytes (numeric)  
**Example**: `export CLAUDE_AUTO_TEE_MAX_SIZE=52428800`  # 50MB

Enforces a hard limit on temp file size by using `head -c SIZE` in the command pipeline. When output exceeds this limit:
- Output is truncated at the specified size
- A warning message is displayed to stderr
- Temp file is created with truncated content
- Command continues normally with truncated data passed to the pipeline

**Size Guidelines:**
- **Small files**: 1MB-10MB for log analysis, config processing
- **Medium files**: 50MB-100MB for build outputs, test results  
- **Large files**: 500MB-1GB for data processing (use with caution)
- **Maximum recommended**: 1GB to avoid system resource issues

## Environment Variable Priority

The environment variables are processed in the following order:

1. **CLAUDE_AUTO_TEE_TEMP_DIR** - Highest priority temp directory override
2. **TMPDIR** - Standard Unix temp directory variable
3. **TMP** - Windows/cross-platform temp directory variable  
4. **TEMP** - Windows temp directory variable
5. **Platform defaults** - `/tmp`, `/var/tmp`, etc.
6. **Last resort** - `~/.tmp`, `~/tmp`, current directory

## Usage Examples

### Basic Verbose Mode
```bash
# Enable verbose logging for debugging
export CLAUDE_AUTO_TEE_VERBOSE=true
claude-code  # All subsequent commands will show detailed logging
```

### Custom Temp Directory
```bash
# Use a specific temp directory (must exist and be writable)
export CLAUDE_AUTO_TEE_TEMP_DIR=/mnt/fast-storage/temp
claude-code  # Temp files will be created in /mnt/fast-storage/temp
```

### Preserve All Temp Files
```bash
# Disable cleanup to preserve all temp files for analysis
export CLAUDE_AUTO_TEE_CLEANUP_ON_SUCCESS=false
claude-code  # All temp files will be preserved after command completion
```

### Custom File Prefix
```bash
# Use custom prefix for easier temp file identification
export CLAUDE_AUTO_TEE_TEMP_PREFIX=debug
claude-code  # Temp files will be named debug-{timestamp}.log
```

### Combined Configuration
```bash
# Set multiple overrides for a debugging session
export CLAUDE_AUTO_TEE_VERBOSE=true
export CLAUDE_AUTO_TEE_CLEANUP_ON_SUCCESS=false
export CLAUDE_AUTO_TEE_TEMP_PREFIX=debug
export CLAUDE_AUTO_TEE_TEMP_DIR=/tmp/claude-debug

claude-code  # Verbose mode, no cleanup, custom prefix, custom directory
```

## Shell Integration

### Bash/Zsh Profile Setup
Add to `~/.bashrc`, `~/.zshrc`, or equivalent:

```bash
# Claude Auto-Tee Environment Configuration
export CLAUDE_AUTO_TEE_VERBOSE=false
export CLAUDE_AUTO_TEE_CLEANUP_ON_SUCCESS=true
export CLAUDE_AUTO_TEE_TEMP_PREFIX=claude

# Optional: Set custom temp directory for all sessions
# export CLAUDE_AUTO_TEE_TEMP_DIR=/custom/temp/path
```

### Session-Specific Overrides
```bash
# Temporary override for current session only
CLAUDE_AUTO_TEE_VERBOSE=true claude-code

# Or export for session duration
export CLAUDE_AUTO_TEE_VERBOSE=true
claude-code
# ... multiple commands with verbose output ...
unset CLAUDE_AUTO_TEE_VERBOSE  # Reset to default
```

### Project-Specific Configuration
Create a `.env` file in your project directory:

```bash
# .env file for project-specific claude-auto-tee settings
CLAUDE_AUTO_TEE_VERBOSE=true
CLAUDE_AUTO_TEE_CLEANUP_ON_SUCCESS=false
CLAUDE_AUTO_TEE_TEMP_PREFIX=project
```

Then source it before running Claude Code:
```bash
source .env && claude-code
```

## Validation and Error Handling

### Directory Validation
- **CLAUDE_AUTO_TEE_TEMP_DIR**: Must exist, be writable, and executable
- Falls back to standard hierarchy if custom directory is not suitable
- Verbose logging shows directory testing process

### Value Validation
- **CLAUDE_AUTO_TEE_VERBOSE**: Only accepts `true` or `false`
- **CLAUDE_AUTO_TEE_CLEANUP_ON_SUCCESS**: Only accepts `true` or `false`
- **CLAUDE_AUTO_TEE_MAX_SIZE**: Must be numeric (bytes)
- **CLAUDE_AUTO_TEE_TEMP_PREFIX**: Any valid filename characters

### Fallback Behavior
If an environment variable contains an invalid value:
- Variable is ignored and default value is used
- Warning message logged in verbose mode
- System continues with graceful degradation

## Security Considerations

### Directory Permissions
- Custom temp directories should have appropriate permissions (700 recommended)
- Avoid using world-writable directories for temp files
- Ensure temp directory is on a filesystem with sufficient space

### Environment Variable Exposure
- Environment variables may be visible in process lists
- Consider using configuration files for sensitive deployments
- Temp file paths may be logged in verbose mode

### File Path Safety
- Custom prefixes are validated for safe filename characters
- Directory paths are normalized to prevent traversal attacks
- Temp files use secure random timestamps

## Troubleshooting

### Common Issues

**Issue**: "CLAUDE_AUTO_TEE_TEMP_DIR override not suitable"  
**Solution**: Verify directory exists and is writable: `ls -ld /path/to/dir`

**Issue**: Temp files not being cleaned up  
**Solution**: Check `CLAUDE_AUTO_TEE_CLEANUP_ON_SUCCESS` setting

**Issue**: No verbose output appearing  
**Solution**: Ensure `CLAUDE_AUTO_TEE_VERBOSE=true` (case-sensitive)

**Issue**: Invalid MAX_TEMP_FILE_SIZE warning  
**Solution**: Use numeric values only (bytes): `1048576` not `1MB`

### Debugging Environment Variables
```bash
# Check current environment variable values
env | grep CLAUDE_AUTO_TEE

# Test temp directory detection with verbose mode
export CLAUDE_AUTO_TEE_VERBOSE=true
echo '{"tool":{"name":"Bash","input":{"command":"ls | head"}},"timeout":null}' | src/claude-auto-tee.sh
```

## See Also

- [README.md](../README.md) - Installation and basic usage
- [VERBOSE-MODE.md](VERBOSE-MODE.md) - Detailed verbose mode documentation  
- [CLEANUP-ON-SUCCESS.md](CLEANUP-ON-SUCCESS.md) - Cleanup behavior details
- [PLATFORM-TEMP-RESEARCH.md](PLATFORM-TEMP-RESEARCH.md) - Temp directory research
- [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) - Common issues and solutions

---

*Environment Variables Documentation - P1.T003 Implementation*  
*Provides comprehensive override capabilities for advanced claude-auto-tee customization*