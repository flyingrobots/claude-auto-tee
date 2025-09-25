# Context Block Format Specification

## Overview

The Context Block Format defines how the PostToolUse hook presents captured command output to Claude. This format is designed to be immediately scannable by both humans and AI, providing essential metadata about captured files in a visually distinctive way.

## Design Principles

### 1. Visual Distinctiveness
- **Clear boundaries**: Uses Unicode box drawing characters for clean separation
- **Non-interfering**: Stands out from normal command output without disruption  
- **Monospace optimized**: Formatted specifically for terminal and code editor display
- **Colorblind accessible**: Uses symbols and structure rather than color-only indicators

### 2. Information Density
- **Essential metadata**: Path, timestamp, command, file size
- **Scannable layout**: Information organized for quick visual parsing
- **Concise but complete**: All necessary context without verbosity

### 3. Machine Readability
- **Structured format**: Consistent structure for AI recognition
- **Standard delimiters**: Predictable boundaries for parsing
- **Semantic labels**: Clear field identification

## Format Variants

### Minimal Format

For single captures or when space is limited:

```
┌─ OUTPUT CAPTURED ─────────────────────────────────────────┐
│ 📝 /tmp/capture_20250113_142305.txt                      │
│ ⏰ 2025-01-13 14:23:05  📏 45.2 KB  🖥️  npm test         │
└───────────────────────────────────────────────────────────┘
```

### Verbose Format  

For detailed information or multiple captures:

```
┌─ OUTPUT CAPTURED ─────────────────────────────────────────┐
│ Path:     /tmp/capture_20250113_142305.txt                │
│ Command:  npm test                                        │
│ Time:     2025-01-13 14:23:05                             │
│ Size:     45.2 KB (46,284 bytes)                         │
│ Duration: 2.3s                                            │
└───────────────────────────────────────────────────────────┘
```

### Multi-Capture Format

When multiple outputs are captured in a single session:

```
┌─ OUTPUT CAPTURED (3 files) ───────────────────────────────┐
│ 📝 /tmp/build_20250113_142305.txt                        │
│    🖥️  npm run build  ⏰ 14:23:05  📏 128.4 KB           │
│                                                           │
│ 📝 /tmp/test_20250113_142318.txt                         │
│    🖥️  npm test       ⏰ 14:23:18  📏 45.2 KB            │
│                                                           │
│ 📝 /tmp/lint_20250113_142325.txt                         │
│    🖥️  npm run lint   ⏰ 14:23:25  📏 12.1 KB            │
└───────────────────────────────────────────────────────────┘
```

## ASCII Fallback Format

For environments without Unicode support:

```
+-- OUTPUT CAPTURED -------------------------------------------+
| File: /tmp/capture_20250113_142305.txt                      |
| Cmd:  npm test                                              |
| Time: 2025-01-13 14:23:05         Size: 45.2 KB           |
+-------------------------------------------------------------+
```

## Format Elements

### Box Drawing Characters

**Unicode (Preferred):**
- Top border: `┌─` `─` `─┐`
- Side borders: `│`
- Bottom border: `└─` `─` `─┘`
- Content separator: `│`

**ASCII Fallback:**
- Top border: `+--` `-` `--+`
- Side borders: `|`  
- Bottom border: `+--` `-` `--+`
- Content separator: `|`

### Icons and Indicators

- **📝** File/Output indicator
- **⏰** Timestamp indicator  
- **📏** File size indicator
- **🖥️** Command indicator
- **⚠️** Warning/Error indicator (when applicable)

### Field Specifications

#### Path Display
- **Full path**: Always show complete absolute path
- **Unicode safe**: Properly handle Unicode characters in paths
- **Truncation**: Truncate long paths with `...` in middle if needed
- **Max width**: Respect terminal width constraints

#### Timestamp Format
- **ISO 8601 style**: YYYY-MM-DD HH:MM:SS format
- **Timezone**: Local timezone with clear indication
- **Precision**: Second-level precision for uniqueness

#### File Size Display
- **Human readable**: Use KB, MB, GB with decimal precision
- **Byte count**: Show exact bytes in verbose mode
- **Zero size**: Indicate empty files clearly

#### Command Display
- **Truncated safely**: Show first N characters with `...` if needed
- **Shell quoted**: Display as it would appear in shell
- **Security conscious**: Don't expose sensitive arguments

