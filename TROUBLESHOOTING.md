# 🔧 Troubleshooting Guide

This guide covers common error scenarios you might encounter when using claude-auto-tee and how to resolve them.

## 📋 Quick Diagnosis

If you encounter an error, first check:
1. **Error code** - All errors include numeric codes (1-99) for precise identification
2. **Error message** - Detailed descriptions explaining what went wrong
3. **Context** - When and what command triggered the error
4. **Platform** - Some issues are platform-specific (macOS/Linux/Windows)

## 🚨 Common Error Scenarios

### Input/Configuration Errors (1-9)

#### Error 1: Invalid Input
**Problem:** `[ERROR 1] Invalid input provided`
- **Cause:** Malformed or missing input to claude-auto-tee
- **Solution:**
  ```bash
  # Ensure you're piping valid command output
  echo "ls -la" | claude-auto-tee  # ✅ Good
  echo "" | claude-auto-tee       # ❌ Bad - empty input
  ```

#### Error 2: Malformed JSON  
**Problem:** `[ERROR 2] Malformed JSON input`
- **Cause:** Invalid JSON structure in configuration or input
- **Solution:**
  - Validate JSON syntax using `jq` or online validator
  - Check for trailing commas, unescaped quotes, or missing brackets
  ```bash
  # Test your JSON
  echo '{"command": "ls -la"}' | jq '.' # Should parse without error
  ```

#### Error 3: Missing Command
**Problem:** `[ERROR 3] No command specified in input` 
- **Cause:** No command provided to execute
- **Solution:**
  ```bash
  # Provide a command
  echo "pwd && date" | claude-auto-tee  # ✅ Good
  echo "" | claude-auto-tee             # ❌ Bad
  ```

### Temp Directory/File System Errors (10-19)

#### Error 10: No Temp Directory
**Problem:** `[ERROR 10] No suitable temp directory found`
- **Cause:** System temp directories not available or accessible
- **Platform-specific solutions:**
  
  **macOS/Linux:**
  ```bash
  export TMPDIR=/tmp
  mkdir -p "$TMPDIR" && chmod 755 "$TMPDIR"
  ```
  
  **Windows (WSL):**
  ```bash
  export TMPDIR=/mnt/c/temp
  mkdir -p "$TMPDIR"
  ```

#### Error 11: Temp Directory Not Writable
**Problem:** `[ERROR 11] Temp directory is not writable`
- **Cause:** Permission issues with temp directory
- **Solution:**
  ```bash
  # Check permissions
  ls -ld "$TMPDIR" || ls -ld /tmp
  
  # Fix permissions (macOS/Linux)
  sudo chmod 755 /tmp
  
  # Alternative: Use user temp directory
  export TMPDIR="$HOME/tmp"
  mkdir -p "$TMPDIR"
  ```

#### Error 12: Temp File Creation Failed
**Problem:** `[ERROR 12] Failed to create temp file`
- **Causes & Solutions:**
  - **Disk full:** Free up space or use different temp location
  - **Permission denied:** Check directory permissions
  - **Name collision:** Usually auto-resolved, but restart if persistent
  ```bash
  # Check available space
  df -h /tmp
  
  # Check for permission issues
  touch /tmp/test.txt && rm /tmp/test.txt
  ```

### Resource/Space Errors (20-29)

#### Error 20: Insufficient Space
**Problem:** `[ERROR 20] Insufficient disk space for temp file`
- **Cause:** Not enough free space for output storage
- **Solution:**
  ```bash
  # Check available space
  df -h
  
  # Clean up space
  rm -rf /tmp/claude-*  # Remove old claude-auto-tee temp files
  docker system prune   # Free Docker space if using Docker
  
  # Use alternative temp location with more space
  export TMPDIR="/path/to/larger/disk/tmp"
  mkdir -p "$TMPDIR"
  ```

#### Error 21: Disk Full
**Problem:** `[ERROR 21] Disk full during operation`
- **Immediate action:** Stop running processes generating large output
- **Solution:** Free up disk space immediately
  ```bash
  # Quick cleanup
  sudo rm -rf /tmp/*
  sudo rm -rf ~/.cache/*  # User cache files
  
  # Find large files
  du -h / 2>/dev/null | sort -rh | head -20
  ```

### Command Execution Errors (30-39)

#### Error 30: Command Not Found
**Problem:** `[ERROR 30] Command not found`
- **Cause:** Command doesn't exist in PATH
- **Solution:**
  ```bash
  # Check if command exists
  which your-command
  command -v your-command
  
  # Add to PATH if needed
  export PATH="$PATH:/usr/local/bin:/opt/homebrew/bin"
  
  # Use full path
  echo "/usr/bin/ls -la" | claude-auto-tee
  ```

#### Error 31: Command Timeout
**Problem:** `[ERROR 31] Command execution timed out`
- **Cause:** Command taking too long to execute
- **Solution:**
  ```bash
  # For long-running commands, increase timeout
  timeout 300s your-long-command | claude-auto-tee
  
  # Or run without claude-auto-tee for very long commands
  your-long-command > output.log 2>&1
  ```

