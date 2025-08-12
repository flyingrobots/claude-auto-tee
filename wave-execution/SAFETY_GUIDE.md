# Safety and Recovery Guide

This guide covers safety mechanisms, emergency procedures, and recovery operations for the wave-based execution system.

## 🛡️ Safety Philosophy

The wave execution system is designed with multiple safety layers:

1. **Prevention:** Quality gates and validation before transitions
2. **Detection:** Continuous monitoring and health checks
3. **Response:** Emergency stops and rollback capabilities
4. **Recovery:** Backup/restore and state reconstruction
5. **Learning:** Comprehensive logging and incident analysis

## 🔒 Safety Mechanisms

### 1. Quality Gates

**Purpose:** Prevent defective work from progressing between waves

**Implementation:**
```bash
# Automatic quality validation before transitions
./wave-quality-gates.sh validate "$JOB_ID" "$WAVE"

# Validates:
# ✅ PR merge status with GitHub API
# ✅ Ready file integrity and authenticity
# ✅ Branch quality and commit standards
# ✅ Code quality checks (warnings)
# ✅ Task completion status (advisory)
```

**Safety Controls:**
- Wave transitions blocked until ALL teams pass quality gates
- Invalid ready files rejected automatically
- PR merge requirement enforced
- Quality certificates required for progression

### 2. Emergency Stop System

**Purpose:** Immediately halt all wave transitions during critical issues

**Usage:**
```bash
# Emergency stop
./wave-safety-manager.sh emergency-stop "$JOB_ID" "critical-bug-found"

# Creates emergency stop file that prevents:
# ❌ Wave transitions
# ❌ Ready file processing
# ❌ Automated monitoring actions

# Resume after issue resolution
./wave-safety-manager.sh resume "$JOB_ID"
```

**Emergency Stop Triggers:**
- Critical bugs affecting multiple teams
- System infrastructure failures
- Security incidents
- Data corruption detected
- Coordination system failures

### 3. Backup and Versioning

**Purpose:** Enable rollback to known good states

**Automatic Backups:**
- Before each wave transition
- Before emergency operations
- Before restore operations
- Daily scheduled backups

**Manual Backups:**
```bash
# Create backup with reason
./wave-safety-manager.sh backup "$JOB_ID" "before-critical-change"

# List available backups
./wave-safety-manager.sh list-backups "$JOB_ID"

# Restore from backup
./wave-safety-manager.sh restore "$JOB_ID" "20250812-143022"
```

### 4. Health Monitoring

**Purpose:** Detect system issues before they become critical

**Continuous Monitoring:**
```bash
# Comprehensive health check
./wave-safety-manager.sh health "$JOB_ID"

# Checks:
# ✅ Sync directory integrity
# ✅ Metadata file validity
# ✅ Emergency stop status
# ✅ GitHub CLI accessibility
# ✅ Backup system functionality
# ✅ File system permissions
```

**Health Scores:**
- **Green (8-10/10):** System healthy, ready for operation
- **Yellow (6-7/10):** Warnings present, monitor closely
- **Red (0-5/10):** Critical issues, intervention required

### 5. State Validation

**Purpose:** Ensure coordination state consistency

**Validation Types:**
```bash
# Sync directory integrity
./wave-safety-manager.sh validate "$JOB_ID" --fix

# Ready file authenticity
./wave-quality-gates.sh check-ready "$JOB_ID" "$WAVE" "$TEAM"

# PR merge verification
./wave-quality-gates.sh check-pr "$JOB_ID" "$WAVE" "$TEAM"
```

## 🚨 Emergency Procedures

### Level 1: Team Issues (Low Impact)

**Scope:** Single team blocked or having issues

**Response:**
```bash
# Diagnose team status
./wave-sync-coordinator.sh status "$JOB_ID" "$WAVE" "$TEAM"

# Check team worktree
./git-worktree-manager.sh list "$JOB_ID"

# Validate team readiness
./wave-quality-gates.sh validate "$JOB_ID" "$WAVE" "$TEAM"
```

**Resolution Options:**
1. **Team Support:** Help team resolve technical issues
2. **Task Redistribution:** Move tasks to other teams if critical
3. **Timeline Adjustment:** Allow extra time for completion
4. **Reset Ready State:** If team marked complete prematurely

```bash
# Reset team ready state if needed
./wave-safety-manager.sh reset-team "$JOB_ID" "$WAVE" "$TEAM" "pr-not-actually-merged"
```

### Level 2: Wave Issues (Medium Impact)

**Scope:** Multiple teams affected or wave transition problems

**Response:**
```bash
# Create immediate backup
./wave-safety-manager.sh backup "$JOB_ID" "level2-incident"

# Assess wave status
./wave-transition-manager.sh status "$JOB_ID"

# Check system health
./wave-safety-manager.sh health "$JOB_ID"
```

**Resolution Options:**
1. **Quality Gate Override:** If validation system has false positives
2. **Manual Transition:** If automated system fails
3. **Wave Restart:** Reset wave state and restart
4. **Emergency Stop:** If issue is severe

