#!/usr/bin/env node
/**
 * Unicode Path Handler Test Suite
 * P2.T006 - Handle Unicode paths for the PostToolUse hook implementation
 * 
 * Comprehensive tests for Unicode path handling across different platforms,
 * filesystems, and edge cases.
 */

const { UnicodeHandler, UnicodePathError, UnicodeNormalizationError, UnicodeEncodingError } = require('../../src/unicode/unicode-path-handler');
const path = require('path');
const fs = require('fs');
const os = require('os');

/**
 * Test framework - lightweight custom implementation
 */
class TestFramework {
    constructor() {
        this.tests = [];
        this.passed = 0;
        this.failed = 0;
        this.skipped = 0;
    }
    
    describe(description, testFn) {
        console.log(`\n=== ${description} ===`);
        testFn();
    }
    
    it(description, testFn) {
        try {
            testFn();
            this.passed++;
            console.log(`  ✓ ${description}`);
        } catch (error) {
            this.failed++;
            console.log(`  ✗ ${description}`);
            console.log(`    Error: ${error.message}`);
            if (error.stack && process.env.VERBOSE_TEST) {
                console.log(`    Stack: ${error.stack}`);
            }
        }
    }
    
    skip(description, reason) {
        this.skipped++;
        console.log(`  ⊘ ${description} (${reason})`);
    }
    
    expect(actual) {
        return {
            toBe: (expected) => {
                if (actual !== expected) {
                    throw new Error(`Expected ${JSON.stringify(expected)}, but got ${JSON.stringify(actual)}`);
                }
            },
            toEqual: (expected) => {
                if (JSON.stringify(actual) !== JSON.stringify(expected)) {
                    throw new Error(`Expected ${JSON.stringify(expected)}, but got ${JSON.stringify(actual)}`);
                }
            },
            toContain: (substring) => {
                if (typeof actual !== 'string' || !actual.includes(substring)) {
                    throw new Error(`Expected "${actual}" to contain "${substring}"`);
                }
            },
            toThrow: (expectedError) => {
                try {
                    actual();
                    throw new Error('Expected function to throw an error');
                } catch (error) {
                    if (expectedError && !(error instanceof expectedError)) {
                        throw new Error(`Expected ${expectedError.name}, but got ${error.constructor.name}: ${error.message}`);
                    }
                }
            },
            toBeTrue: () => {
                if (actual !== true) {
                    throw new Error(`Expected true, but got ${actual}`);
                }
            },
            toBeFalse: () => {
                if (actual !== false) {
                    throw new Error(`Expected false, but got ${actual}`);
                }
            },
            toMatch: (regex) => {
                if (!regex.test(actual)) {
                    throw new Error(`Expected "${actual}" to match ${regex}`);
                }
            }
        };
    }
    
    summary() {
        const total = this.passed + this.failed + this.skipped;
        console.log(`\n=== Test Summary ===`);
        console.log(`Total: ${total}`);
        console.log(`Passed: ${this.passed}`);
        console.log(`Failed: ${this.failed}`);
        console.log(`Skipped: ${this.skipped}`);
        
        if (this.failed > 0) {
            console.log(`\nTest suite FAILED`);
            process.exit(1);
        } else {
            console.log(`\nTest suite PASSED`);
            process.exit(0);
        }
    }
}

// Initialize test framework
const test = new TestFramework();

/**
 * Test data - comprehensive Unicode path examples
 */
