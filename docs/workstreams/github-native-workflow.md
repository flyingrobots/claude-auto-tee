# GitHub-Native Wave Execution Workflow

**Comprehensive plan for executing wave-based project delivery using GitHub issues, PRs, and comments for progress tracking**

## 🎯 Overview

This document details a GitHub-native workflow where teams execute tasks corresponding to GitHub issues, report progress via issue comments, and coordinate wave completion through filesystem sync. The GitHub API serves as the primary data source for progress monitoring and team coordination.

## 🔄 Complete Task Execution Workflow

### Step 1: Task Initiation
**Action:** Leave initial comment on GitHub issue
```bash
# Team posts comment:
"🚀 Team {team-name} starting task at $(date)"

# Example:
"🚀 Team Alpha starting task at Mon Aug 12 14:30:22 PDT 2025"
```

**Automation:** 
- `start-task.sh P1.T001` script posts comment automatically
- Updates team progress tracking file
- Links to team's current wave assignment

### Step 2: Branch Synchronization  
**Action:** Sync to target branch
```bash
git fetch && git checkout origin/main
```

**Validation:**
- Ensure clean working directory
- Confirm latest main branch
- Report any merge conflicts that need resolution

### Step 3: Feature Branch Creation
**Action:** Create task-specific branch
```bash
git checkout -B "feat/P1.T001-temp-directory-detection"
```

**GitHub Comment:**
```bash
# Auto-generated comment:
"📁 Created branch feat/P1.T001-temp-directory-detection at $(date)"
```

**Branch Naming Convention:**
- Format: `feat/{task-id}-{kebab-case-description}`
- Examples:
  - `feat/P1.T001-temp-directory-detection`
  - `feat/P1.T024-error-codes-framework` 
  - `feat/P1.T049-test-suite-expansion`

### Step 4: Task Implementation with Progress Tracking
**Action:** Work through task steps, committing between major steps

**Progress Reporting via GitHub Comments:**
```bash
# After each significant commit:
"✅ Commit abc123def completes step 2 of 5

Implemented cross-platform temp directory detection with fallback hierarchy:
- Added support for TMPDIR, TEMP, TMP environment variables
- Implemented macOS (/tmp), Linux (/tmp, /var/tmp), Windows (%TEMP%) detection
- Created fallback to /tmp with proper error handling

Next: Add environment variable override support"
```

**Comment Format Template:**
```
✅ Commit {commit-sha} completes step {current} of {total}

{description of work completed}

Next: {description of next step}
```

**Automation Support:**
- `commit-progress.sh "step description"` - Commits and posts comment
- Automatically extracts commit SHA and formats comment
- Maintains step counter within task

### Step 5: PR Creation and Task Completion
**Action:** Create PR when definition of done is met

**GitHub Comment:**
```bash
"🎯 Completed task. Opened PR #42

✅ Definition of done met:
- Cross-platform temp directory detection implemented
- Unit tests added and passing
- Documentation updated
- Code review ready

PR: https://github.com/org/repo/pull/42"
```

**PR Requirements:**
- Title: `feat(P1.T001): implement cross-platform temp directory detection`
- Body must reference issue: `Closes #123` (auto-closes issue when merged)
- All acceptance criteria addressed
- Tests added and passing locally
- Documentation updated

### Step 6: CI Monitoring and Iteration
**Action:** Monitor PR CI status, fix issues

**CI Failure Reporting:**
```bash
"🔴 CI failure detected at $(date)

Failed check: test-suite-linux
Error: Unit test failure in temp_directory_test.sh line 45
Issue: Mock environment variable not properly reset between tests

Investigating fix..."
```

**CI Fix Reporting:**
```bash
"🔧 CI fix pushed at $(date)

Fix applied: Reset TMPDIR environment variable in test teardown
Additional test added: Verify environment isolation between test cases
Commit: def456abc

Monitoring CI re-run..."
```

**CI Success Reporting:**
```bash
"✅ All CI checks passing at $(date)

Ready for merge:
- ✅ test-suite-linux
- ✅ test-suite-macos  
- ✅ test-suite-windows
- ✅ lint-and-format
- ✅ security-scan

Proceeding with merge..."
```

### Step 7: PR Merge and Issue Closure
**Action:** Merge PR when all CI is green

**Automatic Actions:**
- PR merge triggers issue auto-closure (via "Closes #123" in PR body)
- GitHub generates merge commit
- Issue status changes to "closed"
- Team can proceed to next task or wave completion

### Step 8: Wave Progression
**Action:** Start next task OR mark wave complete

