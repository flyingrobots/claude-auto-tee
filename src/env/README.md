# Environment Exporter (P1.T004)

The Environment Exporter module provides the `EnvExporter:v1` interface for setting `CLAUDE_LAST_CAPTURE` and `CLAUDE_CAPTURES` environment variables in the PostToolUse hook implementation.

## Files

- **`environment-exporter.js`** - Main EnvExporter class implementation
- **`../test/env/environment-exporter.test.js`** - Comprehensive test suite (30 tests)
- **`../test/env/acceptance-test.sh`** - Acceptance test verifying `test -n "$CLAUDE_LAST_CAPTURE"` succeeds
- **`../test/env/demo.js`** - Interactive demonstration of all features

## Features Implemented

### ✅ Core Functionality
- **CLAUDE_LAST_CAPTURE**: Sets path to most recent capture file
- **CLAUDE_CAPTURES**: Sets JSON array of recent captures (limited to last 10 entries)
- **History Management**: Automatic cleanup and size limiting
- **Metadata Support**: Timestamps, file sizes, and custom metadata

### ✅ Shell Compatibility
- **Bash/Zsh/Sh**: Uses `export VAR="value"` syntax
- **Fish Shell**: Uses `set -gx VAR value` syntax
- **Auto-detection**: Supports shell type detection and validation

### ✅ Security & Safety
- **Path Escaping**: Proper quoting for special characters (`"`, `$`, `` ` ``, `!`, etc.)
- **JSON Escaping**: Safe encoding of JSON data for shell variables
- **Input Validation**: Comprehensive error handling and type checking
- **Shell Injection Prevention**: All paths and data properly escaped

### ✅ Atomic Operations
- **Race Condition Prevention**: Optional atomic updates to history
- **Data Consistency**: Immutable operations when atomicity is enabled
- **Thread Safety**: Safe for concurrent access patterns

### ✅ Edge Case Handling
- **Unicode Paths**: Full support for international characters
- **Special Characters**: Handles spaces, quotes, dollar signs, etc.
- **Long Paths**: No arbitrary length limits
- **Non-existent Files**: Graceful handling with test mode support

## Usage

```javascript
const { EnvExporter } = require('./src/env/environment-exporter.js');

// Create exporter instance
const exporter = new EnvExporter({
    maxCapturesHistory: 10,        // Keep last 10 captures
    enableAtomicOperations: true,  // Prevent race conditions
    verbose: false                 // Enable debug logging
});

// Add a capture
exporter.addCapture('/path/to/capture.log', {
    toolName: 'Bash',
    command: 'npm run build | tee /path/to/capture.log'
});

// Generate export commands
const exports = exporter.generateAllExports('bash');
console.log(exports.lastCapture);  // export CLAUDE_LAST_CAPTURE="/path/to/capture.log"
console.log(exports.captures);     // export CLAUDE_CAPTURES="[{...}]"

// Generate complete shell script
const script = exporter.generateExportScript('bash');
```

## Error Handling

The module defines custom error types for robust error handling:

- **`EnvironmentExportError`** - Base error class
- **`ShellCompatibilityError`** - Shell type validation errors
- **`PathEscapingError`** - Path processing errors

## Testing

Run the test suite:
```bash
npm run test:env              # Full test suite (30 tests)
npm run test:env-acceptance   # Acceptance test
npm run test:env-demo         # Interactive demo
```

## Shell Support Matrix

| Shell | Export Syntax | Unset Syntax | Status |
|-------|---------------|--------------|--------|
| bash  | `export VAR="value"` | `unset VAR` | ✅ Full |
| zsh   | `export VAR="value"` | `unset VAR` | ✅ Full |
| sh    | `export VAR="value"` | `unset VAR` | ✅ Full |
| fish  | `set -gx VAR 'value'` | `set -e VAR` | ✅ Full |

## Integration with PostToolUse Hook

The EnvExporter is designed to integrate seamlessly with the PostToolUse hook:

1. **Tool Completion**: When a Bash tool completes with tee output
2. **Capture Addition**: Add the capture file path to the exporter
3. **Export Generation**: Generate shell-appropriate export commands
4. **Environment Setting**: Execute exports to make variables available

The acceptance criteria `test -n "$CLAUDE_LAST_CAPTURE"` succeeds after proper integration.