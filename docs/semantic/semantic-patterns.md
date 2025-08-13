# Semantic Extraction Patterns

## Overview

The SemanticExtractor uses pattern-based matching to extract meaningful information from command outputs. This document describes the extraction patterns, their confidence levels, and provides examples of what they match.

## Pattern Categories

### Error Patterns

#### Generic Error (Confidence: 0.95)
- **Pattern**: `^Error:\s*(.+)$`
- **Examples**:
  - `Error: File not found`
  - `Error: Permission denied`
  - `Error: Invalid argument`

#### Typed Error (Confidence: 0.9)
- **Pattern**: `^(.+)Error:\s*(.+)$`
- **Examples**:
  - `TypeError: Cannot read property 'length' of undefined`
  - `SyntaxError: Unexpected token '}'`
  - `ReferenceError: variable is not defined`

#### Stack Trace (Confidence: 0.95)
- **Pattern**: `^\s*at\s+(.+?)\s*\((.+?):(\d+):(\d+)\)`
- **Examples**:
  - `    at Object.test (/path/to/file.js:123:45)`
  - `    at validateInput (validator.js:67:8)`
  - `    at processData (/app/processor.js:42:18)`

#### NPM Errors (Confidence: 0.9)
- **Pattern**: `^npm ERR!\s*(.+)$`
- **Examples**:
  - `npm ERR! code ENOENT`
  - `npm ERR! syscall open`
  - `npm ERR! path /missing/file`

#### Test Failures (Confidence: 0.85)
- **Pattern**: `^FAIL\s*(.*)$`
- **Examples**:
  - `FAIL tests/example.test.js`
  - `FAIL src/components/Button.test.tsx`

#### Fatal Errors (Confidence: 0.95)
- **Pattern**: `^fatal:\s*(.+)$`
- **Examples**:
  - `fatal: not a git repository`
  - `fatal: remote origin already exists`

### Success Patterns

#### Generic Success (Confidence: 0.9)
- **Pattern**: `^Success:\s*(.+)$`
- **Examples**:
  - `Success: Operation completed successfully`
  - `Success: File saved to disk`

#### Test Pass (Confidence: 0.85)
- **Pattern**: `^PASS\s*(.*)$`
- **Examples**:
  - `PASS tests/example.test.js`
  - `PASS src/utils/helper.test.js (5.2s)`

#### Check Passed (Confidence: 0.8)
- **Pattern**: `^✓\s*(.+)$`
- **Examples**:
  - `✓ All tests passing`
  - `✓ Build completed successfully`
  - `✓ Dependencies installed`

#### Build Success (Confidence: 0.95)
- **Pattern**: `^Build successful`
- **Examples**:
  - `Build successful`
  - `Build successful in 15.3 seconds`

#### Test Summary Pass (Confidence: 0.9)
- **Pattern**: `^\s*(\d+)\s+passing`
- **Examples**:
  - `  15 passing`
  - `  142 passing (2.5s)`

### Metrics Patterns

#### Time Metrics (Confidence: 0.9)
- **Pattern**: `(\d+(?:\.\d+)?)\s*(ms|milliseconds?)`
- **Examples**:
  - `Completed in 1234ms`
  - `Response time: 45.2 milliseconds`
  - `Duration: 15.7ms`

#### Time Metrics in Seconds (Confidence: 0.85)  
- **Pattern**: `(\d+(?:\.\d+)?)\s*(s|seconds?)`
- **Examples**:
  - `Finished in 2.5 seconds`
  - `Total time: 45s`
  - `Elapsed: 1.23 seconds`

#### Size Metrics (Confidence: 0.9)
- **Pattern**: `(\d+(?:\.\d+)?)\s*(KB|MB|GB)`
- **Examples**:
  - `File size: 125.5 KB`
  - `Memory usage: 2.1 MB`
  - `Bundle size: 1.8 GB`

