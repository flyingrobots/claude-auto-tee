# Problem Statement: PreToolUse/PostToolUse Hook Coordination

## Context
The claude-auto-tee system uses hooks to inform Claude about output capture:
- **PreToolUse Hook**: Runs BEFORE command execution
- **Main Script**: Creates temp file and executes command with tee injection
- **PostToolUse Hook**: Runs AFTER command execution

## The Core Problem
The PreToolUse hook wants to tell Claude where output will be captured, but the temp file hasn't been created yet. This creates a prediction problem where PreToolUse must guess what filename the main script will generate.

## Current Attempted Solution
Making filename generation deterministic/predictable so PreToolUse can accurately predict the path. However, this is complex and fragile.

## Decision Points
1. **Should PreToolUse markers include the capture path at all?**
2. **If yes, how should the path be coordinated between hooks?**
3. **If no, what value do PreToolUse markers provide?**
4. **What is the optimal architecture for hook coordination?**

## Proposed Options
1. **Remove Path from PreToolUse**: PreToolUse only signals that capture will occur, PostToolUse provides the actual path
2. **Shared State via Environment**: PreToolUse generates the path and passes it via environment variable
3. **Shared State via File**: PreToolUse writes path to a coordination file
4. **Remove PreToolUse Markers**: Rely entirely on PostToolUse for capture notification
5. **Deterministic Generation**: Keep trying to make path generation predictable

## Success Criteria
- **Reliability**: Solution must work consistently across platforms
- **Simplicity**: Minimize complexity and moving parts
- **Performance**: Minimal overhead for command execution
- **Claude Awareness**: Claude must reliably know about captured output
- **Maintainability**: Easy to understand and modify

## Constraints
- Must work on macOS, Linux, and BSD
- Cannot require GNU-specific tools
- Must handle rapid concurrent executions
- Should not break existing workflows