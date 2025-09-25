# Expert 003 Opening Statement: LLM Integration Patterns and AI System Behavior

## Executive Summary

The core issue is Claude's inconsistent awareness of captured output, despite clear stderr notifications. This stems from fundamental LLM attention and context processing patterns. The solution requires leveraging Claude's natural parsing behaviors and structured output preferences.

## Problem Analysis from LLM Perspective

### Attention and Parsing Patterns
- LLMs exhibit stronger attention to structured, predictable output formats
- stderr messages can be overlooked when mixed with verbose stdout
- Claude specifically responds well to structured metadata and explicit file references
- Tool output parsing prioritizes consistent formatting over ad-hoc notifications

### Current Failure Modes
1. **Context Dilution**: Important capture notifications lost in command output noise
2. **Inconsistent Parsing**: stderr messages compete with stdout for attention
3. **No Structured Metadata**: Lack of machine-readable capture indicators

## Proposed Solution: Multi-Channel Notification Strategy

### Primary: Structured Tool Metadata
```bash
# Tool should inject structured metadata into bash output
echo "CLAUDE_AUTO_TEE_CAPTURE_METADATA: {\"captured\": true, \"file\": \"/tmp/claude-xyz.log\", \"original_command\": \"$cmd\"}" >&2
```

### Secondary: Consistent Formatting Pattern
```bash
# Highly visible, consistent format that LLMs reliably parse
echo "═══ FULL OUTPUT CAPTURED TO: /tmp/claude-xyz.log ═══" >&2
echo "═══ Use 'cat /tmp/claude-xyz.log' to view complete output ═══" >&2
```

### Tertiary: Exit Code Signaling
- Use specific exit codes (e.g., 201-210 range) to indicate capture status
- Allows programmatic detection without parsing text output

## Implementation Strategy

### Phase 1: Enhanced Stderr Formatting
- Implement highly visible, consistent formatting
- Use visual separators that LLMs consistently recognize
- Include explicit retrieval instructions

### Phase 2: Metadata Injection
- Add structured JSON metadata to stderr
- Include capture status, file path, and original command
- Format for easy programmatic parsing

### Phase 3: Context Preservation
- Store command metadata alongside captured output
- Enable reconstruction of full execution context
- Support batch retrieval of multiple captured commands

## Cross-Platform Considerations

### Universal Shell Features
- All solutions use standard stderr redirection (`>&2`)
- No platform-specific formatting or escape sequences
- Rely on basic echo and printf commands available everywhere

### File Path Handling
- Use platform-appropriate temporary directories
- Normalize path separators in metadata
- Include absolute paths for reliable access

## Voting Options Proposal

**Option A: Enhanced Stderr with Visual Separators**
- Pros: Simple, immediate implementation, high visibility
- Cons: Still relies on text parsing, no structured metadata

**Option B: Structured JSON Metadata + Visual**  
- Pros: Machine-readable, preserves human readability, most robust
- Cons: Slightly more complex implementation

**Option C: Exit Code Signaling Only**
- Pros: Programmatically reliable, minimal overhead
- Cons: Requires Claude to check exit codes consistently, less explicit

**Option D: Multi-file approach (separate metadata file)**
- Pros: Clean separation, structured data
- Cons: Additional file management, complexity

## Recommended Approach

**Hybrid Implementation (Option B + A):**
1. Structured JSON metadata for programmatic detection
2. Visual separators for human/LLM readability  
3. Explicit retrieval instructions
4. Consistent formatting across all captures

This maximizes Claude's awareness through multiple channels while maintaining simplicity and cross-platform compatibility.

## Risk Assessment

### Low Risk
- Enhanced formatting implementations
- Metadata injection via stderr
- File path standardization

### Medium Risk  
- Exit code signaling (requires consistent checking)
- Multi-file approaches (complexity increase)

### Success Metrics
- 100% Claude awareness of captured output
- Zero unnecessary command re-runs
- Maintained tool simplicity and cross-platform function

---
**Expert 003 - LLM Integration Patterns and AI System Behavior**