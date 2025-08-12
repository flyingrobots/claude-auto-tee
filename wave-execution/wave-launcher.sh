#!/usr/bin/env bash
# Wave Launcher - Quick start script for wave-based execution
# Provides guided setup and common operations

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_REPO_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] $1${NC}" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}" >&2
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

info() {
    echo -e "${CYAN}[INFO] $1${NC}" >&2
}

# Show banner
show_banner() {
    echo -e "${BOLD}${BLUE}"
    cat << 'EOF'
🌊 Claude Auto-Tee Wave Execution System
========================================

Production-ready coordination for parallel team execution
with wave-based synchronization and GitHub integration.

EOF
    echo -e "${NC}"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    local missing=()
    
    # Check required tools
    command -v jq >/dev/null || missing+=("jq")
    command -v gh >/dev/null || missing+=("github-cli")
    command -v git >/dev/null || missing+=("git")
    
    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required tools: ${missing[*]}"
        echo ""
        echo "Install missing tools:"
        for tool in "${missing[@]}"; do
            case "$tool" in
                "jq") echo "  macOS: brew install jq" ;;
                "github-cli") echo "  macOS: brew install gh" ;;
                "git") echo "  macOS: brew install git" ;;
            esac
        done
        return 1
    fi
    
    # Check GitHub authentication
    if ! gh auth status >/dev/null 2>&1; then
        warn "GitHub CLI not authenticated"
        echo "Run: gh auth login"
        return 1
    fi
    
    # Check project structure
    if [ ! -f "$MAIN_REPO_DIR/TASKS_WAVES.json" ]; then
        error "TASKS_WAVES.json not found in $MAIN_REPO_DIR"
        return 1
    fi
    
    success "✅ All prerequisites satisfied"
    return 0
}

# Quick start wizard
quick_start() {
    show_banner
    
    echo "🚀 Quick Start Wizard"
    echo "====================="
    echo ""
    
    if ! check_prerequisites; then
        error "Prerequisites not met. Please install required tools and try again."
        exit 1
    fi
    
    # Generate job ID
    local job_id="job-$(date +%Y%m%d-%H%M%S)"
    echo "Generated Job ID: $job_id"
    echo ""
    
    # Ask for team configuration
    echo "Team Configuration:"
    echo "=================="
    
    read -p "Number of teams for Wave 1 (3-6 recommended): " wave1_teams
    read -p "Number of teams for Wave 2 (8-15 recommended): " wave2_teams  
    read -p "Number of teams for Wave 3 (4-8 recommended): " wave3_teams
    
    # Validate team counts
    if ! [[ "$wave1_teams" =~ ^[0-9]+$ ]] || [ "$wave1_teams" -lt 1 ]; then
        error "Invalid team count for Wave 1"
        exit 1
    fi
    
    echo ""
    echo "Configuration Summary:"
    echo "======================"
    echo "Job ID: $job_id"
    echo "Wave 1 Teams: $wave1_teams"
    echo "Wave 2 Teams: $wave2_teams"
    echo "Wave 3 Teams: $wave3_teams"
    echo ""
    
    read -p "Proceed with setup? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi
    
    echo ""
    log "Initializing wave execution environment..."
    
    # Initialize job
    "$SCRIPT_DIR/wave-sync-coordinator.sh" init "$job_id"
    
    # Calculate task distribution for Wave 1
    local tasks_per_team=$((18 / wave1_teams))
    local remaining_tasks=$((18 % wave1_teams))
    
    local wave1_assignment=""
    for ((i=1; i<=wave1_teams; i++)); do
        local team_name="team$i"
        local team_tasks=$tasks_per_team
        
        # Distribute remaining tasks to first teams
        if [ $i -le $remaining_tasks ]; then
            team_tasks=$((team_tasks + 1))
        fi
        
        if [ -n "$wave1_assignment" ]; then
            wave1_assignment="$wave1_assignment,"
        fi
        wave1_assignment="$wave1_assignment$team_name:$team_tasks"
    done
    
    log "Assigning Wave 1 tasks..."
    "$SCRIPT_DIR/wave-sync-coordinator.sh" assign "$job_id" 1 "$wave1_assignment"
    
    log "Creating team worktrees..."
    for ((i=1; i<=wave1_teams; i++)); do
        "$SCRIPT_DIR/git-worktree-manager.sh" create "team$i" 1 "$job_id"
    done
    
    log "Creating GitHub coordination issue..."
    "$SCRIPT_DIR/git-worktree-manager.sh" issue 1 "$job_id"
    
    success "🎉 Wave execution setup complete!"
    echo ""
    echo "Next Steps:"
    echo "==========="
    echo "1. Start monitoring:"
    echo "   $SCRIPT_DIR/wave-dashboard.sh live $job_id --detailed"
    echo ""
    echo "2. Start automated transitions:"
    echo "   $SCRIPT_DIR/wave-transition-manager.sh monitor $job_id"
    echo ""
    echo "3. Teams can access their worktrees:"
    for ((i=1; i<=wave1_teams; i++)); do
        echo "   Team $i: cd ~/claude-wave-worktrees/claude-auto-tee-$job_id/team$i-wave-1/"
    done
    echo ""
    echo "4. View task assignments:"
    echo "   ls ~/claude-wave-workstream-sync/$job_id/assignments/"
    echo ""
    echo "Job ID: $job_id (save this for monitoring and management)"
}