**Next Task:**
```bash
"🔄 Starting next task: P1.T002 - Implement fallback hierarchy
Transitioning to new GitHub issue #124"
```

**Wave Completion:**
```bash
"🌊 Wave 1 complete for Team Alpha at $(date)

Completed tasks in Wave 1:
- ✅ P1.T001 - Cross-platform temp directory detection (PR #42)
- ✅ P1.T013 - Cleanup on successful completion (PR #43)  
- ✅ P1.T024 - Error codes framework (PR #44)
- ✅ P1.T037 - README installation instructions (PR #45)
- ✅ P1.T049 - Test suite expansion (PR #46)
- ✅ P1.T061 - Edge case review (PR #47)

Creating ready.txt for wave sync..."
```

**Filesystem Sync Action:**
```bash
# Create wave completion marker
echo "Team Alpha completed Wave 1 at $(date)" > ~/claude-wave-sync/job-20250812/wave-1/team-alpha.ready.txt
```

## 📊 Progress Tracking Architecture

### GitHub API Integration
**Primary Data Sources:**
- Issue comments for granular progress
- PR status for CI monitoring  
- Issue closure for task completion
- Commit history for development progress

**Dashboard Queries:**
```javascript
// Real-time progress monitoring
const teamProgress = await github.rest.issues.listComments({
  owner: 'org',
  repo: 'repo', 
  issue_number: taskId,
  since: waveStartTime
});

// CI status monitoring
const prChecks = await github.rest.checks.listForRef({
  owner: 'org',
  repo: 'repo',
  ref: prBranch
});
```

### Progress Granularity Levels

**Level 1: Wave Progress**
- Ready.txt files in sync directory
- Wave completion percentage by team
- Overall wave status (in-progress, blocked, complete)

**Level 2: Task Progress**  
- GitHub issue status (open, in-progress, complete)
- PR status (draft, ready, merged)
- CI status (pending, passing, failing)

**Level 3: Step Progress**
- Individual commit progress within tasks
- Step completion comments on issues
- Development velocity tracking

**Level 4: Real-time Updates**
- Live commit stream via GitHub webhooks
- CI status changes
- Comment-based progress updates

## 🛠 Team Automation Scripts

### Core Team Scripts

#### `start-task.sh`
```bash
#!/bin/bash
# Usage: ./start-task.sh P1.T001

TASK_ID=$1
ISSUE_NUMBER=$(get_issue_number_for_task $TASK_ID)
TEAM_NAME=$(get_team_name)

# Post starting comment
gh issue comment $ISSUE_NUMBER --body "🚀 Team $TEAM_NAME starting task at $(date)"

# Sync to main
git fetch && git checkout origin/main

# Create feature branch  
BRANCH_NAME="feat/$TASK_ID-$(get_task_slug $TASK_ID)"
git checkout -B "$BRANCH_NAME"

# Post branch creation comment
gh issue comment $ISSUE_NUMBER --body "📁 Created branch $BRANCH_NAME at $(date)"

# Update team progress tracking
echo "$TASK_ID:started:$(date)" >> ~/.claude-wave-progress/team-$TEAM_NAME.log
```

#### `commit-progress.sh`
```bash
#!/bin/bash
# Usage: ./commit-progress.sh "Implemented temp directory detection"

DESCRIPTION="$1"
TASK_ID=$(get_current_task_id)
ISSUE_NUMBER=$(get_issue_number_for_task $TASK_ID)
COMMIT_SHA=$(git rev-parse HEAD)
STEP_NUM=$(get_next_step_number $TASK_ID)
TOTAL_STEPS=$(get_total_steps $TASK_ID)

# Create commit
git add . && git commit -m "$DESCRIPTION"
NEW_SHA=$(git rev-parse HEAD)

# Post progress comment
COMMENT="✅ Commit $NEW_SHA completes step $STEP_NUM of $TOTAL_STEPS

$DESCRIPTION

Next: $(get_next_step_description $TASK_ID)"

gh issue comment $ISSUE_NUMBER --body "$COMMENT"

# Update progress tracking
echo "$TASK_ID:step-$STEP_NUM:$(date):$NEW_SHA" >> ~/.claude-wave-progress/team-$(get_team_name).log
```

