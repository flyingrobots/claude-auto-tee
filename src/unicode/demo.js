#!/usr/bin/env node
/**
 * Unicode Path Handler Demo
 * 
 * Demonstrates the capabilities of the Unicode path handler
 * for the PostToolUse hook implementation.
 */

const { UnicodeHandler } = require('./unicode-path-handler.js');
const PathParser = require('../parser/capture-path-parser.js');

console.log('=== Unicode Path Handler Demo ===');
console.log();

// Create instances
const handler = new UnicodeHandler();
const parser = new PathParser();

console.log('System Information:');
console.log(`Platform: ${handler.platform}`);
console.log(`Default Unicode Normalization: ${handler.defaultNormalization}`);
console.log(`Maximum Path Length: ${handler.maxPathLength}`);
console.log();

// Demo 1: Basic Unicode path handling
console.log('Demo 1: Basic Unicode Path Processing');
console.log('=====================================');

const samplePaths = [
    '/tmp/📝_capture_2025.txt',           // Emoji
    '/home/用户/输出.log',                 // CJK
    '/path/with/مجلد/file.txt',           // RTL Arabic
    '/café/naïve_résumé.txt'              // Diacritics
];

samplePaths.forEach(samplePath => {
    console.log(`\nProcessing: ${samplePath}`);
    
    const analysis = handler.analyzePath(samplePath);
    console.log(`  Normalized: ${analysis.normalized}`);
    console.log(`  Length: ${analysis.length} chars, ${analysis.byteLength} bytes`);
    console.log(`  Scripts: ${[
        analysis.containsEmoji ? 'Emoji' : null,
        analysis.containsCJK ? 'CJK' : null, 
        analysis.containsRTL ? 'RTL' : null
    ].filter(Boolean).join(', ') || 'Latin'}`);
    console.log(`  Shell safe: ${analysis.shellEncoded.bash}`);
});

// Demo 2: Integration with PathParser
console.log('\n\nDemo 2: PathParser Integration');
console.log('==============================');

const stderrExamples = [
    'Command executed successfully\nFull output saved to: /tmp/🎉_test_output.log\nProcess completed',
    'Processing data...\nFull output saved to: /home/用户/分析_结果.txt',
    'Error: Connection timeout\nFull output saved to: "/workspace/مشروع/نتائج.log"'
];

stderrExamples.forEach((stderr, index) => {
    console.log(`\nStderr Example ${index + 1}:`);
    console.log(`Input: ${stderr.replace(/\n/g, '\\n')}`);
    
    const captures = parser.parse(stderr);
    if (captures.length > 0) {
        const capture = captures[0];
        console.log(`  Captured path: ${capture.path}`);
        
        const analysis = handler.analyzePath(capture.path);
        console.log(`  Unicode analysis:`);
        console.log(`    - Normalized: ${analysis.normalized}`);
        console.log(`    - Contains special scripts: ${[
            analysis.containsEmoji ? 'Emoji' : null,
            analysis.containsCJK ? 'CJK' : null,
            analysis.containsRTL ? 'RTL' : null
        ].filter(Boolean).join(', ') || 'None'}`);
        console.log(`    - Shell-safe encoding: ${analysis.shellEncoded.bash}`);
    } else {
        console.log('  No paths captured');
    }
});

// Demo 3: Shell encoding for different environments
console.log('\n\nDemo 3: Cross-Platform Shell Encoding');
console.log('=====================================');

const complexPath = '/project/测试_🔥_café_مجلد/output.log';
console.log(`Complex path: ${complexPath}`);

const shellEncodings = {
    'Bash (Linux/macOS)': handler.encodeForShell(complexPath, 'bash'),
    'CMD (Windows)': handler.encodeForShell(complexPath, 'cmd'),
    'PowerShell': handler.encodeForShell(complexPath, 'powershell')
};

Object.entries(shellEncodings).forEach(([shell, encoded]) => {
    console.log(`  ${shell}: ${encoded}`);
});

// Demo 4: Error handling showcase
console.log('\n\nDemo 4: Error Handling');
console.log('======================');

const problematicPaths = [
    null,                               // Null input
    '',                                // Empty string  
    '/path/with/null\x00byte.txt',     // Null bytes
    '/path/' + 'a'.repeat(5000) + '.txt' // Too long
];

problematicPaths.forEach((badPath, index) => {
    try {
        const result = handler.normalizePath(badPath);
        console.log(`  Test ${index + 1}: ❌ Should have failed for: ${JSON.stringify(badPath)}`);
    } catch (error) {
        console.log(`  Test ${index + 1}: ✓ Correctly rejected: ${error.name} - ${error.message.substring(0, 50)}...`);
    }
});

console.log('\n=== Demo Complete ===');
console.log();
console.log('The Unicode Path Handler successfully:');
console.log('✓ Handles emoji, CJK, RTL, and diacritic characters in paths');
console.log('✓ Normalizes paths according to filesystem requirements');
console.log('✓ Provides shell-safe encoding for different environments');
console.log('✓ Integrates seamlessly with the PathParser');
console.log('✓ Validates and sanitizes paths for security');
console.log('✓ Supports cross-platform path handling');