```bash
# Manual wave transition if automation fails
./wave-transition-manager.sh transition "$JOB_ID" "$WAVE" "$TEAMS"

# Emergency stop if needed
./wave-safety-manager.sh emergency-stop "$JOB_ID" "wave-transition-failure"
```

### Level 3: System Issues (High Impact)

**Scope:** System-wide failures affecting entire job

**Response:**
```bash
# IMMEDIATE: Emergency stop
./wave-safety-manager.sh emergency-stop "$JOB_ID" "system-failure"

# Create emergency backup
./wave-safety-manager.sh backup "$JOB_ID" "emergency-$(date +%Y%m%d-%H%M%S)"

# Document incident
echo "Level 3 Incident: $(date)" >> emergency-log.txt
./wave-safety-manager.sh health "$JOB_ID" >> emergency-log.txt
```

**Resolution Process:**
1. **Immediate:** Stop all operations to prevent data corruption
2. **Assess:** Determine scope and root cause
3. **Communicate:** Notify all teams of situation
4. **Resolve:** Fix underlying issues
5. **Validate:** Ensure system is stable
6. **Resume:** Carefully restart operations

### Level 4: Data Corruption (Critical Impact)

**Scope:** Data integrity compromised, coordination state invalid

**Response:**
```bash
# IMMEDIATE: Emergency stop and isolate
./wave-safety-manager.sh emergency-stop "$JOB_ID" "data-corruption-detected"

# Create forensic backup (don't overwrite)
cp -r "$HOME/claude-wave-workstream-sync/$JOB_ID" \
     "$HOME/claude-wave-forensics/$JOB_ID-$(date +%Y%m%d-%H%M%S)"

# List available clean backups
./wave-safety-manager.sh list-backups "$JOB_ID"
```

**Recovery Process:**
1. **Isolate:** Prevent further corruption
2. **Analyze:** Determine corruption scope and cause
3. **Restore:** Use most recent clean backup
4. **Validate:** Verify restored state integrity
5. **Rebuild:** Reconstruct lost work if possible
6. **Resume:** Restart with enhanced monitoring

```bash
# Restore from clean backup
./wave-safety-manager.sh restore "$JOB_ID" "$CLEAN_BACKUP_TIMESTAMP" --force

# Validate restored state
./wave-safety-manager.sh validate "$JOB_ID" --fix
./wave-safety-manager.sh health "$JOB_ID"
```

## 🔄 Recovery Procedures

### Backup and Restore Operations

**Creating Backups:**
```bash
# Manual backup with reason
./wave-safety-manager.sh backup "$JOB_ID" "pre-major-change"

# Automatic backups are created:
# - Before wave transitions
# - Before emergency operations  
# - Before restore operations
# - Daily (if configured)
```

**Restoring from Backup:**
```bash
# List available backups
./wave-safety-manager.sh list-backups "$JOB_ID"

# Restore specific backup
./wave-safety-manager.sh restore "$JOB_ID" "20250812-143022"

# Force restore (overwrites current state)
./wave-safety-manager.sh restore "$JOB_ID" "20250812-143022" --force
```

**Backup Validation:**
```bash
# Verify backup integrity before restore
ls -la "$HOME/.claude-wave-backups/$JOB_ID-20250812-143022/"
cat "$HOME/.claude-wave-backups/$JOB_ID-20250812-143022/.backup-metadata.json"
```

### State Reconstruction

**When backups are insufficient:**

1. **Manual State Rebuild:**
   ```bash
   # Reinitialize sync environment
   ./wave-sync-coordinator.sh init "$JOB_ID"
   
   # Recreate team assignments
   ./wave-sync-coordinator.sh assign "$JOB_ID" "$WAVE" "$ASSIGNMENTS"
   
   # Manually recreate ready files (if teams confirm completion)
   # This should be done very carefully with team verification
   ```

2. **Partial Recovery:**
   ```bash
   # Identify what can be recovered
   ./wave-safety-manager.sh validate "$JOB_ID"
   
   # Fix what can be automated
   ./wave-safety-manager.sh validate "$JOB_ID" --fix
   
   # Manual intervention for the rest
   ```

### Team Worktree Recovery

**If team worktrees are corrupted:**

```bash
# List existing worktrees
./git-worktree-manager.sh list "$JOB_ID"

# Clean up corrupted worktrees
./git-worktree-manager.sh cleanup "$JOB_ID"

# Recreate team worktrees
for team in $TEAMS; do
    ./git-worktree-manager.sh create "$team" "$WAVE" "$JOB_ID"
done
```

**Team Data Recovery:**
- Teams should have their work in PRs (hopefully merged)
- Worktrees are just working copies
- Critical data is in main repository and ready files

## 📊 Monitoring and Alerting

### Health Check Automation