#### Percentage Metrics (Confidence: 0.85)
- **Pattern**: `(\d+(?:\.\d+)?)\s*%`
- **Examples**:
  - `Coverage: 87.5%`
  - `Progress: 100%`
  - `Memory usage: 45.2%`

#### Coverage Metrics (Confidence: 0.95)
- **Pattern**: `Coverage:\s*(\d+(?:\.\d+)?)\s*%`
- **Examples**:
  - `Coverage: 85.3%`
  - `Code Coverage: 92.1%`

#### Ratio Metrics (Confidence: 0.8)
- **Pattern**: `(\d+)\/(\d+)`
- **Examples**:
  - `Tests: 15/20 passed`
  - `Build: 3/5 stages complete`
  - `Progress: 45/100`

#### Rate Metrics (Confidence: 0.85)
- **Pattern**: `(\d+(?:\.\d+)?)\s*(fps|qps|rps)`
- **Examples**:
  - `Performance: 60fps`
  - `Throughput: 1500 qps`
  - `Rate: 250.5 rps`

### Path Patterns

#### Unix Paths (Confidence: 0.8)
- **Pattern**: `(?:^|\s)(\/(?:[^\/\s]+\/)*[^\/\s]*)`
- **Examples**:
  - `/usr/local/bin/node`
  - `/home/user/project/src/index.js`
  - `/var/log/application.log`

#### Windows Paths (Confidence: 0.8)
- **Pattern**: `(?:^|\s)([A-Za-z]:\\(?:[^\\\/\s]+[\\\/])*[^\\\/\s]*)`
- **Examples**:
  - `C:\Program Files\Node\node.exe`
  - `D:\Projects\app\src\index.js`
  - `E:\Data\logs\error.txt`

#### Relative Paths (Confidence: 0.75)
- **Pattern**: `(?:^|\s)(\.\/(?:[^\/\s]+\/)*[^\/\s]*)`
- **Examples**:
  - `./config.json`
  - `./src/components/Button.tsx`
  - `./test/fixtures/data.xml`

#### Parent Relative Paths (Confidence: 0.75)
- **Pattern**: `(?:^|\s)(\.\.\/(?:[^\/\s]+\/)*[^\/\s]*)`
- **Examples**:
  - `../utils/helper.js`
  - `../../config/database.json`
  - `../../../shared/constants.ts`

#### Home Relative Paths (Confidence: 0.8)
- **Pattern**: `(?:^|\s)(~\/(?:[^\/\s]+\/)*[^\/\s]*)`
- **Examples**:
  - `~/projects/myapp`
  - `~/.bashrc`
  - `~/Documents/data.csv`

#### URLs (Confidence: 0.95)
- **Pattern**: `https?:\/\/(?:[-\w.])+(?::[0-9]+)?(?:\/(?:[\w\/_.])*)?(?:\?[;&%\w=]*)?`
- **Examples**:
  - `https://api.example.com/data`
  - `http://localhost:3000/app`
  - `https://github.com/user/repo.git`

### Command Patterns

#### Shell Commands (Confidence: 0.9)
- **Pattern**: `^\$\s*(.+)$`
- **Examples**:
  - `$ npm install`
  - `$ node server.js`
  - `$ git status`

#### Prompt Commands (Confidence: 0.8)
- **Pattern**: `^>\s*(.+)$`
- **Examples**:
  - `> npm start`
  - `> node --version`
  - `> git log --oneline`

#### NPM Commands (Confidence: 0.95)
- **Pattern**: `^npm\s+(install|start|test|build|run)\s*(.*)?$`
- **Examples**:
  - `npm install express`
  - `npm test --verbose`
  - `npm run build:production`

#### Git Commands (Confidence: 0.95)
- **Pattern**: `^git\s+(\w+)\s*(.*)?$`
- **Examples**:
  - `git commit -m "message"`
  - `git push origin main`
  - `git status --short`

#### Docker Commands (Confidence: 0.9)
- **Pattern**: `^docker\s+(\w+)\s*(.*)?$`
- **Examples**:
  - `docker build -t myapp .`
  - `docker run -p 3000:3000 myapp`
  - `docker ps --all`

