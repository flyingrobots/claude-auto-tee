# Beta Test Scenarios - Quick Reference

**Task:** P1.T058 - Create beta testing instructions  
**Date:** 2025-08-12  
**Purpose:** Ready-to-use test scenarios for beta testers  

## 🚀 Quick Test Suite

Copy and paste these commands to quickly verify claude-auto-tee functionality:

### Basic Functionality Test
```bash
# Test 1: Simple pipe detection
echo '{"tool":{"name":"Bash","input":{"command":"echo \"Hello Claude Auto-Tee\" | wc -c"}},"timeout":null}' | claude-code

# Test 2: Complex pipeline
echo '{"tool":{"name":"Bash","input":{"command":"ps aux | grep -v grep | head -5 | awk \"{print \\$1}\""}},"timeout":null}' | claude-code

# Test 3: No false positives (should NOT add tee)
echo '{"tool":{"name":"Bash","input":{"command":"ls -la"}},"timeout":null}' | claude-code
```

### Environment Variables Test
```bash
# Enable verbose mode and test
export CLAUDE_AUTO_TEE_VERBOSE=true
export CLAUDE_AUTO_TEE_TEMP_PREFIX=beta-test

echo '{"tool":{"name":"Bash","input":{"command":"date | head -1"}},"timeout":null}' | claude-code
```

### Platform-Specific Test
```bash
# Test temp directory override
mkdir -p /tmp/claude-beta-test
export CLAUDE_AUTO_TEE_TEMP_DIR=/tmp/claude-beta-test

echo '{"tool":{"name":"Bash","input":{"command":"uname -a | cut -d\" \" -f1-3"}},"timeout":null}' | claude-code

# Check if temp file was created in correct location
ls -la /tmp/claude-beta-test/
```

### Error Handling Test
```bash
# Test size limit
export CLAUDE_AUTO_TEE_MAX_SIZE=100  # Very small limit
echo '{"tool":{"name":"Bash","input":{"command":"seq 1 100 | head -20"}},"timeout":null}' | claude-code
```

### Real-World Examples
```bash
# Development workflow examples
echo '{"tool":{"name":"Bash","input":{"command":"npm list --depth=0 | head -10"}},"timeout":null}' | claude-code

echo '{"tool":{"name":"Bash","input":{"command":"git log --oneline -5 | head -3"}},"timeout":null}' | claude-code

echo '{"tool":{"name":"Bash","input":{"command":"df -h | grep -E \"(Filesystem|/dev/)\""}},"timeout":null}' | claude-code
```

## 🎯 Scenario-Based Testing

### Scenario 1: Developer Workflow
**Context:** You're a developer checking build status and logs

```bash
# Simulate build output
echo '{"tool":{"name":"Bash","input":{"command":"echo \"Building project...\" && sleep 1 && echo \"Build completed\" | head -2"}},"timeout":null}' | claude-code

# Check test results
echo '{"tool":{"name":"Bash","input":{"command":"echo \"Running tests...\" && seq 1 5 | xargs -I {} echo \"Test {} passed\" | head -3"}},"timeout":null}' | claude-code
```

**What to check:**
- Temp files preserve build/test output
- You can reference results without re-running builds
- Performance impact is minimal

### Scenario 2: System Administration
**Context:** You're monitoring system resources and processes

```bash
# System monitoring
echo '{"tool":{"name":"Bash","input":{"command":"top -l 1 -n 5 | head -10"}},"timeout":null}' | claude-code

# Log analysis
echo '{"tool":{"name":"Bash","input":{"command":"tail -n 50 /var/log/system.log 2>/dev/null | grep -i error | head -5 || echo \"No system.log access\""}},"timeout":null}' | claude-code

# Network monitoring
echo '{"tool":{"name":"Bash","input":{"command":"netstat -an | head -10 | grep LISTEN"}},"timeout":null}' | claude-code
```

**What to check:**
- Large log outputs are handled efficiently
- Temp files don't consume excessive disk space
- System monitoring doesn't slow down

### Scenario 3: Data Processing
**Context:** You're analyzing data files and generating reports

```bash
# Data analysis simulation
echo '{"tool":{"name":"Bash","input":{"command":"seq 1 100 | awk \"{sum+=\\$1} END {print \\\"Sum:\\\", sum}\" | head -1"}},"timeout":null}' | claude-code

# File processing
echo '{"tool":{"name":"Bash","input":{"command":"find /etc -type f -name \"*.conf\" 2>/dev/null | head -5 | xargs wc -l"}},"timeout":null}' | claude-code

# Report generation
echo '{"tool":{"name":"Bash","input":{"command":"echo \\\"Report Date: $(date)\\\" && echo \\\"Files processed: 42\\\" | head -2"}},"timeout":null}' | claude-code
```

**What to check:**
- Complex data processing pipelines work correctly
- Results are preserved for further analysis
- No data corruption or loss

## 🧪 Edge Case Scenarios

