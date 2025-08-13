#!/usr/bin/env node
/**
 * Comprehensive Test Suite for PathParser
 * 
 * Tests all functionality including:
 * - Basic path extraction
 * - Multiple path formats (Unix, Windows, relative)  
 * - Paths with spaces and Unicode characters
 * - Multiple captures from single stderr
 * - Error handling for malformed messages
 * - Edge cases and boundary conditions
 * 
 * Target: 95%+ test coverage
 * 
 * @author Claude Code
 */

const assert = require('assert');
const path = require('path');
const PathParser = require('../../src/parser/capture-path-parser.js');

/**
 * Test runner class
 */
class PathParserTestSuite {
    constructor() {
        this.results = {
            passed: 0,
            failed: 0,
            errors: []
        };
    }

    /**
     * Run all tests
     */
    async runAllTests() {
        console.log('🧪 Running PathParser Tests\n');

        const testMethods = [
            // Basic functionality tests
            'testBasicPathExtraction',
            'testMultiplePathExtraction',
            'testEmptyInput',
            'testNoMatches',
            
            // Path format tests
            'testUnixPaths',
            'testWindowsPaths', 
            'testRelativePaths',
            'testPathsWithSpaces',
            'testUnicodePaths',
            
            // Edge case tests
            'testQuotedPaths',
            'testEscapedQuotes',
            'testMalformedMessages',
            'testDuplicatePaths',
            'testVeryLongPaths',
            'testSpecialCharacters',
            
            // Multiple input tests
            'testParseMultiple',
            'testParseMultipleWithErrors',
            
            // Utility method tests
            'testHasCaptures',
            'testExtractPaths',
            'testGetStats',
            'testResetStats',
            'testFactoryMethod',
            
            // Error handling tests
            'testInvalidInput',
            'testTypeErrors',
            
            // Secondary pattern tests
            'testTempFilePreservedPattern',
            'testMixedPatterns',
            
            // Performance tests
            'testLargeInput',
            'testRegexPerformance'
        ];

        for (const testMethod of testMethods) {
            try {
                await this[testMethod]();
                console.log(`✅ ${testMethod}`);
                this.results.passed++;
            } catch (error) {
                console.log(`❌ ${testMethod}: ${error.message}`);
                this.results.failed++;
                this.results.errors.push({ test: testMethod, error: error.message });
            }
        }

        this.printResults();
        return this.results;
    }

    // Basic functionality tests

    testBasicPathExtraction() {
        const parser = new PathParser();
        const stderr = 'Some output\nFull output saved to: /tmp/claude-123.log\nMore output';
        
        const results = parser.parse(stderr);
        
        assert.strictEqual(results.length, 1);
        assert.strictEqual(results[0].path, '/tmp/claude-123.log');
        assert(results[0].timestamp instanceof Date);
        assert.strictEqual(results[0].raw, 'Full output saved to: /tmp/claude-123.log');
    }

    testMultiplePathExtraction() {
        const parser = new PathParser();
        const stderr = `Build started
Full output saved to: /tmp/build-123.log
Processing...
Full output saved to: /var/log/process-456.log
Done`;
        
        const results = parser.parse(stderr);
        
        assert.strictEqual(results.length, 2);
        assert.strictEqual(results[0].path, '/tmp/build-123.log');
        assert.strictEqual(results[1].path, '/var/log/process-456.log');
    }

    testEmptyInput() {
        const parser = new PathParser();
        
        // Empty string should return empty array
        const results1 = parser.parse('');
        assert.strictEqual(results1.length, 0);
        
        // Whitespace only should return empty array  
        const results2 = parser.parse('   \n\t  ');
        assert.strictEqual(results2.length, 0);
    }

    testNoMatches() {
        const parser = new PathParser();
        const stderr = `Build output
Error occurred
Process completed
No file saved`;
        
        const results = parser.parse(stderr);
        assert.strictEqual(results.length, 0);
    }

    // Path format tests

    testUnixPaths() {
        const parser = new PathParser();
        const testCases = [
            '/tmp/file.log',
            '/var/log/app.log', 
            '/home/user/documents/file.txt',
            '/usr/local/bin/script.sh',
            '/tmp/dir/subdir/file-with-dashes.log'
        ];
        
        for (const testPath of testCases) {
            const stderr = `Full output saved to: ${testPath}`;
            const results = parser.parse(stderr);
            
            assert.strictEqual(results.length, 1);
            assert.strictEqual(results[0].path, testPath);
        }
    }