#### Node Commands (Confidence: 0.85)
- **Pattern**: `^node\s+(.*)?$`
- **Examples**:
  - `node server.js`
  - `node --version`
  - `node index.js --env=production`

#### Python Commands (Confidence: 0.85)
- **Pattern**: `^python\s+(.*)?$`
- **Examples**:
  - `python app.py`
  - `python -m pip install requests`
  - `python manage.py migrate`

## Confidence Scoring

### Individual Pattern Confidence
Each pattern has a base confidence score (0.0-1.0) based on:
- **Precision**: How likely the pattern is to match what it's supposed to
- **Specificity**: How specific the pattern is (more specific = higher confidence)
- **Context dependence**: Patterns that work in specific contexts have adjusted confidence

### Overall Extraction Confidence
The overall confidence for an extraction is calculated by:
1. **Base confidence**: Average of all individual pattern confidences found
2. **Diversity bonus**: +0.05 for each different pattern type found (max +0.25)
3. **Capped at 1.0**: Final confidence is capped at maximum 1.0

### Confidence Ranges
- **0.9-1.0**: Very high confidence (e.g., stack traces, fatal errors, URLs)
- **0.8-0.9**: High confidence (e.g., typed errors, paths, check marks)
- **0.7-0.8**: Good confidence (e.g., relative paths, percentages)
- **0.6-0.7**: Moderate confidence (less specific patterns)
- **0.1-0.6**: Low confidence (ambiguous or no clear patterns)

## ANSI Code Handling

The extractor automatically strips ANSI escape sequences by default:
- **Stripped codes**: Color codes, cursor movement, text formatting
- **Preserved content**: All text content is preserved after stripping
- **Performance**: ANSI stripping adds minimal overhead (<1ms)

### Example ANSI Stripping
```
Input:  "\x1b[31mError: Something failed\x1b[0m"
Output: "Error: Something failed"
```

## Performance Characteristics

### Performance Requirements
- **Processing time**: <50ms for 10KB of output
- **Memory usage**: Minimal - processes line by line
- **Scalability**: Linear time complexity with input size

### Optimization Techniques
1. **Regex reuse**: Pattern objects are created once and reused
2. **Early termination**: Global regex patterns prevent infinite loops
3. **Deduplication**: Results are deduplicated to reduce processing
4. **Line-by-line processing**: Avoids loading entire output into memory

## Usage Examples

### Basic Usage
```javascript
const { SemanticExtractor } = require('./semantic-extractor');

const extractor = new SemanticExtractor();
const output = `
Error: File not found
✓ 15 tests passing
Coverage: 85.3%
Completed in 1.2 seconds
`;

const result = extractor.extract(output);
console.log(result.errors);     // [{ type: 'generic_error', ... }]
console.log(result.successes);  // [{ type: 'check_passed', ... }]
console.log(result.metrics);    // [{ type: 'coverage_metric', ... }]
```

### With Options
```javascript
const extractor = new SemanticExtractor({
    stripAnsi: true,        // Strip ANSI codes (default: true)
    includeLineNumbers: true, // Include line numbers in results
    maxProcessingTime: 100    // Max processing time in ms
});
```

### Adding Custom Patterns
```javascript
extractor.addPattern('errors', {
    pattern: /^CUSTOM_ERROR:\s*(.+)$/gmi,
    confidence: 0.9,
    type: 'custom_error'
});
```

## Integration Notes

This semantic extractor is designed for Phase 3 of the PostToolUse hook implementation, providing foundational intelligence for:

- **Capture search**: Find captures by semantic content
- **Context generation**: Generate intelligent context summaries
- **Invalidation rules**: Trigger invalidation based on error patterns
- **Freshness scoring**: Weight freshness by success/failure patterns

The extracted semantic information enables Claude to understand capture contents at a glance, improving the overall user experience with intelligent capture management.