# Expert 001: Opening Statement
## System Boundaries and Inter-Process Communication Analysis

### Executive Summary

From a system boundaries and inter-process communication perspective, the PostToolUse hook represents a paradigm shift from **push-based notification** to **structured data persistence**. The current PreToolUse approach suffers from communication boundary violations—it relies on stderr message parsing across process boundaries, creating an unreliable information channel with ~10% failure rate.

### Core Technical Assessment

**Current Architecture Violations:**
1. **Boundary Crossing Anti-Pattern**: Information flows from PreToolUse (injection) → Bash execution → stderr parsing → Claude memory, crossing multiple process boundaries with lossy communication
2. **Temporal Coupling**: Claude must parse stderr messages *during* execution, creating timing dependencies
3. **State Inconsistency**: No persistent registry means capture information dies with process termination

**PostToolUse Opportunities:**
The PostToolUse hook receives structured JSON with complete tool response, enabling **clean separation of concerns**:
- **Injection Phase** (PreToolUse): Pure command modification
- **Registration Phase** (PostToolUse): Structured data persistence
- **Discovery Phase** (Claude): Query-based retrieval

### Optimal Strategy Recommendation

**1. Capture Registry Architecture**
Implement a persistent capture registry with clear API boundaries:

```bash
# PostToolUse hook workflow
REGISTRY_FILE="/tmp/.claude-captures.json"
{
  "session_id": "abc123",
  "captures": [
    {
      "capture_id": "claude-1234567890.log",
      "command_hash": "sha256...",
      "timestamp": "2024-01-15T10:30:00Z",
      "file_path": "/tmp/claude-1234567890.log",
      "file_size": 1024,
      "status": "complete"
    }
  ]
}
```

**2. Environment-Based Discovery Mechanism**
Set structured environment variables that Claude can access:
```bash
export CLAUDE_AUTO_TEE_LAST_CAPTURE="/tmp/claude-1234567890.log"
export CLAUDE_AUTO_TEE_CAPTURE_COUNT="3"
export CLAUDE_AUTO_TEE_CAPTURE_REGISTRY="/tmp/.claude-captures.json"
```

**3. Clear Communication Protocol**
- PostToolUse hook processes tool_response.stderr to extract capture file paths
- Validates capture file exists and is readable
- Updates persistent registry with structured metadata
- Sets environment variables for immediate discoverability
- Claude queries environment first, falls back to registry for history

### System Boundary Benefits

**Process Isolation**: Each component operates within clean boundaries:
- PreToolUse: Command injection (stateless)
- Bash execution: Command processing (isolated)
- PostToolUse: Data registration (persistent)
- Claude: Query and retrieval (consumer)

**Failure Isolation**: Registry persistence ensures capture information survives:
- Process termination
- Session boundaries
- Tool invocation failures
- Network interruptions

**Scalability**: Registry-based approach handles:
- Concurrent captures from parallel commands
- Cross-session discovery
- Historical capture queries
- Multiple Claude instances

### Implementation Priorities

**Phase 1: Core Registry**
1. PostToolUse hook extracts capture paths from stderr
2. Maintains JSON registry with file metadata
3. Sets environment variables for immediate access

**Phase 2: Enhanced Discovery**
1. Claude checks environment variables first
2. Falls back to registry query for historical data
3. Automatic cleanup of stale entries

**Phase 3: Advanced Features**
1. Cross-session persistence
2. Capture indexing and search
3. Distributed registry for multi-instance scenarios

### Proposed Voting Options

1. **Registry + Environment Variables** (Recommended): Structured persistence with immediate environment-based discovery
2. **Environment Variables Only**: Lightweight approach using only env vars
3. **File-based Markers**: Simple file creation for each capture
4. **Hybrid Notification**: Combine stdout messages with registry persistence
5. **Status Quo Enhancement**: Improve current stderr parsing reliability

### Risk Assessment

**High Risk**: Continuing with stderr parsing creates persistent reliability issues
**Medium Risk**: Pure environment variable approach may have session boundary issues  
**Low Risk**: Structured registry with environment fallback provides robust communication channels

The system boundaries analysis strongly favors structured data persistence over message passing for this use case, as capture information represents state rather than events.