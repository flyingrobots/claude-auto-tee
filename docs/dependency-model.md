# Dependency Model Documentation

## Overview

The Command Dependency Schema provides a comprehensive data model for tracking relationships between command executions in the PostToolUse hook system. This schema enables intelligent capture lifecycle management through dependency tracking, invalidation rules, and freshness scoring.

## Schema Version

**Current Version**: 1.0.0

**Schema Location**: `/schemas/dependency.json`

## Core Concepts

### 1. Command Genealogy

Commands form a hierarchical tree structure through parent-child relationships:

- **Root Commands**: Commands spawned directly by user actions (`parentId: null`)
- **Child Commands**: Commands spawned by other commands (`parentId: "cmd-xxxxx"`)
- **Session Grouping**: Related commands share a `sessionId` for logical grouping

### 2. Dependency Types

The schema supports six types of command relationships:

| Type | Description | Strength | Use Case |
|------|-------------|----------|----------|
| `sequential` | Commands must run in order | 1.0 (hard) | build → test |
| `parallel` | Commands can run concurrently | 0.8 (medium) | parallel test suites |
| `conditional` | Dependency based on conditions | 0.7 (variable) | deploy only if tests pass |
| `input_output` | File-based dependencies | 0.6-0.9 | output of A feeds input of B |
| `invalidation` | Invalidation triggers | 1.0 (hard) | git pull invalidates old builds |
| `parent_child` | Genealogical relationship | 0.8 (medium) | command spawning |

### 3. Temporal Relationships

Commands are ordered by:

- **Timestamp**: Execution start time (`ISO 8601`)
- **Duration**: Execution time in milliseconds
- **Topological Order**: Dependency-aware ordering for cascade operations

### 4. File Dependencies

Each command tracks involved files with metadata:

```json
{
  "path": "/path/to/file",
  "hash": "sha256-hash",
  "size": 1024,
  "mtime": "2025-01-13T10:00:00Z",
  "type": "input|output|dependency"
}
```

File types:
- **input**: Files read by the command
- **output**: Files created/modified by the command  
- **dependency**: Files that affect command validity

### 5. Invalidation System

#### Invalidation Triggers

- `file_modified`: File system changes
- `dependency_changed`: Upstream command changes
- `time_elapsed`: Age-based expiration
- `command_failed`: Failure cascade
- `manual`: Explicit user invalidation

#### Invalidation Actions

- `invalidate`: Mark command as stale
- `recompute`: Schedule for re-execution
- `cascade`: Propagate to dependent commands

## Schema Structure

### Root Object

```json
{
  "schemaVersion": "1.0.0",
  "metadata": { /* versioning info */ },
  "commands": { /* command map */ },
  "dependencies": [ /* dependency edges */ ],
  "globalInvalidationRules": [ /* system rules */ ],
  "indices": { /* performance indices */ }
}
```

### Command Object

```json
{
  "id": "cmd-uuid",
  "parentId": "cmd-parent-uuid|null",
  "sessionId": "session-identifier",
  "timestamp": "2025-01-13T10:00:00Z",
  "metadata": {
    "tool": "Bash|Edit|Read|etc",
    "command": "actual command string",
    "workingDirectory": "/path",
    "exitCode": 0,
    "duration": 5000,
    "captureSize": 2048
  },
  "files": [ /* file metadata array */ ],
  "capturePath": "/tmp/output.log",
  "status": "completed|failed|invalidated|pending|running",
  "freshnessScore": 0.95,
  "invalidationRules": [ /* command-specific rules */ ]
}
```

### Dependency Edge

```json
{
  "from": "cmd-source-uuid",
  "to": "cmd-target-uuid", 
  "type": "sequential|parallel|conditional|input_output|invalidation|parent_child",
  "strength": 0.8,
  "metadata": {
    "reason": "human readable explanation",
    "files": ["/shared/files"],
    "conditional": false
  }
}
```

## Graph Operations

### Traversal Algorithms

#### Forward Traversal (Dependencies)
Find all commands that depend on a given command:

```javascript
function findDependents(commandId, graph) {
  return graph.dependencies
    .filter(edge => edge.from === commandId)
    .map(edge => edge.to);
}
```

#### Backward Traversal (Prerequisites) 
Find all commands that a given command depends on:

```javascript
function findPrerequisites(commandId, graph) {
  return graph.dependencies
    .filter(edge => edge.to === commandId)
    .map(edge => edge.from);
}
```

#### Topological Sort
Commands ordered by dependency relationships:

```javascript
function topologicalSort(graph) {
  // Implementation uses Kahn's algorithm
  // Result stored in graph.indices.topological
}
```

### Cascade Detection

When a command is invalidated, determine which commands need to be invalidated or recomputed:

```javascript
function cascadeInvalidation(commandId, graph) {
  const visited = new Set();
  const toInvalidate = [];
  
  function dfs(nodeId, strength) {
    if (visited.has(nodeId)) return;
    visited.add(nodeId);
    
    const dependents = graph.dependencies
      .filter(edge => edge.from === nodeId && edge.strength >= strength)
      .map(edge => edge.to);
    
    dependents.forEach(dependent => {
      toInvalidate.push(dependent);
      dfs(dependent, strength * 0.8); // Decay strength
    });
  }
  
  dfs(commandId, 1.0);
  return toInvalidate;
}
```

## Freshness Scoring