## Implementation Guidelines

### Width Management

```javascript
// Dynamic width calculation
const terminalWidth = process.stdout.columns || 80;
const maxContentWidth = Math.min(terminalWidth - 4, 120); // Leave margin
const borderWidth = Math.min(maxContentWidth, 63); // Minimum readable width
```

### Unicode Detection

```javascript
// Check for Unicode support
const supportsUnicode = process.env.TERM !== 'dumb' && 
                       process.stdout.isTTY && 
                       !process.env.CLAUDE_AUTO_TEE_ASCII_ONLY;

const boxChars = supportsUnicode ? 
  { topLeft: '┌', horizontal: '─', topRight: '┐', vertical: '│', bottomLeft: '└', bottomRight: '┘' } :
  { topLeft: '+', horizontal: '-', topRight: '+', vertical: '|', bottomLeft: '+', bottomRight: '+' };
```

### Path Truncation Strategy

```javascript
// Intelligent path truncation
function truncatePath(path, maxWidth) {
  if (path.length <= maxWidth) return path;
  
  const fileName = basename(path);
  const dirPath = dirname(path);
  
  if (fileName.length > maxWidth - 3) {
    return '...' + fileName.slice(-(maxWidth - 3));
  }
  
  const availableForDir = maxWidth - fileName.length - 4; // 4 for ".../"
  if (dirPath.length > availableForDir) {
    return '...' + dirPath.slice(-(availableForDir)) + '/' + fileName;
  }
  
  return path;
}
```

## Context Generation Examples

### Single Command Success

```
┌─ OUTPUT CAPTURED ─────────────────────────────────────────┐
│ 📝 /Users/dev/.claude/captures/git_status_20250113.txt   │
│ ⏰ 2025-01-13 14:23:05  📏 1.2 KB  🖥️  git status       │
└───────────────────────────────────────────────────────────┘

The output above contains the current git repository status.
You can analyze it to understand what files have been modified.
```

### Build Command with Warnings

```
┌─ OUTPUT CAPTURED ─────────────────────────────────────────┐
│ ⚠️  /tmp/build_20250113_142305.txt                       │
│ 🖥️  npm run build:prod                                   │
│ ⏰ 2025-01-13 14:23:05  📏 156.7 KB  ⚠️  Exit code: 1   │
└───────────────────────────────────────────────────────────┘

The build process completed with warnings. Check the captured
output for compilation errors and optimization suggestions.
```

### Test Results

```
┌─ OUTPUT CAPTURED ─────────────────────────────────────────┐
│ 📝 /tmp/jest_results_20250113_142318.txt                 │
│ 🖥️  npm test -- --coverage                              │
│ ⏰ 2025-01-13 14:23:18  📏 45.2 KB  ✅ All tests passed  │
└───────────────────────────────────────────────────────────┘

Complete test results with coverage report are available above.
All 127 tests passed successfully.
```

## Environment Integration

### Environment Variables

- `CLAUDE_AUTO_TEE_FORMAT`: Control format variant (`minimal`, `verbose`, `multi`)
- `CLAUDE_AUTO_TEE_ASCII_ONLY`: Force ASCII-only output
- `CLAUDE_AUTO_TEE_MAX_WIDTH`: Override maximum content width
- `CLAUDE_AUTO_TEE_TIMEZONE`: Override timezone display

### Terminal Detection

```javascript
// Adaptive formatting based on terminal capabilities
const formatPreference = process.env.CLAUDE_AUTO_TEE_FORMAT || 
  (process.stdout.columns > 100 ? 'verbose' : 'minimal');

const useUnicode = !process.env.CLAUDE_AUTO_TEE_ASCII_ONLY && 
  process.stdout.isTTY && 
  (process.env.TERM !== 'dumb');
```

## Accessibility Considerations

### Visual Accessibility
- **High contrast**: Strong visual boundaries without relying on color
- **Symbol redundancy**: Icons paired with text labels
- **Consistent spacing**: Predictable layout for screen readers

### Cognitive Accessibility  
- **Logical order**: Information flows top to bottom, left to right
- **Clear hierarchy**: Essential information (path) prominently displayed
- **Predictable format**: Consistent structure across all contexts

### Assistive Technology
- **Screen reader friendly**: Structured content with semantic meaning
- **Text-only fallback**: ASCII format for text-only environments
- **Keyboard navigation**: No interactive elements that require mouse

