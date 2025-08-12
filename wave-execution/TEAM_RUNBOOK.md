# Team Execution Runbook

This runbook provides step-by-step instructions for individual teams participating in wave-based execution.

## 🎯 Team Responsibilities

As a team member, you are responsible for:

1. ✅ Completing your assigned wave tasks
2. ✅ Working in your isolated team worktree
3. ✅ Creating a PR with your team's work
4. ✅ Getting your PR reviewed and merged
5. ✅ Marking your wave complete ONLY after PR merge
6. ✅ Communicating status via GitHub issues

## 🚀 Getting Started

### 1. Access Your Team Worktree

Your team coordinator will provide you with:
- **Job ID:** Unique identifier for this execution (e.g., `job-20250812-143022`)
- **Team ID:** Your team identifier (e.g., `alpha`, `beta`, `gamma`)
- **Wave Number:** Current wave (e.g., `1`, `2`, `3`)

```bash
# Navigate to your team worktree
cd ~/claude-wave-worktrees/claude-auto-tee-{JOB_ID}/{TEAM_ID}-wave-{WAVE}/

# Example:
cd ~/claude-wave-worktrees/claude-auto-tee-job-20250812-143022/alpha-wave-1/
```

### 2. Understand Your Environment

Your worktree contains:

```
📁 team-worktree/
├── 📄 .team-metadata.json          # Team and wave information
├── 📁 team-scripts/                # Team-specific coordination scripts
│   ├── 🔧 sync-status.sh          # Check sync status
│   ├── 🔧 validate-pr-ready.sh    # Validate PR readiness
│   ├── 🔧 mark-wave-complete.sh   # Mark wave complete (after PR merge)
│   └── 🔧 check-wave-sync.sh      # Check overall wave progress
├── 📁 tasks/                      # Task workspace
├── 📁 src/                        # Source code
├── 📁 docs/                       # Documentation
└── ... (rest of project files)
```

### 3. Review Your Task Assignment

```bash
# Check your assigned tasks
TASK_FILE="$HOME/claude-wave-workstream-sync/{JOB_ID}/assignments/{TEAM_ID}-wave-{WAVE}-tasklist.md"
cat "$TASK_FILE"

# Example:
cat "$HOME/claude-wave-workstream-sync/job-20250812-143022/assignments/alpha-wave-1-tasklist.md"
```

Your task list will show:
- Specific tasks assigned to your team
- Task descriptions and requirements
- Completion protocol
- Links to relevant documentation

## 🔄 Team Workflow

### Phase 1: Work on Tasks

1. **Start Working**
   ```bash
   # Check your team metadata
   cat .team-metadata.json
   
   # Review sync status
   ./team-scripts/sync-status.sh
   ```

2. **Complete Your Tasks**
   - Work on assigned tasks in your worktree
   - Make commits as you progress
   - Update task status in your task list file
   - Test your changes thoroughly

3. **Stay Updated**
   ```bash
   # Check overall wave progress
   ./team-scripts/check-wave-sync.sh
   
   # Monitor other teams (optional)
   wave-dashboard.sh show {JOB_ID}
   ```

### Phase 2: Prepare for PR

1. **Validate Your Work**
   ```bash
   # Check if you're ready to create PR
   ./team-scripts/validate-pr-ready.sh
   ```

   This checks:
   - All changes are committed
   - Branch is ahead of main
   - No uncommitted/staged changes
   - GitHub CLI is set up

2. **Create Pull Request**
   ```bash
   # Create PR via GitHub CLI
   gh pr create \
     --title "Wave {WAVE} - Team {TEAM_ID}" \
     --body "Completed wave {WAVE} tasks for team {TEAM_ID}
   
   ## Tasks Completed
   - Task 1: Description
   - Task 2: Description
   - Task 3: Description
   
   ## Testing
   - [ ] All assigned tasks completed
   - [ ] Code tested locally
   - [ ] Documentation updated
   
   Ready for review and merge."
   
   # Or create PR via GitHub web interface
   echo "Create PR at: https://github.com/{OWNER}/{REPO}/compare/{BRANCH_NAME}"
   ```

3. **Track PR Status**
   ```bash
   # Check PR status
   gh pr status
   
   # View PR details
   gh pr view
   
   # Check validation again
   ./team-scripts/validate-pr-ready.sh
   ```

### Phase 3: Wait for PR Merge

1. **Monitor PR Progress**
   - Respond to review feedback promptly
   - Make requested changes if needed
   - Ensure CI checks pass
   - Coordinate with reviewers

2. **Do NOT Mark Complete Yet**
   ```bash
   # ❌ DON'T do this until PR is merged
   # ./team-scripts/mark-wave-complete.sh
   
   # ✅ Check status instead
   ./team-scripts/validate-pr-ready.sh
   ```

### Phase 4: Mark Wave Complete

**ONLY after your PR is merged:**

1. **Verify PR is Merged**
   ```bash
   # This will tell you if you can proceed
   ./team-scripts/validate-pr-ready.sh
   ```

   Look for: `✅ PR is merged! Ready to mark wave complete`

2. **Mark Wave Complete**
   ```bash
   # This creates your ready.txt file
   ./team-scripts/mark-wave-complete.sh
   ```

   This script:
   - ✅ Validates PR is actually merged
   - ✅ Creates authenticated ready file
   - ✅ Includes audit trail with PR details
   - ✅ Adds your team to wave sync coordination

3. **Comment on GitHub Issue**
   ```bash
   # Find the wave coordination issue
   gh issue list --search "Wave {WAVE} Coordination"
   
   # Add your completion comment
   gh issue comment {ISSUE_NUMBER} --body "Team {TEAM_ID} wave {WAVE} complete ✅
   
   All assigned tasks completed and PR #{PR_NUMBER} merged to main.
   Ready for next wave transition."
   ```

