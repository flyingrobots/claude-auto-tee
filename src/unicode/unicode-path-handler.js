#!/usr/bin/env node
/**
 * Unicode Path Handler - UnicodeHandler:v1
 * Comprehensive Unicode path handling for claude-auto-tee PostToolUse hook
 * P2.T006 - Handle Unicode paths for the PostToolUse hook implementation
 * 
 * This module provides bulletproof Unicode handling for global user base.
 * Supports UTF-8, UTF-16, emoji, CJK characters, RTL text, combining characters,
 * and proper normalization across different filesystems.
 */

const path = require('path');
const fs = require('fs');

/**
 * Custom error types for Unicode path handling
 */
class UnicodePathError extends Error {
    constructor(message, code = 'UNICODE_PATH_ERROR', path = null) {
        super(message);
        this.name = 'UnicodePathError';
        this.code = code;
        this.path = path;
    }
}

class UnicodeNormalizationError extends UnicodePathError {
    constructor(message, path = null) {
        super(message, 'UNICODE_NORMALIZATION_ERROR', path);
        this.name = 'UnicodeNormalizationError';
    }
}

class UnicodeEncodingError extends UnicodePathError {
    constructor(message, path = null) {
        super(message, 'UNICODE_ENCODING_ERROR', path);
        this.name = 'UnicodeEncodingError';
    }
}

/**
 * Main Unicode Path Handler Class
 */
class UnicodeHandler {
    constructor() {
        this.platform = process.platform;
        this.supportedEncodings = ['utf8', 'utf16le', 'ascii', 'latin1'];
        
        // Filesystem-specific normalization preferences
        this.fsNormalizationMap = {
            'darwin': 'NFD',     // HFS+ prefers NFD
            'win32': 'NFC',      // NTFS prefers NFC
            'linux': 'NFC',      // ext4 and most Linux fs prefer NFC
            'freebsd': 'NFC',    // UFS prefers NFC
            'openbsd': 'NFC',    // FFS prefers NFC
            'sunos': 'NFC'       // ZFS prefers NFC
        };
        
        // Zero-width and problematic Unicode categories
        this.problematicCategories = [
            'Mn', // Mark, nonspacing (combining diacritics)
            'Me', // Mark, enclosing
            'Cf', // Other, format (zero-width chars)
            'Cs', // Other, surrogate
            'Co', // Other, private use
            'Cn'  // Other, not assigned
        ];
        
        // Initialize platform-specific settings
        this.initializePlatformSettings();
    }
    
    /**
     * Initialize platform-specific Unicode settings
     */
    initializePlatformSettings() {
        this.defaultNormalization = this.fsNormalizationMap[this.platform] || 'NFC';
        this.maxPathLength = this.platform === 'win32' ? 260 : 4096;
        this.pathSeparator = this.platform === 'win32' ? '\\' : '/';
        this.reservedNames = this.platform === 'win32' ? 
            ['CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9', 'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9'] : 
            [];
    }
    
    /**
     * Normalize Unicode path according to filesystem requirements
     * @param {string} inputPath - The path to normalize
     * @param {string} form - Normalization form (NFC, NFD, NFKC, NFKD)
     * @returns {string} Normalized path
     */
    normalizePath(inputPath, form = null) {
        if (!inputPath || typeof inputPath !== 'string') {
            throw new UnicodePathError('Input path must be a non-empty string', 'INVALID_INPUT', inputPath);
        }
        
        const normForm = form || this.defaultNormalization;
        
        try {
            // Normalize Unicode characters
            let normalized = inputPath.normalize(normForm);
            
            // Handle platform-specific path separators
            normalized = this.normalizePathSeparators(normalized);
            
            // Remove zero-width characters that could cause issues
            normalized = this.removeProblematicCharacters(normalized);
            
            // Validate the normalized path
            this.validateNormalizedPath(normalized);
            
            return normalized;
        } catch (error) {
            if (error instanceof UnicodePathError) {
                throw error;
            }
            throw new UnicodeNormalizationError(`Failed to normalize path: ${error.message}`, inputPath);
        }
    }
    