#### `create-task-pr.sh`
```bash
#!/bin/bash
# Usage: ./create-task-pr.sh P1.T001

TASK_ID=$1
ISSUE_NUMBER=$(get_issue_number_for_task $TASK_ID)
BRANCH_NAME=$(git branch --show-current)
TASK_TITLE=$(get_task_title $TASK_ID)

# Create PR
PR_TITLE="feat($TASK_ID): $(echo $TASK_TITLE | tr '[:upper:]' '[:lower:]')"
PR_BODY="Closes #$ISSUE_NUMBER

## Definition of Done
$(get_definition_of_done $TASK_ID)

## Acceptance Criteria  
$(get_acceptance_criteria $TASK_ID)

## Changes Made
$(git log --oneline main..$BRANCH_NAME)"

PR_NUMBER=$(gh pr create --title "$PR_TITLE" --body "$PR_BODY" --base main | grep -o '#[0-9]\+' | tr -d '#')

# Post PR creation comment
gh issue comment $ISSUE_NUMBER --body "🎯 Completed task. Opened PR #$PR_NUMBER

✅ Definition of done met
✅ Acceptance criteria addressed  
✅ Tests added and passing
✅ Documentation updated

PR: $(gh pr view $PR_NUMBER --json url -q .url)"

# Start CI monitoring
./monitor-ci.sh $PR_NUMBER &
```

#### `monitor-ci.sh`
```bash
#!/bin/bash
# Usage: ./monitor-ci.sh 42

PR_NUMBER=$1
TASK_ID=$(get_task_id_for_pr $PR_NUMBER)
ISSUE_NUMBER=$(get_issue_number_for_task $TASK_ID)

while true; do
  # Check CI status
  CI_STATUS=$(gh pr view $PR_NUMBER --json statusCheckRollup -q '.statusCheckRollup[] | select(.status == "FAILURE")')
  
  if [[ -n "$CI_STATUS" ]]; then
    # Report failure
    FAILED_CHECK=$(echo "$CI_STATUS" | jq -r '.context')
    gh issue comment $ISSUE_NUMBER --body "🔴 CI failure detected at $(date)

Failed check: $FAILED_CHECK
Investigating..."
    
    # Wait for fix
    wait_for_new_commit $PR_NUMBER
    
    # Report fix attempt
    gh issue comment $ISSUE_NUMBER --body "🔧 CI fix pushed at $(date)
Monitoring CI re-run..."
  fi
  
  # Check if all green
  ALL_PASSED=$(gh pr view $PR_NUMBER --json statusCheckRollup -q '[.statusCheckRollup[] | select(.status != "SUCCESS")] | length')
  
  if [[ "$ALL_PASSED" == "0" ]]; then
    gh issue comment $ISSUE_NUMBER --body "✅ All CI checks passing at $(date)
Ready for merge!"
    break
  fi
  
  sleep 30
done
```

#### `complete-task.sh`
```bash
#!/bin/bash
# Usage: ./complete-task.sh P1.T001

TASK_ID=$1
PR_NUMBER=$(get_pr_number_for_task $TASK_ID)

# Merge PR
gh pr merge $PR_NUMBER --squash

# Check if this was last task in wave
REMAINING_TASKS=$(get_remaining_wave_tasks)

if [[ ${#REMAINING_TASKS[@]} -eq 0 ]]; then
  # Mark wave complete
  ./mark-wave-complete.sh
else
  # Start next task
  NEXT_TASK=${REMAINING_TASKS[0]}
  echo "🔄 Starting next task: $NEXT_TASK"
  ./start-task.sh $NEXT_TASK
fi
```

### Wave Coordination Scripts

#### `mark-wave-complete.sh`
```bash
#!/bin/bash
# Mark current wave complete for this team

TEAM_NAME=$(get_team_name)
CURRENT_WAVE=$(get_current_wave)
JOB_ID=$(get_job_id)
COMPLETED_TASKS=$(get_completed_wave_tasks)

# Create completion summary
SUMMARY="Team $TEAM_NAME completed Wave $CURRENT_WAVE at $(date)

Completed tasks in Wave $CURRENT_WAVE:
$(echo "$COMPLETED_TASKS" | while read task pr; do
  echo "- ✅ $task (PR #$pr)"
done)

Creating ready.txt for wave sync..."

# Post to coordination issue
COORD_ISSUE=$(get_wave_coordination_issue $CURRENT_WAVE)
gh issue comment $COORD_ISSUE --body "$SUMMARY"

# Create ready file for filesystem sync
SYNC_DIR="$HOME/claude-wave-sync/$JOB_ID/wave-$CURRENT_WAVE"
mkdir -p "$SYNC_DIR"
echo "Team $TEAM_NAME completed Wave $CURRENT_WAVE at $(date)" > "$SYNC_DIR/team-$TEAM_NAME.ready.txt"

echo "🌊 Wave $CURRENT_WAVE marked complete. Waiting for other teams..."
```

## 📈 Dashboard and Monitoring