**Scheduled Health Checks:**
```bash
# Add to cron for regular health monitoring
# 0 */6 * * * /path/to/wave-safety-manager.sh health "$JOB_ID" >> health.log

# Health check failure alerting
if ! ./wave-safety-manager.sh health "$JOB_ID"; then
    echo "Health check failed for $JOB_ID" | mail -s "Wave Execution Alert" coordinator@example.com
fi
```

### Critical Event Detection

**Automated Monitoring:**
```bash
# Monitor for emergency stop files
watch -n 300 'find $HOME/claude-wave-workstream-sync -name ".EMERGENCY_STOP" | wc -l'

# Monitor backup success
ls -t "$HOME/.claude-wave-backups/" | head -1

# Monitor sync directory integrity
./wave-safety-manager.sh validate "$JOB_ID" > /dev/null || echo "Integrity issues detected"
```

### Log Analysis

**Important Log Locations:**
```bash
# Safety operations log
tail -f "$HOME/.claude-wave-safety/safety.log"

# Quality gate operations
tail -f "$HOME/.claude-wave-quality/quality-gates.log"

# Wave transitions
tail -f "$HOME/.claude-wave-transitions/wave-transitions.log"
```

## 🛠️ Recovery Tools

### Diagnostic Commands

```bash
# Complete system status
./wave-transition-manager.sh status "$JOB_ID"
./wave-safety-manager.sh health "$JOB_ID"
./wave-quality-gates.sh report "$JOB_ID"

# File system integrity
find "$HOME/claude-wave-workstream-sync/$JOB_ID" -type f -name "*.txt" -empty
find "$HOME/claude-wave-workstream-sync/$JOB_ID" -type f -name "*.json" -exec jq . {} \; > /dev/null

# GitHub integration status
gh auth status
gh api user > /dev/null
```

### Repair Tools

```bash
# Automatic integrity repair
./wave-safety-manager.sh validate "$JOB_ID" --fix

# Manual metadata recreation
# (Emergency use only - creates basic metadata for corrupted files)

# Permission fixes
chmod -R u+rw "$HOME/claude-wave-workstream-sync/$JOB_ID"
chmod +x "$HOME/claude-wave-workstream-sync/$JOB_ID"/*/*.sh 2>/dev/null || true
```

## 📋 Incident Response Checklist

### Immediate Response (First 5 minutes)

- [ ] Emergency stop activated if needed
- [ ] Immediate backup created
- [ ] Incident severity assessed (Level 1-4)
- [ ] Stakeholders notified
- [ ] Initial diagnosis started

### Assessment Phase (5-30 minutes)

- [ ] Root cause identified
- [ ] Impact scope determined
- [ ] Recovery options evaluated
- [ ] Team status checked
- [ ] System health assessed

### Resolution Phase (30 minutes - hours)

- [ ] Recovery plan executed
- [ ] System integrity validated
- [ ] Team worktrees verified
- [ ] Quality gates tested
- [ ] Monitoring resumed

### Post-Incident (After resolution)

- [ ] Incident documented
- [ ] Lessons learned captured
- [ ] Process improvements identified
- [ ] Monitoring enhanced
- [ ] Team feedback collected

## 🔐 Security Considerations

### Access Control

**File Permissions:**
- Sync directories: Read/write for coordinator, read-only for teams
- Ready files: Write-once, verified integrity
- Backup directories: Coordinator access only

**GitHub Integration:**
- Use GitHub CLI with appropriate permissions
- Validate PR merge status via API
- Ensure team authentication is working

### Data Integrity

**Verification Methods:**
- Ready file format validation
- Cryptographic hash verification
- PR merge status confirmation
- Branch integrity checks

**Protection Against:**
- Premature ready file creation
- Man-in-the-middle PR status spoofing
- Ready file tampering
- Unauthorized wave transitions

## 📚 Best Practices

### Preventive Measures

1. **Regular Health Checks**
   - Schedule automated health monitoring
   - Review health scores daily
   - Address warnings promptly

2. **Backup Strategy**
   - Create backups before major operations
   - Test restore procedures regularly
   - Maintain multiple backup generations

3. **Quality Gates**
   - Run quality validation before transitions
   - Don't skip quality checks for speed
   - Address quality issues promptly

4. **Monitoring**
   - Keep dashboard visible during execution
   - Monitor GitHub coordination issues
   - Watch for team escalations

### Recovery Best Practices

1. **Think Before Acting**
   - Assess situation thoroughly before changes
   - Create backup before any recovery operation
   - Document all recovery steps

2. **Incremental Recovery**
   - Fix issues incrementally
   - Validate each recovery step
   - Don't rush the recovery process

3. **Communication**
   - Keep teams informed during incidents
   - Document decisions and rationale
   - Update stakeholders regularly

4. **Learning**
   - Analyze incidents for root causes
   - Improve processes based on lessons learned
   - Update documentation and procedures

---

**Remember:** The goal is to complete the wave execution successfully with minimal disruption. Safety mechanisms are there to help, not hinder progress. Use them appropriately based on the situation severity.

*Safety first, but keep moving forward! 🛡️🌊*