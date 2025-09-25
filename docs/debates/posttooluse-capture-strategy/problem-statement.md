# Problem Statement: PostToolUse Hook Strategy for Claude Auto-Tee

## Context and Background

The claude-auto-tee tool successfully captures full command output by injecting `tee` into piped bash commands via a PreToolUse hook. However, ensuring Claude reliably uses the captured output instead of re-running commands remains challenging.

**Critical New Information**: Claude Code supports both PreToolUse AND PostToolUse hooks. The PostToolUse hook:
- Runs immediately after a tool completes successfully
- Receives the complete tool response including stdout/stderr
- Can process, store, or modify information after execution
- Receives JSON with `tool_response` containing all output

This fundamentally changes the solution space from our previous debate, which incorrectly assumed only PreToolUse hooks existed.

## Current Implementation

**PreToolUse Hook**: 
- Detects pipes in bash commands
- Injects `tee /tmp/claude-xyz.log` to capture full output
- Outputs "Full output saved to: /tmp/claude-xyz.log" to stderr

**Problem**: Claude must parse this stderr message, extract the path, and remember it - unreliable process with ~10% failure rate.

## Specific Decision Points

1. **PostToolUse Integration**: How should the PostToolUse hook process and store capture information?
2. **Communication Protocol**: What's the most reliable way to inform Claude about captures?
3. **State Management**: Where and how should capture metadata be persisted?
4. **Discovery Mechanism**: How should Claude query/discover available captures?
5. **Context Injection**: Can PostToolUse modify Claude's context or only store data?
6. **Coordination**: How should PreToolUse and PostToolUse hooks work together?

## Success Criteria

- **100% Awareness**: Claude must ALWAYS know when output was captured
- **Zero Re-runs**: Eliminate unnecessary command re-execution
- **Automatic Discovery**: Claude should automatically find captures without manual intervention
- **Cross-Session Persistence**: Captures should be discoverable across tool invocations
- **Minimal Complexity**: Solution should be simple and maintainable
- **Robust Error Handling**: Graceful degradation if hooks fail

## Constraints and Requirements

- Must work within Claude Code's hook architecture
- PostToolUse receives JSON with tool_response but cannot modify Claude's memory directly
- Must handle concurrent captures from multiple commands
- Cross-platform compatibility (Linux, macOS, Windows via WSL)
- Cannot modify Claude Code core or Claude's internal behavior
- Must coordinate between PreToolUse (injection) and PostToolUse (notification)

## Key Technical Capabilities

**PostToolUse Hook Receives**:
```json
{
  "session_id": "...",
  "transcript_path": "...",
  "cwd": "...",
  "hook_event_name": "PostToolUse",
  "tool_name": "Bash",
  "tool_input": {"command": "..."},
  "tool_response": {
    "stdout": "...",
    "stderr": "...",
    "exit_code": 0
  }
}
```

The hook can:
- Parse the tool_response to extract capture file paths
- Write structured data to persistent storage
- Create marker files or registries
- Set environment variables for future commands
- Generate summaries or indexes

## Critical Question

Given that PostToolUse hooks CAN process the complete tool response AFTER execution, what is the optimal strategy to ensure Claude will ALWAYS use captured output from tee injections rather than re-running commands?