#### Error 34: Broken Pipe
**Problem:** `[ERROR 34] Broken pipe in command chain`
- **Cause:** One part of pipe chain terminated unexpectedly
- **Solution:**
  ```bash
  # Check each part of your pipeline individually
  cmd1 | tee debug1.log | cmd2 | tee debug2.log | cmd3
  
  # Use set -o pipefail to catch pipe errors
  set -o pipefail
  your-command-chain | claude-auto-tee
  ```

### Platform-Specific Issues (60-69)

#### Error 60: Platform Compatibility
**Problem:** `[ERROR 60] Platform compatibility issue detected`

**macOS Issues:**
- **SIP (System Integrity Protection):** Some system directories protected
  ```bash
  # Use homebrew installation directory
  export PATH="/opt/homebrew/bin:$PATH"
  ```

**Linux Issues:**
- **SELinux:** May block temp file operations
  ```bash
  # Check SELinux status
  getenforce
  
  # Temporary disable if needed (caution!)
  sudo setenforce 0
  ```

**Windows/WSL Issues:**
- **Path separators:** Use Unix-style paths in WSL
- **File permissions:** Windows filesystem may not support Unix permissions
  ```bash
  # Ensure using WSL paths
  export TMPDIR="/mnt/c/Users/$USER/AppData/Local/Temp"
  mkdir -p "$TMPDIR"
  ```

### Permission/Security Errors (70-79)

#### Error 70: Permission Denied
**Problem:** `[ERROR 70] Permission denied`
- **Cause:** Insufficient permissions for file/directory access
- **Solution:**
  ```bash
  # Check current user permissions
  id
  groups
  
  # Fix temp directory permissions
  sudo chown $USER:$USER /tmp/claude-*
  
  # Use user-owned temp directory
  export TMPDIR="$HOME/.cache/claude-auto-tee"
  mkdir -p "$TMPDIR"
  chmod 755 "$TMPDIR"
  ```

## 🔍 Advanced Debugging

### Enable Verbose Logging
```bash
# Set debug mode
export CLAUDE_AUTO_TEE_DEBUG=1

# Run your command
echo "ls -la" | claude-auto-tee

# Check debug output in temp files
ls -la /tmp/claude-*.log
```

### Check System Requirements
```bash
# Verify bash version (requires 3.0+)
bash --version

# Check available temp space
df -h /tmp

# Verify tee command works
echo "test" | tee /tmp/test.log
```

### Trace Execution
```bash
# Run with bash tracing
bash -x /path/to/claude-auto-tee.sh < <(echo "your command")

# Or enable tracing in script
set -x
your-command | claude-auto-tee
set +x
```

## 📱 Platform-Specific Quick Fixes

### macOS
```bash
# Common macOS fixes
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export TMPDIR="${TMPDIR:-/tmp}"
```

### Ubuntu/Debian
```bash
# Install missing dependencies
sudo apt-get update
sudo apt-get install coreutils

# Fix temp permissions
sudo chmod 1777 /tmp
```

### CentOS/RHEL
```bash
# SELinux context issues
sudo restorecon -R /tmp

# Temp directory setup
sudo mkdir -p /var/tmp/claude-auto-tee
sudo chown $USER:$USER /var/tmp/claude-auto-tee
export TMPDIR="/var/tmp/claude-auto-tee"
```

### Windows WSL
```bash
# Use Windows temp directory
export TMPDIR="/mnt/c/temp"
mkdir -p "$TMPDIR"

# Fix line ending issues  
dos2unix /path/to/claude-auto-tee.sh
```

## 🆘 Getting Help

### Before Reporting Issues
1. **Check error code** - Use this guide to find solutions
2. **Test minimal case** - Try with simple commands first
3. **Check platform** - Note your OS and shell version
4. **Collect logs** - Enable debug mode and collect output

### Report Template
```
**Error Code:** [ERROR XX]
**Platform:** macOS 13.x / Ubuntu 20.04 / Windows WSL2
**Shell:** bash 5.x.x
**Command:** echo "ls -la" | claude-auto-tee
**Full Error Message:** [paste complete error]
**Debug Output:** [paste with CLAUDE_AUTO_TEE_DEBUG=1]
```

### Useful Debug Commands
```bash
# System information
uname -a
bash --version
echo $TMPDIR
df -h /tmp

# Test basic functionality
echo "pwd" | tee /tmp/test.log
cat /tmp/test.log

# Check permissions
ls -la /tmp/claude-*
```

## 🔧 Recovery Procedures

### Clean Reset
```bash
# Remove all claude-auto-tee temp files
rm -rf /tmp/claude-* 2>/dev/null

# Reset environment
unset TMPDIR CLAUDE_AUTO_TEE_DEBUG
export TMPDIR="/tmp"

# Test basic functionality
echo "echo test" | claude-auto-tee
```

### Emergency Fallback
```bash
# If claude-auto-tee is completely broken, use manual tee
your-command 2>&1 | tee "$(mktemp).log"
```

---

*This troubleshooting guide covers the most common scenarios. For additional help, please check our [GitHub Issues](https://github.com/flyingrobots/claude-auto-tee/issues) or create a new issue with the report template above.*