    testWindowsPaths() {
        const parser = new PathParser();
        const testCases = [
            'C:\\temp\\file.log',
            'D:\\Users\\user\\Documents\\file.txt',
            'C:\\Program Files\\app\\log.txt',
            'E:\\data\\logs\\app-2023.log'
        ];
        
        for (const testPath of testCases) {
            const stderr = `Full output saved to: ${testPath}`;
            const results = parser.parse(stderr);
            
            assert.strictEqual(results.length, 1);
            // Path separators are normalized
            assert.strictEqual(results[0].path, testPath.replace(/[\/\\]+/g, path.sep));
        }
    }

    testRelativePaths() {
        const parser = new PathParser();
        const testCases = [
            './file.log',
            '../logs/app.log',
            'file.txt',
            'logs/app.log',
            './dir/subdir/file.log'
        ];
        
        for (const testPath of testCases) {
            const stderr = `Full output saved to: ${testPath}`;
            const results = parser.parse(stderr);
            
            assert.strictEqual(results.length, 1);
            assert.strictEqual(results[0].path, testPath.replace(/[\/\\]+/g, path.sep));
        }
    }

    testPathsWithSpaces() {
        const parser = new PathParser();
        const testCases = [
            '/tmp/file with spaces.log',
            'C:\\Users\\John Doe\\Documents\\my file.txt',
            './my project/build.log',
            '/var/log/app server.log'
        ];
        
        for (const testPath of testCases) {
            const stderr = `Full output saved to: ${testPath}`;
            const results = parser.parse(stderr);
            
            assert.strictEqual(results.length, 1);
            assert.strictEqual(results[0].path, testPath.replace(/[\/\\]+/g, path.sep));
        }
    }

    testUnicodePaths() {
        const parser = new PathParser();
        const testCases = [
            '/tmp/файл.log',  // Cyrillic
            '/tmp/文件.log',   // Chinese
            '/tmp/ファイル.log', // Japanese
            '/tmp/archivo-español.log', // Spanish
            '/tmp/tệp-tiếng-việt.log'   // Vietnamese
        ];
        
        for (const testPath of testCases) {
            const stderr = `Full output saved to: ${testPath}`;
            const results = parser.parse(stderr);
            
            assert.strictEqual(results.length, 1);
            assert.strictEqual(results[0].path, testPath);
        }
    }

    // Edge case tests

    testQuotedPaths() {
        const parser = new PathParser();
        
        // Double quotes
        const stderr1 = 'Full output saved to: "/tmp/file with spaces.log"';
        const results1 = parser.parse(stderr1);
        assert.strictEqual(results1.length, 1);
        assert.strictEqual(results1[0].path, '/tmp/file with spaces.log');
        
        // Single quotes
        const stderr2 = "Full output saved to: '/tmp/another file.log'";
        const results2 = parser.parse(stderr2);
        assert.strictEqual(results2.length, 1);
        assert.strictEqual(results2[0].path, '/tmp/another file.log');
    }

    testEscapedQuotes() {
        const parser = new PathParser();
        
        const stderr = 'Full output saved to: "/tmp/file\\"with\\"quotes.log"';
        const results = parser.parse(stderr);
        
        assert.strictEqual(results.length, 1);
        assert.strictEqual(results[0].path, '/tmp/file"with"quotes.log');
    }

    testMalformedMessages() {
        const parser = new PathParser();
        
        // Incomplete message
        const stderr1 = 'Full output saved to:';
        const results1 = parser.parse(stderr1);
        assert.strictEqual(results1.length, 0);
        
        // Missing colon
        const stderr2 = 'Full output saved /tmp/file.log';
        const results2 = parser.parse(stderr2);
        assert.strictEqual(results2.length, 0);
        
        // Wrong prefix
        const stderr3 = 'Output saved to: /tmp/file.log';
        const results3 = parser.parse(stderr3);
        assert.strictEqual(results3.length, 0);
    }