### Edge Case 1: Very Long Output
```bash
# Test large output handling
export CLAUDE_AUTO_TEE_MAX_SIZE=1048576  # 1MB limit
echo '{"tool":{"name":"Bash","input":{"command":"seq 1 10000 | head -100"}},"timeout":null}' | claude-code
```

### Edge Case 2: Special Characters
```bash
# Test special character handling
echo '{"tool":{"name":"Bash","input":{"command":"echo \"Special chars: !@#$%^&*()[]{}\" | head -1"}},"timeout":null}' | claude-code
```

### Edge Case 3: Empty Output
```bash
# Test empty output handling
echo '{"tool":{"name":"Bash","input":{"command":"grep \"nonexistent\" /dev/null | head -1"}},"timeout":null}' | claude-code
```

### Edge Case 4: Command Failure
```bash
# Test failed command handling
echo '{"tool":{"name":"Bash","input":{"command":"ls /nonexistent-directory 2>&1 | head -1"}},"timeout":null}' | claude-code
```

## 📱 Quick Validation Checklist

After running test scenarios, verify:

**Functionality Checklist:**
- [ ] Tee injection works for piped commands
- [ ] No tee injection for non-piped commands  
- [ ] Complex pipelines preserved correctly
- [ ] Temp files created in expected locations
- [ ] Environment variables work as expected

**Quality Checklist:**
- [ ] No command failures or errors
- [ ] Reasonable performance (commands complete in expected time)
- [ ] Temp files contain expected content
- [ ] Cleanup works (if enabled)
- [ ] Verbose mode provides useful information

**Platform Checklist:**
- [ ] Works on your specific OS version
- [ ] Handles your shell environment correctly
- [ ] Integrates with your development tools
- [ ] Respects your system's temp directory conventions

## 🎬 Recording Test Results

### Quick Results Template
```
=== Quick Test Results ===
Date: $(date)
Platform: $(uname -a)
Shell: $SHELL

Test Results:
✓ Basic functionality: PASS/FAIL
✓ Environment variables: PASS/FAIL  
✓ Platform-specific: PASS/FAIL
✓ Error handling: PASS/FAIL
✓ Real-world scenarios: PASS/FAIL

Notes:
- [Any observations]
- [Performance notes]
- [Issues found]

Overall Assessment: EXCELLENT/GOOD/NEEDS_WORK
```

### Detailed Test Log Template
```bash
# Create detailed test log
TEST_LOG="detailed-test-$(date +%Y%m%d-%H%M%S).log"
echo "=== Detailed Claude Auto-Tee Test Log ===" > "$TEST_LOG"
echo "Platform: $(uname -a)" >> "$TEST_LOG"
echo "Date: $(date)" >> "$TEST_LOG"
echo "Shell: $SHELL" >> "$TEST_LOG"
echo "" >> "$TEST_LOG"

# Run tests and capture output
echo "=== Basic Functionality Tests ===" >> "$TEST_LOG"
# Add test commands here with >> "$TEST_LOG" 2>&1

echo "Test log saved to: $TEST_LOG"
```

## 🚀 Performance Benchmarking

### Simple Performance Test
```bash
# Measure overhead
time echo '{"tool":{"name":"Bash","input":{"command":"seq 1 1000 | tail -10"}},"timeout":null}' | claude-code

# Compare with direct execution (if possible)
time bash -c "seq 1 1000 | tail -10"
```

### Resource Usage Test
```bash
# Monitor during execution
echo '{"tool":{"name":"Bash","input":{"command":"echo \"Starting resource test\" && sleep 2 && find /usr -name \"*.txt\" 2>/dev/null | head -50"}},"timeout":null}' | claude-code &
PID=$!

# Monitor resources (in another terminal)
while kill -0 $PID 2>/dev/null; do
    ps -p $PID -o pid,pcpu,pmem,vsz,rss
    sleep 1
done 2>/dev/null
```

---

## 🏁 Scenario Completion Tracking

Keep track of your testing progress:

### Basic Scenarios (Week 1)
- [ ] Basic Functionality Test
- [ ] Environment Variables Test  
- [ ] Platform-Specific Test
- [ ] Error Handling Test
- [ ] Real-World Examples

### Advanced Scenarios (Week 2)
- [ ] Developer Workflow Scenario
- [ ] System Administration Scenario
- [ ] Data Processing Scenario
- [ ] All Edge Cases (4 scenarios)

### Performance Scenarios (Week 3)
- [ ] Performance Benchmarking
- [ ] Resource Usage Testing
- [ ] Concurrent Usage Testing
- [ ] Extended Runtime Testing

### Validation Complete
- [ ] All functionality checklists passed
- [ ] All quality checklists passed
- [ ] Platform-specific testing complete
- [ ] Detailed feedback submitted

---

**These scenarios provide comprehensive coverage of claude-auto-tee functionality. Mix and match based on your testing time and focus areas!**