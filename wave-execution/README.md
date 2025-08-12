# Wave-Based Execution System

A production-ready coordination system for parallel team execution with wave-based synchronization. This system enables teams to work completely independently within waves while ensuring hard synchronization between waves using filesystem coordination and GitHub integration.

## 🎯 Executive Summary

**Execution Model:** Wave-based with thread.join() synchronization  
**Total Waves:** 3 dependency levels (84 tasks)  
**Team Scaling:** Supports 3-15+ teams working independently within each wave  
**Coordination:** Filesystem + GitHub integration with PR merge validation  
**Safety:** Built-in rollback, emergency stop, and quality gates

## 🏗️ System Architecture

### Core Components

1. **Git Worktree Manager** (`git-worktree-manager.sh`)
   - Creates isolated worktrees for team independence
   - Manages branch creation and team metadata
   - Provides team-specific scripts for coordination

2. **Wave Sync Coordinator** (`wave-sync-coordinator.sh`)
   - Filesystem-based sync using ready.txt files
   - Task assignment and distribution
   - Sync status monitoring and validation

3. **Wave Transition Manager** (`wave-transition-manager.sh`)
   - Automated sync detection and wave transitions
   - GitHub issue integration and updates
   - Real-time monitoring with configurable intervals

4. **Wave Safety Manager** (`wave-safety-manager.sh`)
   - Backup and restore capabilities
   - Emergency stop and rollback mechanisms
   - Health checks and integrity validation

5. **Wave Dashboard** (`wave-dashboard.sh`)
   - Real-time progress monitoring
   - Team status visualization
   - HTML report generation

6. **Wave Quality Gates** (`wave-quality-gates.sh`)
   - PR merge validation
   - Code quality checks
   - Ready file integrity verification

### Key Principles

- **Within Wave:** Complete independence - zero coordination needed between teams
- **Between Waves:** Hard synchronization barrier - ALL teams must complete current wave before ANY team starts next wave
- **Team Assignment:** Teams can pick up any available task within their current wave
- **PR Requirement:** Teams can only mark wave complete AFTER their PR is merged to main
- **Quality Gates:** Comprehensive validation before wave transitions

## 🚀 Quick Start

### Prerequisites

```bash
# Required tools
- bash 4.0+
- git 2.0+
- jq (JSON processor)
- GitHub CLI (gh) - for PR validation

# Optional but recommended
- shellcheck (for code quality)
```

### 1. Initialize Job Environment

```bash
# Create job with unique ID
JOB_ID="job-$(date +%Y%m%d-%H%M%S)"

# Initialize sync environment
./wave-sync-coordinator.sh init "$JOB_ID"

# Assign tasks to teams (example: 3 teams for wave 1)
./wave-sync-coordinator.sh assign "$JOB_ID" 1 "alpha:6,beta:6,gamma:6"
```

### 2. Create Team Worktrees

```bash
# Create isolated worktree for each team
./git-worktree-manager.sh create alpha 1 "$JOB_ID"
./git-worktree-manager.sh create beta 1 "$JOB_ID"
./git-worktree-manager.sh create gamma 1 "$JOB_ID"

# Create GitHub coordination issue
./git-worktree-manager.sh issue 1 "$JOB_ID"
```

### 3. Start Monitoring

```bash
# Start live dashboard
./wave-dashboard.sh live "$JOB_ID" --detailed

# Start automated transition monitoring
./wave-transition-manager.sh monitor "$JOB_ID"
```

### 4. Team Workflow (in team worktree)

```bash
# Change to team worktree
cd ~/claude-wave-worktrees/claude-auto-tee-$JOB_ID/alpha-wave-1/

# Complete assigned tasks
# ... do work ...

# Create PR when ready
gh pr create --title "Wave 1 - Team Alpha" --body "Completed wave 1 tasks"

# After PR is merged, mark wave complete
./team-scripts/mark-wave-complete.sh
```

## 📖 Detailed Documentation

### Team Runbook

See: [Team Execution Runbook](TEAM_RUNBOOK.md)

### Coordinator Runbook

See: [Job Coordinator Runbook](COORDINATOR_RUNBOOK.md)

### Safety and Recovery

See: [Safety and Recovery Guide](SAFETY_GUIDE.md)