### Real-time Progress Dashboard
**Data Sources:**
- GitHub API for issue comments and PR status
- Filesystem sync directory for wave completion
- Git commit history for development velocity

**Dashboard Features:**
```javascript
// Live team progress
const teamProgress = {
  'team-alpha': {
    currentWave: 1,
    currentTask: 'P1.T001',
    taskStatus: 'in-progress',
    lastUpdate: '2025-08-12T14:30:22Z',
    ciStatus: 'passing',
    commitsToday: 5
  }
};

// Wave completion status
const waveStatus = {
  wave1: {
    totalTasks: 18,
    completedTasks: 15,
    teamsReady: ['alpha', 'beta'],
    teamsPending: ['gamma'],
    estimatedCompletion: '2025-08-12T18:00:00Z'
  }
};
```

**Dashboard Views:**
1. **Overview**: Wave progress, team status, timeline
2. **Team Detail**: Individual team task progress, CI status
3. **Task Detail**: GitHub issue activity, commit history  
4. **CI Monitor**: Real-time build status across all teams
5. **Wave Sync**: Ready file status, blocking dependencies

### GitHub Webhook Integration
**Real-time Updates:**
- Issue comment webhooks → Update progress tracking
- PR status webhooks → Update CI monitoring
- Push webhooks → Update commit activity
- PR merge webhooks → Update task completion

## 🔄 Wave Transition Mechanism

### Sync Point Detection
**Monitoring Process:**
1. **Filesystem Scan**: Check for all team ready.txt files
2. **GitHub Validation**: Verify all wave tasks are closed via merged PRs
3. **Quality Gates**: Run automated validation checks
4. **Transition Trigger**: Auto-advance all teams to next wave

**Transition Script:**
```bash
#!/bin/bash
# wave-transition-monitor.sh

JOB_ID=$1
CURRENT_WAVE=$2

while true; do
  # Check if all teams ready
  TEAMS_READY=$(ls ~/claude-wave-sync/$JOB_ID/wave-$CURRENT_WAVE/*.ready.txt 2>/dev/null | wc -l)
  TOTAL_TEAMS=$(get_total_teams $JOB_ID)
  
  if [[ $TEAMS_READY -eq $TOTAL_TEAMS ]]; then
    echo "🌊 All teams ready for Wave $CURRENT_WAVE → $((CURRENT_WAVE + 1)) transition"
    
    # Validate all tasks complete via GitHub
    if validate_wave_completion_via_github $CURRENT_WAVE; then
      # Trigger wave transition
      trigger_wave_transition $CURRENT_WAVE $((CURRENT_WAVE + 1))
      break
    else
      echo "❌ GitHub validation failed. Manual intervention required."
    fi
  fi
  
  sleep 30
done
```

## 🛡 Quality Gates and Validation

### Pre-PR Quality Gates
**Automated Checks Before PR Creation:**
- All acceptance criteria addressed
- Tests added and passing locally
- Documentation updated
- Code formatting compliance
- No TODO/FIXME comments in production code

### Wave Completion Validation
**GitHub API Validation:**
```bash
validate_wave_completion_via_github() {
  local wave=$1
  local wave_tasks=$(get_wave_tasks $wave)
  
  for task in $wave_tasks; do
    local issue_num=$(get_issue_number_for_task $task)
    local issue_status=$(gh issue view $issue_num --json state -q .state)
    
    if [[ "$issue_status" != "CLOSED" ]]; then
      echo "❌ Task $task (issue #$issue_num) not completed"
      return 1
    fi
    
    # Verify closed via merged PR (not manual closure)
    local closing_pr=$(gh issue view $issue_num --json closedBy -q .closedBy.url)
    if [[ ! "$closing_pr" =~ "/pull/" ]]; then
      echo "❌ Task $task closed manually, not via PR merge"
      return 1
    fi
  done
  
  echo "✅ All Wave $wave tasks completed via merged PRs"
  return 0
}
```

## 🚨 Error Handling and Recovery

### Common Issues and Solutions

**Issue: CI Consistently Failing**
```bash
# Escalation comment template:
"🆘 CI failure escalation at $(date)

Issue persists after 3 fix attempts:
- Attempt 1: Fixed test environment setup (still failing)
- Attempt 2: Updated dependency versions (still failing)  
- Attempt 3: Refactored test isolation (still failing)

Current error: [detailed error message]

Requesting team lead assistance. @teamlead"
```

