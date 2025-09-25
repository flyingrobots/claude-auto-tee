# Expert 004 Opening Statement: API Contract and System Boundaries

## Problem Analysis

From a system architecture perspective, this is fundamentally a **communication contract failure** between the claude-auto-tee tool and Claude. The current implementation relies on stderr messaging, which creates an unreliable out-of-band communication channel that Claude may or may not process consistently.

## Core Issues

1. **Implicit Communication Contract**: The tool assumes Claude will parse stderr messages and understand their semantic meaning
2. **Weak System Boundary**: No formal interface definition between tool and AI agent
3. **Non-Deterministic Awareness**: Claude's awareness depends on message parsing heuristics rather than structured data
4. **Single Channel Dependency**: Relying solely on stderr creates a single point of failure

## Proposed Solution: Structured Output Protocol

### Primary Recommendation: JSON-Wrapped Output Format

Implement a structured output format that embeds metadata directly in stdout using a parseable wrapper:

```json
{
  "claude_auto_tee": {
    "captured": true,
    "log_file": "/tmp/claude-xyz.log",
    "original_command": "npm test",
    "timestamp": "2025-08-13T10:30:00Z"
  },
  "output": "... actual command output here ..."
}
```

### Alternative: Header-Footer Pattern

Use clear delimiters in stdout that Claude can reliably detect:

```
=== CLAUDE-AUTO-TEE: OUTPUT CAPTURED TO /tmp/claude-xyz.log ===
... actual command output ...
=== CLAUDE-AUTO-TEE: END CAPTURE ===
```

## System Boundaries Definition

### Tool Responsibilities
- Detect pipe conditions
- Capture full output to temp file
- Communicate capture status through structured format
- Maintain cross-platform file path compatibility

### Claude Responsibilities  
- Parse structured output format
- Recognize capture indicators
- Reference log files instead of re-running commands
- Handle both captured and non-captured output gracefully

## Implementation Considerations

### Cross-Platform Compatibility
- Use forward slashes in paths (works on all platforms)
- Ensure JSON parsing handles Unicode and special characters
- Test temp file creation across different OS temp directories

### Simplicity Constraints
- Minimal changes to existing pre-tool-use hook
- No external dependencies or complex parsing logic
- Backward compatibility with existing command patterns

### Robustness Guarantees
- Well-defined error states (capture failure, file not found)
- Clear success/failure indicators
- Graceful degradation when capture fails

## Proposed Voting Options

1. **JSON Wrapper Protocol** - Embed capture metadata in JSON-structured stdout
2. **Header-Footer Delimiters** - Use clear text markers around actual output
3. **Dual Channel Approach** - Enhanced stderr + stdout indicators
4. **Status Code Extension** - Modify exit codes to signal capture status
5. **Environment Variable Bridge** - Set capture status in environment variables

## Risk Assessment

### High Risk
- Complex parsing requirements that break cross-platform compatibility
- Solutions requiring Claude training/behavior changes
- Multi-step communication protocols

### Low Risk  
- Simple, deterministic output formats
- Self-contained capture indicators
- Backward-compatible implementations

The solution must prioritize **deterministic communication** over clever inference. Claude should never need to "guess" whether output was captured - it should be explicitly and unambiguously communicated through the established interface contract.