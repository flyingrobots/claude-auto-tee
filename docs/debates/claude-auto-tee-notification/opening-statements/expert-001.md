# Expert 001: Opening Statement
## Architectural Patterns for Reliable Tool-AI Communication

### Core Architectural Challenge

The fundamental issue is a **communication boundary problem** between two autonomous systems: the claude-auto-tee tool and Claude's command execution environment. We need a robust, deterministic communication channel that doesn't rely on Claude's ability to parse unstructured stderr output.

### Architectural Pattern Analysis

#### Current Anti-Pattern: Implicit State Communication
The existing approach exhibits the **"Hope and Prayer" anti-pattern** - relying on Claude to notice, parse, and remember stderr messages. This violates the **Principle of Least Surprise** and creates a fragile integration point.

#### Proposed Solution: Structured State Persistence Pattern

I propose implementing the **Structured State Persistence Pattern** with three architectural layers:

**Layer 1: State Registry**
- Create a lightweight state registry using a standardized format (JSON/YAML)
- Location: `~/.claude/auto-tee/capture-registry.json`
- Schema:
```json
{
  "captures": {
    "session_id": {
      "command_hash": {
        "file_path": "/tmp/claude-xyz.log",
        "timestamp": "2025-01-15T10:30:00Z",
        "command": "original command",
        "status": "active|expired"
      }
    }
  }
}
```

**Layer 2: Discovery Interface**
- Implement a simple discovery mechanism through environment variables
- Set `CLAUDE_AUTO_TEE_LAST_CAPTURE=/path/to/file` in the shell environment
- This provides immediate access to the most recent capture without parsing

**Layer 3: Integration Adapter**
- Create a companion utility `cat-last-capture` that reads from the registry
- Claude can reliably call this utility to retrieve captured output
- No parsing required - direct file access

### Architectural Benefits

1. **Separation of Concerns**: Tool handles capture, registry handles state, Claude handles consumption
2. **Loose Coupling**: Components communicate through well-defined interfaces
3. **Idempotent Operations**: Registry queries are side-effect free
4. **Atomic State Updates**: Registry updates are atomic and consistent
5. **Cross-Platform Compatibility**: File-based registry works universally

### Integration Strategy

The solution leverages the **Adapter Pattern** to bridge the gap between the existing hook system and Claude's needs:

```bash
# In pre-tool-use hook:
claude-auto-tee detect-pipe "$COMMAND" && {
    CAPTURE_FILE=$(claude-auto-tee execute "$COMMAND")
    export CLAUDE_AUTO_TEE_LAST_CAPTURE="$CAPTURE_FILE"
    echo "CLAUDE_AUTO_TEE_CAPTURE_AVAILABLE=true" >&2
}
```

This provides both immediate environment-based access AND a structured signal to Claude.

### Proposed Voting Options

1. **Environment Variable Pattern**: Use shell environment to communicate most recent capture
2. **Registry Pattern**: Implement structured JSON registry for all captures
3. **Hybrid Approach**: Combine environment variables for immediate access with registry for historical tracking
4. **Signal File Pattern**: Create marker files that Claude can detect and consume
5. **Status Quo Plus**: Enhance current stderr approach with structured markers

### Risk Assessment

- **Low Risk**: Environment variable approach - minimal complexity, immediate compatibility
- **Medium Risk**: Registry pattern - requires additional tooling but provides comprehensive solution
- **High Risk**: Modifying Claude Code core - architectural boundary violation

### Recommendation

I recommend **Option 3: Hybrid Approach** as it provides immediate reliability through environment variables while building toward a comprehensive registry-based solution for advanced use cases.

This maintains architectural integrity by:
- Preserving existing boundaries
- Providing clear interfaces
- Enabling incremental adoption
- Supporting both simple and complex scenarios

The architecture follows the **Single Responsibility Principle** - each component has one clear job - and enables **Open/Closed Principle** compliance by allowing extension without modification of core systems.