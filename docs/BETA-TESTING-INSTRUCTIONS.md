# Claude Auto-Tee Beta Testing Instructions

**Task:** P1.T058 - Create beta testing instructions  
**Date:** 2025-08-12  
**Status:** Ready for Execution  

## 🎯 Overview

This document provides comprehensive testing instructions for claude-auto-tee beta testers. These instructions ensure systematic testing coverage across all supported platforms, features, and edge cases.

## 📋 Prerequisites

Before starting, ensure you have:
- [ ] Completed the onboarding process (see BETA-ONBOARDING-GUIDE.md)
- [ ] Claude Code installed and working on your system
- [ ] Access to the beta testing Discord/GitHub channels
- [ ] At least 2-4 hours per week for testing activities

## 🗺️ Testing Roadmap

### Week 1: Core Functionality Testing
**Focus:** Basic pipe detection, temp file creation, cross-platform compatibility

### Week 2: Advanced Features & Edge Cases  
**Focus:** Error handling, resource management, environment variables

### Week 3: Integration & Real-World Testing
**Focus:** Daily workflow integration, performance, reliability

### Week 4: Polish & Feedback Synthesis
**Focus:** Documentation feedback, final bugs, user experience

---

## 📝 Test Execution Instructions

### Before Each Testing Session

1. **Environment Check**
   ```bash
   # Verify Claude Code is working
   echo '{"tool":{"name":"Bash","input":{"command":"echo test"}},"timeout":null}' | claude-code
   
   # Check temp directory space
   df -h ${TMPDIR:-/tmp}
   
   # Enable verbose mode for testing
   export CLAUDE_AUTO_TEE_VERBOSE=true
   ```

2. **Create Test Log**
   ```bash
   # Create session log file
   TEST_SESSION="beta-test-$(date +%Y%m%d-%H%M%S).log"
   echo "=== Claude Auto-Tee Beta Test Session ===" > "$TEST_SESSION"
   echo "Date: $(date)" >> "$TEST_SESSION"
   echo "Platform: $(uname -a)" >> "$TEST_SESSION"
   echo "Claude Code Version: $(claude-code --version 2>/dev/null || echo 'unknown')" >> "$TEST_SESSION"
   echo "" >> "$TEST_SESSION"
   ```

### After Each Testing Session

1. **Collect Results**
   - Save any error messages or unexpected behavior
   - Note temp file locations and cleanup status
   - Document any performance observations

2. **Submit Feedback**
   - Post findings in Discord #bug-reports or #general
   - Create GitHub issues for reproducible bugs
   - Share positive findings and success stories

---

## 🧪 Test Cases

### Core Functionality Tests (Week 1)

#### Test Case 1.1: Basic Pipe Detection
**Objective:** Verify automatic tee injection works correctly

**Steps:**
1. Run a simple command with pipe:
   ```bash
   echo '{"tool":{"name":"Bash","input":{"command":"ls -la | head -5"}},"timeout":null}' | claude-code
   ```

**Expected Results:**
- Command should be modified to include `| tee /tmp/claude-auto-tee-*.log`
- Output appears both in terminal and temp file
- Temp file path is reported in output

**Report Format:**
```
Test 1.1 - Basic Pipe Detection
Status: PASS/FAIL
Platform: [your platform]
Notes: [any observations]
```

#### Test Case 1.2: Complex Pipeline Preservation
**Objective:** Ensure complex pipelines work correctly

**Steps:**
1. Test multi-stage pipeline:
   ```bash
   echo '{"tool":{"name":"Bash","input":{"command":"ps aux | grep -v grep | sort | head -10"}},"timeout":null}' | claude-code
   ```

**Expected Results:**
- Tee injection at appropriate point (after first command)
- All pipeline stages execute correctly
- Final output matches expected results

#### Test Case 1.3: No False Positives
**Objective:** Ensure tee is not added unnecessarily

**Steps:**
1. Test commands that should NOT trigger tee:
   ```bash
   # Commands without pipes
   echo '{"tool":{"name":"Bash","input":{"command":"ls -la"}},"timeout":null}' | claude-code
   
   # Commands with existing tee
   echo '{"tool":{"name":"Bash","input":{"command":"ls | tee /tmp/existing.log"}},"timeout":null}' | claude-code
   ```

**Expected Results:**
- No tee injection for commands without pipes
- No double-tee for commands that already have tee

### Cross-Platform Tests (Week 1)

#### Test Case 1.4: Platform-Specific Temp Directories
**Objective:** Verify temp directory detection works on your platform

**Steps:**
1. Test default temp directory usage:
   ```bash
   unset TMPDIR TMP TEMP CLAUDE_AUTO_TEE_TEMP_DIR
   echo '{"tool":{"name":"Bash","input":{"command":"echo platform-test | wc -l"}},"timeout":null}' | claude-code
   ```

