# Claude Auto-Tee Marker Format Specification

## Overview

The Claude Auto-Tee system uses structured markers in stderr to improve capture detection accuracy. These markers are injected by the PreToolUse hook and parsed by the PostToolUse hook to provide reliable identification of captured output files.

## Marker Format

### Basic Format

**Start Marker:**
```
###CLAUDE-CAPTURE-START### <PATH> ###CLAUDE-CAPTURE-END###
```

**End Marker:**
```
###CLAUDE-CAPTURE-END### <PATH> ###CLAUDE-CAPTURE-START###
```

### Components

1. **Start Delimiter**: `###CLAUDE-CAPTURE-START###`
2. **Separator**: Single space character (` `)  
3. **Path**: Full absolute path to the capture file
4. **End Delimiter**: `###CLAUDE-CAPTURE-END###` (for start markers) or `###CLAUDE-CAPTURE-START###` (for end markers)

### Examples

```bash
# Start marker example
###CLAUDE-CAPTURE-START### /tmp/claude-1609459200000.log ###CLAUDE-CAPTURE-END###

# End marker example  
###CLAUDE-CAPTURE-END### /tmp/claude-1609459200000.log ###CLAUDE-CAPTURE-START###
```

## Design Principles

### 1. Unique Delimiters
- Uses triple hash marks (`###`) to ensure uniqueness
- Combines with `CLAUDE-CAPTURE` prefix to avoid conflicts with normal output
- Chosen to be highly unlikely to appear in regular command output

### 2. Structured Format
- Fixed format enables reliable regex-based parsing
- Symmetric start/end markers for validation
- Single space separators for consistent parsing

### 3. Path Handling
- Supports absolute paths with full directory structure
- Handles special characters in filenames
- Unicode filename support across platforms
- Normalized paths for cross-platform consistency

### 4. Concurrent Safety
- Process ID and timestamp enrichment for concurrent execution
- Background injection to avoid blocking command execution
- Atomic marker operations

## Implementation Details

### Marker Injection

Markers are injected to stderr using background processes:

```bash
# Non-blocking injection
echo "$marker" >&2 &
```

### Concurrent Execution Support

For concurrent safety, paths can be enriched with process information:

```bash
# Enriched format: path#processid#timestamp
/tmp/file.log#12345#1609459200000000000
```

The cleaning function removes the enrichment:

```bash
# Clean back to original path
/tmp/file.log
```

### Environment Controls

- `CLAUDE_AUTO_TEE_ENABLE_MARKERS` - Enable/disable markers (default: true)
- `CLAUDE_AUTO_TEE_VERBOSE` - Enable verbose logging (default: false)

## Parsing Algorithm

### Regular Expressions

**Start Marker Pattern:**
```regex
###CLAUDE-CAPTURE-START### ([^ ]+) ###CLAUDE-CAPTURE-END###
```

**End Marker Pattern:**
```regex
###CLAUDE-CAPTURE-END### ([^ ]+) ###CLAUDE-CAPTURE-START###
```

**Combined Pattern:**
```regex
###CLAUDE-CAPTURE-(START|END)### ([^ ]+) ###CLAUDE-CAPTURE-(END|START)###
```

### Path Extraction

```bash
# Extract path from start marker
echo "$marker" | sed -E 's/^###CLAUDE-CAPTURE-START### (.+) ###CLAUDE-CAPTURE-END###$/\1/'

# Extract path from end marker  
echo "$marker" | sed -E 's/^###CLAUDE-CAPTURE-END### (.+) ###CLAUDE-CAPTURE-START###$/\1/'
```

## Edge Cases

### 1. Special Characters in Paths
- Handles spaces, Unicode characters, and special symbols
- Path normalization ensures consistent format
- Proper escaping for shell safety

### 2. Multiple Captures
- Each capture gets unique markers
- Process ID and timestamp prevent conflicts
- Sequential processing maintains order

### 3. Nested Commands
- Markers work with complex shell pipelines
- Background injection avoids command interference
- Stderr isolation prevents contamination

### 4. Error Conditions
- Invalid paths are handled gracefully
- Missing markers don't break parsing
- Fallback to traditional parsing methods

## Validation

### Format Validation

```bash
# Check start marker format
if echo "$marker" | grep -qE "^###CLAUDE-CAPTURE-START### .+ ###CLAUDE-CAPTURE-END###$"; then
    echo "Valid start marker"
fi

# Check end marker format
if echo "$marker" | grep -qE "^###CLAUDE-CAPTURE-END### .+ ###CLAUDE-CAPTURE-START###$"; then
    echo "Valid end marker"
fi
```

### Path Extraction Validation

```bash
# Validate extracted path exists and is readable
extracted_path=$(parse_path_from_marker "$marker")
if [[ -r "$extracted_path" ]]; then
    echo "Valid capture file: $extracted_path"
fi
```

## Integration Points

### PreToolUse Hook Integration
- Called before command execution
- Injects start marker when temp file is created
- Optional end marker after command completion

### PostToolUse Hook Integration
- Scans stderr for markers during parsing
- Falls back to traditional parsing if no markers found
- Combines marker data with heuristic detection

## Testing

The marker system includes comprehensive tests:

```bash
# Run all marker tests
bash test/markers/test-markers.sh

# Run specific test category
bash test/markers/test-markers.sh single unicode
```

### Test Coverage
- Basic marker format validation
- Path extraction and parsing
- Unicode filename support  
- Concurrent execution safety
- Edge case handling
- Integration with realistic paths

## Performance Considerations

### Injection Performance
- Background processes prevent command blocking
- Minimal overhead (~1ms per marker)
- No impact on command execution time

### Parsing Performance
- Regex-based parsing is efficient
- Falls back to heuristics if needed
- Scales linearly with stderr size

## Future Enhancements

### Potential Improvements
1. **Compressed Markers** - For very long paths
2. **Metadata Inclusion** - Command info, timing data
3. **Checksum Validation** - Ensure marker integrity
4. **Binary Markers** - For non-text-safe environments

### Backward Compatibility
- Markers are additive enhancement
- Traditional parsing always available as fallback
- Environment variables provide full control

## Error Handling

### Graceful Degradation
- Missing markers don't break functionality
- Invalid markers are logged and ignored
- System falls back to heuristic parsing

### Debugging Support
- Verbose mode provides detailed logging
- Test utilities validate marker operation
- Clear error messages for troubleshooting

## Security Considerations

### Path Injection Prevention
- Path validation prevents injection attacks
- No shell execution of marker content
- Proper quoting and escaping throughout

### Information Disclosure
- Markers only contain file paths
- No sensitive command information exposed
- Standard file system permissions apply