## 🔧 Script Reference

### Git Worktree Manager

```bash
./git-worktree-manager.sh create <team_id> <wave_number> [job_id]
./git-worktree-manager.sh list [job_id]
./git-worktree-manager.sh cleanup <job_id>
./git-worktree-manager.sh issue <wave_number> <job_id>
```

### Wave Sync Coordinator

```bash
./wave-sync-coordinator.sh init <job_id> [total_waves]
./wave-sync-coordinator.sh status <job_id> <wave_number> [expected_teams]
./wave-sync-coordinator.sh monitor <job_id> <wave_number> [teams] [interval]
./wave-sync-coordinator.sh assign <job_id> <wave_number> <team_assignments>
```

### Wave Transition Manager

```bash
./wave-transition-manager.sh monitor <job_id> [check_interval]
./wave-transition-manager.sh transition <job_id> <wave_number> <expected_teams>
./wave-transition-manager.sh status <job_id>
```

### Wave Safety Manager

```bash
./wave-safety-manager.sh backup <job_id> [reason]
./wave-safety-manager.sh restore <job_id> <backup_timestamp>
./wave-safety-manager.sh emergency-stop <job_id> [reason]
./wave-safety-manager.sh health <job_id>
```

### Wave Dashboard

```bash
./wave-dashboard.sh live <job_id> [--detailed]
./wave-dashboard.sh show <job_id>
./wave-dashboard.sh html <job_id> [output_file]
```

### Wave Quality Gates

```bash
./wave-quality-gates.sh validate <job_id> <wave_number> [team_id]
./wave-quality-gates.sh report <job_id> [output_file]
```

## 🌊 Wave Execution Flow

### Wave 1: Foundation (18 tasks)
- **Duration:** 1-2 days
- **Characteristics:** Research, setup, foundation work
- **Team Capacity:** 3-6 teams

### Wave 2: Implementation (46 tasks)
- **Duration:** 2-3 days
- **Characteristics:** Core implementation and feature development
- **Team Capacity:** 8-15+ teams

### Wave 3: Integration (20 tasks)
- **Duration:** 1-2 days
- **Characteristics:** Platform-specific features and finalization
- **Team Capacity:** 4-8 teams

### Sync Points

#### Sync Point 1: Wave 1 → Wave 2
- **Duration:** 30-60 minutes
- **Validation:** Foundation readiness check
- **Activities:** Team assignment for Wave 2

#### Sync Point 2: Wave 2 → Wave 3
- **Duration:** 1-2 hours
- **Validation:** Integration testing and compatibility
- **Activities:** Final wave preparation

## 📊 Monitoring and Observability

### Real-time Monitoring

```bash
# Live dashboard with auto-refresh
./wave-dashboard.sh live "$JOB_ID" --detailed

# Monitor specific wave progress
./wave-sync-coordinator.sh monitor "$JOB_ID" 1 "alpha,beta,gamma" 30

# Automated transition monitoring
./wave-transition-manager.sh monitor "$JOB_ID" 60
```

### Status Checks

```bash
# Overall project status
./wave-transition-manager.sh status "$JOB_ID"

# Wave-specific status
./wave-sync-coordinator.sh status "$JOB_ID" 1 "alpha,beta,gamma"

# Team-specific status (from team worktree)
./team-scripts/sync-status.sh
```

### Reports

```bash
# Generate HTML dashboard
./wave-dashboard.sh html "$JOB_ID" "dashboard.html"

# Quality report
./wave-quality-gates.sh report "$JOB_ID" "quality-report.md"

# Safety health check
./wave-safety-manager.sh health "$JOB_ID"
```

## 🔒 Safety Features

### Emergency Controls

```bash
# Emergency stop all transitions
./wave-safety-manager.sh emergency-stop "$JOB_ID" "critical-issue-found"

# Resume operations
./wave-safety-manager.sh resume "$JOB_ID"
```

### Backup and Recovery

```bash
# Create backup before critical operations
./wave-safety-manager.sh backup "$JOB_ID" "before-wave-2-transition"

# List available backups
./wave-safety-manager.sh list-backups "$JOB_ID"

# Restore from backup
./wave-safety-manager.sh restore "$JOB_ID" "20250812-143022"
```

### Quality Gates

