#!/usr/bin/env bash
# Check overall wave sync status from team worktree
# This script is copied into each team worktree for easy access

set -euo pipefail

# Load team metadata
if [ ! -f ".team-metadata.json" ]; then
    echo "Error: Not in a team worktree directory"
    echo "This script must be run from a team worktree created by git-worktree-manager.sh"
    exit 1
fi

# Extract metadata using simple grep/sed (avoid jq dependency in worktrees)
TEAM_ID=$(grep '"team_id"' .team-metadata.json | sed 's/.*"team_id":[[:space:]]*"\([^"]*\)".*/\1/')
WAVE_NUMBER=$(grep '"wave_number"' .team-metadata.json | sed 's/.*"wave_number":[[:space:]]*\([0-9]*\).*/\1/')
JOB_ID=$(grep '"job_id"' .team-metadata.json | sed 's/.*"job_id":[[:space:]]*"\([^"]*\)".*/\1/')

SYNC_DIR="$HOME/claude-wave-workstream-sync/$JOB_ID/wave-$WAVE_NUMBER"

echo "🌊 Wave $WAVE_NUMBER Sync Status Check"
echo "====================================="
echo "👥 Team: $TEAM_ID"
echo "🆔 Job: $JOB_ID"
echo "📁 Sync Directory: $SYNC_DIR"
echo "📅 Checked At: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

if [ ! -d "$SYNC_DIR" ]; then
    echo "❌ Sync directory not found: $SYNC_DIR"
    echo ""
    echo "💡 The job coordinator needs to initialize the sync environment:"
    echo "   wave-sync-coordinator.sh init $JOB_ID"
    exit 1
fi

# Check this team's status
READY_FILE="$SYNC_DIR/$TEAM_ID.ready.txt"
if [ -f "$READY_FILE" ]; then
    echo "✅ This team ($TEAM_ID) is READY for wave transition"
    echo "📄 Ready file: $READY_FILE"
    echo "⏰ Ready since: $(stat -f %Sm "$READY_FILE" 2>/dev/null || stat -c %y "$READY_FILE" 2>/dev/null)"
    echo ""
else
    echo "⏳ This team ($TEAM_ID) is NOT YET READY"
    echo "📋 Complete your tasks and merge PR, then run: ./team-scripts/mark-wave-complete.sh"
    echo ""
fi

# Count all ready teams
READY_FILES=($(find "$SYNC_DIR" -name "*.ready.txt" -type f 2>/dev/null || true))
READY_COUNT=${#READY_FILES[@]}

echo "📊 Overall Wave $WAVE_NUMBER Status"
echo "==================================="
echo "✅ Teams Ready: $READY_COUNT"

if [ $READY_COUNT -eq 0 ]; then
    echo "⏳ No teams have completed wave $WAVE_NUMBER yet"
elif [ $READY_COUNT -eq 1 ] && [ -f "$READY_FILE" ]; then
    echo "🏃 You are the first team ready! Waiting for others..."
else
    echo ""
    echo "Ready teams:"
    for ready_file in "${READY_FILES[@]}"; do
        local team=$(basename "$ready_file" .ready.txt)
        local ready_time=$(stat -f %Sm "$ready_file" 2>/dev/null || stat -c %y "$ready_file" 2>/dev/null | cut -d' ' -f1,2)
        echo "  ✅ $team (ready: $ready_time)"
    done
fi

echo ""
echo "🔄 Real-time monitoring:"
echo "   wave-sync-coordinator.sh monitor $JOB_ID $WAVE_NUMBER"
echo ""
echo "📋 Full status check:"
echo "   wave-sync-coordinator.sh status $JOB_ID $WAVE_NUMBER"