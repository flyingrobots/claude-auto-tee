# Job Coordinator Runbook

This runbook provides comprehensive instructions for coordinators managing wave-based execution jobs.

## 🎯 Coordinator Responsibilities

As a job coordinator, you are responsible for:

1. ✅ Job initialization and team setup
2. ✅ Task assignment and distribution
3. ✅ Monitoring wave progress and transitions
4. ✅ Quality gate validation
5. ✅ Emergency response and issue resolution
6. ✅ Final project delivery coordination

## 🚀 Job Setup and Initialization

### 1. Pre-Flight Checklist

Before starting a wave execution job:

```bash
# Verify prerequisites
command -v jq >/dev/null || echo "Install jq: brew install jq"
command -v gh >/dev/null || echo "Install GitHub CLI: brew install gh"
gh auth status || echo "Authenticate: gh auth login"

# Verify project structure
[ -f "TASKS_WAVES.json" ] || echo "TASKS_WAVES.json not found"
[ -f "TASKS.md" ] || echo "TASKS.md not found (optional)"

# Test wave execution scripts
./wave-safety-manager.sh help >/dev/null && echo "✅ Scripts accessible"
```

### 2. Initialize Job Environment

```bash
# Create unique job ID
JOB_ID="job-$(date +%Y%m%d-%H%M%S)"
echo "Job ID: $JOB_ID"

# Initialize sync environment
./wave-sync-coordinator.sh init "$JOB_ID"

# Verify initialization
ls -la "$HOME/claude-wave-workstream-sync/$JOB_ID/"

# Create initial backup
./wave-safety-manager.sh backup "$JOB_ID" "initial-setup"
```

### 3. Plan Team Assignments

Review the wave structure and plan team assignments:

```bash
# View wave configuration
cat TASKS_WAVES.json | jq '.waves'

# Wave 1: 18 tasks - plan for 3-6 teams
# Wave 2: 46 tasks - plan for 8-15 teams  
# Wave 3: 20 tasks - plan for 4-8 teams

# Example assignment strategies:
```

**Option A: Balanced Teams (6 teams per wave)**
- Wave 1: 6 teams × 3 tasks each
- Wave 2: 6 teams × 7-8 tasks each
- Wave 3: 6 teams × 3-4 tasks each

**Option B: Specialized Teams (varying team counts)**
- Wave 1: 3 teams × 6 tasks each
- Wave 2: 10 teams × 4-5 tasks each
- Wave 3: 5 teams × 4 tasks each

## 📋 Wave 1 Execution

### 1. Assign Wave 1 Tasks

```bash
# Example: 3 teams with 6 tasks each
./wave-sync-coordinator.sh assign "$JOB_ID" 1 "alpha:6,beta:6,gamma:6"

# Example: 6 teams with 3 tasks each
./wave-sync-coordinator.sh assign "$JOB_ID" 1 "team1:3,team2:3,team3:3,team4:3,team5:3,team6:3"

# Verify assignments
ls -la "$HOME/claude-wave-workstream-sync/$JOB_ID/assignments/"
```

### 2. Create Team Worktrees

```bash
# Create worktree for each team
for team in alpha beta gamma; do
    ./git-worktree-manager.sh create "$team" 1 "$JOB_ID"
done

# Verify worktrees
./git-worktree-manager.sh list "$JOB_ID"
```

### 3. Create Coordination Issue

```bash
# Create GitHub issue for wave coordination
./git-worktree-manager.sh issue 1 "$JOB_ID"

# Note the issue URL for team communication
```

### 4. Start Monitoring

```bash
# Start automated monitoring (in background)
nohup ./wave-transition-manager.sh monitor "$JOB_ID" 60 > wave-monitor.log 2>&1 &

# Start live dashboard (in separate terminal)
./wave-dashboard.sh live "$JOB_ID" --detailed

# Manual status checks
./wave-sync-coordinator.sh status "$JOB_ID" 1 "alpha,beta,gamma"
```

### 5. Monitor Wave 1 Progress

**Daily Activities:**
```bash
# Morning status check
./wave-transition-manager.sh status "$JOB_ID"

# Review team progress
./wave-dashboard.sh show "$JOB_ID" --detailed

# Check for issues
./wave-safety-manager.sh health "$JOB_ID"
```

**Team Support:**
- Monitor GitHub coordination issue for team questions
- Help teams with worktree or PR issues
- Validate team readiness when they report completion

**Wave 1 Completion:**
- All teams create ready.txt files (after PR merges)
- Automated transition manager detects completion
- Quality gate validation runs automatically
- GitHub issue updated with completion status

## 📋 Wave 2 Execution

### 1. Wave 1 → Wave 2 Transition

When Wave 1 completes:

```bash
# Verify wave 1 completion
./wave-sync-coordinator.sh status "$JOB_ID" 1 "alpha,beta,gamma"

# Run quality gate validation
./wave-quality-gates.sh validate "$JOB_ID" 1

# Check transition status
./wave-transition-manager.sh status "$JOB_ID"
```

**Transition should happen automatically, but if manual intervention needed:**

