#!/usr/bin/env node
/**
 * PathParser - Capture Path Parser for PostToolUse Hook Implementation
 * 
 * Extracts file paths from stderr messages containing "Full output saved to: <path>"
 * Handles various path formats including:
 * - Absolute paths (Unix: /tmp/file, Windows: C:\temp\file)
 * - Relative paths (./file, ../file, file.txt)
 * - Paths with spaces, Unicode characters
 * - Multiple captures from single stderr output
 * 
 * Returns structured data: {path: string, timestamp: Date, raw: string}
 * 
 * @author Claude Code
 * @interface PathParser:v1
 */

const path = require('path');

/**
 * PathParser class for extracting capture paths from PostToolUse tool_response
 */
class PathParser {
    constructor() {
        // Regex patterns for different path formats
        this.patterns = {
            // Primary pattern: "Full output saved to: <path>"
            primary: /Full output saved to:\s*([^\r\n]+?)(?:\s*$|\r|\n)/gm,
            
            // Secondary patterns for edge cases
            tempFile: /temp file preserved:\s*([^\r\n]+?)(?:\s*$|\r|\n)/gm,
            
            // Path validation patterns (cross-platform) - allow quotes in path content
            unix: /^\/[^<>:|?*\x00-\x1f]*$/,
            windows: /^[A-Za-z]:[^<>|?*\x00-\x1f]*$/,
            relative: /^\.{1,2}[\/\\][^<>:|?*\x00-\x1f]*$|^[^\/\\<>:|?*\x00-\x1f][^<>:|?*\x00-\x1f]*$/
        };
        
        // Statistics for monitoring
        this.stats = {
            totalProcessed: 0,
            pathsExtracted: 0,
            errors: 0,
            lastProcessed: null
        };
    }

    /**
     * Parse stderr output to extract file paths
     * @param {string} stderr - The stderr output to parse
     * @param {Date} [timestamp] - Optional timestamp for the capture
     * @returns {Array<Object>} Array of parsed capture objects
     */
    parse(stderr, timestamp = new Date()) {
        this.stats.totalProcessed++;
        this.stats.lastProcessed = timestamp;
        
        if (stderr === null || stderr === undefined || typeof stderr !== 'string') {
            throw new TypeError('stderr must be a non-empty string');
        }
        
        // Handle empty strings gracefully
        if (stderr === '') {
            return [];
        }

        const captures = [];
        
        try {
            // Extract paths using primary pattern
            captures.push(...this._extractWithPattern(stderr, this.patterns.primary, timestamp));
            
            // Extract paths using secondary pattern
            captures.push(...this._extractWithPattern(stderr, this.patterns.tempFile, timestamp));
            
            // Remove duplicates based on path
            const uniqueCaptures = this._removeDuplicates(captures);
            
            this.stats.pathsExtracted += uniqueCaptures.length;
            return uniqueCaptures;
            
        } catch (error) {
            this.stats.errors++;
            throw new Error(`Failed to parse stderr: ${error.message}`);
        }
    }

    /**
     * Extract paths using a specific regex pattern
     * @private
     * @param {string} text - Text to search
     * @param {RegExp} pattern - Regex pattern to use
     * @param {Date} timestamp - Timestamp for captures
     * @returns {Array<Object>} Array of capture objects
     */
    _extractWithPattern(text, pattern, timestamp) {
        const captures = [];
        let match;
        
        // Reset regex state
        pattern.lastIndex = 0;
        
        while ((match = pattern.exec(text)) !== null) {
            const rawPath = match[1];
            if (!rawPath) continue;
            
            // Clean and validate the path
            const cleanPath = this._cleanPath(rawPath);
            if (this._isValidPath(cleanPath)) {
                captures.push({
                    path: cleanPath,
                    timestamp: new Date(timestamp),
                    raw: match[0].trim()
                });
            }
        }
        
        return captures;
    }

