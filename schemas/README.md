# Claude Auto-Tee Registry Schema

This directory contains the JSON schema definition for the PostToolUse hook capture registry, along with validation examples and utilities.

## Files

- `registry.json` - The main JSON schema definition for the capture registry
- `validate-schema.js` - Node.js validation script using AJV
- `examples/valid-registry.json` - Example of a valid registry file
- `examples/invalid-registry.json` - Example demonstrating validation failures

## Schema Overview

The registry schema defines a structured format for tracking captured tool outputs with the following core structure:

```json
{
  "version": "1.0.0",
  "lastModified": "2025-01-13T15:30:45.123Z",
  "totalCaptures": 3,
  "captures": [
    {
      "path": "/path/to/capture/file.txt",
      "command": "ls -la",
      "timestamp": "2025-01-13T15:30:45.123Z",
      "size": 1024,
      "hash": "sha256hash..."
    }
  ]
}
```

## Key Features

### Core Fields (Required)
- `version` - Semantic version of registry format
- `lastModified` - ISO 8601 timestamp of last modification
- `totalCaptures` - Count of capture entries (max 10,000)
- `captures` - Array of capture records

### Capture Record Fields
- **Required**: `path`, `command`, `timestamp`, `size`, `hash`
- **Optional**: `toolName`, `toolVersion`, `exitCode`, `duration`, `workingDirectory`, `environment`, `tags`, `metadata`

### Cross-Platform Path Support
The schema supports paths for:
- Unix/Linux: `/path/to/file`
- macOS: `/Users/username/file` 
- Windows: `C:\\Users\\username\\file`
- UNC paths: `\\\\server\\share\\file`

### Validation Rules
- **Paths**: Must be absolute, max 4096 characters
- **Commands**: Non-empty strings, max 8192 characters
- **File sizes**: 0 to 1GB (1,073,741,824 bytes)
- **Hashes**: SHA-256 (64 hex characters)
- **Tags**: Alphanumeric with underscore/dash, max 50 chars
- **Environment vars**: String values only, max 100 properties

### Future Extensibility
- `additionalProperties: true` on capture records for custom fields
- Optional `stats` object for registry metrics
- Optional `config` object for behavior settings
- Extensible `metadata` field for tool-specific data

## Usage

### Validate Schema
```bash
npm run test:schema
```

### Programmatic Validation
```javascript
const ajv = new Ajv();
const schema = require('./schemas/registry.json');
const validate = ajv.compile(schema);

const isValid = validate(registryData);
if (!isValid) {
  console.log(validate.errors);
}
```

### Creating Registry Files
Registry files should be created atomically and follow the schema exactly. Use the `valid-registry.json` example as a template.

## Performance Considerations

- **Max captures**: Limited to 10,000 entries
- **File size limits**: Individual captures max 1GB
- **Array validation**: Schema validates all items in captures array
- **Hash verification**: SHA-256 hashes provide integrity checking

## Error Handling

The schema provides detailed validation errors including:
- Field path locations (e.g., `/captures/0/path`)
- Specific constraint violations
- Pattern matching failures
- Type mismatches
- Missing required fields

See `invalid-registry.json` for examples of common validation failures.