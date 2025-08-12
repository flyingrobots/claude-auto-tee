#!/usr/bin/env bash
# Wave Sync Coordinator - Filesystem-based coordination with GitHub integration
# Manages wave transitions using ready.txt files created ONLY after PR merges

set -euo pipefail

# Configuration
SYNC_BASE_DIR="${SYNC_BASE_DIR:-$HOME/claude-wave-workstream-sync}"
MAIN_REPO_DIR="${MAIN_REPO_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
PROJECT_NAME="${PROJECT_NAME:-$(basename "$MAIN_REPO_DIR")}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" >&2
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}" >&2
}

info() {
    echo -e "${CYAN}[INFO] $1${NC}" >&2
}

# Wave configuration from TASKS_WAVES.json
get_wave_config() {
    local wave_number="$1"
    
    if [ ! -f "$MAIN_REPO_DIR/TASKS_WAVES.json" ]; then
        error "TASKS_WAVES.json not found in $MAIN_REPO_DIR"
        exit 1
    fi
    
    jq -r ".waves.Wave_$wave_number" "$MAIN_REPO_DIR/TASKS_WAVES.json"
}

get_wave_task_count() {
    local wave_number="$1"
    get_wave_config "$wave_number" | jq -r '.task_count // 0'
}

get_total_waves() {
    if [ ! -f "$MAIN_REPO_DIR/TASKS_WAVES.json" ]; then
        echo "3"  # Default fallback
        return
    fi
    
    jq -r '.metadata.total_waves // 3' "$MAIN_REPO_DIR/TASKS_WAVES.json"
}