2. Test environment variable override:
   ```bash
   export CLAUDE_AUTO_TEE_TEMP_DIR="/tmp/claude-test"
   mkdir -p "/tmp/claude-test"
   echo '{"tool":{"name":"Bash","input":{"command":"echo override-test | wc -l"}},"timeout":null}' | claude-code
   ```

**Expected Results:**
- Temp files created in appropriate directory for your platform
- Environment variable overrides work correctly
- Verbose mode shows temp directory selection logic

#### Test Case 1.5: Path Handling
**Objective:** Test path handling for your specific platform

**Steps:**
```bash
# Test paths with spaces (if applicable to your platform)
export CLAUDE_AUTO_TEE_TEMP_DIR="/tmp/path with spaces"
mkdir -p "/tmp/path with spaces"
echo '{"tool":{"name":"Bash","input":{"command":"echo space-test | head -1"}},"timeout":null}' | claude-code

# Test long paths
export CLAUDE_AUTO_TEE_TEMP_DIR="/tmp/very/deep/directory/structure/for/testing"
mkdir -p "/tmp/very/deep/directory/structure/for/testing"
echo '{"tool":{"name":"Bash","input":{"command":"echo deep-test | head -1"}},"timeout":null}' | claude-code
```

**Expected Results:**
- Paths with spaces handled correctly (if supported)
- Deep directory structures work
- Appropriate error messages if paths are invalid

### Advanced Features Tests (Week 2)

#### Test Case 2.1: Environment Variable Configuration
**Objective:** Test all environment variable options

**Steps:**
1. Test verbose mode:
   ```bash
   export CLAUDE_AUTO_TEE_VERBOSE=true
   echo '{"tool":{"name":"Bash","input":{"command":"echo verbose-test | head -1"}},"timeout":null}' | claude-code
   ```

2. Test cleanup options:
   ```bash
   export CLAUDE_AUTO_TEE_CLEANUP_ON_SUCCESS=false
   echo '{"tool":{"name":"Bash","input":{"command":"echo no-cleanup | head -1"}},"timeout":null}' | claude-code
   # Verify temp file remains after completion
   ```

3. Test custom prefix:
   ```bash
   export CLAUDE_AUTO_TEE_TEMP_PREFIX=beta-test
   echo '{"tool":{"name":"Bash","input":{"command":"echo prefix-test | head -1"}},"timeout":null}' | claude-code
   # Check that temp files use beta-test-* naming
   ```

4. Test size limits:
   ```bash
   export CLAUDE_AUTO_TEE_MAX_SIZE=1024  # 1KB limit
   echo '{"tool":{"name":"Bash","input":{"command":"head -c 2048 /dev/zero | base64"}},"timeout":null}' | claude-code
   # Should see truncation warning
   ```

**Expected Results:**
- All environment variables function as documented
- Verbose mode provides useful debugging information
- Size limits prevent excessive temp file creation

#### Test Case 2.2: Error Handling and Edge Cases
**Objective:** Test graceful degradation and error scenarios

**Steps:**
1. Test insufficient disk space (simulate with very small size limit):
   ```bash
   export CLAUDE_AUTO_TEE_MAX_SIZE=10  # 10 bytes
   echo '{"tool":{"name":"Bash","input":{"command":"echo this-is-longer-than-ten-bytes | head -1"}},"timeout":null}' | claude-code
   ```

2. Test read-only temp directory:
   ```bash
   # Create read-only directory (platform-specific)
   mkdir -p /tmp/readonly-test
   chmod 444 /tmp/readonly-test
   export CLAUDE_AUTO_TEE_TEMP_DIR=/tmp/readonly-test
   echo '{"tool":{"name":"Bash","input":{"command":"echo readonly-test | head -1"}},"timeout":null}' | claude-code
   ```

3. Test very long command output:
   ```bash
   export CLAUDE_AUTO_TEE_MAX_SIZE=104857600  # Reset to 100MB
   echo '{"tool":{"name":"Bash","input":{"command":"seq 1 10000 | head -100"}},"timeout":null}' | claude-code
   ```

**Expected Results:**
- Appropriate error messages for disk space issues
- Graceful fallback for read-only directories
- Large outputs handled without system impact

#### Test Case 2.3: Age-Based Cleanup Testing
**Objective:** Test orphaned file cleanup functionality

**Steps:**
1. Create some orphaned files manually:
   ```bash
   # Create old temp files
   touch /tmp/claude-old-$$.log
   
   # Make them appear old (if your system supports it)
   touch -t 202501010000 /tmp/claude-old-$$.log
   
   # Test cleanup on next run
   export CLAUDE_AUTO_TEE_CLEANUP_AGE_HOURS=1
   echo '{"tool":{"name":"Bash","input":{"command":"echo cleanup-test | head -1"}},"timeout":null}' | claude-code
   ```

