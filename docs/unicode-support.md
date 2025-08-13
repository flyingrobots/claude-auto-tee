# Unicode Support Documentation

## Overview

The Unicode Path Handler (`UnicodeHandler:v1`) provides comprehensive Unicode support for the claude-auto-tee PostToolUse hook implementation. This ensures that the tool works reliably with paths containing Unicode characters from global users across different platforms and filesystems.

## Features

### Core Capabilities

- **Multi-platform Support**: Works on Windows, macOS, Linux, and Unix-like systems
- **Filesystem Awareness**: Adapts normalization based on target filesystem (HFS+, NTFS, ext4, etc.)
- **Encoding Support**: Handles UTF-8, UTF-16LE, ASCII, and Latin-1 encodings
- **Script Support**: Comprehensive support for:
  - Emoji characters (🎉, 📁, 🖼️, etc.)
  - CJK ideographs (Chinese, Japanese, Korean)
  - RTL scripts (Arabic, Hebrew)
  - Latin scripts with diacritics (café, naïve, etc.)
  - Mixed scripts in single paths

### Normalization Forms

The handler supports all Unicode normalization forms:

- **NFC** (Canonical Decomposition, followed by Canonical Composition)
- **NFD** (Canonical Decomposition)
- **NFKC** (Compatibility Decomposition, followed by Canonical Composition)
- **NFKD** (Compatibility Decomposition)

Platform-specific defaults:
- **macOS (HFS+)**: NFD (decomposed form)
- **Windows (NTFS)**: NFC (composed form)
- **Linux/Unix (ext4, etc.)**: NFC (composed form)

### Security Features

- **Directory Traversal Prevention**: Blocks `../` and `..\\` patterns
- **Null Byte Protection**: Prevents null byte injection attacks
- **Path Length Limits**: Enforces platform-specific maximum path lengths
- **Reserved Name Detection**: Prevents use of Windows reserved names (CON, PRN, etc.)
- **Problematic Character Removal**: Strips zero-width and bidirectional control characters

## API Reference

### UnicodeHandler Class

```javascript
const { UnicodeHandler } = require('./src/unicode/unicode-path-handler');
const handler = new UnicodeHandler();
```

#### Methods

##### normalizePath(inputPath, form)

Normalizes a Unicode path according to filesystem requirements.

```javascript
// Basic normalization
const normalized = handler.normalizePath('/tmp/café.txt');

// Specific normalization form
const nfdPath = handler.normalizePath('/tmp/café.txt', 'NFD');
```

Parameters:
- `inputPath` (string): Path to normalize
- `form` (string, optional): Normalization form (NFC, NFD, NFKC, NFKD)

Returns: Normalized path string

##### encodeForShell(pathStr, shellType)

Encodes paths for safe shell execution.

```javascript
// Bash encoding
const bashSafe = handler.encodeForShell('/tmp/test 🎉.txt', 'bash');
// Result: '/tmp/test 🎉.txt'

// Windows CMD encoding
const cmdSafe = handler.encodeForShell('C:\\temp\\test 🎉.txt', 'cmd');
// Result: "C:\\temp\\test 🎉.txt"

// PowerShell encoding  
const pwshSafe = handler.encodeForShell('/tmp/test 🎉.txt', 'powershell');
// Result: '/tmp/test 🎉.txt'
```

Parameters:
- `pathStr` (string): Path to encode
- `shellType` (string): Shell type ('bash', 'cmd', 'powershell')

Returns: Shell-encoded path string

##### encodeForJSON(pathStr)

Encodes paths for JSON contexts.

```javascript
const jsonSafe = handler.encodeForJSON('/tmp/test 🎉.txt');
// Result: "\"/tmp/test 🎉.txt\""
```

##### analyzePath(pathStr)

Provides comprehensive analysis of Unicode path properties.

```javascript
const analysis = handler.analyzePath('/test_🎉_中文_العربية/café.txt');
console.log(analysis);
```

Returns object with:
- `original`: Original path
- `normalized`: Normalized path
- `platform`: Current platform
- `encoding`: Detected encoding
- `normalizationForm`: Applied normalization form
- `length`: Character length
- `byteLength`: Byte length
- `containsRTL`: Boolean - contains RTL text
- `containsCJK`: Boolean - contains CJK characters
- `containsEmoji`: Boolean - contains emoji
- `shellEncoded`: Object with encoded versions for different shells
- `jsonEncoded`: JSON-encoded version

##### createSafeTempPath(tempDir, prefix, suffix)

Creates safe temporary file paths with Unicode support.

```javascript
const safePath = handler.createSafeTempPath('/tmp', 'claude-auto-tee', '.log');
// Result: '/tmp/claude-auto-tee-1640995200000-1234.log'
```

### Error Types

#### UnicodePathError

Base error for Unicode path handling issues.

