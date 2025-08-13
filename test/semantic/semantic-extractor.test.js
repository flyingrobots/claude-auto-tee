/**
 * Test suite for SemanticExtractor
 * 
 * Tests pattern matching, ANSI stripping, confidence scoring,
 * and performance requirements.
 */

const { SemanticExtractor } = require('../../src/semantic/semantic-extractor');

// Mock assert for compatibility with different test runners
const assert = {
    ok: (condition, message) => {
        if (!condition) {
            throw new Error(message || 'Assertion failed');
        }
    },
    equal: (actual, expected, message) => {
        if (actual !== expected) {
            throw new Error(message || `Expected ${expected}, got ${actual}`);
        }
    },
    deepEqual: (actual, expected, message) => {
        if (JSON.stringify(actual) !== JSON.stringify(expected)) {
            throw new Error(message || `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
        }
    }
};

class SemanticExtractorTests {
    constructor() {
        this.extractor = new SemanticExtractor();
        this.testResults = {
            total: 0,
            passed: 0,
            failed: 0,
            failures: []
        };
    }
    
    runTest(testName, testFunction) {
        this.testResults.total++;
        try {
            testFunction();
            this.testResults.passed++;
            console.log(`✓ ${testName}`);
        } catch (error) {
            this.testResults.failed++;
            this.testResults.failures.push({ testName, error: error.message });
            console.log(`✗ ${testName}: ${error.message}`);
        }
    }
    
    runAllTests() {
        console.log('Running SemanticExtractor tests...\n');
        
        // Basic functionality tests
        this.runTest('Empty input handling', () => this.testEmptyInput());
        this.runTest('ANSI code stripping', () => this.testAnsiStripping());
        
        // Error extraction tests
        this.runTest('Generic error extraction', () => this.testGenericErrorExtraction());
        this.runTest('Typed error extraction', () => this.testTypedErrorExtraction());
        this.runTest('Stack trace extraction', () => this.testStackTraceExtraction());
        this.runTest('NPM error extraction', () => this.testNpmErrorExtraction());
        
        // Success extraction tests
        this.runTest('Success pattern extraction', () => this.testSuccessExtraction());
        this.runTest('Test pass extraction', () => this.testTestPassExtraction());
        this.runTest('Check mark extraction', () => this.testCheckMarkExtraction());
        
        // Metrics extraction tests
        this.runTest('Time metrics extraction', () => this.testTimeMetrics());
        this.runTest('Size metrics extraction', () => this.testSizeMetrics());
        this.runTest('Percentage metrics extraction', () => this.testPercentageMetrics());
        this.runTest('Ratio metrics extraction', () => this.testRatioMetrics());
        
        // Path extraction tests
        this.runTest('Unix path extraction', () => this.testUnixPaths());
        this.runTest('Windows path extraction', () => this.testWindowsPaths());
        this.runTest('Relative path extraction', () => this.testRelativePaths());
        this.runTest('URL extraction', () => this.testUrlExtraction());
        
        // Command extraction tests
        this.runTest('Shell command extraction', () => this.testShellCommands());
        this.runTest('NPM command extraction', () => this.testNpmCommands());
        this.runTest('Git command extraction', () => this.testGitCommands());
        
        // Confidence and performance tests
        this.runTest('Confidence scoring', () => this.testConfidenceScoring());
        this.runTest('Performance requirements', () => this.testPerformance());
        
        // Integration tests
        this.runTest('Real-world NPM test output', () => this.testRealWorldNpmOutput());
        this.runTest('Real-world build output', () => this.testRealWorldBuildOutput());
        this.runTest('Real-world error output', () => this.testRealWorldErrorOutput());
        
        this.printSummary();
        return this.testResults.passed / this.testResults.total >= 0.9; // 90% pass rate
    }
    
    testEmptyInput() {
        const result = this.extractor.extract('');
        assert.equal(result.confidence, 0.1);
        assert.equal(result.errors.length, 0);
        assert.equal(result.successes.length, 0);
    }
    
    testAnsiStripping() {
        const inputWithAnsi = '\x1b[31mError: Something failed\x1b[0m';
        const result = this.extractor.extract(inputWithAnsi);
        assert.ok(result.errors.length > 0);
        assert.ok(result.errors[0].content.includes('Error: Something failed'));
        assert.ok(!result.errors[0].content.includes('\x1b'));
    }
    
    testGenericErrorExtraction() {
        const output = 'Error: File not found\nSome other line';
        const result = this.extractor.extract(output);
        
        assert.ok(result.errors.length > 0);
        const error = result.errors.find(e => e.type === 'generic_error');
        assert.ok(error, 'Should find generic error');
        assert.ok(error.content.includes('Error: File not found'));
        assert.ok(error.confidence >= 0.9);
    }
    
    testTypedErrorExtraction() {
        const output = 'TypeError: Cannot read property of null';
        const result = this.extractor.extract(output);
        
        const error = result.errors.find(e => e.type === 'typed_error');
        assert.ok(error, 'Should find typed error');
        assert.ok(error.confidence >= 0.8);
    }
    
    testStackTraceExtraction() {
        const output = `
        at Object.test (/path/to/file.js:123:45)
        at runTest (test.js:67:8)
        `;
        const result = this.extractor.extract(output);
        
        const stackTrace = result.errors.find(e => e.type === 'stack_trace');
        assert.ok(stackTrace, 'Should find stack trace');
        assert.ok(stackTrace.confidence >= 0.9);
    }
    
    testNpmErrorExtraction() {
        const output = 'npm ERR! code ENOENT\nnpm ERR! syscall open';
        const result = this.extractor.extract(output);
        
        const npmErrors = result.errors.filter(e => e.type === 'npm_error');
        assert.ok(npmErrors.length >= 1, 'Should find npm errors');
    }
    
    testSuccessExtraction() {
        const output = 'Success: Operation completed successfully';
        const result = this.extractor.extract(output);
        
        const success = result.successes.find(s => s.type === 'generic_success');
        assert.ok(success, 'Should find generic success');
        assert.ok(success.confidence >= 0.8);
    }
    
    testTestPassExtraction() {
        const output = 'PASS tests/example.test.js\n✓ should work correctly';
        const result = this.extractor.extract(output);
        
        const passResult = result.successes.find(s => s.type === 'test_pass');
        const checkResult = result.successes.find(s => s.type === 'check_passed');
        
        assert.ok(passResult || checkResult, 'Should find test pass indicators');
    }
    
    testCheckMarkExtraction() {
        const output = '✓ All tests passing\n✓ Build completed';
        const result = this.extractor.extract(output);
        
        const checks = result.successes.filter(s => s.type === 'check_passed');
        assert.ok(checks.length >= 2, 'Should find multiple check marks');
    }
    
    testTimeMetrics() {
        const output = 'Completed in 1234ms\nTook 5.67 seconds to finish';
        const result = this.extractor.extract(output);
        
        const timeMetrics = result.metrics.filter(m => m.type === 'time_metric');
        assert.ok(timeMetrics.length >= 2, 'Should find time metrics');
        
        const msMetric = timeMetrics.find(m => m.unit === 'ms');
        const sMetric = timeMetrics.find(m => m.unit === 's');
        assert.ok(msMetric, 'Should find millisecond metric');
        assert.ok(sMetric, 'Should find second metric');
    }
    
    testSizeMetrics() {
        const output = 'File size: 125.5 KB\nMemory usage: 2.1 MB';
        const result = this.extractor.extract(output);
        
        const sizeMetrics = result.metrics.filter(m => m.type === 'size_metric');
        assert.ok(sizeMetrics.length >= 2, 'Should find size metrics');
    }
    
    testPercentageMetrics() {
        const output = 'Coverage: 87.5%\nProgress: 100%';
        const result = this.extractor.extract(output);
        
        const percentageMetrics = result.metrics.filter(m => m.type === 'percentage_metric');
        assert.ok(percentageMetrics.length >= 2, 'Should find percentage metrics');
    }
    
    testRatioMetrics() {
        const output = 'Tests: 15/20 passed\nBuild: 3/5 stages complete';
        const result = this.extractor.extract(output);
        
        const ratioMetrics = result.metrics.filter(m => m.type === 'ratio_metric');
        assert.ok(ratioMetrics.length >= 2, 'Should find ratio metrics');
    }
    
    testUnixPaths() {
        const output = 'Reading /usr/local/bin/node\nFile: /home/user/project/file.js';
        const result = this.extractor.extract(output);
        
        const unixPaths = result.paths.filter(p => p.type === 'unix_path');
        assert.ok(unixPaths.length >= 2, 'Should find Unix paths');
    }
    
    testWindowsPaths() {
        const output = 'Reading C:\\Program Files\\Node\\node.exe\nFile: D:\\Projects\\app\\index.js';
        const result = this.extractor.extract(output);
        
        const windowsPaths = result.paths.filter(p => p.type === 'windows_path');
        assert.ok(windowsPaths.length >= 2, 'Should find Windows paths');
    }
    
    testRelativePaths() {
        const output = 'Loading ./config.json\nImporting ../utils/helper.js';
        const result = this.extractor.extract(output);
        
        const relativePaths = result.paths.filter(p => 
            p.type === 'relative_path' || p.type === 'parent_relative_path'
        );
        assert.ok(relativePaths.length >= 2, 'Should find relative paths');
    }
    
    testUrlExtraction() {
        const output = 'Fetching https://api.example.com/data\nRedirect to http://localhost:3000/app';
        const result = this.extractor.extract(output);
        
        const urls = result.paths.filter(p => p.type === 'url');
        assert.ok(urls.length >= 2, 'Should find URLs');
    }
    
    testShellCommands() {
        const output = '$ npm install\n$ node index.js\n> git status';
        const result = this.extractor.extract(output);
        
        const shellCommands = result.commands.filter(c => 
            c.type === 'shell_command' || c.type === 'prompt_command'
        );
        assert.ok(shellCommands.length >= 2, 'Should find shell commands');
    }
    
    testNpmCommands() {
        const output = 'npm install express\nnpm test --verbose\nNPM START server';
        const result = this.extractor.extract(output);
        
        const npmCommands = result.commands.filter(c => c.type === 'npm_command');
        assert.ok(npmCommands.length >= 2, 'Should find npm commands');
    }
    
    testGitCommands() {
        const output = 'git commit -m "message"\ngit push origin main\nGIT STATUS --short';
        const result = this.extractor.extract(output);
        
        const gitCommands = result.commands.filter(c => c.type === 'git_command');
        assert.ok(gitCommands.length >= 2, 'Should find git commands');
    }
    
    testConfidenceScoring() {
        // Test with high-confidence patterns
        const highConfidenceOutput = 'Error: Critical failure\nPASS tests/test.js\nCompleted in 123ms';
        const highResult = this.extractor.extract(highConfidenceOutput);
        
        // Test with low-confidence/no patterns
        const lowConfidenceOutput = 'Some random text without patterns';
        const lowResult = this.extractor.extract(lowConfidenceOutput);
        
        assert.ok(highResult.confidence > lowResult.confidence, 'High confidence output should score higher');
        assert.ok(highResult.confidence > 0.5, 'Should have reasonable confidence for pattern-rich output');
    }
    
    testPerformance() {
        // Generate 10KB of test data
        const largeOutput = this.generateLargeTestOutput(10000);
        
        const startTime = Date.now();
        const result = this.extractor.extract(largeOutput);
        const processingTime = Date.now() - startTime;
        
        assert.ok(processingTime < 50, `Processing should take <50ms, took ${processingTime}ms`);
        assert.ok(result.metadata.processingTime < 50, 'Reported processing time should be <50ms');
        
        // Verify it still extracts patterns from large output
        assert.ok(result.errors.length > 0 || result.successes.length > 0, 'Should extract patterns from large output');
    }
    
    testRealWorldNpmOutput() {
        const npmOutput = `
npm install express

> express@4.18.2
> node-gyp rebuild

  SOLINK_MODULE(target) Release/.node
  COPY /Users/user/project/node_modules/express/lib/express.js
  Build successful

✓ express@4.18.2 installed successfully
Coverage: 85.3%
Tests: 45/50 passed
Completed in 2.5 seconds
`;
        
        const result = this.extractor.extract(npmOutput);
        
        assert.ok(result.successes.length >= 1, `Should find success indicators, found ${result.successes.length}`);
        assert.ok(result.metrics.length >= 2, `Should find metrics (coverage, tests, time), found ${result.metrics.length}`);
        assert.ok(result.paths.length >= 1, 'Should find file paths');
        assert.ok(result.confidence > 0.5, 'Should have reasonable confidence for rich output');
    }
    
    testRealWorldBuildOutput() {
        const buildOutput = `
Building application...

Bundling /src/index.js
Minifying assets... 1.2 MB → 800 KB (33% reduction)
Generated source maps: 150 KB

✓ Build completed successfully in 15.3 seconds
✓ All 25 chunks emitted
⚠ Warning: Large bundle size detected

Output saved to: /dist/bundle.js
Ready for deployment!
`;
        
        const result = this.extractor.extract(buildOutput);
        
        assert.ok(result.successes.length >= 2, 'Should find build success indicators');
        assert.ok(result.metrics.length >= 4, 'Should find size and time metrics');
        assert.ok(result.paths.length >= 2, 'Should find file paths');
    }
    
    testRealWorldErrorOutput() {
        const errorOutput = `
TypeError: Cannot read properties of undefined (reading 'length')
    at validateInput (/Users/user/app/validator.js:15:23)  
    at processData (/Users/user/app/processor.js:42:18)
    at Object.main (/Users/user/app/index.js:128:9)

npm ERR! code 1
npm ERR! path /Users/user/app
npm ERR! command failed

FAIL tests/validator.test.js
  ✗ should validate input correctly (45ms)
  ✗ should handle edge cases (23ms)

Tests: 2/10 passed
Coverage: 45.2%
`;
        
        const result = this.extractor.extract(errorOutput);
        
        assert.ok(result.errors.length >= 4, 'Should find multiple error types');
        assert.ok(result.metrics.length >= 2, 'Should find time, ratio, and coverage metrics');
        assert.ok(result.paths.length >= 1, `Should find file paths in stack trace, found ${result.paths.length}`);
        
        // Should find stack traces
        const stackTraces = result.errors.filter(e => e.type === 'stack_trace');
        assert.ok(stackTraces.length >= 1, `Should find stack trace lines, found ${stackTraces.length}`);
    }
    
    generateLargeTestOutput(targetSize) {
        const patterns = [
            'Error: Something went wrong',
            '✓ Test passed successfully', 
            'Completed in 123ms',
            'File: /path/to/file.js',
            '$ npm test',
            'Coverage: 85.5%',
            'https://example.com/api',
            'npm ERR! Something failed',
            'PASS tests/example.test.js',
            'Processing 15/20 items'
        ];
        
        let output = '';
        while (output.length < targetSize) {
            const pattern = patterns[Math.floor(Math.random() * patterns.length)];
            output += pattern + '\n';
            output += 'Some random filler text to increase output size '.repeat(5) + '\n';
        }
        
        return output.substring(0, targetSize);
    }
    
    printSummary() {
        console.log('\n' + '='.repeat(50));
        console.log('SEMANTIC EXTRACTOR TEST SUMMARY');
        console.log('='.repeat(50));
        console.log(`Total tests: ${this.testResults.total}`);
        console.log(`Passed: ${this.testResults.passed}`);
        console.log(`Failed: ${this.testResults.failed}`);
        console.log(`Pass rate: ${(this.testResults.passed / this.testResults.total * 100).toFixed(1)}%`);
        
        if (this.testResults.failures.length > 0) {
            console.log('\nFailures:');
            this.testResults.failures.forEach(failure => {
                console.log(`  - ${failure.testName}: ${failure.error}`);
            });
        }
        
        const passRate = this.testResults.passed / this.testResults.total;
        if (passRate >= 0.9) {
            console.log('\n✓ ACCEPTANCE CRITERIA MET (90% pass rate)');
        } else {
            console.log('\n✗ ACCEPTANCE CRITERIA NOT MET (< 90% pass rate)');
        }
    }
}

// Export for use in other test runners or direct execution
if (require.main === module) {
    const tests = new SemanticExtractorTests();
    const success = tests.runAllTests();
    process.exit(success ? 0 : 1);
}

module.exports = { SemanticExtractorTests };