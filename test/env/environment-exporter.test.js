#!/usr/bin/env node
/**
 * Tests for Environment Exporter
 * 
 * Comprehensive test suite covering:
 * - Basic functionality
 * - Shell compatibility (bash, zsh, fish)
 * - Path escaping and special characters
 * - Atomic operations
 * - Edge cases and error handling
 * - Integration tests with actual shell execution
 */

const { execSync, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const assert = require('assert');
const os = require('os');

const {
    EnvExporter,
    EnvironmentExportError,
    ShellCompatibilityError,
    PathEscapingError
} = require('../../src/env/environment-exporter.js');

// Test configuration
const TEMP_DIR = fs.mkdtempSync(path.join(os.tmpdir(), 'claude-env-test-'));
const TEST_FILES = [];

// Cleanup helper
function cleanup() {
    // Remove test files
    TEST_FILES.forEach(file => {
        try {
            if (fs.existsSync(file)) {
                fs.unlinkSync(file);
            }
        } catch (error) {
            // Ignore cleanup errors
        }
    });
    
    // Remove temp directory
    try {
        if (fs.existsSync(TEMP_DIR)) {
            fs.rmSync(TEMP_DIR, { recursive: true, force: true });
        }
    } catch (error) {
        // Ignore cleanup errors
    }
}

// Helper to create test files
function createTestFile(filename, content = 'test content') {
    const filePath = path.join(TEMP_DIR, filename);
    fs.writeFileSync(filePath, content);
    TEST_FILES.push(filePath);
    return filePath;
}

// Helper to test shell command execution
async function testShellCommand(command, shell = 'bash', timeout = 5000) {
    return new Promise((resolve, reject) => {
        const child = spawn(shell, ['-c', command], {
            stdio: ['pipe', 'pipe', 'pipe'],
            timeout: timeout
        });
        
        let stdout = '';
        let stderr = '';
        
        child.stdout.on('data', (data) => stdout += data.toString());
        child.stderr.on('data', (data) => stderr += data.toString());
        
        child.on('close', (code) => {
            resolve({ code, stdout, stderr });
        });
        
        child.on('error', (error) => {
            reject(error);
        });
        
        // Timeout handling
        setTimeout(() => {
            child.kill('SIGTERM');
            reject(new Error(`Shell command timed out after ${timeout}ms`));
        }, timeout);
    });
}

// Test runner
async function runTests() {
    console.log('🧪 Running Environment Exporter Tests\n');
    
    const tests = [
        // Basic functionality tests
        testConstructor,
        testAddCapture,
        testGetLastCapture,
        testGetCaptures,
        testClearHistory,
        
        // Shell compatibility tests
        testBashExports,
        testZshExports,
        testFishExports,
        testShellValidation,
        
        // Path escaping tests
        testBasicPathEscaping,
        testSpecialCharacterEscaping,
        testUnicodePathEscaping,
        testLongPathEscaping,
        
        // JSON escaping tests
        testJsonEscaping,
        
        // Atomic operations tests
        testAtomicOperations,
        testNonAtomicOperations,
        
        // History management tests
        testHistoryLimits,
        testUpdateCapture,
        testRemoveCapture,
        
        // Export generation tests
        testLastCaptureExport,
        testCapturesExport,
        testAllExports,
        testExportScript,
        testUnsetCommands,
        
        // Error handling tests
        testErrorTypes,
        testInvalidInputs,
        testFileNotFound,
        
        // Integration tests
        testBashIntegration,
        testEnvironmentVariableAccess,
        testMultipleShellTypes
    ];
    
    let passed = 0;
    let failed = 0;
    
    for (const test of tests) {
        try {
            await test();
            console.log(`✅ ${test.name}`);
            passed++;
        } catch (error) {
            console.log(`❌ ${test.name}: ${error.message}`);
            failed++;
        }
    }
    
    console.log(`\n📊 Results: ${passed} passed, ${failed} failed`);
    
    // Cleanup
    cleanup();
    
    if (failed > 0) {
        process.exit(1);
    }
}

// Basic functionality tests

async function testConstructor() {
    const exporter = new EnvExporter();
    assert.strictEqual(exporter.maxCapturesHistory, 10, 'Default max captures should be 10');
    assert.strictEqual(exporter.enableAtomicOperations, true, 'Atomic operations should be enabled by default');
    
    const customExporter = new EnvExporter({
        maxCapturesHistory: 5,
        enableAtomicOperations: false,
        verbose: true
    });
    assert.strictEqual(customExporter.maxCapturesHistory, 5, 'Custom max captures should be respected');
    assert.strictEqual(customExporter.enableAtomicOperations, false, 'Custom atomic operations setting should be respected');
}

async function testAddCapture() {
    const exporter = new EnvExporter();
    const testFile = createTestFile('test1.log', 'test content');
    
    const capture = exporter.addCapture(testFile, { testMode: false });
    
    assert.strictEqual(capture.path, path.resolve(testFile), 'Capture path should be absolute');
    assert(capture.timestamp, 'Capture should have timestamp');
    assert.strictEqual(typeof capture.size, 'number', 'Capture should have size');
    assert.strictEqual(exporter.capturesHistory.length, 1, 'History should contain one capture');
}

async function testGetLastCapture() {
    const exporter = new EnvExporter();
    
    // Test with empty history
    assert.strictEqual(exporter.getLastCapture(), null, 'Should return null for empty history');
    
    // Add captures
    const testFile1 = createTestFile('test1.log');
    const testFile2 = createTestFile('test2.log');
    
    exporter.addCapture(testFile1, { testMode: true });
    const capture1 = exporter.getLastCapture();
    assert.strictEqual(capture1.path, path.resolve(testFile1), 'Should return first capture');
    
    exporter.addCapture(testFile2, { testMode: true });
    const capture2 = exporter.getLastCapture();
    assert.strictEqual(capture2.path, path.resolve(testFile2), 'Should return most recent capture');
}

async function testGetCaptures() {
    const exporter = new EnvExporter();
    const testFile = createTestFile('test.log');
    
    // Test empty captures
    const emptyCapturesCopy = exporter.getCaptures();
    assert.strictEqual(emptyCapturesCopy.length, 0, 'Should return empty array');
    
    // Add capture and test immutability
    exporter.addCapture(testFile, { testMode: true });
    const capturesCopy = exporter.getCaptures();
    assert.strictEqual(capturesCopy.length, 1, 'Should return copy with captures');
    
    // Modify copy and ensure original is unchanged
    capturesCopy.push({ fake: true });
    assert.strictEqual(exporter.getCaptures().length, 1, 'Original should remain unchanged');
}

async function testClearHistory() {
    const exporter = new EnvExporter();
    const testFile = createTestFile('test.log');
    
    exporter.addCapture(testFile, { testMode: true });
    assert.strictEqual(exporter.capturesHistory.length, 1, 'Should have one capture');
    
    exporter.clearHistory();
    assert.strictEqual(exporter.capturesHistory.length, 0, 'History should be empty after clear');
    assert.strictEqual(exporter.getLastCapture(), null, 'Last capture should be null after clear');
}

// Shell compatibility tests

async function testBashExports() {
    const exporter = new EnvExporter();
    const testFile = createTestFile('test.log');
    
    exporter.addCapture(testFile, { testMode: true });
    
    const lastCaptureExport = exporter.generateLastCaptureExport('bash');
    assert(lastCaptureExport.startsWith('export CLAUDE_LAST_CAPTURE='), 'Should generate bash export');
    assert(lastCaptureExport.includes(testFile), 'Should include file path');
    
    const capturesExport = exporter.generateCapturesExport('bash');
    assert(capturesExport.startsWith('export CLAUDE_CAPTURES='), 'Should generate bash captures export');
}

async function testZshExports() {
    const exporter = new EnvExporter();
    const testFile = createTestFile('test.log');
    
    exporter.addCapture(testFile, { testMode: true });
    
    const lastCaptureExport = exporter.generateLastCaptureExport('zsh');
    assert(lastCaptureExport.startsWith('export CLAUDE_LAST_CAPTURE='), 'Should generate zsh export');
    
    const capturesExport = exporter.generateCapturesExport('zsh');
    assert(capturesExport.startsWith('export CLAUDE_CAPTURES='), 'Should generate zsh captures export');
}

async function testFishExports() {
    const exporter = new EnvExporter();
    const testFile = createTestFile('test.log');
    
    exporter.addCapture(testFile, { testMode: true });
    
    const lastCaptureExport = exporter.generateLastCaptureExport('fish');
    assert(lastCaptureExport.startsWith('set -gx CLAUDE_LAST_CAPTURE '), 'Should generate fish export');
    
    const capturesExport = exporter.generateCapturesExport('fish');
    assert(capturesExport.startsWith('set -gx CLAUDE_CAPTURES '), 'Should generate fish captures export');
}

async function testShellValidation() {
    const exporter = new EnvExporter();
    
    // Test valid shells
    const validShells = ['bash', 'zsh', 'fish', 'sh'];
    for (const shell of validShells) {
        assert.doesNotThrow(() => exporter.validateShellType(shell), `Should accept ${shell}`);
    }
    
    // Test invalid shells
    assert.throws(() => exporter.validateShellType('invalid'), ShellCompatibilityError, 'Should reject invalid shell');
    assert.throws(() => exporter.validateShellType(''), ShellCompatibilityError, 'Should reject empty shell');
    assert.throws(() => exporter.validateShellType(null), ShellCompatibilityError, 'Should reject null shell');
}

// Path escaping tests

async function testBasicPathEscaping() {
    const exporter = new EnvExporter();
    
    // Test basic path
    const basicPath = '/tmp/test.log';
    const escaped = exporter.escapePath(basicPath, 'bash');
    assert(escaped.startsWith('"') && escaped.endsWith('"'), 'Should wrap in quotes');
    assert(escaped.includes(basicPath), 'Should contain original path');
}

async function testSpecialCharacterEscaping() {
    const exporter = new EnvExporter();
    
    // Create test files with special characters
    const specialPaths = [
        'test with spaces.log',
        'test"with"quotes.log',
        'test$with$dollar.log',
        'test`with`backticks.log',
        'test!with!exclamation.log'
    ];
    
    for (const filename of specialPaths) {
        const testFile = createTestFile(filename);
        
        // Test bash escaping
        const bashEscaped = exporter.escapePath(testFile, 'bash');
        assert(bashEscaped.includes('\\"') || !filename.includes('"') || bashEscaped.startsWith('"'), 
               `Bash escaping should handle special characters in ${filename}`);
        
        // Test fish escaping
        const fishEscaped = exporter.escapePath(testFile, 'fish');
        assert(fishEscaped.startsWith("'") && fishEscaped.endsWith("'"), 
               `Fish escaping should use single quotes for ${filename}`);
    }
}

async function testUnicodePathEscaping() {
    const exporter = new EnvExporter();
    
    // Test unicode characters
    const unicodeFile = createTestFile('测试文件.log');
    
    const bashEscaped = exporter.escapePath(unicodeFile, 'bash');
    assert(bashEscaped.includes('测试文件'), 'Should preserve unicode characters');
    
    const fishEscaped = exporter.escapePath(unicodeFile, 'fish');
    assert(fishEscaped.includes('测试文件'), 'Fish should preserve unicode characters');
}

async function testLongPathEscaping() {
    const exporter = new EnvExporter();
    
    // Create a file with a very long name
    const longName = 'a'.repeat(200) + '.log';
    const longFile = createTestFile(longName);
    
    const escaped = exporter.escapePath(longFile, 'bash');
    assert(escaped.length > 200, 'Should handle long paths');
    assert(escaped.includes(longName), 'Should contain long filename');
}

// JSON escaping tests

async function testJsonEscaping() {
    const exporter = new EnvExporter();
    
    const complexJson = JSON.stringify({
        path: '/tmp/test "quoted" path.log',
        content: 'Some $pecial characters and `backticks`',
        special: 'Line\nBreak\tTab'
    });
    
    // Test bash JSON escaping
    const bashEscaped = exporter.escapeJsonForShell(complexJson, 'bash');
    assert(bashEscaped.startsWith('"') && bashEscaped.endsWith('"'), 'Bash JSON should be double quoted');
    
    // Test fish JSON escaping
    const fishEscaped = exporter.escapeJsonForShell(complexJson, 'fish');
    assert(fishEscaped.startsWith("'") && fishEscaped.endsWith("'"), 'Fish JSON should be single quoted');
}

// Atomic operations tests

async function testAtomicOperations() {
    const exporter = new EnvExporter({ enableAtomicOperations: true });
    const testFile = createTestFile('test.log');
    
    // Test atomic add
    exporter.addCapture(testFile, { testMode: true });
    const originalHistory = exporter.capturesHistory;
    
    // Add another capture
    const testFile2 = createTestFile('test2.log');
    exporter.addCapture(testFile2, { testMode: true });
    
    // Original array should be replaced, not modified
    assert.notStrictEqual(exporter.capturesHistory, originalHistory, 'History array should be replaced atomically');
    assert.strictEqual(exporter.capturesHistory.length, 2, 'Should have two captures');
}

async function testNonAtomicOperations() {
    const exporter = new EnvExporter({ enableAtomicOperations: false });
    const testFile = createTestFile('test.log');
    
    exporter.addCapture(testFile, { testMode: true });
    const originalHistory = exporter.capturesHistory;
    
    // Add another capture
    const testFile2 = createTestFile('test2.log');
    exporter.addCapture(testFile2, { testMode: true });
    
    // In non-atomic mode, same array should be modified
    assert.strictEqual(exporter.capturesHistory, originalHistory, 'History array should be the same object in non-atomic mode');
    assert.strictEqual(exporter.capturesHistory.length, 2, 'Should have two captures');
}

// History management tests

async function testHistoryLimits() {
    const exporter = new EnvExporter({ maxCapturesHistory: 3 });
    
    // Add more captures than the limit
    for (let i = 1; i <= 5; i++) {
        const testFile = createTestFile(`test${i}.log`);
        exporter.addCapture(testFile, { testMode: true });
    }
    
    assert.strictEqual(exporter.capturesHistory.length, 3, 'Should respect history limit');
    
    // Check that the most recent captures are kept
    const lastCapture = exporter.getLastCapture();
    assert(lastCapture.path.includes('test5.log'), 'Should keep most recent capture');
}

async function testUpdateCapture() {
    const exporter = new EnvExporter();
    const testFile = createTestFile('test.log');
    
    exporter.addCapture(testFile, { testMode: true, originalData: 'test' });
    
    // Update the capture
    exporter.updateCapture(testFile, { updatedData: 'updated', size: 1000 });
    
    const captures = exporter.getCaptures();
    assert.strictEqual(captures.length, 1, 'Should still have one capture');
    assert.strictEqual(captures[0].updatedData, 'updated', 'Should have updated data');
    assert.strictEqual(captures[0].originalData, 'test', 'Should preserve original data');
    assert(captures[0].updatedAt, 'Should have updatedAt timestamp');
}

async function testRemoveCapture() {
    const exporter = new EnvExporter();
    const testFile1 = createTestFile('test1.log');
    const testFile2 = createTestFile('test2.log');
    
    exporter.addCapture(testFile1, { testMode: true });
    exporter.addCapture(testFile2, { testMode: true });
    
    assert.strictEqual(exporter.capturesHistory.length, 2, 'Should have two captures');
    
    const removed = exporter.removeCapture(testFile1);
    assert.strictEqual(removed, true, 'Should return true for successful removal');
    assert.strictEqual(exporter.capturesHistory.length, 1, 'Should have one capture after removal');
    assert(exporter.getLastCapture().path.includes('test2.log'), 'Should keep the right capture');
    
    const removedAgain = exporter.removeCapture(testFile1);
    assert.strictEqual(removedAgain, false, 'Should return false for non-existent capture');
}

// Export generation tests

async function testLastCaptureExport() {
    const exporter = new EnvExporter();
    
    // Test with no captures
    const emptyExport = exporter.generateLastCaptureExport('bash');
    assert.strictEqual(emptyExport, 'unset CLAUDE_LAST_CAPTURE', 'Should unset when no captures');
    
    // Test with capture
    const testFile = createTestFile('test.log');
    exporter.addCapture(testFile, { testMode: true });
    
    const bashExport = exporter.generateLastCaptureExport('bash');
    assert(bashExport.startsWith('export CLAUDE_LAST_CAPTURE='), 'Should export for bash');
    assert(bashExport.includes(testFile), 'Should include file path');
    
    const fishExport = exporter.generateLastCaptureExport('fish');
    assert(fishExport.startsWith('set -gx CLAUDE_LAST_CAPTURE '), 'Should set for fish');
}

async function testCapturesExport() {
    const exporter = new EnvExporter();
    
    // Test with no captures
    const emptyExport = exporter.generateCapturesExport('bash');
    assert.strictEqual(emptyExport, 'unset CLAUDE_CAPTURES', 'Should unset when no captures');
    
    // Test with captures
    const testFile1 = createTestFile('test1.log');
    const testFile2 = createTestFile('test2.log');
    
    exporter.addCapture(testFile1, { testMode: true });
    exporter.addCapture(testFile2, { testMode: true });
    
    const bashExport = exporter.generateCapturesExport('bash');
    assert(bashExport.startsWith('export CLAUDE_CAPTURES='), 'Should export for bash');
    assert(bashExport.includes(testFile1) || bashExport.includes('test1.log'), 'Should include first file');
    assert(bashExport.includes(testFile2) || bashExport.includes('test2.log'), 'Should include second file');
    
    // Verify it's valid JSON
    const jsonMatch = bashExport.match(/export CLAUDE_CAPTURES="(.*)"/);
    if (jsonMatch) {
        const jsonString = jsonMatch[1].replace(/\\"/g, '"').replace(/\\\\/g, '\\');
        assert.doesNotThrow(() => JSON.parse(jsonString), 'Should generate valid JSON');
    }
}

async function testAllExports() {
    const exporter = new EnvExporter();
    const testFile = createTestFile('test.log');
    
    exporter.addCapture(testFile, { testMode: true });
    
    const allExports = exporter.generateAllExports('bash');
    assert.strictEqual(allExports.shell, 'bash', 'Should return shell type');
    assert(allExports.lastCapture, 'Should have last capture export');
    assert(allExports.captures, 'Should have captures export');
    assert(allExports.lastCapture.includes('CLAUDE_LAST_CAPTURE'), 'Should export last capture');
    assert(allExports.captures.includes('CLAUDE_CAPTURES'), 'Should export captures');
}

async function testExportScript() {
    const exporter = new EnvExporter();
    const testFile = createTestFile('test.log');
    
    exporter.addCapture(testFile, { testMode: true });
    
    const bashScript = exporter.generateExportScript('bash');
    assert(bashScript.startsWith('#!/usr/bin/env bash'), 'Should have bash shebang');
    assert(bashScript.includes('# Claude Auto-Tee Environment Variables Export'), 'Should have header comment');
    assert(bashScript.includes('export CLAUDE_LAST_CAPTURE='), 'Should include last capture export');
    assert(bashScript.includes('export CLAUDE_CAPTURES='), 'Should include captures export');
    
    const fishScript = exporter.generateExportScript('fish');
    assert(fishScript.startsWith('#!/usr/bin/env fish'), 'Should have fish shebang');
    assert(fishScript.includes('set -gx CLAUDE_LAST_CAPTURE'), 'Should include fish last capture export');
}

async function testUnsetCommands() {
    const exporter = new EnvExporter();
    
    const bashUnset = exporter.generateUnsetCommand('TEST_VAR', 'bash');
    assert.strictEqual(bashUnset, 'unset TEST_VAR', 'Should generate bash unset');
    
    const fishUnset = exporter.generateUnsetCommand('TEST_VAR', 'fish');
    assert.strictEqual(fishUnset, 'set -e TEST_VAR', 'Should generate fish unset');
}

// Error handling tests

async function testErrorTypes() {
    const exporter = new EnvExporter();
    
    // Test error type hierarchy
    try {
        exporter.validateShellType('invalid');
        assert.fail('Should throw error');
    } catch (error) {
        assert(error instanceof ShellCompatibilityError, 'Should be ShellCompatibilityError');
        assert(error instanceof EnvironmentExportError, 'Should be EnvironmentExportError');
        assert.strictEqual(error.shell, 'invalid', 'Should include shell info');
    }
    
    try {
        exporter.escapePath('', 'bash');
        assert.fail('Should throw error');
    } catch (error) {
        assert(error instanceof PathEscapingError, 'Should be PathEscapingError');
        assert(error instanceof EnvironmentExportError, 'Should be EnvironmentExportError');
    }
}

async function testInvalidInputs() {
    const exporter = new EnvExporter();
    
    // Test invalid path escaping
    assert.throws(() => exporter.escapePath(null), PathEscapingError, 'Should reject null path');
    assert.throws(() => exporter.escapePath(''), PathEscapingError, 'Should reject empty path');
    
    // Test invalid capture operations
    assert.throws(() => exporter.addCapture(''), EnvironmentExportError, 'Should reject empty capture path');
    assert.throws(() => exporter.updateCapture(''), EnvironmentExportError, 'Should reject empty update path');
    assert.throws(() => exporter.removeCapture(''), EnvironmentExportError, 'Should reject empty remove path');
}

async function testFileNotFound() {
    const exporter = new EnvExporter();
    const nonExistentFile = path.join(TEMP_DIR, 'non-existent-file.log');
    
    // Should throw when file doesn't exist and not in test mode
    assert.throws(() => exporter.addCapture(nonExistentFile), EnvironmentExportError, 'Should reject non-existent file');
    
    // Should work in test mode
    assert.doesNotThrow(() => exporter.addCapture(nonExistentFile, { testMode: true }), 'Should accept non-existent file in test mode');
}

// Integration tests

async function testBashIntegration() {
    const exporter = new EnvExporter();
    const testFile = createTestFile('integration-test.log', 'integration test content');
    
    exporter.addCapture(testFile, { testMode: false });
    
    const exportScript = exporter.generateExportScript('bash');
    
    // Write script to temp file
    const scriptPath = path.join(TEMP_DIR, 'test-export.sh');
    fs.writeFileSync(scriptPath, exportScript);
    fs.chmodSync(scriptPath, 0o755);
    
    try {
        // Test that the script executes without error and sources the environment
        const testCommand = `source ${scriptPath} && echo "CLAUDE_LAST_CAPTURE=$CLAUDE_LAST_CAPTURE"`;
        const result = await testShellCommand(testCommand, 'bash');
        
        assert.strictEqual(result.code, 0, 'Export script should execute successfully');
        assert(result.stdout.includes('CLAUDE_LAST_CAPTURE='), 'Should set CLAUDE_LAST_CAPTURE');
        assert(result.stdout.includes(path.basename(testFile)) || result.stdout.includes(testFile), 'Should include test file path');
    } catch (error) {
        // If bash is not available, skip this test
        if (error.code === 'ENOENT') {
            console.log('  ⚠️  Bash not available, skipping integration test');
            return;
        }
        throw error;
    }
}

async function testEnvironmentVariableAccess() {
    const exporter = new EnvExporter();
    const testFile = createTestFile('env-access-test.log');
    
    exporter.addCapture(testFile, { testMode: true });
    
    const bashExport = exporter.generateLastCaptureExport('bash');
    
    try {
        // Test that we can access the environment variable after export
        const testCommand = `${bashExport} && test -n "$CLAUDE_LAST_CAPTURE" && echo "SUCCESS: $CLAUDE_LAST_CAPTURE"`;
        const result = await testShellCommand(testCommand, 'bash');
        
        assert.strictEqual(result.code, 0, 'Environment variable should be accessible');
        assert(result.stdout.includes('SUCCESS:'), 'Should confirm variable is set');
        assert(result.stdout.includes(testFile), 'Should include file path');
    } catch (error) {
        if (error.code === 'ENOENT') {
            console.log('  ⚠️  Bash not available, skipping environment variable access test');
            return;
        }
        throw error;
    }
}

async function testMultipleShellTypes() {
    const exporter = new EnvExporter();
    const testFile = createTestFile('multi-shell-test.log');
    
    exporter.addCapture(testFile, { testMode: true });
    
    const shells = ['bash', 'sh'];  // Test with commonly available shells
    
    for (const shell of shells) {
        try {
            const exportCommand = exporter.generateLastCaptureExport(shell);
            const testCommand = `${exportCommand} && test -n "$CLAUDE_LAST_CAPTURE" && echo "SUCCESS-${shell.toUpperCase()}"`;
            
            const result = await testShellCommand(testCommand, shell);
            assert.strictEqual(result.code, 0, `${shell} export should work`);
            assert(result.stdout.includes(`SUCCESS-${shell.toUpperCase()}`), `${shell} should confirm variable is set`);
        } catch (error) {
            if (error.code === 'ENOENT') {
                console.log(`  ⚠️  ${shell} not available, skipping test for this shell`);
                continue;
            }
            throw error;
        }
    }
}

// Run tests if called directly
if (require.main === module) {
    // Set up cleanup on exit
    process.on('exit', cleanup);
    process.on('SIGINT', cleanup);
    process.on('SIGTERM', cleanup);
    
    runTests().catch((error) => {
        console.error('Test runner error:', error);
        cleanup();
        process.exit(1);
    });
}

module.exports = { runTests };