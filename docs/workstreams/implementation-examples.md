# GitHub-Native Workflow Implementation Examples

**Real examples and validation scenarios for the GitHub-native wave execution workflow**

## 🎬 Complete Task Execution Example

**Scenario:** Team Alpha executes task P1.T001 (Cross-platform temp directory detection)

### GitHub Issue #123: P1.T001 - Research platform-specific temp directory conventions

**Initial State:**
- Issue created with acceptance criteria
- Assigned to Wave 1, Team Alpha
- Implementation guide in issue comments

### Execution Timeline with GitHub Comments

#### Comment 1: Task Start (14:30:22)
```
🚀 Team Alpha starting task at Mon Aug 12 14:30:22 PDT 2025
```

#### Comment 2: Branch Creation (14:31:15)
```
📁 Created branch feat/P1.T001-temp-directory-detection at Mon Aug 12 14:31:15 PDT 2025
```

#### Comment 3: Research Progress (15:45:30)
```
✅ Commit a1b2c3d completes step 1 of 4

Completed research on platform-specific temp directory conventions:
- macOS: $TMPDIR (default /tmp), fallback to /tmp
- Linux: $TMPDIR, $TMP, fallback to /tmp and /var/tmp  
- Windows: %TEMP%, %TMP%, fallback to C:\Users\{user}\AppData\Local\Temp
- Documented priority order and edge cases for each platform

Next: Implement detection algorithm with fallback hierarchy
```

#### Comment 4: Implementation Progress (16:20:45)
```
✅ Commit d4e5f6g completes step 2 of 4

Implemented core detection algorithm in src/temp-directory.sh:
- Added detect_temp_directory() function with platform detection
- Implemented environment variable priority: TMPDIR > TMP > TEMP
- Added platform-specific fallbacks with directory existence checks
- Included proper error handling for read-only filesystems

Next: Add comprehensive test coverage
```

#### Comment 5: Testing Progress (17:10:12)
```
✅ Commit g7h8i9j completes step 3 of 4

Added comprehensive test suite for temp directory detection:
- test/temp-directory-test.sh with 15 test cases
- Covers all platforms: macOS, Linux, Windows (via WSL)
- Tests environment variable overrides and fallback scenarios
- Added edge case testing: read-only dirs, missing permissions
- All tests passing locally

Next: Update documentation and create PR
```

#### Comment 6: Documentation and PR (17:45:20)
```
✅ Commit j0k1l2m completes step 4 of 4

Updated documentation and prepared for PR:
- Updated README.md with temp directory requirements
- Added inline code documentation
- Created platform compatibility matrix
- All acceptance criteria verified

🎯 Completed task. Opened PR #42

✅ Definition of done met:
- Cross-platform temp directory detection implemented
- Unit tests added and passing (15/15)
- Documentation updated
- Code review ready

PR: https://github.com/flyingrobots/claude-auto-tee/pull/42
```

#### Comment 7: CI Monitoring (18:00:05)
```
🔴 CI failure detected at Mon Aug 12 18:00:05 PDT 2025

Failed check: test-suite-windows
Error: test_temp_directory_windows_permissions failing on line 82
Issue: Windows permission model differs from Unix, need to adjust test expectations

Investigating fix...
```

#### Comment 8: CI Fix (18:25:30)
```
🔧 CI fix pushed at Mon Aug 12 18:25:30 PDT 2025

Fix applied: Updated Windows permission test to use icacls instead of chmod
Additional test added: Verify Windows-specific permission handling
Commit: m3n4o5p

Details:
- Replaced Unix permission checks with Windows-compatible approach
- Added icacls command validation for Windows environments
- Updated test isolation to properly restore Windows permissions

Monitoring CI re-run...
```

#### Comment 9: CI Success (18:40:15)
```
✅ All CI checks passing at Mon Aug 12 18:40:15 PDT 2025

Ready for merge:
- ✅ test-suite-linux
- ✅ test-suite-macos
- ✅ test-suite-windows  
- ✅ lint-and-format
- ✅ security-scan

Proceeding with merge...
```

#### Comment 10: Task Completion (18:42:00)
```
✅ Task completed and merged at Mon Aug 12 18:42:00 PDT 2025

PR #42 merged successfully. Issue auto-closed.
Moving to next task: P1.T013 - Implement cleanup on successful completion

Transition time: 4 hours 12 minutes
```

## 📊 Dashboard Data Examples

