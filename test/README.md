# Claude Auto-Tee Test Suite

Comprehensive testing strategy for claude-auto-tee covering all aspects identified by expert analysis.

## 🚨 Critical Finding

**Implementation Mismatch Detected**: The current implementation in `src/hook.js` uses a **hybrid activation strategy** (pattern matching + pipe detection), but the expert debate concluded that **pure pipe-only detection** should be used (4-1 expert consensus).

## Test Suites

### 1. Basic Tests (`test/test.js`)
- Core functionality validation
- Hook integration testing  
- Basic activation scenarios
- Error handling

**Run**: `npm test`

### 2. Activation Strategy Tests (`test/activation/`)
**CRITICAL TEST SUITE** - Validates the mismatch between current implementation and expert recommendation.

- Tests current hybrid behavior vs expected behavior
- Simulates pure pipe-only detection
- Performance comparison between strategies
- Validates expert claims about 165x performance degradation

**Run**: `npm run test:activation`

### 3. Performance Benchmark (`test/performance/`)
Tests performance claims from Expert 002:
- AST parsing performance under load
- Pattern matching vs pipe-only detection speed
- Memory usage analysis
- Concurrent request handling
- Cross-platform performance variance

**Run**: `npm run test:performance`

### 4. Security Tests (`test/security/`)
Validates security concerns from Expert 001:
- DoS attack resistance
- Command injection prevention
- Path traversal protection
- Resource exhaustion testing
- Permission escalation attempts

**Run**: `npm run test:security`

### 5. Edge Case Tests (`test/edge-cases/`)
Complex scenarios that could break the system:
- Unicode handling
- Nested command structures
- Process substitution
- Cross-platform path handling
- AST parsing failures

**Run**: `npm run test:edge-cases`

### 6. CI/CD Environment Tests (`test/ci/`)
Behavior in continuous integration environments:
- CI environment detection
- Auto-tee disabling in CI (per problem statement)
- Parallel build support
- Resource constraints
- Container compatibility

**Run**: `npm run test:ci`

## Docker Testing

### Cross-Platform Testing
Test on multiple platforms simultaneously:

```bash
npm run docker:test:cross-platform
```

This runs tests in:
- Alpine Linux (lightweight)
- Ubuntu (standard Linux)
- Different configurations

### Individual Docker Tests
```bash
npm run docker:test:all      # All tests in Alpine container
npm run docker:test          # Basic tests only
```

## Comprehensive Testing

### Run All Tests
```bash
npm run test:all
```

This executes:
1. All test suites in sequence
2. Generates comprehensive reports
3. Analyzes results and provides recommendations
4. Creates HTML, JSON, and Markdown reports

### Results Location
```
/tmp/test-results/
├── master-test-report.json    # Detailed data
├── master-test-report.html    # Visual report  
├── test-summary.md           # Executive summary
├── performance-results.json   # Benchmark data
└── [suite-specific-results]
```

## CI/CD Integration

GitHub Actions workflow (`.github/workflows/comprehensive-tests.yml`) runs:
- Multi-platform testing (Ubuntu, Windows, macOS)
- Multiple Node.js versions (16, 18, 20)
- All test suites
- Expert recommendation validation
- Security scanning

## Key Test Scenarios

### 1. Expert Recommendation Validation
```javascript
// Current implementation (hybrid)
shouldInjectTee('npm run build') // ✅ Activates (pattern match)
shouldInjectTee('npm run build | head -10') // ✅ Activates (pattern + pipe)

// Pure pipe-only (expert recommendation)  
shouldInjectTee('npm run build') // ❌ No activation (no pipe)
shouldInjectTee('npm run build | head -10') // ✅ Activates (pipe detected)
```

### 2. Performance Comparison
Tests validate Expert 002's claim of 165x performance degradation:
- Pattern matching: ~1-8ms per command
- Pipe-only detection: ~0.02-0.05ms per command
- Memory usage: Pattern DB vs minimal pipe detection

### 3. Security Validation
Tests Expert 001's DoS vulnerability claims:
- Complex pattern commands causing timeouts
- Resource exhaustion through pattern complexity
- Command injection through pattern bypass

## Test Development Guidelines

### Adding New Tests
1. Follow existing test structure
2. Use descriptive test names
3. Include both positive and negative cases
4. Test error conditions and edge cases
5. Validate performance impact
6. Consider cross-platform compatibility

### Test Patterns
```javascript
// Arrange
const input = { tool: { name: 'Bash', input: { command: 'test command' } } };

// Act  
const result = await runHook(input);

// Assert
assert(condition, 'Descriptive error message');
```

## Debugging Tests

### Enable Verbose Output
```bash
DEBUG=true npm run test:all
```

### Run Specific Test Category
```bash
npm run test:activation    # Just activation strategy
npm run test:performance  # Just performance
npm run test:security     # Just security  
```

### Docker Debug Mode
```bash
npm run docker:dev  # Interactive container for debugging
```

## Maintenance

### Regular Testing
- Run `npm run test:all` before commits
- Run cross-platform tests before releases
- Monitor performance benchmarks for regressions
- Update security tests for new vulnerabilities

### Updating Tests
When modifying `src/hook.js`:
1. Update relevant test expectations
2. Add tests for new functionality
3. Verify no regressions in other suites
4. Update documentation

## Expert Analysis Integration

The test suites directly validate expert findings:

- **Expert 001 (Security)**: DoS vulnerabilities, attack surface analysis
- **Expert 002 (Performance)**: 165x degradation, cross-platform variance  
- **Expert 003 (UX)**: User mental models, predictability
- **Expert 004 (Platform)**: Cross-platform compatibility, CI/CD integration
- **Expert 005 (Architecture)**: Maintainability, technical debt

## Recommendations Based on Test Results

The comprehensive test suite will provide specific recommendations:
1. **Architecture alignment** - Switch to pipe-only if tests validate expert claims
2. **Performance optimization** - Remove pattern matching overhead
3. **Security hardening** - Address identified vulnerabilities
4. **CI/CD integration** - Disable auto-tee in appropriate environments
5. **Cross-platform fixes** - Address platform-specific issues

## Getting Help

- Check test output for specific error messages
- Review generated HTML reports for visual analysis
- Examine `/tmp/test-results/` for detailed data
- Run individual test suites to isolate issues
- Use Docker tests to reproduce cross-platform problems