    /**
     * Clean extracted path by removing extra whitespace and quotes
     * @private
     * @param {string} rawPath - Raw path string
     * @returns {string} Cleaned path
     */
    _cleanPath(rawPath) {
        if (!rawPath) return '';
        
        // Trim whitespace
        let cleaned = rawPath.trim();
        
        // Remove surrounding quotes if they match
        if ((cleaned.startsWith('"') && cleaned.endsWith('"')) ||
            (cleaned.startsWith("'") && cleaned.endsWith("'"))) {
            cleaned = cleaned.slice(1, -1);
        }
        
        // Handle escaped quotes
        cleaned = cleaned.replace(/\\"/g, '"').replace(/\\'/g, "'");
        
        // Normalize path separators for the current platform
        // Keep original separators but normalize repeated separators
        cleaned = cleaned.replace(/[\/\\]+/g, path.sep);
        
        return cleaned;
    }

    /**
     * Validate if a path is a valid file system path
     * @private
     * @param {string} pathStr - Path to validate
     * @returns {boolean} True if path is valid
     */
    _isValidPath(pathStr) {
        if (!pathStr || pathStr.length === 0) return false;
        
        // Check for invalid characters or suspicious patterns
        if (pathStr.includes('\x00') || pathStr.includes('\r') || pathStr.includes('\n')) {
            return false;
        }
        
        // Check against path patterns
        return this.patterns.unix.test(pathStr) || 
               this.patterns.windows.test(pathStr) || 
               this.patterns.relative.test(pathStr);
    }

    /**
     * Remove duplicate captures based on path
     * @private
     * @param {Array<Object>} captures - Array of capture objects
     * @returns {Array<Object>} Array with duplicates removed
     */
    _removeDuplicates(captures) {
        const seen = new Set();
        return captures.filter(capture => {
            const key = path.resolve(capture.path);
            if (seen.has(key)) {
                return false;
            }
            seen.add(key);
            return true;
        });
    }

    /**
     * Parse multiple stderr outputs
     * @param {Array<string>} stderrList - Array of stderr outputs
     * @param {Date} [timestamp] - Optional base timestamp
     * @returns {Array<Object>} Array of all parsed captures
     */
    parseMultiple(stderrList, timestamp = new Date()) {
        if (!Array.isArray(stderrList)) {
            throw new TypeError('stderrList must be an array');
        }

        const allCaptures = [];
        
        stderrList.forEach((stderr, index) => {
            // Use incrementing timestamps for multiple entries
            const entryTimestamp = new Date(timestamp.getTime() + index * 100);
            try {
                const captures = this.parse(stderr, entryTimestamp);
                allCaptures.push(...captures);
            } catch (error) {
                // Continue processing other entries even if one fails
                console.warn(`Failed to parse stderr entry ${index}: ${error.message}`);
            }
        });

        return this._removeDuplicates(allCaptures);
    }

    /**
     * Get parser statistics
     * @returns {Object} Statistics object
     */
    getStats() {
        return { ...this.stats };
    }

    /**
     * Reset parser statistics
     */
    resetStats() {
        this.stats = {
            totalProcessed: 0,
            pathsExtracted: 0,
            errors: 0,
            lastProcessed: null
        };
    }

    /**
     * Check if stderr contains capture patterns
     * @param {string} stderr - stderr output to check
     * @returns {boolean} True if patterns are found
     */
    hasCaptures(stderr) {
        if (!stderr || typeof stderr !== 'string') return false;
        
        return this.patterns.primary.test(stderr) || this.patterns.tempFile.test(stderr);
    }

    /**
     * Extract just the paths (strings) from stderr
     * @param {string} stderr - stderr output to parse
     * @returns {Array<string>} Array of path strings
     */
    extractPaths(stderr) {
        const captures = this.parse(stderr);
        return captures.map(capture => capture.path);
    }

    /**
     * Factory method to create a new PathParser instance
     * @returns {PathParser} New PathParser instance
     */
    static create() {
        return new PathParser();
    }
}

module.exports = PathParser;