**Issue: Merge Conflicts**
```bash
# Resolution process:
git fetch origin main
git checkout feat/P1.T001-task
git rebase origin/main

# If conflicts:
# 1. Resolve conflicts
# 2. git add resolved files
# 3. git rebase --continue
# 4. Force push: git push --force-with-lease

# Comment on issue:
"🔧 Resolved merge conflicts with main branch at $(date)
Rebased feature branch and force-pushed updates"
```

**Issue: Team Falls Behind**
```bash
# Team assistance request:
"📞 Team assistance requested at $(date)

Team Alpha behind schedule:
- Wave 1 target: 18 tasks in 2 days
- Current progress: 12 tasks completed, 6 remaining  
- Estimated completion: +4 hours beyond sync point

Requesting task redistribution or deadline adjustment"
```

### Recovery Mechanisms
**Wave Rollback:**
- Revert ready.txt files  
- Reset team assignments
- Communicate new timeline to all teams

**Task Redistribution:**
- Move incomplete tasks between teams
- Update GitHub issue assignments
- Redistribute team-specific task lists

## 📝 Team Communication Templates

### Standard Comment Formats

**Task Start:**
```
🚀 Team {team-name} starting task at {timestamp}
```

**Branch Creation:**
```
📁 Created branch {branch-name} at {timestamp}
```

**Progress Update:**
```
✅ Commit {sha} completes step {n} of {total}

{description of work}

Next: {next step description}
```

**PR Creation:**
```
🎯 Completed task. Opened PR #{number}

✅ Definition of done met
✅ Acceptance criteria addressed
✅ Tests added and passing  
✅ Documentation updated

PR: {url}
```

**CI Failure:**
```
🔴 CI failure detected at {timestamp}

Failed check: {check-name}
Error: {error-description}
Issue: {root-cause-analysis}

{action-plan}
```

**CI Fix:**
```
🔧 CI fix pushed at {timestamp}

Fix applied: {fix-description}
Additional changes: {additional-work}
Commit: {commit-sha}

Monitoring CI re-run...
```

**Wave Completion:**
```
🌊 Wave {n} complete for Team {name} at {timestamp}

Completed tasks in Wave {n}:
{task-list-with-pr-links}

Creating ready.txt for wave sync...
```

## 🎯 Success Metrics

### Task-Level Metrics
- **Task completion rate**: Issues closed via merged PRs
- **CI success rate**: Percentage of PRs passing CI on first try
- **Development velocity**: Commits per day per team
- **Code quality**: PR review comments, failed CI fixes

### Wave-Level Metrics  
- **Wave completion time**: From start to all ready.txt files created
- **Sync efficiency**: Time spent at sync points
- **Quality gates**: Validation failures requiring rework
- **Team coordination**: Ready file creation timing variance

### Project-Level Metrics
- **Overall timeline**: Total days from Wave 1 start to Wave 3 completion
- **Team utilization**: Percentage of time teams spend on productive work vs coordination
- **GitHub activity**: Issues, PRs, comments, commits generated
- **CI/CD efficiency**: Build times, failure rates, recovery times

## 🚀 Implementation Plan

### Phase 1: Core Scripts (Week 1)
1. Implement team automation scripts (`start-task.sh`, `commit-progress.sh`, etc.)
2. Set up GitHub API integration for comment posting
3. Create basic dashboard for progress monitoring
4. Test with single team on small task set

### Phase 2: Wave Coordination (Week 2)  
1. Implement wave transition monitoring
2. Add filesystem sync with ready.txt validation
3. Create GitHub webhook integration for real-time updates
4. Test with multiple teams on single wave

### Phase 3: Full System (Week 3)
1. Complete dashboard with all monitoring features
2. Add quality gates and validation checks
3. Implement error handling and recovery mechanisms
4. Full system test with all teams and all waves

### Phase 4: Production (Week 4)
1. Deploy monitoring dashboard
2. Train teams on workflow and scripts
3. Execute real Phase 1 implementation
4. Monitor and optimize based on real usage

## ✅ Ready for Implementation

This GitHub-native workflow provides:

**✅ Complete Audit Trail**: Every action tracked via GitHub comments  
**✅ Real-time Monitoring**: Dashboard tracks progress via GitHub API  
**✅ Quality Assurance**: CI validation and quality gates  
**✅ Team Independence**: Zero coordination needed within waves  
**✅ Automated Coordination**: Filesystem sync for wave transitions  
**✅ Error Recovery**: Comprehensive error handling and escalation  
**✅ Scalable Architecture**: Supports 3-15+ teams with linear scaling  

**The system is ready for immediate implementation and testing!** 🎉

---

*Questions or improvements? This plan creates a production-ready system that teams can execute today while providing complete visibility and coordination through GitHub-native tools.*