# Show system status
show_status() {
    local job_id="${1:-}"
    
    if [ -z "$job_id" ]; then
        echo "Available jobs:"
        ls -1 "$HOME/claude-wave-workstream-sync/" 2>/dev/null | grep "^job-" || echo "  No jobs found"
        echo ""
        echo "Usage: $0 status <job_id>"
        return 1
    fi
    
    echo "🌊 Wave Execution Status"
    echo "========================"
    echo "Job ID: $job_id"
    echo ""
    
    # Use existing status scripts
    "$SCRIPT_DIR/wave-transition-manager.sh" status "$job_id" 2>/dev/null || {
        error "Job $job_id not found or invalid"
        return 1
    }
}

# Emergency operations
emergency_stop() {
    local job_id="$1"
    local reason="${2:-emergency-stop}"
    
    warn "EMERGENCY STOP for job $job_id"
    warn "Reason: $reason"
    echo ""
    
    read -p "Are you sure you want to emergency stop this job? (yes/NO): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Emergency stop cancelled."
        return 0
    fi
    
    "$SCRIPT_DIR/wave-safety-manager.sh" emergency-stop "$job_id" "$reason"
    
    echo ""
    echo "Emergency stop activated. To resume:"
    echo "  $0 resume $job_id"
}

# Resume operations
resume_operations() {
    local job_id="$1"
    
    info "Resuming operations for job $job_id"
    "$SCRIPT_DIR/wave-safety-manager.sh" resume "$job_id"
    
    echo ""
    echo "Operations resumed. Restart monitoring:"
    echo "  $SCRIPT_DIR/wave-transition-manager.sh monitor $job_id"
}

# Launch monitoring dashboard
launch_dashboard() {
    local job_id="$1"
    
    log "Launching dashboard for job $job_id"
    "$SCRIPT_DIR/wave-dashboard.sh" live "$job_id" --detailed
}

# Launch monitoring
launch_monitoring() {
    local job_id="$1"
    local interval="${2:-60}"
    
    log "Starting automated monitoring for job $job_id (${interval}s intervals)"
    "$SCRIPT_DIR/wave-transition-manager.sh" monitor "$job_id" "$interval"
}

# Show help
show_help() {
    cat << EOF
Wave Launcher - Quick start and management for wave execution

Usage: $0 <command> [options]

Commands:
  quick-start                          Guided setup wizard for new jobs
  status <job_id>                      Show job status and progress
  dashboard <job_id>                   Launch live monitoring dashboard
  monitor <job_id> [interval]          Start automated transition monitoring
  emergency-stop <job_id> [reason]     Emergency halt all operations
  resume <job_id>                      Resume from emergency stop
  help                                 Show this help

Examples:
  $0 quick-start                       # Start new wave execution
  $0 status job-20250812-143022        # Check job progress
  $0 dashboard job-20250812-143022     # Live dashboard
  $0 monitor job-20250812-143022 30    # Auto-monitor every 30s
  $0 emergency-stop job-20250812-143022 "critical-bug"

Quick Reference:
  📁 Team worktrees: ~/claude-wave-worktrees/
  📁 Sync directory: ~/claude-wave-workstream-sync/
  📁 Backups: ~/.claude-wave-backups/

Available Scripts:
  git-worktree-manager.sh      Team worktree management
  wave-sync-coordinator.sh     Sync coordination and task assignment
  wave-transition-manager.sh   Automated transition monitoring
  wave-safety-manager.sh       Safety, backup, and recovery
  wave-dashboard.sh           Progress monitoring and visualization
  wave-quality-gates.sh       Quality validation and gates

Documentation:
  README.md                    System overview and architecture
  TEAM_RUNBOOK.md             Team member guide
  COORDINATOR_RUNBOOK.md      Job coordinator guide
  SAFETY_GUIDE.md             Safety and recovery procedures

For detailed help on any script: <script-name> help
EOF
}

# Main command dispatcher
main() {
    case "${1:-help}" in
        "quick-start"|"start")
            quick_start
            ;;
        "status")
            if [ $# -lt 2 ]; then
                show_status
            else
                show_status "$2"
            fi
            ;;
        "dashboard")
            if [ $# -lt 2 ]; then
                error "Usage: $0 dashboard <job_id>"
                exit 1
            fi
            launch_dashboard "$2"
            ;;
        "monitor")
            if [ $# -lt 2 ]; then
                error "Usage: $0 monitor <job_id> [interval]"
                exit 1
            fi
            launch_monitoring "$2" "${3:-60}"
            ;;
        "emergency-stop"|"stop")
            if [ $# -lt 2 ]; then
                error "Usage: $0 emergency-stop <job_id> [reason]"
                exit 1
            fi
            emergency_stop "$2" "${3:-emergency-stop}"
            ;;
        "resume")
            if [ $# -lt 2 ]; then
                error "Usage: $0 resume <job_id>"
                exit 1
            fi
            resume_operations "$2"
            ;;
        "check")
            check_prerequisites
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

main "$@"