### Team Progress API Response
```json
{
  "job_id": "job-20250812",
  "current_wave": 1,
  "teams": {
    "alpha": {
      "current_task": "P1.T013",
      "status": "in_progress", 
      "last_update": "2025-08-12T18:42:00Z",
      "completed_tasks": ["P1.T001"],
      "active_pr": null,
      "ci_status": "n/a",
      "commits_today": 8,
      "wave_progress": "1/6 tasks complete"
    },
    "beta": {
      "current_task": "P1.T017",
      "status": "pr_review",
      "last_update": "2025-08-12T17:30:00Z", 
      "completed_tasks": ["P1.T005", "P1.T024"],
      "active_pr": 45,
      "ci_status": "passing",
      "commits_today": 12,
      "wave_progress": "2/6 tasks complete"
    },
    "gamma": {
      "current_task": "P1.T037", 
      "status": "ci_failing",
      "last_update": "2025-08-12T18:00:00Z",
      "completed_tasks": ["P1.T021", "P1.T049"],
      "active_pr": 47,
      "ci_status": "failing",
      "commits_today": 6,
      "wave_progress": "2/6 tasks complete"
    }
  },
  "wave_status": {
    "total_tasks": 18,
    "completed_tasks": 5,
    "in_progress_tasks": 3,
    "teams_ready": [],
    "estimated_completion": "2025-08-12T20:30:00Z"
  }
}
```

### CI Status Monitoring
```json
{
  "pr_number": 47,
  "team": "gamma",
  "task": "P1.T037",
  "ci_checks": [
    {
      "name": "test-suite-linux",
      "status": "success",
      "conclusion": "success",
      "completed_at": "2025-08-12T18:35:00Z"
    },
    {
      "name": "test-suite-macos", 
      "status": "completed",
      "conclusion": "failure",
      "completed_at": "2025-08-12T18:37:00Z",
      "details": "Unit test timeout in installation_test.sh"
    },
    {
      "name": "lint-and-format",
      "status": "success", 
      "conclusion": "success",
      "completed_at": "2025-08-12T18:32:00Z"
    }
  ],
  "overall_status": "failing",
  "failing_checks": ["test-suite-macos"],
  "last_failure_time": "2025-08-12T18:37:00Z"
}
```

## 🌊 Wave Transition Example

### Wave 1 Completion Scenario

**Team Ready Files:**
```bash
# ~/claude-wave-sync/job-20250812/wave-1/
team-alpha.ready.txt    # Created at 18:45:22
team-beta.ready.txt     # Created at 19:12:07  
team-gamma.ready.txt    # Created at 19:03:15
```

**Wave Coordination Issue #200 Comments:**

#### Team Alpha Wave Completion
```
🌊 Wave 1 complete for Team Alpha at Mon Aug 12 18:45:22 PDT 2025

Completed tasks in Wave 1:
- ✅ P1.T001 - Cross-platform temp directory detection (PR #42)
- ✅ P1.T013 - Cleanup on successful completion (PR #44)
- ✅ P1.T024 - Error codes framework (PR #46)
- ✅ P1.T037 - README installation instructions (PR #48)
- ✅ P1.T049 - Test suite expansion (PR #50)
- ✅ P1.T061 - Edge case review (PR #52)

Wave 1 execution time: 4 hours 15 minutes
Average task completion: 42 minutes
Total commits: 31
Total PR reviews: 6

Creating ready.txt for wave sync...
```

#### Team Beta Wave Completion  
```
🌊 Wave 1 complete for Team Beta at Mon Aug 12 19:12:07 PDT 2025

Completed tasks in Wave 1:
- ✅ P1.T005 - Set up testing environments (PR #43)
- ✅ P1.T017 - Check available disk space (PR #45)
- ✅ P1.T028 - Define graceful degradation (PR #47)
- ✅ P1.T041 - Common error scenarios (PR #49)
- ✅ P1.T053 - Manual test checklist (PR #51)
- ✅ P1.T065 - Configuration file support (PR #53)

Wave 1 execution time: 4 hours 42 minutes
Average task completion: 47 minutes
Total commits: 28
Total PR reviews: 6

Creating ready.txt for wave sync...
```

