#!/usr/bin/env bash
# Wave Safety Manager - Error handling, rollback, and safety mechanisms
# Provides recovery tools and safety checks for wave-based execution

set -euo pipefail

# Configuration
SYNC_BASE_DIR="${SYNC_BASE_DIR:-$HOME/claude-wave-workstream-sync}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/.claude-wave-backups}"
MAIN_REPO_DIR="${MAIN_REPO_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SAFETY_LOG_DIR="${SAFETY_LOG_DIR:-$HOME/.claude-wave-safety}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    local msg="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${BLUE}[$timestamp] $msg${NC}" >&2
    echo "[$timestamp] $msg" >> "$SAFETY_LOG_DIR/safety.log"
}

error() {
    local msg="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${RED}[ERROR $timestamp] $msg${NC}" >&2
    echo "[ERROR $timestamp] $msg" >> "$SAFETY_LOG_DIR/safety.log"
}

success() {
    local msg="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${GREEN}[SUCCESS $timestamp] $msg${NC}" >&2
    echo "[SUCCESS $timestamp] $msg" >> "$SAFETY_LOG_DIR/safety.log"
}

warn() {
    local msg="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${YELLOW}[WARNING $timestamp] $msg${NC}" >&2
    echo "[WARNING $timestamp] $msg" >> "$SAFETY_LOG_DIR/safety.log"
}

critical() {
    local msg="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${PURPLE}[CRITICAL $timestamp] $msg${NC}" >&2
    echo "[CRITICAL $timestamp] $msg" >> "$SAFETY_LOG_DIR/safety.log"
}

# Initialize safety logging
init_safety_logging() {
    mkdir -p "$SAFETY_LOG_DIR" "$BACKUP_DIR"
    if [ ! -f "$SAFETY_LOG_DIR/safety.log" ]; then
        echo "# Wave Safety Log - $(date)" > "$SAFETY_LOG_DIR/safety.log"
    fi
}