```bash
# Manual transition (if automated system has issues)
./wave-transition-manager.sh transition "$JOB_ID" 1 "alpha,beta,gamma"
```

### 2. Assign Wave 2 Tasks

```bash
# Wave 2 has 46 tasks - more teams needed
# Example: 10 teams with 4-5 tasks each
./wave-sync-coordinator.sh assign "$JOB_ID" 2 "team1:5,team2:5,team3:5,team4:5,team5:5,team6:4,team7:4,team8:4,team9:4,team10:4"
```

### 3. Create Wave 2 Worktrees

```bash
# Create worktrees for wave 2 teams
for team in team1 team2 team3 team4 team5 team6 team7 team8 team9 team10; do
    ./git-worktree-manager.sh create "$team" 2 "$JOB_ID"
done

# Create wave 2 coordination issue
./git-worktree-manager.sh issue 2 "$JOB_ID"
```

### 4. Monitor Wave 2 Progress

```bash
# Update monitoring for wave 2
./wave-sync-coordinator.sh monitor "$JOB_ID" 2 "team1,team2,team3,team4,team5,team6,team7,team8,team9,team10" 30

# Continue dashboard monitoring
./wave-dashboard.sh live "$JOB_ID" --detailed
```

## 📋 Wave 3 Execution

### 1. Wave 2 → Wave 3 Transition

```bash
# Verify wave 2 completion
./wave-sync-coordinator.sh status "$JOB_ID" 2

# Quality gate validation
./wave-quality-gates.sh validate "$JOB_ID" 2

# Monitor transition
./wave-transition-manager.sh status "$JOB_ID"
```

### 2. Assign Wave 3 Tasks

```bash
# Wave 3 has 20 tasks - fewer teams needed
# Example: 5 teams with 4 tasks each
./wave-sync-coordinator.sh assign "$JOB_ID" 3 "final1:4,final2:4,final3:4,final4:4,final5:4"
```

### 3. Final Wave Execution

```bash
# Create wave 3 worktrees
for team in final1 final2 final3 final4 final5; do
    ./git-worktree-manager.sh create "$team" 3 "$JOB_ID"
done

# Create final coordination issue
./git-worktree-manager.sh issue 3 "$JOB_ID"

# Monitor completion
./wave-sync-coordinator.sh monitor "$JOB_ID" 3 "final1,final2,final3,final4,final5"
```

## 📊 Monitoring and Management

### Daily Coordinator Activities

**Morning (Start of Day):**
```bash
# Overall status check
./wave-transition-manager.sh status "$JOB_ID"

# Health check
./wave-safety-manager.sh health "$JOB_ID"

# Review overnight progress
./wave-dashboard.sh show "$JOB_ID" --detailed
```

**Midday (Progress Check):**
```bash
# Current wave status
CURRENT_WAVE=$(./wave-transition-manager.sh status "$JOB_ID" | grep "Active Wave" | cut -d':' -f2 | tr -d ' ')
./wave-sync-coordinator.sh status "$JOB_ID" "$CURRENT_WAVE"

# Team assistance check
gh issue list --search "Wave Coordination" --state open
```

**Evening (End of Day):**
```bash
# Create progress backup
./wave-safety-manager.sh backup "$JOB_ID" "end-of-day-$(date +%Y%m%d)"

# Generate status report
./wave-dashboard.sh html "$JOB_ID" "daily-report-$(date +%Y%m%d).html"

# Quality assessment
./wave-quality-gates.sh report "$JOB_ID" "quality-$(date +%Y%m%d).md"
```

### Continuous Monitoring Commands

```bash
# Real-time dashboard (keep open in terminal)
./wave-dashboard.sh live "$JOB_ID" --detailed

# Automated monitoring (runs in background)
./wave-transition-manager.sh monitor "$JOB_ID" 60

# Manual status checks (run as needed)
./wave-sync-coordinator.sh status "$JOB_ID" {WAVE} "{TEAMS}"
```

### Performance Metrics

Track key metrics:

```bash
# Wave completion times
# Team utilization rates  
# Quality gate pass/fail rates
# Issue escalation counts
# Emergency stop incidents

# Generate metrics report
./wave-quality-gates.sh report "$JOB_ID"
```

## 🚨 Issue Management

### Common Issues and Solutions

#### Issue: Team Not Making Progress

**Diagnosis:**
```bash
# Check team status
./wave-sync-coordinator.sh status "$JOB_ID" {WAVE} "{TEAM}"

# Check team worktree
./git-worktree-manager.sh list "$JOB_ID"

# Health check
./wave-safety-manager.sh health "$JOB_ID"
```

**Solutions:**
- Contact team via GitHub issue
- Review task assignments for complexity
- Provide additional guidance or resources
- Consider task redistribution if critical

#### Issue: PR Not Getting Merged

**Diagnosis:**
```bash
# Check PR status for team
./wave-quality-gates.sh check-pr "$JOB_ID" {WAVE} {TEAM}

# GitHub PR review
gh pr list --search "team:{TEAM}"
```

**Solutions:**
- Expedite PR reviews
- Help resolve merge conflicts
- Assign additional reviewers
- Coordinate with maintainers

#### Issue: Quality Gate Failures