```javascript
try {
  handler.normalizePath(null);
} catch (error) {
  if (error instanceof UnicodePathError) {
    console.log('Unicode path error:', error.message);
    console.log('Error code:', error.code);
    console.log('Problematic path:', error.path);
  }
}
```

#### UnicodeNormalizationError

Specific error for normalization failures.

#### UnicodeEncodingError

Specific error for encoding/decoding failures.

## Usage Examples

### Basic Usage

```javascript
const { UnicodeHandler } = require('./src/unicode/unicode-path-handler');
const handler = new UnicodeHandler();

// Normalize a path with emoji
const emojiPath = '/tmp/test_🎉_output.txt';
const normalized = handler.normalizePath(emojiPath);
console.log('Normalized:', normalized);

// Encode for shell execution
const shellSafe = handler.encodeForShell(normalized, 'bash');
console.log('Shell safe:', shellSafe);
```

### Multi-Script Paths

```javascript
// Chinese path
const chinesePath = '/用户/文档/输出.log';
const normalizedChinese = handler.normalizePath(chinesePath);

// Arabic (RTL) path  
const arabicPath = '/مستندات/إخراج.log';
const normalizedArabic = handler.normalizePath(arabicPath);

// Mixed script path
const mixedPath = '/English_中文_日本語_العربية/file.txt';
const analysis = handler.analyzePath(mixedPath);
console.log('Contains RTL:', analysis.containsRTL);
console.log('Contains CJK:', analysis.containsCJK);
```

### Integration with File Operations

```javascript
const fs = require('fs');
const path = require('path');

// Safe file operations with Unicode paths
const unicodePath = '/tmp/café_🎉.txt';
const safePath = handler.normalizePath(unicodePath);

try {
  fs.writeFileSync(safePath, 'Unicode content', 'utf8');
  console.log('File written successfully');
} catch (error) {
  console.error('File operation failed:', error.message);
}
```

### Shell Command Construction

```javascript
const { spawn } = require('child_process');

const inputPath = '/tmp/test_🎉_input.txt';
const outputPath = '/tmp/test_🎉_output.txt';

const safeInput = handler.encodeForShell(inputPath, 'bash');
const safeOutput = handler.encodeForShell(outputPath, 'bash');

const command = `cat ${safeInput} > ${safeOutput}`;
console.log('Safe command:', command);
```

## Testing

### Running Tests

```bash
# Run Unicode-specific tests
npm test -- unicode

# Run with verbose output
VERBOSE_TEST=1 node test/unicode/unicode-paths.test.js

# Run specific test categories
node test/unicode/unicode-paths.test.js
```

### Test Coverage

The test suite covers:

- **Basic ASCII paths**: Standard filesystem paths
- **Emoji paths**: Paths containing Unicode emoji (🎉, 📁, 🖼️)
- **CJK paths**: Chinese, Japanese, Korean character paths
- **RTL paths**: Arabic and Hebrew right-to-left text paths
- **Diacritic paths**: Latin characters with accents (café, naïve)
- **Mixed scripts**: Paths combining multiple writing systems
- **Edge cases**: Spaces, tabs, long paths, special characters
- **Normalization**: NFC/NFD conversion and compatibility
- **Shell encoding**: Bash, CMD, PowerShell safety
- **JSON encoding**: Safe JSON representation
- **Error handling**: Invalid inputs and security issues
- **Cross-platform**: Windows, macOS, Linux compatibility

### Example Test Paths

```javascript
// Test paths used in the test suite
const testPaths = [
  '/tmp/test_🎉_output.txt',           // Emoji
  '/用户/文档/输出.log',                // Chinese
  '/ユーザー/ドキュメント/出力.txt',     // Japanese
  '/사용자/문서/출력.log',              // Korean
  '/מסמכים/פלט.txt',                  // Hebrew
  '/مستندات/إخراج.log',               // Arabic
  '/café/naïve.txt',                   // Diacritics
  '/English_中文_日本語/mixed.txt'      // Mixed scripts
];
```

## Filesystem Compatibility

### HFS+ (macOS)

- Prefers NFD normalization
- Case-insensitive by default
- Supports full Unicode range
- Maximum path length: 1024 bytes

### NTFS (Windows)

- Prefers NFC normalization
- Case-insensitive, case-preserving
- Supports full Unicode range
- Maximum path length: 260 characters (legacy), 32,767 with long path support
- Reserved names: CON, PRN, AUX, NUL, COM1-9, LPT1-9

### ext4 (Linux)

- Prefers NFC normalization
- Case-sensitive
- Supports full Unicode range
- Maximum path length: 4096 bytes
- Maximum filename: 255 bytes

### Cross-Platform Considerations

