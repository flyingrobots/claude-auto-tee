# Manual Testing Checklist

This comprehensive manual testing guide complements the automated test suite (103 tests) and ensures complete validation coverage for all user scenarios, edge cases, and real-world usage patterns.

## 🎯 Testing Overview

**Purpose**: Validate claude-auto-tee functionality through manual testing scenarios that require human judgment, real-world validation, and end-to-end user experience verification.

**Scope**: Manual testing focuses on areas that automated tests cannot effectively cover:

- Installation and setup procedures
- User experience and workflow validation  
- Real-world Claude Code integration
- Performance under actual usage conditions
- Platform-specific behavior verification

---

## 📋 Pre-Testing Setup

### Environment Preparation

- [ ] **Clean Environment**: Test on fresh system or VM
- [ ] **Platform Selection**: Choose target platform (macOS, Linux, Windows WSL)
- [ ] **Claude Code**: Ensure Claude Code is installed and functional
- [ ] **Dependencies**: Verify bash, git, and required tools available
- [ ] **Permissions**: Confirm appropriate file/directory permissions

### Documentation Review

- [ ] Review README.md installation instructions
- [ ] Review TROUBLESHOOTING.md for known issues
- [ ] Review TEST-COVERAGE.md for automated test coverage
- [ ] Familiarize with expected behavior patterns

---

## 🚀 Installation Testing

### Fresh Installation Process

- [ ] **Clone Repository**: `git clone https://github.com/flyingrobots/claude-auto-tee.git`
- [ ] **Directory Navigation**: `cd claude-auto-tee`
- [ ] **Permission Setting**: `chmod +x src/claude-auto-tee.sh`
- [ ] **Functionality Verification**: Test basic script execution

### Global Installation (Recommended Method)

- [ ] **Create Claude Config Directory**: `mkdir -p ~/.claude`
- [ ] **Install Hook Configuration**: Follow README.md step 3 exactly
- [ ] **Verify Configuration**: `cat ~/.claude/settings.json`
- [ ] **JSON Validation**: Ensure valid JSON structure
- [ ] **Path Verification**: Confirm absolute path in configuration

### Alternative Installation Methods

- [ ] **System-wide Installation**: Test `/usr/local/bin/` method
- [ ] **Project-local Installation**: Test `.claude/settings.json` method
- [ ] **Homebrew Installation**: Test if available (future)

### Installation Verification

- [ ] **Hook Response Test**: Manual input/output validation
- [ ] **Claude Code Integration**: Test with actual Claude Code session
- [ ] **Error Handling**: Verify graceful handling of configuration issues

---

## 🔧 Core Functionality Testing

### Basic Pipe Detection

Test with actual Claude Code commands:

- [ ] **Simple Pipe**: `ls -la | head -5`
  - **Expected**: Command modified with tee injection
  - **Verify**: Temp file created with full output
  
- [ ] **Complex Pipeline**: `find . -name "*.md" | grep -v node_modules | head -10`
  - **Expected**: Tee injected after first command
  - **Verify**: Complete find results saved to temp file
  
- [ ] **Build Command**: `npm run build 2>&1 | tail -20`
  - **Expected**: Full build log preserved
  - **Verify**: Can review complete build output later

### Non-Pipe Command Passthrough

- [ ] **Simple Commands**: `ls -la`, `pwd`, `echo "test"`
  - **Expected**: Commands pass through unchanged
  - **Verify**: No temp files created
  
- [ ] **Complex Non-Pipe**: `find . -name "*.js" -exec echo {} \;`
  - **Expected**: No modification, no temp file
  - **Verify**: Output appears normally

### Existing Tee Preservation

- [ ] **Manual Tee**: `ls -la | tee custom.log`
  - **Expected**: No modification of command
  - **Verify**: Only custom.log created, no claude temp file
  
- [ ] **Multi-Tee**: `command | tee first.log | tee second.log`
  - **Expected**: Command preserved as-is
  - **Verify**: Specified log files created correctly

---

## 🌍 Platform-Specific Testing

### macOS Testing

- [ ] **System Temp Directory**: Verify `/tmp/` usage
- [ ] **SIP Compatibility**: Test with System Integrity Protection enabled  
- [ ] **Homebrew Integration**: Test with Homebrew-installed bash
- [ ] **Terminal Variants**: Test in Terminal.app, iTerm2
- [ ] **Path Handling**: Verify absolute path resolution

### Linux Testing

- [ ] **Distribution Compatibility**: Test on Ubuntu, CentOS, Arch, etc.
- [ ] **SELinux**: Test with SELinux enabled/enforcing
- [ ] **Bash Versions**: Test with bash 3.0+, 4.0+, 5.0+
- [ ] **Container Environments**: Test in Docker containers
- [ ] **SSH Sessions**: Verify functionality over SSH