2. Test cleanup disable:
   ```bash
   export CLAUDE_AUTO_TEE_ENABLE_AGE_CLEANUP=false
   echo '{"tool":{"name":"Bash","input":{"command":"echo no-cleanup-test | head -1"}},"timeout":null}' | claude-code
   ```

**Expected Results:**
- Old temp files are cleaned up when enabled
- Cleanup can be disabled via environment variable
- Verbose mode shows cleanup activity

### Integration Tests (Week 3)

#### Test Case 3.1: Real Workflow Integration
**Objective:** Test claude-auto-tee in your actual daily workflow

**Steps:**
1. Use claude-auto-tee with your typical development commands:
   - Build processes (`npm run build`, `make`, `cargo build`, etc.)
   - Test suites (`npm test`, `pytest`, `go test`, etc.)
   - Data processing (`grep`, `sed`, `awk` combinations)
   - System administration (`ps`, `netstat`, `df` with pipes)

2. Run for several days with normal work activities

**Expected Results:**
- No interference with normal workflow
- Helpful temp file preservation for expensive operations
- Reasonable resource usage (disk space, performance)

#### Test Case 3.2: Performance Impact Assessment
**Objective:** Measure any performance overhead

**Steps:**
1. Baseline measurement (without claude-auto-tee):
   ```bash
   time echo '{"tool":{"name":"Bash","input":{"command":"seq 1 1000 | sort -n | tail -10"}},"timeout":null}' | claude-code-without-hook
   ```

2. With claude-auto-tee:
   ```bash
   time echo '{"tool":{"name":"Bash","input":{"command":"seq 1 1000 | sort -n | tail -10"}},"timeout":null}' | claude-code
   ```

3. Resource monitoring:
   ```bash
   # Monitor during large operations
   echo '{"tool":{"name":"Bash","input":{"command":"find /usr -type f 2>/dev/null | head -1000"}},"timeout":null}' | claude-code
   ```

**Expected Results:**
- Minimal performance overhead (< 5% in most cases)
- Reasonable memory usage
- No significant CPU impact

#### Test Case 3.3: Concurrent Usage Testing
**Objective:** Test multiple simultaneous claude-code sessions

**Steps:**
1. Run multiple sessions simultaneously:
   ```bash
   # Terminal 1
   echo '{"tool":{"name":"Bash","input":{"command":"sleep 5 && echo session1 | head -1"}},"timeout":null}' | claude-code &
   
   # Terminal 2
   echo '{"tool":{"name":"Bash","input":{"command":"sleep 5 && echo session2 | head -1"}},"timeout":null}' | claude-code &
   
   # Terminal 3
   echo '{"tool":{"name":"Bash","input":{"command":"sleep 5 && echo session3 | head -1"}},"timeout":null}' | claude-code &
   
   wait
   ```

**Expected Results:**
- No conflicts between concurrent sessions
- Each session gets unique temp files
- All sessions complete successfully

### Platform-Specific Tests

#### macOS Specific Tests
If you're testing on macOS, also run:

1. **System Integrity Protection (SIP) Compatibility**
   ```bash
   # Test access to system directories
   echo '{"tool":{"name":"Bash","input":{"command":"ls /System/Library | head -5"}},"timeout":null}' | claude-code
   ```

2. **Homebrew Environment Integration**
   ```bash
   # Test with homebrew-installed tools
   echo '{"tool":{"name":"Bash","input":{"command":"brew list --formula | head -10"}},"timeout":null}' | claude-code
   ```

#### Linux Specific Tests
If you're testing on Linux, also run:

1. **Distribution-Specific Package Managers**
   ```bash
   # Ubuntu/Debian
   echo '{"tool":{"name":"Bash","input":{"command":"apt list --installed | head -10"}},"timeout":null}' | claude-code
   
   # RHEL/CentOS/Fedora
   echo '{"tool":{"name":"Bash","input":{"command":"rpm -qa | head -10"}},"timeout":null}' | claude-code
   ```

2. **SELinux Compatibility (if enabled)**
   ```bash
   # Check SELinux status impact
   echo '{"tool":{"name":"Bash","input":{"command":"getenforce 2>/dev/null || echo no-selinux"}},"timeout":null}' | claude-code
   ```

#### Windows WSL Specific Tests
If you're testing on Windows WSL, also run:

1. **Windows Filesystem Access**
   ```bash
   # Test Windows drive access
   echo '{"tool":{"name":"Bash","input":{"command":"ls /mnt/c | head -5"}},"timeout":null}' | claude-code
   ```