# Create backup of sync state
create_sync_backup() {
    local job_id="$1"
    local backup_reason="${2:-manual}"
    
    local backup_timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_path="$BACKUP_DIR/$job_id-$backup_timestamp"
    
    log "Creating sync state backup: $backup_path"
    
    if [ ! -d "$SYNC_BASE_DIR/$job_id" ]; then
        error "Sync directory not found: $SYNC_BASE_DIR/$job_id"
        return 1
    fi
    
    mkdir -p "$backup_path"
    
    # Copy entire sync directory
    cp -r "$SYNC_BASE_DIR/$job_id"/* "$backup_path/" 2>/dev/null || true
    
    # Create backup metadata
    cat > "$backup_path/.backup-metadata.json" << EOF
{
    "job_id": "$job_id",
    "backup_timestamp": "$backup_timestamp",
    "backup_reason": "$backup_reason",
    "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "sync_dir": "$SYNC_BASE_DIR/$job_id",
    "backup_path": "$backup_path",
    "waves_backed_up": $(find "$SYNC_BASE_DIR/$job_id" -name "wave-*" -type d | wc -l | tr -d ' '),
    "ready_files_backed_up": $(find "$SYNC_BASE_DIR/$job_id" -name "*.ready.txt" | wc -l | tr -d ' ')
}
EOF
    
    success "Sync backup created: $backup_path"
    echo "📁 Backup location: $backup_path"
    echo "📊 Backup metadata: $backup_path/.backup-metadata.json"
    
    return 0
}

# Restore from backup
restore_from_backup() {
    local job_id="$1"
    local backup_timestamp="$2"
    local force="${3:-false}"
    
    local backup_path="$BACKUP_DIR/$job_id-$backup_timestamp"
    
    if [ ! -d "$backup_path" ]; then
        error "Backup not found: $backup_path"
        return 1
    fi
    
    if [ ! -f "$backup_path/.backup-metadata.json" ]; then
        error "Invalid backup - metadata not found: $backup_path/.backup-metadata.json"
        return 1
    fi
    
    log "Restoring sync state from backup: $backup_path"
    
    # Validate backup
    local backed_up_job_id=$(jq -r '.job_id' "$backup_path/.backup-metadata.json")
    if [ "$backed_up_job_id" != "$job_id" ]; then
        error "Job ID mismatch - backup: $backed_up_job_id, requested: $job_id"
        return 1
    fi
    
    # Create safety backup of current state before restore
    if [ -d "$SYNC_BASE_DIR/$job_id" ] && [ "$force" != "true" ]; then
        warn "Current sync state exists - creating safety backup before restore"
        create_sync_backup "$job_id" "pre-restore-safety"
    fi
    
    # Remove current sync directory
    if [ -d "$SYNC_BASE_DIR/$job_id" ]; then
        log "Removing current sync directory: $SYNC_BASE_DIR/$job_id"
        rm -rf "$SYNC_BASE_DIR/$job_id"
    fi
    
    # Restore from backup
    mkdir -p "$SYNC_BASE_DIR/$job_id"
    cp -r "$backup_path"/* "$SYNC_BASE_DIR/$job_id/" 2>/dev/null || true
    
    # Remove backup metadata from restored directory
    rm -f "$SYNC_BASE_DIR/$job_id/.backup-metadata.json"
    
    success "Sync state restored from backup"
    echo "📁 Restored to: $SYNC_BASE_DIR/$job_id"
    echo "📊 Backup used: $backup_path"
    
    return 0
}

# Validate sync directory integrity
validate_sync_integrity() {
    local job_id="$1"
    local fix_issues="${2:-false}"
    
    log "Validating sync directory integrity for job: $job_id"
    
    local sync_dir="$SYNC_BASE_DIR/$job_id"
    local issues_found=0
    
    if [ ! -d "$sync_dir" ]; then
        critical "Sync directory not found: $sync_dir"
        return 1
    fi
    
    # Check job metadata
    if [ ! -f "$sync_dir/.job-metadata.json" ]; then
        error "Job metadata missing: $sync_dir/.job-metadata.json"
        issues_found=$((issues_found + 1))
        
        if [ "$fix_issues" = "true" ]; then
            warn "Attempting to recreate job metadata..."
            # Basic metadata recreation
            cat > "$sync_dir/.job-metadata.json" << EOF
{
    "job_id": "$job_id",
    "recovered_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "recovery_note": "Metadata recreated by safety manager",
    "total_waves": 3,
    "sync_protocol_version": "1.0"
}
EOF
            success "Job metadata recreated"
            issues_found=$((issues_found - 1))
        fi
    fi
    
    # Validate wave directories
    local wave_dirs=($(find "$sync_dir" -name "wave-*" -type d | sort))
    for wave_dir in "${wave_dirs[@]}"; do
        local wave_number=$(basename "$wave_dir" | sed 's/wave-//')
        
        # Check wave metadata
        if [ ! -f "$wave_dir/.wave-metadata.json" ]; then
            error "Wave $wave_number metadata missing: $wave_dir/.wave-metadata.json"
            issues_found=$((issues_found + 1))
            
            if [ "$fix_issues" = "true" ]; then
                warn "Recreating wave $wave_number metadata..."
                cat > "$wave_dir/.wave-metadata.json" << EOF
{
    "job_id": "$job_id",
    "wave_number": $wave_number,
    "recovered_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "recovery_note": "Metadata recreated by safety manager"
}
EOF
                success "Wave $wave_number metadata recreated"
                issues_found=$((issues_found - 1))
            fi
        fi
        
        # Validate ready files
        local ready_files=($(find "$wave_dir" -name "*.ready.txt" 2>/dev/null || true))
        for ready_file in "${ready_files[@]}"; do
            if [ ! -s "$ready_file" ]; then
                error "Empty ready file found: $ready_file"
                issues_found=$((issues_found + 1))
                continue
            fi
            
            if ! grep -q "TEAM_WAVE_COMPLETION_CONFIRMATION" "$ready_file"; then
                error "Invalid ready file format: $ready_file"
                issues_found=$((issues_found + 1))
            fi
            
            if ! grep -q "PR Status: MERGED" "$ready_file"; then
                warn "Ready file indicates PR not merged: $ready_file"
                # This might be OK for in-progress work
            fi
        done
    done
    
    # Check assignment directory
    local assignment_dir="$sync_dir/assignments"
    if [ ! -d "$assignment_dir" ]; then
        warn "Assignment directory missing: $assignment_dir"
        
        if [ "$fix_issues" = "true" ]; then
            mkdir -p "$assignment_dir"
            success "Assignment directory created"
        fi
    fi
    
    if [ $issues_found -eq 0 ]; then
        success "✅ Sync directory integrity check passed"
        return 0
    else
        error "❌ Found $issues_found integrity issues"
        if [ "$fix_issues" = "false" ]; then
            echo "Run with --fix to attempt automatic repair"
        fi
        return 1
    fi
}

# Reset team ready state (for rollback scenarios)
reset_team_ready_state() {
    local job_id="$1"
    local wave_number="$2"
    local team_id="$3"
    local reason="${4:-manual reset}"
    
    log "Resetting ready state for team $team_id, wave $wave_number"
    
    local ready_file="$SYNC_BASE_DIR/$job_id/wave-$wave_number/$team_id.ready.txt"
    
    if [ ! -f "$ready_file" ]; then
        warn "Ready file not found: $ready_file"
        return 0
    fi
    
    # Create backup before removal
    local backup_file="$ready_file.backup-$(date +%Y%m%d-%H%M%S)"
    cp "$ready_file" "$backup_file"
    
    # Add reset reason to backup
    echo "" >> "$backup_file"
    echo "# RESET INFORMATION" >> "$backup_file"
    echo "Reset At: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$backup_file"
    echo "Reset Reason: $reason" >> "$backup_file"
    echo "Reset By: $(whoami)@$(hostname)" >> "$backup_file"
    
    # Remove ready file
    rm "$ready_file"
    
    success "Team $team_id ready state reset"
    echo "📄 Ready file removed: $ready_file"
    echo "💾 Backup created: $backup_file"
    
    log "Team $team_id ready state reset - reason: $reason"
}

# Emergency stop - pause all wave transitions
emergency_stop() {
    local job_id="$1"
    local reason="${2:-emergency stop}"
    
    critical "EMERGENCY STOP initiated for job $job_id"
    critical "Reason: $reason"
    
    local stop_file="$SYNC_BASE_DIR/$job_id/.EMERGENCY_STOP"
    
    cat > "$stop_file" << EOF
# EMERGENCY STOP
# This file prevents wave transitions from occurring

Job ID: $job_id
Stop Initiated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Stop Reason: $reason
Stop Initiated By: $(whoami)@$(hostname)

# To resume operations:
# 1. Resolve the underlying issue
# 2. Remove this file: rm "$stop_file"
# 3. Resume monitoring: wave-transition-manager.sh monitor $job_id

EMERGENCY STOP ACTIVE - NO WAVE TRANSITIONS WILL OCCUR
EOF
    
    critical "Emergency stop file created: $stop_file"
    critical "All wave transitions halted until file is removed"
    
    return 0
}

# Resume from emergency stop
resume_operations() {
    local job_id="$1"
    
    local stop_file="$SYNC_BASE_DIR/$job_id/.EMERGENCY_STOP"
    
    if [ ! -f "$stop_file" ]; then
        warn "No emergency stop file found for job $job_id"
        return 0
    fi
    
    log "Resuming operations for job $job_id"
    
    # Archive stop file instead of deleting
    local archive_file="$stop_file.resolved-$(date +%Y%m%d-%H%M%S)"
    mv "$stop_file" "$archive_file"
    
    echo "" >> "$archive_file"
    echo "# RESOLUTION" >> "$archive_file"
    echo "Resolved At: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$archive_file"
    echo "Resolved By: $(whoami)@$(hostname)" >> "$archive_file"
    
    success "Emergency stop removed - operations can resume"
    echo "📄 Stop file archived: $archive_file"
    
    return 0
}

# Comprehensive health check
health_check() {
    local job_id="$1"
    
    echo "🏥 Wave Execution Health Check"
    echo "==============================="
    echo "🆔 Job ID: $job_id"
    echo "📅 Check Time: $(date -u +%Y-%m-%dT%H:%M:%SZ')"
    echo ""
    
    local health_score=0
    local max_score=10
    
    # Check 1: Sync directory exists
    if [ -d "$SYNC_BASE_DIR/$job_id" ]; then
        echo "✅ Sync directory exists"
        health_score=$((health_score + 1))
    else
        echo "❌ Sync directory missing"
    fi
    
    # Check 2: Job metadata valid
    if [ -f "$SYNC_BASE_DIR/$job_id/.job-metadata.json" ]; then
        echo "✅ Job metadata present"
        health_score=$((health_score + 1))
    else
        echo "❌ Job metadata missing"
    fi
    
    # Check 3: No emergency stop
    if [ ! -f "$SYNC_BASE_DIR/$job_id/.EMERGENCY_STOP" ]; then
        echo "✅ No emergency stop active"
        health_score=$((health_score + 1))
    else
        echo "❌ Emergency stop active"
    fi
    
    # Check 4: Wave directories present
    local wave_count=$(find "$SYNC_BASE_DIR/$job_id" -name "wave-*" -type d 2>/dev/null | wc -l | tr -d ' ')
    if [ "$wave_count" -gt 0 ]; then
        echo "✅ Wave directories present ($wave_count found)"
        health_score=$((health_score + 1))
    else
        echo "❌ No wave directories found"
    fi
    
    # Check 5: Assignment directory
    if [ -d "$SYNC_BASE_DIR/$job_id/assignments" ]; then
        echo "✅ Assignment directory exists"
        health_score=$((health_score + 1))
    else
        echo "⚠️  Assignment directory missing"
    fi
    
    # Check 6: GitHub CLI available
    if command -v gh &> /dev/null && gh auth status >/dev/null 2>&1; then
        echo "✅ GitHub CLI authenticated"
        health_score=$((health_score + 1))
    else
        echo "⚠️  GitHub CLI not available or not authenticated"
    fi
    
    # Check 7: Git repository access
    if git rev-parse --git-dir >/dev/null 2>&1; then
        echo "✅ Git repository accessible"
        health_score=$((health_score + 1))
    else
        echo "⚠️  Git repository not accessible"
    fi
    
    # Check 8: Backup directory writable
    if [ -w "$BACKUP_DIR" ] || mkdir -p "$BACKUP_DIR" 2>/dev/null; then
        echo "✅ Backup directory writable"
        health_score=$((health_score + 1))
    else
        echo "❌ Backup directory not writable"
    fi
    
    # Check 9: Safety logging working
    if [ -w "$SAFETY_LOG_DIR" ] || mkdir -p "$SAFETY_LOG_DIR" 2>/dev/null; then
        echo "✅ Safety logging available"
        health_score=$((health_score + 1))
    else
        echo "❌ Safety logging not available"
    fi
    
    # Check 10: Configuration files present
    if [ -f "$MAIN_REPO_DIR/TASKS_WAVES.json" ]; then
        echo "✅ Wave configuration present"
        health_score=$((health_score + 1))
    else
        echo "❌ Wave configuration missing"
    fi
    
    echo ""
    echo "🏥 Health Score: $health_score/$max_score"
    
    if [ $health_score -ge 8 ]; then
        echo "💚 HEALTHY - System ready for wave execution"
        return 0
    elif [ $health_score -ge 6 ]; then
        echo "💛 WARNING - Some issues detected, but system operational"
        return 1
    else
        echo "❤️  CRITICAL - Major issues detected, system may not function properly"
        return 2
    fi
}

# List available backups
list_backups() {
    local job_id="${1:-}"
    
    echo "📦 Available Sync Backups"
    echo "=========================="
    
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "No backup directory found: $BACKUP_DIR"
        return 0
    fi
    
    local backup_pattern="*"
    if [ -n "$job_id" ]; then
        backup_pattern="$job_id-*"
    fi
    
    local backup_count=0
    for backup_dir in "$BACKUP_DIR"/$backup_pattern; do
        if [ -d "$backup_dir" ] && [ -f "$backup_dir/.backup-metadata.json" ]; then
            backup_count=$((backup_count + 1))
            
            local backup_job_id=$(jq -r '.job_id' "$backup_dir/.backup-metadata.json")
            local backup_timestamp=$(jq -r '.backup_timestamp' "$backup_dir/.backup-metadata.json")
            local backup_reason=$(jq -r '.backup_reason' "$backup_dir/.backup-metadata.json")
            local waves_backed_up=$(jq -r '.waves_backed_up' "$backup_dir/.backup-metadata.json")
            local ready_files=$(jq -r '.ready_files_backed_up' "$backup_dir/.backup-metadata.json")
            
            echo "📦 Backup: $backup_timestamp"
            echo "   🆔 Job: $backup_job_id"
            echo "   📁 Path: $backup_dir"
            echo "   📝 Reason: $backup_reason"
            echo "   🌊 Waves: $waves_backed_up"
            echo "   📄 Ready files: $ready_files"
            echo ""
        fi
    done
    
    if [ $backup_count -eq 0 ]; then
        echo "No backups found"
        if [ -n "$job_id" ]; then
            echo "Job ID filter: $job_id"
        fi
    else
        echo "Total backups: $backup_count"
    fi
}

# Main command dispatcher
main() {
    init_safety_logging
    
    case "${1:-help}" in
        "backup")
            if [ $# -lt 2 ]; then
                error "Usage: $0 backup <job_id> [reason]"
                exit 1
            fi
            create_sync_backup "$2" "${3:-manual}"
            ;;
        "restore")
            if [ $# -lt 3 ]; then
                error "Usage: $0 restore <job_id> <backup_timestamp> [--force]"
                exit 1
            fi
            restore_from_backup "$2" "$3" "${4:-false}"
            ;;
        "validate")
            if [ $# -lt 2 ]; then
                error "Usage: $0 validate <job_id> [--fix]"
                exit 1
            fi
            validate_sync_integrity "$2" "${3:-false}"
            ;;
        "reset-team")
            if [ $# -lt 4 ]; then
                error "Usage: $0 reset-team <job_id> <wave> <team_id> [reason]"
                exit 1
            fi
            reset_team_ready_state "$2" "$3" "$4" "${5:-manual reset}"
            ;;
        "emergency-stop")
            if [ $# -lt 2 ]; then
                error "Usage: $0 emergency-stop <job_id> [reason]"
                exit 1
            fi
            emergency_stop "$2" "${3:-emergency stop}"
            ;;
        "resume")
            if [ $# -lt 2 ]; then
                error "Usage: $0 resume <job_id>"
                exit 1
            fi
            resume_operations "$2"
            ;;
        "health")
            if [ $# -lt 2 ]; then
                error "Usage: $0 health <job_id>"
                exit 1
            fi
            health_check "$2"
            ;;
        "list-backups")
            list_backups "${2:-}"
            ;;
        "help"|*)
            echo "Wave Safety Manager - Error handling and recovery tools"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  backup <job_id> [reason]                       Create sync state backup"
            echo "  restore <job_id> <timestamp> [--force]         Restore from backup"
            echo "  validate <job_id> [--fix]                      Validate sync integrity"
            echo "  reset-team <job_id> <wave> <team> [reason]     Reset team ready state"
            echo "  emergency-stop <job_id> [reason]               Emergency halt all transitions"
            echo "  resume <job_id>                                Resume from emergency stop"
            echo "  health <job_id>                                Comprehensive health check"
            echo "  list-backups [job_id]                          List available backups"
            echo "  help                                           Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 backup job-20250812 'before-wave-2'        # Create backup"
            echo "  $0 restore job-20250812 20250812-143022       # Restore from backup"
            echo "  $0 validate job-20250812 --fix                # Validate and fix issues"
            echo "  $0 reset-team job-20250812 1 alpha            # Reset team ready state"
            echo "  $0 emergency-stop job-20250812 'critical-bug' # Emergency stop"
            echo "  $0 health job-20250812                        # Health check"
            echo ""
            echo "Safety Features:"
            echo "  - Automatic backup before critical operations"
            echo "  - Integrity validation and repair"
            echo "  - Emergency stop capabilities"
            echo "  - Team state rollback"
            echo "  - Comprehensive health monitoring"
            ;;
    esac
}

main "$@"