#### Wave Transition Trigger
```
🚀 Wave 1 → Wave 2 Transition Initiated at Mon Aug 12 19:15:00 PDT 2025

✅ All teams ready for transition:
- Team Alpha: Ready at 18:45:22 (6/6 tasks complete)
- Team Beta: Ready at 19:12:07 (6/6 tasks complete)  
- Team Gamma: Ready at 19:03:15 (6/6 tasks complete)

✅ GitHub validation passed:
- All 18 Wave 1 tasks closed via merged PRs
- No open issues remaining for Wave 1
- All PRs passed CI and code review

🌊 Initiating Wave 2 task assignments...

Wave 2 Tasks Available:
- 46 total tasks across 5 categories
- Estimated duration: 2-3 days with current team velocity
- Teams can begin immediately with dependency-free tasks

@team-alpha @team-beta @team-gamma Wave 2 is now active!
```

## 🛠 Automation Script Examples

### start-task.sh Output
```bash
$ ./start-task.sh P1.T024

🚀 Starting task P1.T024 - Create comprehensive error codes/categories

✅ Posted starting comment to issue #145
✅ Synced to origin/main (no conflicts)
✅ Created branch: feat/P1.T024-error-codes-framework
✅ Posted branch creation comment
✅ Updated team progress tracking

📋 Task Details:
- Issue: #145
- Branch: feat/P1.T024-error-codes-framework
- Definition of Done: 
  * Comprehensive error code enumeration
  * Category-based error organization
  * Machine-readable error format
  * Unit tests for error handling
  * Documentation with examples

📂 Implementation Guide Available:
- View issue comments for step-by-step implementation
- Reference existing error patterns in src/
- Follow code style guide in CONTRIBUTING.md

⏱ Estimated time: 2-3 hours
🎯 Ready to begin implementation!
```

### commit-progress.sh Output
```bash
$ ./commit-progress.sh "Implemented error code enumeration with categories"

✅ Committed changes: abc123def
✅ Posted progress comment to issue #145
✅ Updated team progress tracking

📊 Progress Update:
- Step: 2 of 4 completed
- Commit: abc123def
- Files changed: src/error-codes.sh, test/error-codes-test.sh
- Lines added: +89, Lines removed: -12

🔄 Next Step: Add machine-readable error format
📝 See GitHub issue for detailed progress discussion
```

### create-task-pr.sh Output
```bash
$ ./create-task-pr.sh P1.T024

🎯 Creating PR for task P1.T024...

✅ Validated definition of done requirements
✅ Confirmed all acceptance criteria met
✅ Verified tests are passing locally
✅ Checked documentation updates

🔄 Creating GitHub PR...
✅ PR #54 created successfully
✅ Posted completion comment to issue #145
✅ Started CI monitoring (PID: 12345)

📋 PR Summary:
- Title: feat(P1.T024): implement comprehensive error codes framework
- Number: #54
- URL: https://github.com/flyingrobots/claude-auto-tee/pull/54
- Files: 4 changed (+156 -23)
- Tests: 12 new test cases added

🔍 CI Status: Checks starting...
⏱ Estimated CI time: 3-5 minutes
📱 Will notify when CI completes
```

## 🔄 Error Recovery Examples

### CI Failure Escalation
```bash
# After 3 failed CI attempts on PR #54:

🆘 CI failure escalation at Mon Aug 12 16:45:30 PDT 2025

Issue persists after 3 fix attempts on PR #54:

**Attempt 1** (16:10): Fixed test environment setup
- Error: Environment variable collision in test setup
- Fix: Added test isolation with environment reset
- Result: ❌ Still failing (new error in Windows tests)

**Attempt 2** (16:25): Updated Windows compatibility  
- Error: Windows path separator issues in error messages
- Fix: Added cross-platform path normalization
- Result: ❌ Still failing (regex pattern mismatch)

**Attempt 3** (16:40): Fixed regex patterns
- Error: Regex patterns not portable across shell versions
- Fix: Simplified regex to basic POSIX patterns
- Result: ❌ Still failing (timeout in macOS CI)

**Current Error:** macOS tests timing out after 300 seconds
```
Detailed logs: https://github.com/flyingrobots/claude-auto-tee/actions/runs/123456

**Analysis:** Issue appears to be infrastructure-related rather than code-related. 
All tests pass locally on macOS, suggests CI environment problem.

**Escalation:** Requesting team lead assistance and infrastructure review.
@teamlead @devops-team

**Proposed Action:** 
1. Retry with fresh CI runner
2. If persists, investigate macOS CI environment configuration
3. Consider temporary bypass for non-critical macOS-specific tests
```

### Team Coordination Recovery
```bash
# Team falls behind schedule example:

📞 Team assistance requested at Mon Aug 12 20:30:00 PDT 2025