## Performance Considerations

### Generation Speed
- **Template caching**: Pre-compile format templates
- **Lazy evaluation**: Only generate format when actually displayed
- **Minimal computation**: Avoid expensive operations during formatting

### Memory Usage
- **String pooling**: Reuse common format strings
- **Stream generation**: Generate large contexts incrementally
- **Size limits**: Cap maximum context size to prevent memory issues

## Security Considerations

### Path Disclosure
- **Sensitive path filtering**: Option to mask user directories
- **Relative path option**: Convert to relative paths when appropriate
- **Sanitization**: Remove potentially sensitive path components

### Command Exposure
- **Argument filtering**: Hide sensitive command line arguments
- **Credential scrubbing**: Remove passwords, tokens, keys from command display
- **Safe truncation**: Ensure truncation doesn't expose sensitive data

## Integration Points

### Registry Integration
```javascript
// Context generation using registry data
function generateContext(captureEntry) {
  return {
    path: captureEntry.path,
    command: captureEntry.command,
    timestamp: captureEntry.timestamp,
    size: captureEntry.size,
    exitCode: captureEntry.exitCode,
    duration: captureEntry.duration
  };
}
```

### Hook Integration
```javascript  
// PostToolUse hook integration
module.exports = function postToolUseHook(toolResponse) {
  const captures = extractCaptures(toolResponse);
  if (captures.length > 0) {
    const context = generateContextBlock(captures);
    console.log(context);
  }
};
```

### Environment Variable Export
```javascript
// Set environment variables for captured files
process.env.CLAUDE_LAST_CAPTURE = mostRecentCapture.path;
process.env.CLAUDE_CAPTURES = allCaptures.map(c => c.path).join(':');
```

## Rationale for Design Decisions

### Unicode Box Drawing
- **Visual clarity**: Creates clear boundaries without visual noise
- **Professional appearance**: Clean, structured look appropriate for development tools
- **Terminal native**: Widely supported in modern terminals
- **ASCII fallback**: Graceful degradation for limited environments

### Icon Usage
- **Quick scanning**: Emoji icons allow rapid visual identification
- **Universal symbols**: Recognizable across cultures and languages  
- **Semantic meaning**: Icons reinforce textual information
- **Optional display**: Can be disabled in text-only environments

### Information Hierarchy
- **Path first**: Most important information gets prime position
- **Metadata secondary**: Supporting information arranged logically
- **Command context**: Essential for understanding what generated output
- **Size indicator**: Helps gauge content volume at a glance

### Flexible Formatting
- **Context appropriate**: Different formats for different use cases
- **Terminal aware**: Adapts to available screen space
- **Preference driven**: User can control verbosity level
- **Fallback ready**: Works in constrained environments

## Future Enhancements

### Planned Features
- **Color support**: Optional ANSI color codes for enhanced visibility
- **Interactive elements**: Clickable paths in supported terminals  
- **Metadata expansion**: Additional fields like file type, encoding
- **Custom templates**: User-defined format templates

### Extensibility
- **Plugin architecture**: Allow custom format generators
- **Theme support**: Predefined visual themes
- **Internationalization**: Localized text and date formats
- **Context awareness**: Different formats for different tool types

## Testing Strategy

### Format Validation
```javascript
// Test format consistency
describe('Context Format', () => {
  test('minimal format has consistent width', () => {
    const context = generateMinimalContext(testCapture);
    const lines = context.split('\n');
    const widths = lines.map(line => stripAnsi(line).length);
    expect(Math.max(...widths) - Math.min(...widths)).toBeLessThanOrEqual(1);
  });
});
```

### Cross-Platform Testing
- **Terminal emulators**: Test across different terminal applications
- **OS differences**: Validate on Windows, macOS, Linux
- **Unicode support**: Test with various locale settings
- **Screen readers**: Validate accessibility with assistive technology

### Performance Testing
```javascript
// Benchmark format generation
const Benchmark = require('benchmark');
const suite = new Benchmark.Suite();

suite.add('minimal format generation', () => {
  generateMinimalContext(testCapture);
}).add('verbose format generation', () => {
  generateVerboseContext(testCapture);
}).run();
```

This specification provides the foundation for the BasicContextFormat:v1 interface, ensuring captured output is presented in a clear, accessible, and immediately recognizable way that enhances Claude's ability to understand and work with captured command output.