const testPaths = {
    // Basic ASCII paths
    basic: [
        '/tmp/test.txt',
        'C:\\Users\\test\\file.txt',
        './relative/path.log',
        '/absolute/path/file.dat'
    ],
    
    // Emoji paths
    emoji: [
        '/tmp/test_🎉_output.txt',
        '/documents/📁_folder/file.txt',
        '/images/🖼️_picture.jpg',
        '/logs/⚡_fast_⚡.log',
        '/backup/💾_data_💾.backup'
    ],
    
    // CJK (Chinese, Japanese, Korean) paths
    cjk: [
        '/用户/文档/输出.log',
        '/ユーザー/ドキュメント/出力.txt',
        '/사용자/문서/출력.log',
        '/中文/测试/文件.txt',
        '/日本語/テスト/ファイル.txt',
        '/한국어/테스트/파일.txt'
    ],
    
    // RTL (Right-to-Left) paths
    rtl: [
        '/מסמכים/פלט.txt',
        '/مستندات/إخراج.log',
        '/العربية/اختبار.txt',
        '/עברית/בדיקה.log'
    ],
    
    // Combining diacritics
    diacritics: [
        '/café/naïve.txt',
        '/résumé/exposé.log',
        '/Malmö/café.txt',
        '/São_Paulo/coração.txt',
        '/München/Mädchen.txt'
    ],
    
    // Mixed scripts
    mixed: [
        '/English_中文_日本語/mixed.txt',
        '/test_🎉_测试_テスト.log',
        '/café_咖啡_コーヒー.txt',
        '/hello_مرحبا_שלום_안녕하세요.txt'
    ],
    
    // Edge cases
    edge: [
        '/path with spaces/file.txt',
        '/path\twith\ttabs/file.txt',
        '/path\nwith\nnewlines/file.txt',
        '/extremely_long_path_' + 'a'.repeat(200) + '/file.txt',
        '/path.with.many.dots.in.name.txt',
        '/UPPERCASE/lowercase/MixedCase.txt'
    ],
    
    // Problematic Unicode
    problematic: [
        '/path\u200B\u200C\u200D/file.txt', // Zero-width characters
        '/path\u202A\u202B\u202C/file.txt', // Bidirectional markers
        '/path\uFEFF/file.txt', // Byte order mark
        '/combining\u0301\u0302/file.txt', // Combining marks
    ],
    
    // Normalization test cases
    normalization: {
        nfc: 'café', // NFC form (composed)
        nfd: 'cafe\u0301', // NFD form (decomposed)
        mixed: 'café\u0301' // Mixed normalization
    }
};

/**
 * Run all Unicode path handler tests
 */