**Situation:** Team Gamma significantly behind Wave 1 schedule

**Current Status:**
- Wave 1 target: 6 tasks in 8 hours (completed by 18:00)
- Team Gamma progress: 3/6 tasks completed at 20:30
- Remaining tasks: P1.T069, P1.T073, P1.T077
- Estimated completion: +3 hours beyond other teams

**Impact Assessment:**
- Teams Alpha and Beta ready for Wave 2 transition
- Wave sync blocked until Team Gamma completes Wave 1
- Delay affects overall project timeline by 3+ hours

**Root Cause Analysis:**
- P1.T041 took 3 hours instead of 1 hour (complex edge cases)
- P1.T053 blocked by testing environment issues (resolved)
- Team member availability reduced due to urgent production issue

**Proposed Solutions:**
1. **Task Redistribution:** Move P1.T077 to Team Alpha (has capacity)
2. **Parallel Assistance:** Team Beta member assists with P1.T073
3. **Timeline Adjustment:** Extend Wave 1 deadline by 2 hours

**Resource Request:**
- 1 developer from Team Beta for 1-2 hours
- DevOps assistance for any remaining environment issues
- Project manager approval for timeline adjustment

@project-manager @team-alpha @team-beta Please advise on preferred approach.
```

## 📈 Metrics and Analytics Examples

### Team Velocity Analysis
```json
{
  "wave_1_metrics": {
    "duration": "8.5 hours",
    "total_tasks": 18,
    "total_commits": 87,
    "total_prs": 18,
    "teams": {
      "alpha": {
        "tasks_completed": 6,
        "avg_task_time": "42 minutes",
        "commits": 31,
        "ci_failures": 2,
        "review_cycles": 1.2,
        "code_quality_score": 4.8
      },
      "beta": {
        "tasks_completed": 6,
        "avg_task_time": "47 minutes", 
        "commits": 28,
        "ci_failures": 1,
        "review_cycles": 1.0,
        "code_quality_score": 4.9
      },
      "gamma": {
        "tasks_completed": 6,
        "avg_task_time": "85 minutes",
        "commits": 28,
        "ci_failures": 4,
        "review_cycles": 2.1,
        "code_quality_score": 4.3
      }
    }
  }
}
```

### Quality Metrics Dashboard
```
📊 Wave 1 Quality Report - Generated at Mon Aug 12 21:00:00 PDT 2025

## Code Quality
✅ Test Coverage: 94.2% (+12% from baseline)
✅ Code Review Score: 4.7/5.0 (excellent)
✅ Security Scan: 0 critical, 2 minor issues
✅ Documentation: All tasks include updated docs

## Process Efficiency  
✅ CI Success Rate: 89.3% (target: >85%)
✅ First-time PR Approval: 72.2% (target: >70%)
✅ Average Review Time: 23 minutes (target: <30 min)
⚠️  Task Time Variance: 102% (target: <50%, needs improvement)

## Team Coordination
✅ GitHub Comment Responsiveness: 4.2 minutes avg
✅ Wave Sync Efficiency: 2 minutes total overhead
✅ Cross-team Collaboration: 3 instances (good)
✅ Escalation Response: 100% resolved within SLA

## Recommendations
1. 🎯 Improve task estimation accuracy (reduce variance)
2. 📚 Share CI debugging practices across teams
3. 🚀 Team Gamma could benefit from additional training
4. ✅ Overall process working excellently - continue
```

## 🎉 Success Indicators

### What Success Looks Like

**GitHub Issue Activity:**
- Rich comment history showing step-by-step progress
- Clear audit trail from start to PR merge
- Prompt CI issue resolution with detailed explanations
- Professional communication and collaboration

**PR Quality:**
- All PRs reference issues properly (auto-close on merge)
- Comprehensive descriptions linking to requirements
- Clean commit history showing logical development progression
- High first-time approval rate with minimal review cycles

**Wave Coordination:**
- Synchronized ready.txt file creation within narrow time window
- Minimal time spent at sync points (target: <30 minutes)
- Proactive communication about delays or issues
- Smooth transition between waves with no coordination overhead

**Team Performance:**
- Consistent task completion velocity across teams
- Low CI failure rate with fast recovery
- High code quality scores and test coverage
- Effective knowledge sharing and cross-team collaboration

---

**This implementation creates a comprehensive audit trail and monitoring system that provides complete visibility into team progress while maintaining the independence and efficiency benefits of wave-based execution!** 🚀