### Windows WSL Testing

- [ ] **WSL1 vs WSL2**: Test both subsystem versions
- [ ] **Distribution Variants**: Ubuntu, Debian, openSUSE
- [ ] **Path Translation**: Windows/Linux path handling
- [ ] **Temp Directory**: Verify WSL temp directory usage
- [ ] **Git Bash**: Test compatibility with Git Bash environment

---

## 📊 Performance Testing

### Response Time Validation

- [ ] **Small Commands**: `echo test | cat` (< 50ms expected)
- [ ] **Medium Commands**: `ls -la | head -10` (< 100ms expected)
- [ ] **Large Commands**: Complex find/grep operations (< 200ms expected)
- [ ] **JSON Processing**: Large JSON input handling

### Resource Usage Testing

- [ ] **Memory Usage**: Monitor hook memory consumption
- [ ] **Temp File Growth**: Test with large output commands
- [ ] **Cleanup Verification**: Confirm temp file cleanup
- [ ] **Concurrent Usage**: Multiple simultaneous Claude Code instances

### Stress Testing

- [ ] **Rapid Commands**: Quick succession of piped commands
- [ ] **Large Output**: Commands producing MB+ output
- [ ] **Long Sessions**: Extended Claude Code usage
- [ ] **Resource Exhaustion**: Low disk space scenarios

---

## 🔄 Integration Testing

### Claude Code Workflow Integration

- [ ] **Initial Setup**: Fresh Claude Code + claude-auto-tee installation
- [ ] **Hook Activation**: Verify automatic hook triggering
- [ ] **Command Execution**: Test actual development workflows
- [ ] **Output Review**: Verify temp file accessibility and usefulness

### Real-World Development Scenarios

- [ ] **Build Workflows**: `npm run build | tail -10`, review full log later
- [ ] **Log Analysis**: `tail -1000 app.log | grep ERROR | head -20`  
- [ ] **File Search**: `find . -name "*.js" | grep -v node_modules | wc -l`
- [ ] **Test Execution**: `npm test 2>&1 | grep -E "(FAIL|ERROR)"`

### Multi-Session Testing

- [ ] **Multiple Claude Code Windows**: Simultaneous usage
- [ ] **Session Isolation**: Verify temp files don't conflict  
- [ ] **Configuration Changes**: Live config reload testing
- [ ] **Hook Disable/Enable**: Dynamic configuration management

---

## ⚠️ Error Scenario Testing

### Configuration Errors

- [ ] **Invalid JSON**: Malformed settings.json
- [ ] **Missing Files**: Hook script not found
- [ ] **Permission Issues**: Non-executable hook script
- [ ] **Path Problems**: Relative vs absolute paths

### Runtime Errors

- [ ] **Disk Full**: No space for temp files
- [ ] **Permission Denied**: Read-only temp directory
- [ ] **Command Failures**: Commands that return non-zero exit codes
- [ ] **Broken Pipes**: Interrupted command chains

### Recovery Testing

- [ ] **Graceful Degradation**: Verify fallback behavior
- [ ] **Error Messages**: Clear, actionable error reporting
- [ ] **Auto-Recovery**: Automatic retry mechanisms
- [ ] **Manual Recovery**: User intervention procedures

---

## 🧪 Edge Case Testing

### Unusual Command Patterns

- [ ] **Very Long Commands**: 1000+ character command lines
- [ ] **Special Characters**: Commands with quotes, spaces, symbols
- [ ] **Unicode Content**: Non-ASCII characters in commands/output
- [ ] **Binary Output**: Commands that produce binary data

### Boundary Conditions

- [ ] **Empty Commands**: Zero-length or whitespace-only input
- [ ] **Nested Quotes**: Complex quoting scenarios
- [ ] **Command Substitution**: `$(command)` and backtick usage
- [ ] **Here Documents**: Multi-line input handling

### Platform Edge Cases

- [ ] **Case Sensitivity**: Filename case handling across platforms
- [ ] **Path Separators**: Unix vs Windows path handling
- [ ] **Line Endings**: CRLF vs LF handling
- [ ] **Locale Differences**: Non-English system locales

---

## 🔍 Security Testing

### Input Validation

- [ ] **Command Injection**: Attempt malicious command injection
- [ ] **Path Traversal**: Test with `../` sequences in paths
- [ ] **Shell Escaping**: Verify proper escape handling
- [ ] **JSON Injection**: Malformed JSON input handling

### File System Security

- [ ] **Temp File Permissions**: Verify secure temp file creation
- [ ] **Directory Traversal**: Prevent writing outside temp area
- [ ] **Symlink Attacks**: Test symlink handling security
- [ ] **Race Conditions**: Concurrent file access testing