```bash
# Validate wave completion before transition
./wave-quality-gates.sh validate "$JOB_ID" 1

# Check specific team readiness
./wave-quality-gates.sh check-pr "$JOB_ID" 1 alpha
```

## 🎭 Team Coordination

### GitHub Integration

The system integrates with GitHub for coordination:

1. **Issues:** Wave coordination issues track team progress
2. **PRs:** Teams must merge PRs before marking waves complete
3. **Validation:** Automated PR merge verification
4. **Comments:** Teams report status via issue comments

### Filesystem Coordination

Teams coordinate via filesystem:

- **Sync Directory:** `~/claude-wave-workstream-sync/{job-id}/`
- **Ready Files:** `wave-{n}/{team-id}.ready.txt`
- **Protocol:** Ready files created ONLY after PR merge
- **Validation:** Automated integrity and authenticity checks

### Team Independence

Within waves, teams work completely independently:

- **Isolated Worktrees:** No shared filesystem conflicts
- **Independent Branches:** Team-specific branches
- **Separate PRs:** Each team creates own PR
- **No Coordination:** Zero team-to-team communication needed within waves

## 🎯 Success Metrics

### Project Delivery Targets

- **3-4 days:** Large team (10+ developers) with maximum parallelization
- **4-5 days:** Medium team (6-10 developers) with balanced specialization
- **6-7 days:** Small team (3-5 developers) with collaborative approach

### Quality Metrics

- **Wave Completion:** 100% of assigned tasks completed
- **PR Integration:** 100% of team work merged to main
- **Quality Gates:** All validation checks passed
- **Zero Coordination Overhead:** Teams never block each other within waves

### Team Performance

- **Wave Completion Time:** Determined by slowest team in wave
- **Sync Point Efficiency:** <2 hours total sync overhead per project
- **Team Utilization:** >90% parallel execution within waves
- **Error Rate:** <5% issues requiring rollback or emergency stop

## 🔧 Configuration

### Environment Variables

```bash
# Sync coordination
export SYNC_BASE_DIR="$HOME/claude-wave-workstream-sync"

# Worktree management
export WORKTREE_BASE_DIR="$HOME/claude-wave-worktrees"

# Safety and backup
export BACKUP_DIR="$HOME/.claude-wave-backups"
export SAFETY_LOG_DIR="$HOME/.claude-wave-safety"

# Dashboard settings
export DASHBOARD_REFRESH=10  # seconds
```

### Customization

The system can be customized for different project structures:

1. **Wave Configuration:** Modify `TASKS_WAVES.json`
2. **Team Assignment:** Adjust task distribution strategies
3. **Quality Gates:** Add project-specific validation
4. **Monitoring:** Configure check intervals and alerts

## 🚨 Troubleshooting

### Common Issues

1. **Team Not Ready**
   ```bash
   # Check team status
   ./team-scripts/validate-pr-ready.sh
   
   # Verify PR status
   gh pr status
   ```

2. **Sync Issues**
   ```bash
   # Check sync integrity
   ./wave-safety-manager.sh validate "$JOB_ID" --fix
   
   # Reset team ready state if needed
   ./wave-safety-manager.sh reset-team "$JOB_ID" 1 alpha "pr-not-merged"
   ```

3. **Emergency Situations**
   ```bash
   # Emergency stop
   ./wave-safety-manager.sh emergency-stop "$JOB_ID" "critical-bug"
   
   # Create backup
   ./wave-safety-manager.sh backup "$JOB_ID" "emergency-backup"
   ```

### Support

For issues or questions:

1. Check the relevant runbook documentation
2. Review logs in `~/.claude-wave-*` directories
3. Use health check: `./wave-safety-manager.sh health "$JOB_ID"`
4. Consult the troubleshooting guides in individual script help

## 📝 Contributing

This wave execution system is designed to be:

- **Extensible:** Add new validation, monitoring, or coordination features
- **Configurable:** Adapt to different project structures and team sizes
- **Observable:** Comprehensive logging and monitoring throughout
- **Safe:** Multiple safety nets and recovery mechanisms

See individual scripts for detailed implementation notes and extension points.

---

*Last Updated: 2025-08-12*  
*System Version: 1.0*  
*Supports: 3-15+ teams, 3 waves, 84 tasks*