2. **Mixed Path Scenarios**
   ```bash
   # Test with Windows-style paths
   export CLAUDE_AUTO_TEE_TEMP_DIR="/mnt/c/temp/claude-test"
   mkdir -p "/mnt/c/temp/claude-test"
   echo '{"tool":{"name":"Bash","input":{"command":"echo windows-path-test | head -1"}},"timeout":null}' | claude-code
   ```

---

## 🐛 Bug Reporting Guidelines

### When to Report a Bug

Report issues when you encounter:
- **Functionality Failures:** Commands fail that should work
- **Data Loss:** Temp files not created or lost unexpectedly  
- **Performance Problems:** Significant slowdowns or resource usage
- **Cross-Platform Issues:** Platform-specific failures
- **Documentation Gaps:** Instructions unclear or incorrect

### Bug Report Template

```markdown
**Bug Summary:** Brief description

**Environment:**
- OS: [macOS 14.1.1 / Ubuntu 22.04 / Windows 11 WSL2]
- Shell: [bash 5.1 / zsh 5.9]
- Claude Code Version: [output of claude-code --version]

**Steps to Reproduce:**
1. Set environment: export CLAUDE_AUTO_TEE_VERBOSE=true
2. Run command: echo '{"tool":{...}}' | claude-code  
3. Observe result

**Expected Behavior:**
[What should happen]

**Actual Behavior:**
[What actually happened]

**Error Messages:**
[Paste any error messages]

**Additional Context:**
- Temp file status: [created/missing/wrong location]
- Performance impact: [none/slow/very slow]
- Workaround found: [if any]

**Test Session Log:**
[Attach your test session log file]
```

### Severity Levels

**Critical (P0):** 
- Data loss or corruption
- System crashes or hangs
- Security vulnerabilities

**High (P1):**
- Core functionality broken
- Cross-platform compatibility failures
- Performance significantly degraded

**Medium (P2):**
- Edge case failures
- Minor feature issues
- Documentation problems

**Low (P3):**
- Cosmetic issues
- Enhancement requests
- Minor usability problems

---

## ✅ Test Completion Checklist

### Week 1 Completion
- [ ] Completed all Core Functionality Tests (1.1-1.3)
- [ ] Completed Cross-Platform Tests (1.4-1.5)
- [ ] Submitted at least one feedback report
- [ ] Verified basic integration with your workflow

### Week 2 Completion  
- [ ] Completed Environment Variable Tests (2.1)
- [ ] Completed Error Handling Tests (2.2)
- [ ] Completed Age-Based Cleanup Tests (2.3)
- [ ] Tested platform-specific scenarios
- [ ] Submitted detailed feedback on advanced features

### Week 3 Completion
- [ ] Completed Real Workflow Integration (3.1)
- [ ] Completed Performance Assessment (3.2)  
- [ ] Completed Concurrent Usage Testing (3.3)
- [ ] Used claude-auto-tee for daily work activities
- [ ] Provided feedback on real-world usage

### Week 4 Completion
- [ ] Reviewed and tested documentation accuracy
- [ ] Submitted final feedback summary
- [ ] Participated in community discussions
- [ ] Provided testimonial (if willing)

### Overall Program Completion
- [ ] Completed testing on your primary platform
- [ ] Submitted at least 3 detailed feedback reports
- [ ] Helped identify or verify at least 1 issue
- [ ] Provided constructive suggestions for improvement

---

## 📊 Success Metrics

We're measuring success through:

**Functionality Coverage:**
- Core pipe detection: >95% success rate
- Cross-platform compatibility: Works on all major platforms
- Error handling: Graceful degradation in all scenarios

**Quality Metrics:**
- Bug discovery rate: 1+ issues per active tester
- Performance impact: <5% overhead on typical commands  
- User satisfaction: 4+ stars from 80%+ of testers

**Community Engagement:**
- Active participation: 80%+ testers complete Week 1
- Retention rate: 60%+ complete full 4-week program
- Feedback quality: Actionable reports leading to improvements

---

## 🆘 Getting Help

**Quick Questions:**
- Discord #general channel for immediate help
- Tag @dev-team for urgent issues

**Technical Issues:**
- Discord #bug-reports for reproducible problems
- GitHub issues for detailed technical discussion

**Setup Problems:**
- Refer to BETA-ONBOARDING-GUIDE.md first
- Discord #general for setup assistance

**Emergency Contact:**
- Critical security or data loss issues
- Direct message @project-lead on Discord

---

**Thank you for being part of the claude-auto-tee beta testing program! Your feedback is crucial for making this tool reliable and valuable for the entire Claude Code community.**

*Happy testing! 🚀*