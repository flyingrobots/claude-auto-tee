# Platform-Specific Test Suite

**Task:** P1.T006 - Create platform-specific test cases  
**Purpose:** Comprehensive testing across macOS, Linux, and Windows WSL platforms

## Overview

The platform-specific test suite validates that claude-auto-tee works correctly across different operating systems, handling platform-unique characteristics, edge cases, and integration scenarios.

## Test Structure

### Main Test Script
- `test/platform-specific-tests.sh` - Master test runner that executes all platform tests

### Platform-Specific Test Files
- `test/platform/macos-tests.sh` - macOS-specific tests
- `test/platform/linux-tests.sh` - Linux-specific tests  
- `test/platform/windows-wsl-tests.sh` - Windows WSL-specific tests

## Running Platform Tests

### All Platform Tests
```bash
npm run test:platform
```

### Specific Platform Tests
```bash
npm run test:platform:macos      # macOS-specific tests
npm run test:platform:linux      # Linux-specific tests
npm run test:platform:wsl        # Windows WSL-specific tests
```

### Direct Execution
```bash
# Master test runner
bash test/platform-specific-tests.sh

# Individual platform tests
bash test/platform/macos-tests.sh
bash test/platform/linux-tests.sh
bash test/platform/windows-wsl-tests.sh
```

## Test Categories

### macOS-Specific Tests
- **Temp Directory Tests**
  - `/private/tmp` accessibility
  - `/var/folders` TMPDIR handling
  - Temp directory permissions
  
- **System Integration Tests**
  - System Integrity Protection (SIP) compatibility
  - Code signing compatibility
  - Quarantine attribute handling
  
- **Development Environment Tests**
  - Homebrew integration
  - Xcode command line tools
  - MacPorts integration (if installed)
  
- **Filesystem Tests**
  - Case-insensitive filesystem handling
  - Extended attributes (xattr)
  - Resource fork handling
  
- **Performance Tests**
  - Performance with Spotlight indexing
  - Memory pressure handling
  
- **Security Tests**
  - Gatekeeper compatibility
  - Privacy controls handling

### Linux-Specific Tests
- **Temp Directory Tests**
  - `/tmp` sticky bit handling
  - `/var/tmp` access
  - `/dev/shm` tmpfs handling
  
- **Security Tests**
  - SELinux compatibility
  - AppArmor compatibility
  - Linux capabilities handling
  
- **System Integration Tests**
  - `/proc` filesystem access
  - `/sys` filesystem access
  - systemd integration
  
- **Container Tests**
  - Container environment detection
  - cgroup awareness
  - Linux namespace handling
  
- **Distribution Tests**
  - Package manager integration (APT, DNF, YUM, Pacman, APK)
  - Init system compatibility
  
- **File System Tests**
  - ext4 features
  - XFS features  
  - Btrfs features

### Windows WSL-Specific Tests
- **WSL Environment Tests**
  - WSL environment variables
  - WSL interoperability support
  - WSL temp directory handling
  
- **Windows Filesystem Access Tests**
  - C: drive access via `/mnt/c`
  - Windows path translation
  - Case sensitivity with Windows filesystem
  
- **Windows Temp Variable Tests**
  - Windows-style temp variables (`TEMP`, `TMP`)
  - Mixed Linux/Windows path scenarios
  
- **Performance Tests**
  - WSL I/O performance
  - WSL memory handling
  
- **Windows Command Integration Tests**
  - cmd.exe integration
  - PowerShell integration
  - wslpath utility
  
- **Networking Tests**
  - WSL networking capabilities
  - Localhost access (WSL 1 vs WSL 2)
  
- **Edge Cases**
  - Line ending handling (CRLF vs LF)
  - Unicode with Windows filesystem
  - Symbolic link handling

### Cross-Platform Tests
- **Command Compatibility**
  - Cross-platform `stat` command variations
  - Cross-platform `mktemp` compatibility
  - `lsof` availability and behavior
  
- **System Integration**
  - Disk space checking across platforms
  - Process substitution compatibility
  - Unicode handling
  - Long path handling

## Test Features

### Automatic Platform Detection
Tests automatically detect the current platform and skip irrelevant tests:
- macOS tests skip on non-Darwin systems
- Linux tests skip on non-Linux systems  
- WSL tests skip when not running in WSL environment

### Comprehensive Validation
Each test validates:
- Basic hook functionality
- JSON structure integrity
- Platform-specific behavior
- Error handling
- Performance characteristics

### Detailed Reporting
Tests provide:
- Platform information (OS version, architecture, bash version)
- Individual test results with pass/fail status
- Comprehensive summary with failure details
- Actionable error messages for debugging

## Platform Requirements

### macOS
- macOS 10.14+ (Mojave or later)
- Bash 3.2+ (system default or Homebrew-installed)
- Optional: Homebrew, Xcode command line tools

### Linux
- Any modern Linux distribution
- Bash 4.0+ recommended
- Optional: systemd, SELinux, AppArmor, container runtime

### Windows WSL
- Windows 10 version 1903+ with WSL 1 or WSL 2
- Any supported Linux distribution in WSL
- Optional: Windows interop enabled

## Integration with CI/CD

Platform tests are integrated into the main test suite:
- `npm run test:all` includes platform-specific tests
- `npm run test:cross-platform` runs full cross-platform validation
- GitHub Actions can run tests on multiple platforms simultaneously

## Troubleshooting

### Common Issues

**Test Timeouts:**
- Some tests may take longer on slower systems
- Container environments may have different performance characteristics

**Permission Errors:**  
- Ensure temp directories are writable
- Some security features (SIP, SELinux) may restrict access

**Missing Dependencies:**
- Tests gracefully skip when optional tools aren't available
- Core functionality tests always run regardless of environment

### Debug Mode
Enable verbose output for debugging:
```bash
DEBUG=true bash test/platform-specific-tests.sh
```

## Contributing

When adding new platform-specific tests:

1. **Follow Existing Patterns**
   - Use consistent test structure and naming
   - Include comprehensive validation functions
   - Handle edge cases gracefully

2. **Platform Detection**
   - Always check platform before running platform-specific tests
   - Skip tests gracefully when not applicable
   - Provide clear skip messages

3. **Error Handling**
   - Test should handle missing dependencies
   - Provide actionable error messages
   - Clean up temporary resources

4. **Documentation**
   - Update this README with new test categories
   - Document any special requirements
   - Include examples of expected behavior

## Test Results

### Expected Results
- **All platforms**: Core functionality tests should pass
- **Platform-specific**: Only relevant tests run, all should pass
- **Edge cases**: Graceful degradation for unsupported features

### Performance Benchmarks
- macOS: Tests complete in < 30 seconds
- Linux: Tests complete in < 45 seconds  
- WSL: Tests complete in < 60 seconds (varies by WSL version)

---

**Note**: Platform-specific tests validate compatibility and catch platform-unique issues early in development. They ensure claude-auto-tee provides consistent behavior across all supported environments while respecting platform-specific conventions and limitations.