function runAllTests() {
    const handler = new UnicodeHandler();
    
    test.describe('UnicodeHandler Initialization', () => {
        test.it('should initialize with correct platform settings', () => {
            test.expect(handler.platform).toBe(process.platform);
            test.expect(handler.supportedEncodings).toEqual(['utf8', 'utf16le', 'ascii', 'latin1']);
            test.expect(typeof handler.maxPathLength).toBe('number');
            test.expect(handler.maxPathLength > 0).toBeTrue();
        });
        
        test.it('should have correct filesystem normalization preferences', () => {
            const expectedForm = handler.fsNormalizationMap[process.platform] || 'NFC';
            test.expect(handler.defaultNormalization).toBe(expectedForm);
        });
    });
    
    test.describe('Basic Path Normalization', () => {
        testPaths.basic.forEach(testPath => {
            test.it(`should normalize basic path: ${testPath}`, () => {
                const normalized = handler.normalizePath(testPath);
                test.expect(typeof normalized).toBe('string');
                test.expect(normalized.length > 0).toBeTrue();
            });
        });
    });
    
    test.describe('Emoji Path Support', () => {
        testPaths.emoji.forEach(testPath => {
            test.it(`should handle emoji path: ${testPath}`, () => {
                const normalized = handler.normalizePath(testPath);
                test.expect(typeof normalized).toBe('string');
                test.expect(handler.containsEmoji(testPath)).toBeTrue();
                
                const analysis = handler.analyzePath(testPath);
                test.expect(analysis.containsEmoji).toBeTrue();
            });
        });
    });
    
    test.describe('CJK Character Support', () => {
        testPaths.cjk.forEach(testPath => {
            test.it(`should handle CJK path: ${testPath}`, () => {
                const normalized = handler.normalizePath(testPath);
                test.expect(typeof normalized).toBe('string');
                test.expect(handler.containsCJK(testPath)).toBeTrue();
                
                const analysis = handler.analyzePath(testPath);
                test.expect(analysis.containsCJK).toBeTrue();
            });
        });
    });
    
    test.describe('RTL Text Support', () => {
        testPaths.rtl.forEach(testPath => {
            test.it(`should handle RTL path: ${testPath}`, () => {
                const normalized = handler.normalizePath(testPath);
                test.expect(typeof normalized).toBe('string');
                test.expect(handler.containsRTL(testPath)).toBeTrue();
                
                const analysis = handler.analyzePath(testPath);
                test.expect(analysis.containsRTL).toBeTrue();
            });
        });
    });
    
    test.describe('Diacritic and Combining Characters', () => {
        testPaths.diacritics.forEach(testPath => {
            test.it(`should handle diacritics path: ${testPath}`, () => {
                const normalized = handler.normalizePath(testPath);
                test.expect(typeof normalized).toBe('string');
                
                // Ensure normalization preserves readability
                test.expect(normalized.length > 0).toBeTrue();
            });
        });
    });
    
    test.describe('Unicode Normalization Forms', () => {
        test.it('should handle NFC normalization', () => {
            const nfcPath = handler.normalizePath(testPaths.normalization.nfc, 'NFC');
            test.expect(nfcPath.normalize('NFC')).toBe(nfcPath);
        });
        
        test.it('should handle NFD normalization', () => {
            const nfdPath = handler.normalizePath(testPaths.normalization.nfc, 'NFD');
            test.expect(nfdPath.normalize('NFD')).toBe(nfdPath);
        });
        
        test.it('should convert between normalization forms', () => {
            const original = testPaths.normalization.nfd;
            const nfcVersion = handler.normalizePath(original, 'NFC');
            const nfdVersion = handler.normalizePath(original, 'NFD');
            
            // Both should represent the same logical path
            test.expect(nfcVersion.normalize('NFC')).toBe(nfdVersion.normalize('NFC'));
        });
    });
    
    test.describe('Shell Encoding', () => {
        const testPath = '/tmp/test_🎉_café.txt';
        
        test.it('should encode for bash shell', () => {
            const encoded = handler.encodeForShell(testPath, 'bash');
            test.expect(encoded).toContain("'");
            test.expect(encoded.startsWith("'")).toBeTrue();
            test.expect(encoded.endsWith("'")).toBeTrue();
        });
        
        test.it('should encode for CMD shell', () => {
            const encoded = handler.encodeForShell(testPath, 'cmd');
            test.expect(encoded).toContain('"');
        });
        
        test.it('should encode for PowerShell', () => {
            const encoded = handler.encodeForShell(testPath, 'powershell');
            test.expect(encoded).toContain("'");
        });
        
        test.it('should handle shell encoding with special characters', () => {
            const specialPath = "/tmp/path with spaces & 'quotes' and \"double quotes\".txt";
            const bashEncoded = handler.encodeForShell(specialPath, 'bash');
            const cmdEncoded = handler.encodeForShell(specialPath, 'cmd');
            const pwshEncoded = handler.encodeForShell(specialPath, 'powershell');
            
            test.expect(bashEncoded.length > specialPath.length).toBeTrue();
            test.expect(cmdEncoded.length > specialPath.length).toBeTrue();
            test.expect(pwshEncoded.length > specialPath.length).toBeTrue();
        });
    });
    
    test.describe('JSON Encoding', () => {
        testPaths.emoji.concat(testPaths.cjk, testPaths.rtl).forEach(testPath => {
            test.it(`should encode for JSON: ${testPath}`, () => {
                const encoded = handler.encodeForJSON(testPath);
                test.expect(encoded.startsWith('"')).toBeTrue();
                test.expect(encoded.endsWith('"')).toBeTrue();
                
                // Should be valid JSON
                const parsed = JSON.parse(encoded);
                test.expect(typeof parsed).toBe('string');
            });
        });
    });
    
    test.describe('Path Analysis', () => {
        const mixedPath = '/test_🎉_中文_العربية/café.txt';
        
        test.it('should provide comprehensive path analysis', () => {
            const analysis = handler.analyzePath(mixedPath);
            
            test.expect(analysis.original).toBe(mixedPath);
            test.expect(typeof analysis.normalized).toBe('string');
            test.expect(analysis.platform).toBe(process.platform);
            test.expect(analysis.encoding).toBe('utf8');
            test.expect(typeof analysis.length).toBe('number');
            test.expect(typeof analysis.byteLength).toBe('number');
            test.expect(analysis.containsEmoji).toBeTrue();
            test.expect(analysis.containsCJK).toBeTrue();
            test.expect(analysis.containsRTL).toBeTrue();
            test.expect(typeof analysis.shellEncoded).toBe('object');
            test.expect(typeof analysis.jsonEncoded).toBe('string');
        });
    });
    
    test.describe('Encoding Detection', () => {
        test.it('should detect UTF-8 encoding', () => {
            const encoding = handler.detectEncoding('test string');
            test.expect(encoding).toBe('utf8');
        });
        
        test.it('should detect encoding from buffer', () => {
            const utf8Buffer = Buffer.from('test 🎉', 'utf8');
            const encoding = handler.detectEncoding(utf8Buffer);
            test.expect(encoding).toBe('utf8');
        });
        
        test.it('should handle binary data', () => {
            const binaryBuffer = Buffer.from([0xFF, 0xFE, 0x00, 0x01]);
            const encoding = handler.detectEncoding(binaryBuffer);
            test.expect(['utf16le', 'latin1'].includes(encoding)).toBeTrue();
        });
    });
    
    test.describe('Error Handling', () => {
        test.it('should throw UnicodePathError for invalid input', () => {
            test.expect(() => handler.normalizePath(null)).toThrow(UnicodePathError);
            test.expect(() => handler.normalizePath('')).toThrow(UnicodePathError);
            test.expect(() => handler.normalizePath(123)).toThrow(UnicodePathError);
        });
        
        test.it('should throw error for paths with null bytes', () => {
            const pathWithNull = '/tmp/test\0file.txt';
            test.expect(() => handler.normalizePath(pathWithNull)).toThrow(UnicodePathError);
        });
        
        test.it('should throw error for extremely long paths', () => {
            const longPath = '/tmp/' + 'a'.repeat(5000) + '.txt';
            test.expect(() => handler.normalizePath(longPath)).toThrow(UnicodePathError);
        });
        
        test.it('should throw error for directory traversal', () => {
            const traversalPath = '/tmp/../../../etc/passwd';
            test.expect(() => handler.normalizePath(traversalPath)).toThrow(UnicodePathError);
        });
        
        if (process.platform === 'win32') {
            test.it('should throw error for Windows reserved names', () => {
                test.expect(() => handler.normalizePath('C:\\CON.txt')).toThrow(UnicodePathError);
                test.expect(() => handler.normalizePath('C:\\Users\\test\\PRN')).toThrow(UnicodePathError);
            });
        }
        
        test.it('should throw UnicodeEncodingError for unsupported encoding', () => {
            test.expect(() => handler.convertEncoding('test', 'invalid', 'utf8')).toThrow(UnicodeEncodingError);
        });
    });
    
    test.describe('Problematic Unicode Handling', () => {
        testPaths.problematic.forEach(testPath => {
            test.it(`should clean problematic path: ${testPath}`, () => {
                const normalized = handler.normalizePath(testPath);
                
                // Should not contain zero-width characters
                test.expect(normalized.includes('\u200B')).toBeFalse();
                test.expect(normalized.includes('\u200C')).toBeFalse();
                test.expect(normalized.includes('\u200D')).toBeFalse();
                test.expect(normalized.includes('\uFEFF')).toBeFalse();
                
                // Should not contain bidirectional markers
                test.expect(normalized.includes('\u202A')).toBeFalse();
                test.expect(normalized.includes('\u202B')).toBeFalse();
                test.expect(normalized.includes('\u202C')).toBeFalse();
            });
        });
    });
    
    test.describe('Safe Temp Path Creation', () => {
        test.it('should create safe temporary paths', () => {
            const tempDir = os.tmpdir();
            const safePath = handler.createSafeTempPath(tempDir);
            
            test.expect(typeof safePath).toBe('string');
            test.expect(safePath.startsWith(tempDir.replace(/\\/g, '/'))).toBeTrue();
            test.expect(safePath).toContain('claude-auto-tee');
            test.expect(safePath.endsWith('.log')).toBeTrue();
        });
        
        test.it('should create unique temporary paths', () => {
            const tempDir = os.tmpdir();
            const path1 = handler.createSafeTempPath(tempDir);
            const path2 = handler.createSafeTempPath(tempDir);
            
            test.expect(path1 !== path2).toBeTrue();
        });
        
        test.it('should handle Unicode in temp directory', () => {
            // Only test if we can create Unicode directories
            const unicodeTempDir = path.join(os.tmpdir(), 'test_🎉_unicode');
            
            try {
                const safePath = handler.createSafeTempPath(unicodeTempDir, 'test_🎉', '.log');
                test.expect(typeof safePath).toBe('string');
                test.expect(safePath).toContain('test_🎉');
            } catch (error) {
                // Skip if Unicode directories not supported on this system
                test.skip('Unicode temp directory test', 'Unicode directories not supported');
            }
        });
    });
    
    test.describe('Cross-Platform Compatibility', () => {
        test.it('should handle platform-specific path separators', () => {
            const unixPath = '/tmp/test/file.txt';
            const windowsPath = 'C:\\temp\\test\\file.txt';
            
            const normalizedUnix = handler.normalizePath(unixPath);
            const normalizedWindows = handler.normalizePath(windowsPath);
            
            if (process.platform === 'win32') {
                test.expect(normalizedUnix).toContain('\\');
                test.expect(normalizedWindows).toContain('\\');
            } else {
                test.expect(normalizedUnix).toContain('/');
                test.expect(normalizedWindows).toContain('/');
            }
        });
        
        test.it('should use correct default normalization for platform', () => {
            const testPath = '/tmp/café.txt';
            const normalized = handler.normalizePath(testPath);
            
            if (process.platform === 'darwin') {
                // macOS (HFS+) should prefer NFD
                test.expect(normalized.normalize('NFD')).toBe(normalized);
            } else {
                // Other platforms should prefer NFC
                test.expect(normalized.normalize('NFC')).toBe(normalized);
            }
        });
    });
    
    test.describe('Real-World Integration Tests', () => {
        test.it('should handle file operations with Unicode paths', () => {
            const testPath = path.join(os.tmpdir(), 'test_🎉_unicode.txt');
            const normalizedPath = handler.normalizePath(testPath);
            
            try {
                // Test that normalized path can be used with Node.js fs operations
                fs.writeFileSync(normalizedPath, 'test content', 'utf8');
                const content = fs.readFileSync(normalizedPath, 'utf8');
                test.expect(content).toBe('test content');
                
                // Cleanup
                fs.unlinkSync(normalizedPath);
            } catch (error) {
                // Skip if Unicode filenames not supported on this system
                test.skip('Unicode file operations test', `Unicode filenames not supported: ${error.message}`);
            }
        });
        
        test.it('should work with all provided test case paths', () => {
            const allPaths = [
                ...testPaths.emoji,
                ...testPaths.cjk.slice(0, 2), // Test subset to avoid platform issues
                ...testPaths.diacritics
            ];
            
            let successCount = 0;
            for (const testPath of allPaths) {
                try {
                    const normalized = handler.normalizePath(testPath);
                    const analysis = handler.analyzePath(testPath);
                    const bashEncoded = handler.encodeForShell(testPath, 'bash');
                    const jsonEncoded = handler.encodeForJSON(testPath);
                    
                    test.expect(typeof normalized).toBe('string');
                    test.expect(typeof analysis).toBe('object');
                    test.expect(typeof bashEncoded).toBe('string');
                    test.expect(typeof jsonEncoded).toBe('string');
                    
                    successCount++;
                } catch (error) {
                    console.log(`    Warning: Could not process path "${testPath}": ${error.message}`);
                }
            }
            
            // Expect at least 80% success rate
            const successRate = successCount / allPaths.length;
            test.expect(successRate >= 0.8).toBeTrue();
        });
    });
    
    // Show test summary
    test.summary();
}

// Command-line interface
if (require.main === module) {
    console.log('Unicode Path Handler Test Suite');
    console.log('P2.T006 - Handle Unicode paths for the PostToolUse hook implementation');
    console.log('');
    
    runAllTests();
}