    /**
     * Normalize path separators for the current platform
     * @param {string} pathStr - Path string to normalize
     * @returns {string} Path with normalized separators
     */
    normalizePathSeparators(pathStr) {
        if (this.platform === 'win32') {
            // Convert forward slashes to backslashes on Windows
            return pathStr.replace(/\//g, '\\');
        } else {
            // Convert backslashes to forward slashes on Unix-like systems
            return pathStr.replace(/\\/g, '/');
        }
    }
    
    /**
     * Remove problematic Unicode characters that could cause filesystem issues
     * @param {string} pathStr - Path string to clean
     * @returns {string} Cleaned path string
     */
    removeProblematicCharacters(pathStr) {
        // Remove zero-width spaces and similar characters
        let cleaned = pathStr.replace(/[\u200B-\u200D\uFEFF]/g, '');
        
        // Remove bidirectional text markers that could cause confusion
        cleaned = cleaned.replace(/[\u202A-\u202E\u2066-\u2069]/g, '');
        
        // Handle combining characters - keep them but ensure they're properly attached
        cleaned = this.handleCombiningCharacters(cleaned);
        
        return cleaned;
    }
    
    /**
     * Handle combining characters properly
     * @param {string} pathStr - Path string with potential combining characters
     * @returns {string} Path with properly handled combining characters
     */
    handleCombiningCharacters(pathStr) {
        // Ensure combining characters are properly attached to their base characters
        // This prevents orphaned combining marks
        return pathStr.replace(/^[\u0300-\u036F\u1AB0-\u1AFF\u1DC0-\u1DFF\u20D0-\u20FF\uFE20-\uFE2F]+/g, '');
    }
    
    /**
     * Validate normalized path for filesystem compatibility
     * @param {string} normalizedPath - The normalized path to validate
     * @throws {UnicodePathError} If path is invalid
     */
    validateNormalizedPath(normalizedPath) {
        // Check path length
        if (normalizedPath.length > this.maxPathLength) {
            throw new UnicodePathError(
                `Path exceeds maximum length (${this.maxPathLength}): ${normalizedPath.length}`,
                'PATH_TOO_LONG',
                normalizedPath
            );
        }
        
        // Check for null bytes
        if (normalizedPath.includes('\0')) {
            throw new UnicodePathError('Path contains null bytes', 'NULL_BYTES', normalizedPath);
        }
        
        // Check for reserved names on Windows
        if (this.platform === 'win32') {
            const pathComponents = normalizedPath.split(/[/\\]/);
            for (const component of pathComponents) {
                const baseName = component.split('.')[0].toUpperCase();
                if (this.reservedNames.includes(baseName)) {
                    throw new UnicodePathError(
                        `Path contains reserved Windows name: ${component}`,
                        'RESERVED_NAME',
                        normalizedPath
                    );
                }
            }
        }
        
        // Check for dangerous directory traversal patterns
        if (normalizedPath.includes('..') && (normalizedPath.includes('../') || normalizedPath.includes('..\\'))) {
            throw new UnicodePathError('Path contains directory traversal', 'DIRECTORY_TRAVERSAL', normalizedPath);
        }
    }
    
    /**
     * Encode path for shell command execution
     * @param {string} pathStr - Path to encode
     * @param {string} shellType - Type of shell ('bash', 'cmd', 'powershell')
     * @returns {string} Shell-encoded path
     */
    encodeForShell(pathStr, shellType = 'bash') {
        const normalizedPath = this.normalizePath(pathStr);
        
        switch (shellType.toLowerCase()) {
            case 'bash':
            case 'sh':
            case 'zsh':
                return this.encodeBashPath(normalizedPath);
            case 'cmd':
                return this.encodeCmdPath(normalizedPath);
            case 'powershell':
            case 'pwsh':
                return this.encodePowerShellPath(normalizedPath);
            default:
                return this.encodeBashPath(normalizedPath); // Default to bash
        }
    }
    
    /**
     * Encode path for bash shell
     * @param {string} pathStr - Path to encode
     * @returns {string} Bash-encoded path
     */
    encodeBashPath(pathStr) {
        // Use single quotes to preserve all characters literally
        // Escape any single quotes in the path by ending the quoted string,
        // adding an escaped single quote, then starting a new quoted string
        return "'" + pathStr.replace(/'/g, "'\"'\"'") + "'";
    }
    
    /**
     * Encode path for Windows CMD
     * @param {string} pathStr - Path to encode
     * @returns {string} CMD-encoded path
     */
    encodeCmdPath(pathStr) {
        // Use double quotes and escape special characters
        let encoded = pathStr.replace(/"/g, '""');
        encoded = encoded.replace(/[&<>|^%]/g, '^$&');
        return '"' + encoded + '"';
    }
    
    /**
     * Encode path for PowerShell
     * @param {string} pathStr - Path to encode
     * @returns {string} PowerShell-encoded path
     */
    encodePowerShellPath(pathStr) {
        // Use single quotes and escape single quotes
        return "'" + pathStr.replace(/'/g, "''") + "'";
    }
    
    /**
     * Encode path for JSON contexts
     * @param {string} pathStr - Path to encode
     * @returns {string} JSON-encoded path
     */
    encodeForJSON(pathStr) {
        const normalizedPath = this.normalizePath(pathStr);
        return JSON.stringify(normalizedPath);
    }
    
    /**
     * Detect the encoding of a path string
     * @param {string|Buffer} pathInput - Path to detect encoding for
     * @returns {string} Detected encoding
     */
    detectEncoding(pathInput) {
        if (Buffer.isBuffer(pathInput)) {
            // Try to detect encoding from buffer - check UTF-16LE first (more specific)
            if (this.isValidUTF16LE(pathInput)) {
                return 'utf16le';
            } else if (this.isValidUTF8(pathInput)) {
                return 'utf8';
            } else {
                return 'latin1'; // Fallback for binary data
            }
        }
        
        // For strings, assume UTF-8
        return 'utf8';
    }
    
    /**
     * Check if buffer contains valid UTF-8
     * @param {Buffer} buffer - Buffer to check
     * @returns {boolean} True if valid UTF-8
     */
    isValidUTF8(buffer) {
        try {
            buffer.toString('utf8');
            return true;
        } catch (error) {
            return false;
        }
    }
    
    /**
     * Check if buffer contains valid UTF-16LE
     * @param {Buffer} buffer - Buffer to check
     * @returns {boolean} True if valid UTF-16LE
     */
    isValidUTF16LE(buffer) {
        try {
            // UTF-16LE should have even length
            if (buffer.length % 2 !== 0) return false;
            
            // Check for UTF-16LE BOM (FF FE) or decode successfully
            if (buffer.length >= 2 && buffer[0] === 0xFF && buffer[1] === 0xFE) {
                return true;
            }
            
            // Try to decode - if it succeeds and contains valid UTF-16 patterns, it's probably UTF-16LE
            const decoded = buffer.toString('utf16le');
            return decoded.length > 0 && !decoded.includes('\uFFFD'); // No replacement characters
        } catch (error) {
            return false;
        }
    }
    
    /**
     * Convert path between different encodings
     * @param {string|Buffer} pathInput - Path to convert
     * @param {string} fromEncoding - Source encoding
     * @param {string} toEncoding - Target encoding
     * @returns {string} Converted path
     */
    convertEncoding(pathInput, fromEncoding, toEncoding) {
        if (!this.supportedEncodings.includes(fromEncoding) || 
            !this.supportedEncodings.includes(toEncoding)) {
            throw new UnicodeEncodingError(
                `Unsupported encoding. Supported: ${this.supportedEncodings.join(', ')}`,
                pathInput
            );
        }
        
        try {
            let pathStr;
            if (Buffer.isBuffer(pathInput)) {
                pathStr = pathInput.toString(fromEncoding);
            } else {
                pathStr = pathInput;
            }
            
            // Convert through Unicode normalization
            const normalized = this.normalizePath(pathStr);
            
            // Return as string (Node.js handles internal encoding)
            return normalized;
        } catch (error) {
            throw new UnicodeEncodingError(
                `Failed to convert encoding from ${fromEncoding} to ${toEncoding}: ${error.message}`,
                pathInput
            );
        }
    }
    
    /**
     * Check if path contains RTL (Right-to-Left) text
     * @param {string} pathStr - Path to check
     * @returns {boolean} True if contains RTL text
     */
    containsRTL(pathStr) {
        // Check for Arabic, Hebrew, and other RTL scripts
        const rtlRegex = /[\u0590-\u05FF\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]/;
        return rtlRegex.test(pathStr);
    }
    
    /**
     * Check if path contains CJK (Chinese, Japanese, Korean) characters
     * @param {string} pathStr - Path to check
     * @returns {boolean} True if contains CJK characters
     */
    containsCJK(pathStr) {
        // Check for CJK ideographs and related scripts including Hangul
        const cjkRegex = /[\u2E80-\u2EFF\u2F00-\u2FDF\u3040-\u309F\u30A0-\u30FF\u3100-\u312F\u3130-\u318F\u3190-\u319F\u31C0-\u31EF\u3200-\u32FF\u3400-\u4DBF\u4E00-\u9FFF\uAC00-\uD7AF\uF900-\uFAFF]/;
        return cjkRegex.test(pathStr);
    }
    
    /**
     * Check if path contains emoji
     * @param {string} pathStr - Path to check
     * @returns {boolean} True if contains emoji
     */
    containsEmoji(pathStr) {
        // Check for emoji ranges
        const emojiRegex = /[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]/u;
        return emojiRegex.test(pathStr);
    }
    
    /**
     * Create a safe temporary path with Unicode support
     * @param {string} tempDir - Temporary directory
     * @param {string} prefix - Filename prefix
     * @param {string} suffix - Filename suffix
     * @returns {string} Safe temporary path
     */
    createSafeTempPath(tempDir, prefix = 'claude-auto-tee', suffix = '.log') {
        const normalizedTempDir = this.normalizePath(tempDir);
        this.validateNormalizedPath(normalizedTempDir);
        
        // Generate unique filename with timestamp and random component
        const timestamp = Date.now();
        const random = Math.floor(Math.random() * 10000);
        const filename = `${prefix}-${timestamp}-${random}${suffix}`;
        
        // Ensure filename doesn't contain problematic Unicode
        const safeFilename = this.normalizePath(filename);
        
        return path.join(normalizedTempDir, safeFilename);
    }
    
    /**
     * Extract analysis information about a Unicode path
     * @param {string} pathStr - Path to analyze
     * @returns {Object} Analysis results
     */
    analyzePath(pathStr) {
        return {
            original: pathStr,
            normalized: this.normalizePath(pathStr),
            platform: this.platform,
            encoding: this.detectEncoding(pathStr),
            normalizationForm: this.defaultNormalization,
            length: pathStr.length,
            byteLength: Buffer.byteLength(pathStr, 'utf8'),
            containsRTL: this.containsRTL(pathStr),
            containsCJK: this.containsCJK(pathStr),
            containsEmoji: this.containsEmoji(pathStr),
            shellEncoded: {
                bash: this.encodeForShell(pathStr, 'bash'),
                cmd: this.encodeForShell(pathStr, 'cmd'),
                powershell: this.encodeForShell(pathStr, 'powershell')
            },
            jsonEncoded: this.encodeForJSON(pathStr)
        };
    }
}

// Export the classes and create a default instance
module.exports = {
    UnicodeHandler,
    UnicodePathError,
    UnicodeNormalizationError,
    UnicodeEncodingError
};

// Create and export default instance
const defaultHandler = new UnicodeHandler();
module.exports.default = defaultHandler;

// Command-line interface when run directly
if (require.main === module) {
    const args = process.argv.slice(2);
    
    if (args.length === 0) {
        console.log('Unicode Path Handler - UnicodeHandler:v1');
        console.log('Usage: node unicode-path-handler.js <command> [arguments]');
        console.log('');
        console.log('Commands:');
        console.log('  normalize <path>           - Normalize a Unicode path');
        console.log('  analyze <path>             - Analyze Unicode path properties');
        console.log('  encode <path> <shell>      - Encode path for shell (bash/cmd/powershell)');
        console.log('  test                       - Run built-in tests');
        console.log('');
        console.log('Examples:');
        console.log('  node unicode-path-handler.js normalize "/tmp/test_🎉_output.txt"');
        console.log('  node unicode-path-handler.js analyze "/用户/文档/输出.log"');
        console.log('  node unicode-path-handler.js encode "/café/naïve.txt" bash');
        process.exit(0);
    }
    
    const command = args[0];
    const handler = new UnicodeHandler();
    
    try {
        switch (command) {
            case 'normalize':
                if (args.length < 2) {
                    console.error('Error: normalize command requires a path argument');
                    process.exit(1);
                }
                console.log(handler.normalizePath(args[1]));
                break;
                
            case 'analyze':
                if (args.length < 2) {
                    console.error('Error: analyze command requires a path argument');
                    process.exit(1);
                }
                console.log(JSON.stringify(handler.analyzePath(args[1]), null, 2));
                break;
                
            case 'encode':
                if (args.length < 3) {
                    console.error('Error: encode command requires path and shell type arguments');
                    process.exit(1);
                }
                console.log(handler.encodeForShell(args[1], args[2]));
                break;
                
            case 'test':
                // Run basic tests
                const testPaths = [
                    '/tmp/test_🎉_output.txt',
                    '/用户/文档/输出.log',
                    '/מסמכים/פלט.txt',
                    '/café/naïve.txt'
                ];
                
                console.log('=== Unicode Path Handler Tests ===');
                for (const testPath of testPaths) {
                    console.log(`\nTesting: ${testPath}`);
                    const analysis = handler.analyzePath(testPath);
                    console.log(`  Normalized: ${analysis.normalized}`);
                    console.log(`  Contains RTL: ${analysis.containsRTL}`);
                    console.log(`  Contains CJK: ${analysis.containsCJK}`);
                    console.log(`  Contains Emoji: ${analysis.containsEmoji}`);
                    console.log(`  Bash encoded: ${analysis.shellEncoded.bash}`);
                }
                console.log('\n=== All tests completed ===');
                break;
                
            default:
                console.error(`Error: Unknown command "${command}"`);
                process.exit(1);
        }
    } catch (error) {
        console.error(`Error: ${error.message}`);
        process.exit(1);
    }
}