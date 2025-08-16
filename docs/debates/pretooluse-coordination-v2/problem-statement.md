# Problem Statement

## Question
Should PreToolUse hooks include predicted capture paths, and if so, how should this be coordinated with PostToolUse hooks?

## Context
The claude-auto-tee system uses hooks to inform Claude about output capture:
- PreToolUse Hook runs BEFORE command execution
- Main Script creates temp file and executes command with tee injection
- PostToolUse Hook runs AFTER command execution

The core issue: PreToolUse wants to tell Claude where output will be captured, but the temp file hasn't been created yet, requiring path prediction.

## Constraints
- Must work on macOS, Linux, and BSD
- Cannot require GNU-specific tools
- Must handle rapid concurrent executions
- Should not break existing workflows
- POSIX compliance required

## Success Criteria
A valid decision must:
1. Choose one of these approaches with clear rationale:
   - A: Include predicted paths with specific coordination mechanism
   - B: No path prediction - PostToolUse only
   - C: Token-based coordination without paths
   - D: Other clearly specified approach
2. Provide implementation guidance
3. Address security and performance concerns
4. Include rollout/migration strategy