Commands receive freshness scores (0.0 = stale, 1.0 = fresh) based on:

### Age Factor
```javascript
const ageFactor = Math.exp(-age / maxAge);
```

### Dependency Factor
```javascript
const depFactor = Math.min(...prerequisites.map(cmd => cmd.freshnessScore));
```

### File Modification Factor
```javascript
const fileFactor = files.every(f => f.mtime <= command.timestamp) ? 1.0 : 0.0;
```

### Combined Score
```javascript
const freshnessScore = ageFactor * depFactor * fileFactor;
```

## Performance Indices

The schema includes precomputed indices for efficient operations:

### By Parent Index
```json
{
  "byParent": {
    "cmd-parent-uuid": ["cmd-child1-uuid", "cmd-child2-uuid"],
    "null": ["cmd-root1-uuid", "cmd-root2-uuid"]
  }
}
```

### By File Index
```json
{
  "byFile": {
    "/path/to/file": ["cmd1-uuid", "cmd2-uuid"]
  }
}
```

### By Session Index
```json
{
  "bySession": {
    "session-id": ["cmd1-uuid", "cmd2-uuid", "cmd3-uuid"]
  }
}
```

## Example Use Cases

### Build Pipeline
Sequential dependency: `npm install` → `npm build` → `npm test`

**Key Features**:
- Hard dependencies (strength = 1.0)
- File-based invalidation (package.json changes)
- Output validation (dist/ folder creation)

### Parallel Testing
Multiple test suites running concurrently after shared setup

**Key Features**:
- Shared prerequisite (test setup)
- Parallel execution (sibling relationships)
- Aggregate results (coverage merge)

### Invalidation Cascade
Git pull triggers invalidation of dependent builds and tests

**Key Features**:
- Invalidation triggers (file modifications)
- Cascade propagation (strength-based)
- Freshness recalculation

### Multi-Session Workflow
Database migration → API testing → Docker deployment → Performance testing

**Key Features**:
- Cross-session dependencies
- Conditional relationships (deploy only if tests pass)
- Time-based invalidation (performance tests expire)

## Implementation Guidelines

### Command ID Generation
```javascript
const commandId = `cmd-${uuidv4()}`;
```

### File Hash Computation
```javascript
const hash = crypto.createHash('sha256')
  .update(fileContent)
  .digest('hex');
```

### Atomic Updates
Use optimistic concurrency control with version numbers:

```javascript
function updateGraph(graph, changes) {
  const currentVersion = graph.metadata.version;
  const newGraph = applyChanges(graph, changes);
  newGraph.metadata.version = currentVersion + 1;
  newGraph.metadata.updatedAt = new Date().toISOString();
  return newGraph;
}
```

### Error Handling
- Graceful degradation for missing dependencies
- Validation of command IDs and file paths
- Recovery from corrupted graph state

## Future Enhancements

### Planned Features (Phase 3+)

1. **Semantic Analysis**: Extract meaningful information from command outputs
2. **ML-based Freshness**: Machine learning for better freshness scoring
3. **Distributed Dependencies**: Support for multi-machine workflows  
4. **Visual Graph Editor**: GUI for dependency visualization
5. **Performance Profiling**: Command execution performance tracking

### Extensibility Points

- Custom invalidation triggers
- Plugin-based dependency types
- External file watchers integration
- Cloud storage for graph persistence

## Validation Rules

### Schema Validation
- All command IDs must be valid UUIDs with `cmd-` prefix
- Dependency edges must reference existing commands
- File paths should be normalized and validated
- Timestamps must be valid ISO 8601 format

### Logical Validation
- No circular dependencies in graph
- Dependency strengths between 0.0 and 1.0
- Parent-child relationships form valid trees
- File hashes match actual file contents

### Performance Constraints
- Maximum graph size: 10,000 commands
- Maximum dependency depth: 50 levels
- Index update frequency: every 100 operations
- Freshness score recalculation: every 5 minutes

## Integration Points

### PostToolUse Hook
The dependency graph integrates with the PostToolUse hook to:

1. **Capture Command Execution**: Record new commands and their metadata
2. **Track File Dependencies**: Monitor input/output file changes
3. **Update Relationships**: Maintain dependency edges automatically
4. **Trigger Invalidation**: Apply invalidation rules in real-time
5. **Provide Context**: Generate intelligent context for next commands

### Example Integration Flow

```javascript
async function onPostToolUse(toolResult) {
  // 1. Parse command from tool result
  const command = parseCommand(toolResult);
  
  // 2. Extract file dependencies
  const files = extractFiles(toolResult);
  
  // 3. Determine parent command
  const parentId = getCurrentCommandId();
  
  // 4. Create command record
  const commandRecord = {
    id: generateCommandId(),
    parentId,
    sessionId: getCurrentSessionId(),
    timestamp: new Date().toISOString(),
    metadata: extractMetadata(toolResult),
    files,
    status: 'completed'
  };
  
  // 5. Update dependency graph
  await updateDependencyGraph(commandRecord);
  
  // 6. Calculate freshness scores
  await recalculateFreshness();
  
  // 7. Check invalidation rules
  await applyInvalidationRules(commandRecord);
  
  // 8. Generate context for next command
  return generateContext(commandRecord);
}
```

This dependency schema provides the foundation for intelligent capture lifecycle management, enabling the PostToolUse hook to make informed decisions about command relationships, invalidation cascades, and context generation.