    testDuplicatePaths() {
        const parser = new PathParser();
        const stderr = `Full output saved to: /tmp/file.log
Full output saved to: /tmp/file.log
Full output saved to: /tmp/../tmp/file.log`;
        
        const results = parser.parse(stderr);
        
        // Should deduplicate based on resolved path
        assert.strictEqual(results.length, 1);
        assert.strictEqual(results[0].path, '/tmp/file.log');
    }

    testVeryLongPaths() {
        const parser = new PathParser();
        const longPath = '/tmp/' + 'a'.repeat(200) + '.log';
        const stderr = `Full output saved to: ${longPath}`;
        
        const results = parser.parse(stderr);
        assert.strictEqual(results.length, 1);
        assert.strictEqual(results[0].path, longPath);
    }

    testSpecialCharacters() {
        const parser = new PathParser();
        const testCases = [
            '/tmp/file-with-dashes.log',
            '/tmp/file_with_underscores.log',
            '/tmp/file.with.dots.log',
            '/tmp/file+plus+signs.log',
            '/tmp/file(parentheses).log'
        ];
        
        for (const testPath of testCases) {
            const stderr = `Full output saved to: ${testPath}`;
            const results = parser.parse(stderr);
            
            assert.strictEqual(results.length, 1);
            assert.strictEqual(results[0].path, testPath);
        }
    }

    // Multiple input tests

    testParseMultiple() {
        const parser = new PathParser();
        const stderrList = [
            'Full output saved to: /tmp/file1.log',
            'Full output saved to: /tmp/file2.log',
            'No capture here',
            'Full output saved to: /tmp/file3.log'
        ];
        
        const results = parser.parseMultiple(stderrList);
        
        assert.strictEqual(results.length, 3);
        assert.strictEqual(results[0].path, '/tmp/file1.log');
        assert.strictEqual(results[1].path, '/tmp/file2.log');
        assert.strictEqual(results[2].path, '/tmp/file3.log');
    }

    testParseMultipleWithErrors() {
        const parser = new PathParser();
        const stderrList = [
            'Full output saved to: /tmp/file1.log',
            null, // This will cause an error but should not stop processing
            'Full output saved to: /tmp/file2.log'
        ];
        
        // Should continue processing despite errors
        const results = parser.parseMultiple(stderrList);
        
        assert.strictEqual(results.length, 2);
        assert.strictEqual(results[0].path, '/tmp/file1.log');
        assert.strictEqual(results[1].path, '/tmp/file2.log');
    }

    // Utility method tests

    testHasCaptures() {
        const parser = new PathParser();
        
        assert.strictEqual(parser.hasCaptures('Full output saved to: /tmp/file.log'), true);
        assert.strictEqual(parser.hasCaptures('temp file preserved: /tmp/file.log'), true);
        assert.strictEqual(parser.hasCaptures('No captures here'), false);
        assert.strictEqual(parser.hasCaptures(''), false);
        assert.strictEqual(parser.hasCaptures(null), false);
    }

    testExtractPaths() {
        const parser = new PathParser();
        const stderr = `Full output saved to: /tmp/file1.log
Full output saved to: /tmp/file2.log`;
        
        const paths = parser.extractPaths(stderr);
        
        assert.deepStrictEqual(paths, ['/tmp/file1.log', '/tmp/file2.log']);
    }

    testGetStats() {
        const parser = new PathParser();
        
        // Initial stats
        const initialStats = parser.getStats();
        assert.strictEqual(initialStats.totalProcessed, 0);
        assert.strictEqual(initialStats.pathsExtracted, 0);
        assert.strictEqual(initialStats.errors, 0);
        
        // Parse some data
        parser.parse('Full output saved to: /tmp/file.log');
        
        const updatedStats = parser.getStats();
        assert.strictEqual(updatedStats.totalProcessed, 1);
        assert.strictEqual(updatedStats.pathsExtracted, 1);
        assert(updatedStats.lastProcessed instanceof Date);
    }

    testResetStats() {
        const parser = new PathParser();
        
        // Generate some stats
        parser.parse('Full output saved to: /tmp/file.log');
        assert(parser.getStats().totalProcessed > 0);
        
        // Reset and verify
        parser.resetStats();
        const stats = parser.getStats();
        assert.strictEqual(stats.totalProcessed, 0);
        assert.strictEqual(stats.pathsExtracted, 0);
        assert.strictEqual(stats.errors, 0);
        assert.strictEqual(stats.lastProcessed, null);
    }