### Privilege Testing

- [ ] **Non-Root Execution**: Verify works without elevated privileges
- [ ] **Restricted Environments**: Test in sandboxed environments  
- [ ] **SELinux/AppArmor**: Security framework compatibility
- [ ] **Container Security**: Docker/container environment testing

---

## 📝 Usability Testing

### User Experience Validation

- [ ] **Installation Clarity**: Can new user follow README successfully?
- [ ] **Error Messages**: Are errors clear and actionable?
- [ ] **Performance Perception**: Does system feel responsive?
- [ ] **Workflow Disruption**: Minimal impact on normal Claude Code usage

### Documentation Testing

- [ ] **README Accuracy**: All instructions work as described
- [ ] **Troubleshooting Guide**: Can users solve common issues?
- [ ] **Test Documentation**: Manual testing procedures are clear
- [ ] **Examples Validity**: All code examples function correctly

### Accessibility Testing

- [ ] **Screen Readers**: Basic compatibility (where applicable)
- [ ] **Color Blindness**: No color-dependent information
- [ ] **Motor Impairments**: No complex input sequences required
- [ ] **Cognitive Load**: Simple, predictable behavior patterns

---

## 🎯 Acceptance Testing

### User Story Validation

Test each user story from the project requirements:

- [ ] **"As a Claude Code user, I want my pipe commands to be preserved automatically"**
  - Test: Run typical pipe command, verify full output saved
  - Success Criteria: Complete output accessible without re-running
  
- [ ] **"As a developer, I want zero configuration overhead"**
  - Test: Fresh installation and immediate usage
  - Success Criteria: Works immediately after README installation
  
- [ ] **"As a user, I want reliable cross-platform behavior"**
  - Test: Same commands on different platforms
  - Success Criteria: Consistent behavior across macOS/Linux/Windows WSL

### Business Requirements Validation

- [ ] **Performance**: Hook adds < 50ms latency to commands
- [ ] **Reliability**: 99.9% successful hook execution rate
- [ ] **Compatibility**: Works with bash 3.0+ across platforms
- [ ] **Storage**: Efficient temp file usage and cleanup

---

## 📊 Test Execution Tracking

### Test Session Information

- **Tester Name**: ________________
- **Date**: ________________  
- **Platform**: ________________
- **Environment**: ________________
- **Claude Code Version**: ________________
- **claude-auto-tee Version**: ________________

### Results Summary

- **Total Test Cases**: 100+
- **Passed**: _____ / _____
- **Failed**: _____ / _____
- **Blocked**: _____ / _____
- **Not Tested**: _____ / _____

### Critical Issues Found

| Issue | Severity | Description | Status |
|-------|----------|-------------|---------|
| | | | |
| | | | |
| | | | |

### Test Completion Sign-off

- [ ] All critical tests passed
- [ ] No blocking issues remain
- [ ] Cross-platform validation complete
- [ ] Performance requirements met
- [ ] Security validation passed
- [ ] Usability requirements satisfied

**Tester Signature**: ________________ **Date**: ________________

---

## 🔄 Regression Testing

### After Each Release

- [ ] **Core Functionality**: Re-test basic pipe detection and injection
- [ ] **Platform Compatibility**: Verify continued cross-platform support
- [ ] **Performance Baseline**: Confirm no performance regression
- [ ] **Integration**: Re-test Claude Code integration

### Change-Specific Testing

- [ ] **Configuration Changes**: Test new settings and options
- [ ] **Algorithm Updates**: Validate improved pipe detection logic
- [ ] **Platform Updates**: Test with new OS versions
- [ ] **Dependency Changes**: Verify compatibility with updated dependencies

---

## 📚 Testing Resources

### Required Tools

- **Claude Code**: Latest version installed and configured
- **Git**: For repository cloning and version control
- **Text Editor**: For configuration file editing
- **Terminal/Shell**: Native terminal application
- **Process Monitor**: For performance/resource monitoring (optional)

### Reference Materials

- [README.md](README.md): Installation and usage instructions
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md): Common issues and solutions  
- [TEST-COVERAGE.md](TEST-COVERAGE.md): Automated test coverage details
- [Project Issues](https://github.com/flyingrobots/claude-auto-tee/issues): Known issues and feature requests

### Contact Information

- **Project Repository**: [https://github.com/flyingrobots/claude-auto-tee](https://github.com/flyingrobots/claude-auto-tee)
- **Issue Reporting**: Use GitHub Issues for bug reports
- **Documentation**: Available in project root directory

---

*Manual Testing Checklist v1.0 - Created to ensure comprehensive validation coverage for claude-auto-tee functionality, usability, and reliability across all supported platforms and use cases.*