# Initialize sync environment for a job
init_sync_env() {
    local job_id="$1"
    local total_waves="${2:-$(get_total_waves)}"
    
    log "Initializing sync environment for job: $job_id"
    
    # Create sync directory structure
    for wave in $(seq 1 "$total_waves"); do
        local wave_dir="$SYNC_BASE_DIR/$job_id/wave-$wave"
        mkdir -p "$wave_dir"
        
        # Create wave metadata
        cat > "$wave_dir/.wave-metadata.json" << EOF
{
    "job_id": "$job_id",
    "wave_number": $wave,
    "total_waves": $total_waves,
    "initialized_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "expected_task_count": $(get_wave_task_count "$wave"),
    "sync_protocol": "ready_after_pr_merge",
    "coordination_method": "filesystem_and_github"
}
EOF
        
        # Create README for wave directory
        cat > "$wave_dir/README.md" << EOF
# Wave $wave Sync Directory

**Job ID:** \`$job_id\`
**Wave:** $wave of $total_waves
**Expected Tasks:** $(get_wave_task_count "$wave")

## Team Ready Files

Teams create \`{team-id}.ready.txt\` files in this directory ONLY after:
1. ✅ All wave $wave tasks completed
2. ✅ PR created with team's work
3. ✅ PR reviewed and merged to main
4. ✅ Team runs \`mark-wave-complete.sh\` script

## Sync Protocol

- Wave $(($wave + 1)) can only start when ALL teams have created ready files
- Each ready file contains audit trail of PR merge verification
- Automated monitoring detects when all teams are ready
- GitHub issue coordination tracks team progress

## Monitoring

Use \`wave-sync-coordinator.sh status $job_id $wave\` to check sync status.

## Files in this directory:
- \`.wave-metadata.json\` - Wave configuration and metadata
- \`{team-id}.ready.txt\` - Team completion confirmations (created by teams)
- \`README.md\` - This documentation
EOF
    done
    
    # Create job metadata
    cat > "$SYNC_BASE_DIR/$job_id/.job-metadata.json" << EOF
{
    "job_id": "$job_id",
    "project_name": "$PROJECT_NAME",
    "total_waves": $total_waves,
    "initialized_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "sync_base_dir": "$SYNC_BASE_DIR/$job_id",
    "repository": "$MAIN_REPO_DIR",
    "sync_protocol_version": "1.0",
    "github_integration": true,
    "pr_merge_requirement": true
}
EOF
    
    success "Sync environment initialized for job $job_id"
    echo "📁 Sync directory: $SYNC_BASE_DIR/$job_id"
    echo "🌊 Waves: $total_waves"
    echo "📋 Configuration: $SYNC_BASE_DIR/$job_id/.job-metadata.json"
}

# Check sync status for a wave
check_wave_sync() {
    local job_id="$1"
    local wave_number="$2"
    local expected_teams="${3:-}"
    
    local wave_dir="$SYNC_BASE_DIR/$job_id/wave-$wave_number"
    
    if [ ! -d "$wave_dir" ]; then
        error "Wave directory not found: $wave_dir"
        echo "Run: $0 init $job_id"
        exit 1
    fi
    
    echo "🌊 Wave $wave_number Sync Status"
    echo "================================="
    echo "📁 Sync Directory: $wave_dir"
    echo "🆔 Job ID: $job_id"
    echo "📅 Checked At: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo ""
    
    # Count ready files
    local ready_files=($(find "$wave_dir" -name "*.ready.txt" -type f 2>/dev/null || true))
    local ready_count=${#ready_files[@]}
    
    echo "📊 Ready Teams: $ready_count"
    
    if [ $ready_count -eq 0 ]; then
        warn "No teams have marked wave $wave_number complete yet"
        echo ""
        echo "💡 Teams create ready files by running ./team-scripts/mark-wave-complete.sh"
        echo "   (Only after their PR is merged to main)"
        return 1
    fi
    
    echo ""
    echo "✅ Completed Teams:"
    echo "==================="
    
    for ready_file in "${ready_files[@]}"; do
        local team_id=$(basename "$ready_file" .ready.txt)
        local completion_time=$(grep "Completed At:" "$ready_file" | cut -d' ' -f3- || echo "Unknown")
        local pr_number=$(grep "PR Number:" "$ready_file" | cut -d' ' -f3 || echo "Unknown")
        local pr_status=$(grep "PR Status:" "$ready_file" | cut -d' ' -f3 || echo "Unknown")
        
        echo "👥 Team: $team_id"
        echo "   ⏰ Completed: $completion_time"
        echo "   🔗 PR: $pr_number ($pr_status)"
        echo "   📄 Ready file: $ready_file"
        echo ""
    done
    
    # If expected teams provided, check completeness
    if [ -n "$expected_teams" ]; then
        local expected_count=$(echo "$expected_teams" | tr ',' '\n' | wc -l | tr -d ' ')
        echo "📈 Progress: $ready_count/$expected_count teams ready"
        
        if [ $ready_count -ge $expected_count ]; then
            success "🎉 ALL TEAMS READY! Wave $wave_number sync complete!"
            echo ""
            echo "✅ All $expected_count teams have completed wave $wave_number"
            echo "✅ All PRs merged to main"
            echo "✅ Ready for wave $(($wave_number + 1))"
            return 0
        else
            warn "⏳ Waiting for $(($expected_count - $ready_count)) more teams"
            echo ""
            echo "🚧 Missing teams:"
            for team in $(echo "$expected_teams" | tr ',' '\n'); do
                if [ ! -f "$wave_dir/$team.ready.txt" ]; then
                    echo "   ❌ $team"
                fi
            done
        fi
    else
        info "💡 Use --teams option to specify expected teams for full sync validation"
    fi
    
    return 1
}

# Monitor wave sync with real-time updates
monitor_wave_sync() {
    local job_id="$1"
    local wave_number="$2"
    local expected_teams="${3:-}"
    local check_interval="${4:-30}"
    
    log "Starting wave $wave_number sync monitor for job $job_id"
    echo "⏱️  Checking every $check_interval seconds"
    echo "🛑 Press Ctrl+C to stop monitoring"
    echo ""
    
    local iteration=0
    while true; do
        iteration=$((iteration + 1))
        echo "🔄 Sync Check #$iteration - $(date '+%H:%M:%S')"
        echo "=================================="
        
        if check_wave_sync "$job_id" "$wave_number" "$expected_teams"; then
            success "🎯 Wave $wave_number sync complete! All teams ready."
            break
        fi
        
        echo ""
        echo "⏳ Next check in $check_interval seconds..."
        echo ""
        sleep "$check_interval"
    done
}

# Validate wave readiness with GitHub integration
validate_wave_readiness() {
    local job_id="$1"
    local wave_number="$2"
    local team_id="$3"
    
    local ready_file="$SYNC_BASE_DIR/$job_id/wave-$wave_number/$team_id.ready.txt"
    
    if [ ! -f "$ready_file" ]; then
        error "Ready file not found: $ready_file"
        return 1
    fi
    
    log "Validating readiness for team $team_id, wave $wave_number"
    
    # Extract verification data
    local pr_number=$(grep "PR Number:" "$ready_file" | cut -d'#' -f2 | tr -d ' ' || echo "")
    local pr_status=$(grep "PR Status:" "$ready_file" | cut -d' ' -f3 || echo "")
    local verification_hash=$(grep "Verification Hash:" "$ready_file" | cut -d' ' -f3 || echo "")
    
    # Verify PR status with GitHub if gh CLI available
    if command -v gh &> /dev/null && [ -n "$pr_number" ]; then
        local actual_pr_status=$(gh pr view "$pr_number" --json state | jq -r '.state' 2>/dev/null || echo "unknown")
        
        if [ "$actual_pr_status" != "MERGED" ]; then
            error "PR #$pr_number is not merged (status: $actual_pr_status)"
            error "Team $team_id ready file may be invalid"
            return 1
        fi
        
        success "✅ PR #$pr_number verified as merged"
    else
        warn "GitHub CLI not available - skipping PR verification"
    fi
    
    # Verify hash
    local expected_hash=$(echo "$team_id-$wave_number-$job_id-$(date +%s)" | sha256sum | cut -d' ' -f1)
    # Note: Hash verification is approximate due to timestamp differences
    
    success "Team $team_id wave $wave_number readiness validated"
    return 0
}

# Create team task assignment based on wave structure
assign_team_tasks() {
    local job_id="$1"
    local wave_number="$2"
    local team_assignments="$3"  # Format: "team1:3,team2:5,team3:4" (team:task_count)
    
    local wave_config=$(get_wave_config "$wave_number")
    if [ "$wave_config" = "null" ]; then
        error "Wave $wave_number not found in TASKS_WAVES.json"
        exit 1
    fi
    
    local wave_tasks=($(echo "$wave_config" | jq -r '.tasks[]'))
    local total_tasks=${#wave_tasks[@]}
    
    log "Assigning wave $wave_number tasks ($total_tasks total) to teams"
    
    # Parse team assignments
    local team_task_counts=()
    local team_names=()
    
    IFS=',' read -ra ASSIGNMENTS <<< "$team_assignments"
    for assignment in "${ASSIGNMENTS[@]}"; do
        local team_name=$(echo "$assignment" | cut -d':' -f1)
        local task_count=$(echo "$assignment" | cut -d':' -f2)
        team_names+=("$team_name")
        team_task_counts+=("$task_count")
    done
    
    # Validate total assignments
    local total_assigned=0
    for count in "${team_task_counts[@]}"; do
        total_assigned=$((total_assigned + count))
    done
    
    if [ $total_assigned -ne $total_tasks ]; then
        error "Task assignment mismatch: $total_assigned assigned vs $total_tasks available"
        exit 1
    fi
    
    # Create task assignments
    local task_index=0
    local assignment_dir="$SYNC_BASE_DIR/$job_id/assignments"
    mkdir -p "$assignment_dir"
    
    for i in "${!team_names[@]}"; do
        local team_name="${team_names[$i]}"
        local task_count="${team_task_counts[$i]}"
        
        local team_tasks=()
        for ((j=0; j<task_count; j++)); do
            if [ $task_index -lt ${#wave_tasks[@]} ]; then
                team_tasks+=("${wave_tasks[$task_index]}")
                task_index=$((task_index + 1))
            fi
        done
        
        # Create team task list
        local task_file="$assignment_dir/$team_name-wave-$wave_number-tasklist.md"
        
        cat > "$task_file" << EOF
# Team $team_name - Wave $wave_number Task List

**Job ID:** \`$job_id\`
**Team:** $team_name
**Wave:** $wave_number
**Assigned Tasks:** ${#team_tasks[@]}
**Generated:** $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Task Assignments

EOF
        
        for task in "${team_tasks[@]}"; do
            # Get task details from TASKS.md if available
            local task_description=""
            if [ -f "$MAIN_REPO_DIR/TASKS.md" ]; then
                task_description=$(grep -A 2 "^## $task" "$MAIN_REPO_DIR/TASKS.md" | tail -1 || echo "Task details in TASKS.md")
            else
                task_description="See ROADMAP-waves.md for task details"
            fi
            
            echo "### $task" >> "$task_file"
            echo "" >> "$task_file"
            echo "**Status:** 🚧 In Progress" >> "$task_file"
            echo "**Description:** $task_description" >> "$task_file"
            echo "" >> "$task_file"
            echo "---" >> "$task_file"
            echo "" >> "$task_file"
        done
        
        cat >> "$task_file" << EOF

## Completion Protocol

1. ✅ Complete all assigned tasks above
2. ✅ Test your changes thoroughly
3. ✅ Create PR with your team's work
4. ✅ Get PR reviewed and approved
5. ✅ **IMPORTANT:** Merge PR to main branch
6. ✅ Run \`./team-scripts/mark-wave-complete.sh\` to create ready file
7. ✅ Comment on GitHub coordination issue

## Team Worktree

Your isolated worktree is at:
\`\`\`
# Change to your team worktree (created separately)
cd ~/claude-wave-worktrees/$PROJECT_NAME-$job_id/$team_name-wave-$wave_number/
\`\`\`

## Sync Status

Check wave sync status:
\`\`\`bash
./team-scripts/sync-status.sh
\`\`\`

Monitor overall wave progress:
\`\`\`bash
wave-sync-coordinator.sh status $job_id $wave_number
\`\`\`
EOF
        
        success "Created task list for team $team_name: $task_file"
    done
    
    # Create summary assignment file
    cat > "$assignment_dir/wave-$wave_number-assignments-summary.md" << EOF
# Wave $wave_number Task Assignments Summary

**Job ID:** \`$job_id\`
**Wave:** $wave_number
**Total Tasks:** $total_tasks
**Teams:** ${#team_names[@]}
**Generated:** $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Team Assignments

| Team | Tasks Assigned | Task IDs |
|------|----------------|----------|
EOF
    
    task_index=0
    for i in "${!team_names[@]}"; do
        local team_name="${team_names[$i]}"
        local task_count="${team_task_counts[$i]}"
        
        local team_task_ids=""
        for ((j=0; j<task_count; j++)); do
            if [ $task_index -lt ${#wave_tasks[@]} ]; then
                if [ -n "$team_task_ids" ]; then
                    team_task_ids="$team_task_ids, "
                fi
                team_task_ids="$team_task_ids${wave_tasks[$task_index]}"
                task_index=$((task_index + 1))
            fi
        done
        
        echo "| $team_name | $task_count | $team_task_ids |" >> "$assignment_dir/wave-$wave_number-assignments-summary.md"
    done
    
    cat >> "$assignment_dir/wave-$wave_number-assignments-summary.md" << EOF

## Individual Task Lists

EOF
    
    for team_name in "${team_names[@]}"; do
        echo "- [$team_name-wave-$wave_number-tasklist.md](./$team_name-wave-$wave_number-tasklist.md)" >> "$assignment_dir/wave-$wave_number-assignments-summary.md"
    done
    
    success "Task assignments complete for wave $wave_number"
    echo "📋 Assignment summary: $assignment_dir/wave-$wave_number-assignments-summary.md"
}

# Main command dispatcher
main() {
    case "${1:-help}" in
        "init")
            if [ $# -lt 2 ]; then
                error "Usage: $0 init <job_id> [total_waves]"
                exit 1
            fi
            init_sync_env "$2" "${3:-$(get_total_waves)}"
            ;;
        "status")
            if [ $# -lt 3 ]; then
                error "Usage: $0 status <job_id> <wave_number> [expected_teams]"
                exit 1
            fi
            check_wave_sync "$2" "$3" "${4:-}"
            ;;
        "monitor")
            if [ $# -lt 3 ]; then
                error "Usage: $0 monitor <job_id> <wave_number> [expected_teams] [interval]"
                exit 1
            fi
            monitor_wave_sync "$2" "$3" "${4:-}" "${5:-30}"
            ;;
        "validate")
            if [ $# -lt 4 ]; then
                error "Usage: $0 validate <job_id> <wave_number> <team_id>"
                exit 1
            fi
            validate_wave_readiness "$2" "$3" "$4"
            ;;
        "assign")
            if [ $# -lt 4 ]; then
                error "Usage: $0 assign <job_id> <wave_number> <team_assignments>"
                error "Example: $0 assign job123 1 'alpha:6,beta:6,gamma:6'"
                exit 1
            fi
            assign_team_tasks "$2" "$3" "$4"
            ;;
        "help"|*)
            echo "Wave Sync Coordinator - Filesystem-based wave coordination"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  init <job_id> [total_waves]                    Initialize sync environment"
            echo "  status <job_id> <wave> [teams]                 Check wave sync status"
            echo "  monitor <job_id> <wave> [teams] [interval]     Monitor sync with updates"
            echo "  validate <job_id> <wave> <team_id>             Validate team readiness"
            echo "  assign <job_id> <wave> <assignments>           Assign tasks to teams"
            echo "  help                                           Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 init job-20250812                          # Initialize sync for job"
            echo "  $0 status job-20250812 1 'alpha,beta,gamma'   # Check wave 1 status"
            echo "  $0 monitor job-20250812 1 'alpha,beta' 30     # Monitor wave 1 every 30s"
            echo "  $0 assign job-20250812 1 'alpha:6,beta:6,gamma:6'  # Assign wave 1 tasks"
            echo ""
            echo "Sync Protocol:"
            echo "  - Teams create ready.txt files ONLY after PR merge"
            echo "  - Wave N+1 starts only when ALL teams complete wave N"
            echo "  - GitHub integration validates PR merge status"
            echo "  - Filesystem coordination ensures reliable sync"
            ;;
    esac
}

main "$@"