## 📊 Monitoring and Status

### Check Your Status

```bash
# Quick status check
./team-scripts/sync-status.sh

# Detailed validation
./team-scripts/validate-pr-ready.sh

# Overall wave progress
./team-scripts/check-wave-sync.sh
```

### Monitor Other Teams

```bash
# View overall progress
wave-dashboard.sh show {JOB_ID}

# Monitor wave sync
wave-sync-coordinator.sh status {JOB_ID} {WAVE}

# Live dashboard (if desired)
wave-dashboard.sh live {JOB_ID} --detailed
```

### Check Wave Transition

```bash
# See if wave is ready for transition
wave-transition-manager.sh status {JOB_ID}

# Check quality gates
wave-quality-gates.sh validate {JOB_ID} {WAVE} {TEAM_ID}
```

## 🚨 Common Issues and Solutions

### Issue: Can't Create PR

**Problem:** `validate-pr-ready.sh` shows errors

**Solutions:**
```bash
# Uncommitted changes
git add . && git commit -m "Complete wave tasks"

# Not ahead of main
git fetch origin main
git rebase origin/main  # or merge if preferred

# GitHub CLI not set up
gh auth login
```

### Issue: PR Created but Not Merged

**Problem:** `validate-pr-ready.sh` shows "PR is still open"

**Solutions:**
- Wait for reviewers to approve
- Address any review feedback
- Ensure CI checks are passing
- Ping reviewers if urgent

### Issue: Ready File Not Working

**Problem:** `mark-wave-complete.sh` fails

**Solutions:**
```bash
# Check PR status first
./team-scripts/validate-pr-ready.sh

# Ensure you're in team worktree
pwd
cat .team-metadata.json

# Check GitHub authentication
gh auth status
```

### Issue: Can't See Other Team Status

**Problem:** Dashboard or sync status not working

**Solutions:**
```bash
# Check if you have access to sync directory
ls -la "$HOME/claude-wave-workstream-sync/{JOB_ID}/"

# Verify job ID is correct
cat .team-metadata.json | grep job_id

# Check if other teams have started
./team-scripts/check-wave-sync.sh
```

## ⚡ Pro Tips

### Efficient Workflow

1. **Set up aliases** (optional):
   ```bash
   alias wave-status='./team-scripts/sync-status.sh'
   alias wave-ready='./team-scripts/validate-pr-ready.sh'
   alias wave-complete='./team-scripts/mark-wave-complete.sh'
   alias wave-check='./team-scripts/check-wave-sync.sh'
   ```

2. **Monitor progress regularly**:
   ```bash
   # Check every 30 minutes
   watch -n 1800 './team-scripts/check-wave-sync.sh'
   ```

3. **Stay informed**:
   - Watch the GitHub coordination issue
   - Check dashboard occasionally
   - Communicate with your team

### Best Practices

1. **Commit Often**
   - Make small, focused commits
   - Use descriptive commit messages
   - Include task IDs in commit messages

2. **Test Thoroughly**
   - Test your changes before creating PR
   - Run any existing test suites
   - Verify your work doesn't break existing functionality

3. **Communication**
   - Update task status in your task list
   - Respond to PR reviews promptly
   - Comment on coordination issue when complete

4. **Independence**
   - Work in your worktree only
   - Don't depend on other teams' work
   - Complete your assigned tasks fully

## 📚 Reference

### Team Scripts

| Script | Purpose |
|--------|---------|
| `sync-status.sh` | Check your team's ready status and overall wave progress |
| `validate-pr-ready.sh` | Comprehensive pre-completion validation |
| `mark-wave-complete.sh` | Mark wave complete (ONLY after PR merge) |
| `check-wave-sync.sh` | Check overall wave sync status and transitions |

### Key Files

| File | Description |
|------|-------------|
| `.team-metadata.json` | Your team and wave information |
| `{TEAM_ID}-wave-{WAVE}-tasklist.md` | Your assigned tasks |
| `{TEAM_ID}.ready.txt` | Created when you mark wave complete |

### Important Locations

| Path | Purpose |
|------|---------|
| `~/claude-wave-worktrees/` | All team worktrees |
| `~/claude-wave-workstream-sync/{JOB_ID}/` | Sync coordination directory |
| `~/claude-wave-workstream-sync/{JOB_ID}/assignments/` | Task assignments |
| `~/claude-wave-workstream-sync/{JOB_ID}/wave-{N}/` | Wave sync files |

## 🆘 Getting Help

### Self-Help

1. **Read Error Messages Carefully**
   - Scripts provide detailed error messages
   - Follow suggested solutions

2. **Check Status First**
   ```bash
   ./team-scripts/validate-pr-ready.sh
   ./team-scripts/sync-status.sh
   ```

3. **Verify Your Environment**
   ```bash
   cat .team-metadata.json
   gh auth status
   git status
   ```

### Escalation

If you're stuck:

1. **Check Documentation**
   - Review this runbook
   - Check script help: `script-name.sh help`

2. **Contact Coordinator**
   - Report issues on GitHub coordination issue
   - Include error messages and context

3. **Emergency Issues**
   - Critical bugs affecting wave completion
   - Coordination system failures
   - Contact job coordinator immediately

---

**Remember:** Teams work completely independently within waves. You should never need to coordinate with other teams or wait for them during your wave work. The only synchronization happens at wave boundaries when ALL teams are complete.

*Good luck with your wave execution! 🌊*