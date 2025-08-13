# Problem Statement: Claude Auto-Tee Output Notification Strategy

## Context and Background

The claude-auto-tee tool successfully captures full command output to temporary files when it detects pipes in bash commands. However, there's a critical gap in the current implementation: Claude (the AI assistant) may not reliably notice that full output has been captured, leading to inefficient re-running of commands.

Currently, the tool outputs a message to stderr like:
```
Full output saved to: /tmp/claude-xyz.log
```

But Claude must:
1. Notice this message among other stderr output
2. Parse and extract the file path
3. Remember the path across tool invocations
4. Know to use `cat` or similar to retrieve it when needed

This unreliable notification mechanism defeats the tool's primary purpose of avoiding command re-runs.

## Specific Decision Points

1. **Notification Method**: How should the tool communicate to Claude that output was captured?
2. **Persistence Strategy**: How should captured file paths be stored for later retrieval?
3. **Discovery Mechanism**: How should Claude discover/list available captured outputs?
4. **Integration Approach**: Should this require changes to claude-auto-tee, Claude's behavior, or both?
5. **Backwards Compatibility**: How to maintain compatibility with existing Claude Code workflows?

## Success Criteria

- Claude must have 100% awareness when output has been captured
- Claude must be able to easily retrieve captured output without user intervention
- The solution must work within Claude Code's existing hook system
- No significant performance overhead or complexity added
- Clear, unambiguous signals that don't rely on parsing unstructured text

## Constraints and Requirements

- Must work within the pre-tool-use hook architecture (no post-command hooks available)
- Cannot modify Claude Code's core behavior directly
- Should maintain the tool's simplicity philosophy (minimal complexity)
- Must be cross-platform compatible (Linux, macOS, Windows via WSL)
- Should handle multiple concurrent captures gracefully
- File cleanup and lifecycle management must be considered