1. **Normalization**: Always use filesystem-appropriate normalization
2. **Case sensitivity**: Handle platform differences appropriately
3. **Path separators**: Convert between `/` and `\` as needed
4. **Reserved characters**: Avoid platform-specific reserved characters
5. **Length limits**: Respect platform-specific path length limits

## Security Considerations

### Path Traversal Prevention

```javascript
// These will throw UnicodePathError
handler.normalizePath('/tmp/../../../etc/passwd');
handler.normalizePath('C:\\temp\\..\\..\\Windows\\System32');
```

### Null Byte Protection

```javascript
// This will throw UnicodePathError
handler.normalizePath('/tmp/file\0.txt');
```

### Zero-Width Character Removal

```javascript
// Zero-width characters are automatically removed
const path = '/tmp/file\u200B\u200C\u200D.txt';
const safe = handler.normalizePath(path); // '/tmp/file.txt'
```

### Shell Injection Prevention

```javascript
// Proper escaping prevents injection
const maliciousPath = '/tmp/file; rm -rf /';
const safe = handler.encodeForShell(maliciousPath, 'bash');
// Result: '/tmp/file; rm -rf /'
```

## Performance Considerations

### Normalization Cost

- Normalization has computational cost
- Cache normalized paths when possible
- Batch operations for multiple paths

### Memory Usage

- Unicode paths use more memory than ASCII
- Consider memory limits for very long paths
- Monitor memory usage in high-volume scenarios

### Platform Differences

- Different platforms have different performance characteristics
- Test on target platforms for performance requirements
- Consider filesystem-specific optimizations

## Troubleshooting

### Common Issues

#### Path Not Found Errors

```javascript
// Wrong normalization form
const path = '/café.txt'; // NFC form
fs.readFileSync(path); // May fail on NFD filesystem

// Solution: Use proper normalization
const safePath = handler.normalizePath(path);
fs.readFileSync(safePath); // Works correctly
```

#### Shell Command Failures

```javascript
// Unsafe shell command
const cmd = `ls /tmp/test 🎉.txt`; // Will fail

// Solution: Proper encoding
const safePath = handler.encodeForShell('/tmp/test 🎉.txt', 'bash');
const cmd = `ls ${safePath}`; // Works correctly
```

#### Character Display Issues

```javascript
// Check if path contains specific character types
const analysis = handler.analyzePath(problematicPath);
if (analysis.containsRTL) {
  console.log('Path contains RTL text, handle display carefully');
}
```

### Debug Mode

Enable verbose logging for troubleshooting:

```bash
VERBOSE_TEST=1 node your-script.js
```

### Platform-Specific Issues

#### Windows

- Long path support may need to be enabled
- Reserved names cause errors
- Case-insensitive filesystem considerations

#### macOS

- NFD normalization differences
- Case-insensitive filesystem by default
- Unicode filename display in Finder

#### Linux

- Locale settings affect Unicode support
- Different filesystems have different capabilities
- Terminal Unicode support varies

## Best Practices

### Path Handling

1. **Always normalize**: Use `normalizePath()` for all user-provided paths
2. **Validate early**: Check paths at input boundaries
3. **Use proper encoding**: Always encode paths for shell execution
4. **Handle errors**: Implement proper error handling for Unicode issues
5. **Test thoroughly**: Test with real Unicode paths on target platforms

### Performance

1. **Cache normalized paths**: Avoid repeated normalization
2. **Batch operations**: Process multiple paths together when possible
3. **Monitor memory**: Watch memory usage with long Unicode paths
4. **Profile on target platforms**: Performance varies by platform

### Security

1. **Validate input**: Always validate paths from untrusted sources
2. **Use proper escaping**: Never construct shell commands without proper escaping
3. **Limit path length**: Enforce reasonable path length limits
4. **Sanitize characters**: Remove or replace problematic characters

### Compatibility

1. **Test on all platforms**: Unicode behavior varies significantly
2. **Handle filesystem differences**: Different filesystems have different capabilities
3. **Consider locale settings**: User locale affects Unicode handling
4. **Graceful degradation**: Provide fallbacks for unsupported Unicode

## Migration Guide

### From Legacy Path Handling

If migrating from existing path handling code:

```javascript
// Old way (unsafe)
const path = userInput;
const command = `ls ${path}`;

// New way (safe)
const handler = new UnicodeHandler();
const safePath = handler.normalizePath(userInput);
const encodedPath = handler.encodeForShell(safePath, 'bash');
const command = `ls ${encodedPath}`;
```

### Integration Steps

1. **Replace path handling**: Use `UnicodeHandler` for all path operations
2. **Update shell commands**: Use `encodeForShell()` for all shell operations
3. **Add error handling**: Handle `UnicodePathError` and subclasses
4. **Update tests**: Include Unicode path tests in your test suite
5. **Document changes**: Update documentation to reflect Unicode support

## Conclusion

The Unicode Path Handler provides comprehensive, secure, and performant Unicode path support for the claude-auto-tee PostToolUse hook. By following this documentation and using the provided APIs, you can ensure your application works correctly with Unicode paths from global users across all supported platforms.

For additional support or questions, refer to the test suite examples or create an issue in the project repository.