    testFactoryMethod() {
        const parser = PathParser.create();
        
        assert(parser instanceof PathParser);
        assert.strictEqual(typeof parser.parse, 'function');
    }

    // Error handling tests

    testInvalidInput() {
        const parser = new PathParser();
        
        // Should throw TypeError for non-string input
        assert.throws(() => parser.parse(null), TypeError);
        assert.throws(() => parser.parse(undefined), TypeError);
        assert.throws(() => parser.parse(123), TypeError);
        assert.throws(() => parser.parse({}), TypeError);
        assert.throws(() => parser.parse([]), TypeError);
    }

    testTypeErrors() {
        const parser = new PathParser();
        
        // parseMultiple with non-array
        assert.throws(() => parser.parseMultiple('not an array'), TypeError);
        assert.throws(() => parser.parseMultiple(null), TypeError);
        assert.throws(() => parser.parseMultiple(123), TypeError);
    }

    // Secondary pattern tests

    testTempFilePreservedPattern() {
        const parser = new PathParser();
        
        const stderr = 'Command failed - temp file preserved: /tmp/preserved-file.log';
        const results = parser.parse(stderr);
        
        assert.strictEqual(results.length, 1);
        assert.strictEqual(results[0].path, '/tmp/preserved-file.log');
        assert.strictEqual(results[0].raw, 'temp file preserved: /tmp/preserved-file.log');
    }

    testMixedPatterns() {
        const parser = new PathParser();
        
        const stderr = `Build started
Full output saved to: /tmp/build.log
Error occurred
temp file preserved: /tmp/error.log
Done`;
        
        const results = parser.parse(stderr);
        
        assert.strictEqual(results.length, 2);
        assert.strictEqual(results[0].path, '/tmp/build.log');
        assert.strictEqual(results[1].path, '/tmp/error.log');
    }

    // Performance tests

    testLargeInput() {
        const parser = new PathParser();
        
        // Create large input with multiple captures
        const lines = [];
        for (let i = 0; i < 1000; i++) {
            lines.push(`Line ${i} of output`);
            if (i % 100 === 0) {
                lines.push(`Full output saved to: /tmp/file-${i}.log`);
            }
        }
        const largeStderr = lines.join('\n');
        
        const start = Date.now();
        const results = parser.parse(largeStderr);
        const duration = Date.now() - start;
        
        assert.strictEqual(results.length, 10); // Every 100th line
        assert(duration < 1000, `Parsing took too long: ${duration}ms`); // Should be fast
    }

    testRegexPerformance() {
        const parser = new PathParser();
        
        // Test regex performance with pathological input
        const pathologicalInput = 'Full output saved to: ' + 'a'.repeat(1000) + '\n'.repeat(100);
        
        const start = Date.now();
        parser.parse(pathologicalInput);
        const duration = Date.now() - start;
        
        assert(duration < 500, `Regex performance issue: ${duration}ms`);
    }

    /**
     * Print test results summary
     */
    printResults() {
        console.log(`\n📊 Test Results:`);
        console.log(`✅ Passed: ${this.results.passed}`);
        console.log(`❌ Failed: ${this.results.failed}`);
        
        if (this.results.errors.length > 0) {
            console.log('\n🐛 Errors:');
            this.results.errors.forEach(error => {
                console.log(`   ${error.test}: ${error.error}`);
            });
        }
        
        const total = this.results.passed + this.results.failed;
        const passRate = total > 0 ? ((this.results.passed / total) * 100).toFixed(1) : 0;
        console.log(`\n📈 Pass Rate: ${passRate}%`);
        
        if (this.results.failed === 0) {
            console.log('🎉 All tests passed!');
        }
    }
}

// Run tests if called directly
if (require.main === module) {
    const suite = new PathParserTestSuite();
    suite.runAllTests().then(results => {
        if (results.failed > 0) {
            process.exit(1);
        }
    }).catch(error => {
        console.error('Test suite failed:', error);
        process.exit(1);
    });
}

module.exports = PathParserTestSuite;