**Diagnosis:**
```bash
# Run detailed quality validation
./wave-quality-gates.sh validate "$JOB_ID" {WAVE} {TEAM}

# Check specific issues
./wave-quality-gates.sh check-ready "$JOB_ID" {WAVE} {TEAM}
```

**Solutions:**
- Work with team to fix quality issues
- Validate ready file integrity
- Re-run quality gates after fixes
- Document quality exceptions if needed

### Emergency Procedures

#### Emergency Stop

When critical issues arise:

```bash
# Immediate stop
./wave-safety-manager.sh emergency-stop "$JOB_ID" "critical-issue-description"

# Create emergency backup
./wave-safety-manager.sh backup "$JOB_ID" "emergency-$(date +%Y%m%d-%H%M%S)"

# Notify all teams via GitHub issues
# Assess and resolve the critical issue
# Resume when safe
./wave-safety-manager.sh resume "$JOB_ID"
```

#### Rollback Procedures

If a wave transition needs to be rolled back:

```bash
# Create safety backup
./wave-safety-manager.sh backup "$JOB_ID" "pre-rollback"

# Reset team ready states as needed
./wave-safety-manager.sh reset-team "$JOB_ID" {WAVE} {TEAM} "rollback-reason"

# Restore from previous backup if needed
./wave-safety-manager.sh list-backups "$JOB_ID"
./wave-safety-manager.sh restore "$JOB_ID" {BACKUP_TIMESTAMP}
```

## 📋 Quality Management

### Pre-Transition Quality Gates

Before each wave transition:

```bash
# Comprehensive validation
./wave-quality-gates.sh validate "$JOB_ID" {WAVE}

# Individual team validation
for team in {TEAMS}; do
    ./wave-quality-gates.sh validate "$JOB_ID" {WAVE} "$team"
done

# Generate quality report
./wave-quality-gates.sh report "$JOB_ID" "wave-${WAVE}-quality.md"
```

### Quality Metrics Tracking

Track quality throughout execution:

```bash
# Daily quality reports
./wave-quality-gates.sh report "$JOB_ID" "quality-$(date +%Y%m%d).md"

# PR merge success rate
# Ready file integrity rate
# Code quality issue counts
# Rollback frequency
```

## 🎯 Project Completion

### Final Wave Completion

When Wave 3 completes:

```bash
# Verify all waves complete
./wave-transition-manager.sh status "$JOB_ID"

# Final quality validation
./wave-quality-gates.sh validate "$JOB_ID" 3

# Generate completion report
./wave-dashboard.sh html "$JOB_ID" "final-completion-report.html"
./wave-quality-gates.sh report "$JOB_ID" "final-quality-report.md"
```

### Cleanup and Archival

```bash
# Create final backup
./wave-safety-manager.sh backup "$JOB_ID" "project-complete"

# Generate final documentation
./wave-dashboard.sh html "$JOB_ID" "project-summary.html"

# Archive coordination files
tar -czf "${JOB_ID}-coordination-archive.tar.gz" \
    "$HOME/claude-wave-workstream-sync/$JOB_ID"

# Clean up worktrees (optional)
./git-worktree-manager.sh cleanup "$JOB_ID"
```

### Success Metrics Evaluation

Evaluate project success:

- **Timeline:** Did we meet the target completion time?
- **Quality:** Were quality gates consistently passed?
- **Team Efficiency:** How well did teams work independently?
- **Issue Resolution:** How quickly were issues resolved?
- **Coordination Overhead:** Was sync overhead minimal?

## 📚 Advanced Coordination

### Multi-Site Coordination

For distributed teams:

```bash
# Coordinate across time zones
# Adjust monitoring intervals for global coverage
# Plan wave transitions for optimal overlap
# Use GitHub issues for asynchronous communication
```

### Large Team Management

For 15+ teams:

```bash
# Increase monitoring frequency
./wave-transition-manager.sh monitor "$JOB_ID" 30

# Use more specialized team assignments
# Create team lead hierarchy
# Implement additional quality checks
```

### Custom Validation

Add project-specific validation:

```bash
# Extend wave-quality-gates.sh
# Add custom validation scripts
# Integrate with project-specific CI/CD
# Add performance benchmarks
```

## 🆘 Escalation and Support

### When to Escalate

Escalate issues when:
- Multiple teams blocked simultaneously
- Critical system failures affecting coordination
- Quality gates consistently failing
- Timeline at serious risk

### Incident Response

For major incidents:

1. **Immediate Response**
   ```bash
   ./wave-safety-manager.sh emergency-stop "$JOB_ID" "incident-description"
   ./wave-safety-manager.sh backup "$JOB_ID" "incident-backup"
   ```

2. **Assessment**
   - Identify root cause
   - Assess impact scope
   - Determine recovery plan

3. **Resolution**
   - Implement fixes
   - Validate resolution
   - Resume operations

4. **Post-Incident**
   - Document lessons learned
   - Update procedures
   - Improve monitoring

---

**Remember:** Your role is to facilitate team independence and ensure smooth wave transitions. Teams should work autonomously within waves with minimal coordinator intervention.

*Successful coordination leads to successful wave execution! 🌊*