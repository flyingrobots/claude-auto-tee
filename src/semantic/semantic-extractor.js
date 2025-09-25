/**
 * SemanticExtractor - Extract semantic information from command outputs
 * 
 * This class provides pattern-based extraction of key information from
 * captured command outputs, including errors, successes, metrics, paths,
 * and recognized commands.
 * 
 * Interface: SemanticExtractor:v1
 * Performance: <50ms for 10KB output
 * Language-agnostic patterns where possible
 */

class SemanticExtractor {
    constructor(options = {}) {
        this.options = {
            includeLineNumbers: options.includeLineNumbers || false,
            maxProcessingTime: options.maxProcessingTime || 50, // ms
            stripAnsi: options.stripAnsi !== false, // default true
            ...options
        };
        
        // Initialize pattern matchers
        this.patterns = this._initializePatterns();
        
        // ANSI escape sequence regex
        this.ansiRegex = /\x1b\[[0-9;]*[mGKH]/g;
    }
    
    /**
     * Extract semantic information from command output
     * @param {string} output - The command output to analyze
     * @param {Object} metadata - Optional metadata (command, timestamp, etc.)
     * @returns {Object} Extracted semantic information with confidence scores
     */
    extract(output, metadata = {}) {
        const startTime = Date.now();
        
        if (!output || typeof output !== 'string') {
            return this._createEmptyResult();
        }
        
        try {
            // Strip ANSI codes if enabled
            const cleanOutput = this.options.stripAnsi ? 
                this._stripAnsiCodes(output) : output;
            
            // Split into lines for analysis
            const lines = cleanOutput.split('\n');
            
            // Extract information using pattern matchers
            const extraction = {
                errors: this._extractErrors(lines),
                successes: this._extractSuccesses(lines),
                metrics: this._extractMetrics(lines),
                paths: this._extractPaths(lines),
                commands: this._extractCommands(lines),
                metadata: {
                    totalLines: lines.length,
                    originalSize: output.length,
                    cleanedSize: cleanOutput.length,
                    processingTime: Date.now() - startTime,
                    ...metadata
                }
            };
            
            // Calculate overall confidence
            extraction.confidence = this._calculateOverallConfidence(extraction);
            
            return extraction;
            
        } catch (error) {
            return {
                ...this._createEmptyResult(),
                error: error.message,
                metadata: {
                    processingTime: Date.now() - startTime,
                    ...metadata
                }
            };
        }
    }
    
    /**
     * Initialize pattern matching definitions
     * @private
     */
    _initializePatterns() {
        return {
            // Error patterns
            errors: [
                { pattern: /^Error:\s*(.+)$/gmi, confidence: 0.95, type: 'generic_error' },
                { pattern: /^(.+)Error:\s*(.+)$/gmi, confidence: 0.9, type: 'typed_error' },
                { pattern: /^Failed:\s*(.+)$/gmi, confidence: 0.9, type: 'failure' },
                { pattern: /^FAIL\s*(.*)$/gmi, confidence: 0.85, type: 'test_failure' },
                { pattern: /^✗\s*(.+)$/gmi, confidence: 0.8, type: 'failed_check' },
                { pattern: /^Exception:\s*(.+)$/gmi, confidence: 0.9, type: 'exception' },
                { pattern: /^\s*at\s+(.+?)\s*\((.+?):(\d+):(\d+)\)/gmi, confidence: 0.95, type: 'stack_trace' },
                { pattern: /^\s*at\s+(.+?)$/gmi, confidence: 0.7, type: 'stack_frame' },
                { pattern: /^npm ERR!\s*(.+)$/gmi, confidence: 0.9, type: 'npm_error' },
                { pattern: /^fatal:\s*(.+)$/gmi, confidence: 0.95, type: 'fatal_error' }
            ],
            
            // Success patterns
            successes: [
                { pattern: /^Success:\s*(.+)$/gmi, confidence: 0.9, type: 'generic_success' },
                { pattern: /^PASS\s*(.*)$/gmi, confidence: 0.85, type: 'test_pass' },
                { pattern: /^✓\s*(.+)$/gmi, confidence: 0.8, type: 'check_passed' },
                { pattern: /^OK\s*(.*)$/gmi, confidence: 0.75, type: 'ok_status' },
                { pattern: /^Completed:\s*(.+)$/gmi, confidence: 0.8, type: 'completion' },
                { pattern: /^Done\s*(.*)$/gmi, confidence: 0.7, type: 'done_status' },
                { pattern: /^\s*(\d+)\s+passing/gmi, confidence: 0.9, type: 'test_summary_pass' },
                { pattern: /^Build successful/gmi, confidence: 0.95, type: 'build_success' }
            ],
            
            // Metrics patterns (numbers with units)
            metrics: [
                { pattern: /(\d+(?:\.\d+)?)\s*(ms|milliseconds?)/gmi, confidence: 0.9, type: 'time_metric', unit: 'ms' },
                { pattern: /(\d+(?:\.\d+)?)\s*(s|seconds?)/gmi, confidence: 0.85, type: 'time_metric', unit: 's' },
                { pattern: /(\d+(?:\.\d+)?)\s*(KB|MB|GB)/gmi, confidence: 0.9, type: 'size_metric' },
                { pattern: /(\d+(?:\.\d+)?)\s*%/gmi, confidence: 0.85, type: 'percentage_metric', unit: '%' },
                { pattern: /(\d+)\/(\d+)/gmi, confidence: 0.8, type: 'ratio_metric' },
                { pattern: /(\d+(?:\.\d+)?)\s*(fps|qps|rps)/gmi, confidence: 0.85, type: 'rate_metric' },
                { pattern: /Coverage:\s*(\d+(?:\.\d+)?)\s*%/gmi, confidence: 0.95, type: 'coverage_metric', unit: '%' }
            ],
            
            // Path patterns
            paths: [
                { pattern: /(?:^|\s)(\/(?:[^\/\s]+\/)*[^\/\s]*)/gm, confidence: 0.8, type: 'unix_path' },
                { pattern: /(?:^|\s)([A-Za-z]:\\(?:[^\\\/\s]+[\\\/])*[^\\\/\s]*)/gm, confidence: 0.8, type: 'windows_path' },
                { pattern: /(?:^|\s)(\.\/(?:[^\/\s]+\/)*[^\/\s]*)/gm, confidence: 0.75, type: 'relative_path' },
                { pattern: /(?:^|\s)(\.\.\/(?:[^\/\s]+\/)*[^\/\s]*)/gm, confidence: 0.75, type: 'parent_relative_path' },
                { pattern: /https?:\/\/(?:[-\w.])+(?::[0-9]+)?(?:\/(?:[\w\/_.])*)?(?:\?[;&%\w=]*)?/gmi, confidence: 0.95, type: 'url' },
                { pattern: /(?:^|\s)(~\/(?:[^\/\s]+\/)*[^\/\s]*)/gm, confidence: 0.8, type: 'home_relative_path' }
            ],
            
            // Command patterns
            commands: [
                { pattern: /^\$\s*(.+)$/gm, confidence: 0.9, type: 'shell_command' },
                { pattern: /^>\s*(.+)$/gm, confidence: 0.8, type: 'prompt_command' },
                { pattern: /^npm\s+(install|start|test|build|run)\s*(.*)?$/gmi, confidence: 0.95, type: 'npm_command' },
                { pattern: /^git\s+(\w+)\s*(.*)?$/gmi, confidence: 0.95, type: 'git_command' },
                { pattern: /^docker\s+(\w+)\s*(.*)?$/gmi, confidence: 0.9, type: 'docker_command' },
                { pattern: /^node\s+(.*)?$/gmi, confidence: 0.85, type: 'node_command' },
                { pattern: /^python\s+(.*)?$/gmi, confidence: 0.85, type: 'python_command' }
            ]
        };
    }
    
    /**
     * Strip ANSI escape sequences from text
     * @param {string} text - Text to clean
     * @returns {string} Cleaned text
     * @private
     */
    _stripAnsiCodes(text) {
        return text.replace(this.ansiRegex, '');
    }
    
    /**
     * Extract error information from lines
     * @param {string[]} lines - Lines to analyze
     * @returns {Array} Extracted errors with confidence scores
     * @private
     */
    _extractErrors(lines) {
        return this._extractByPatterns(lines, this.patterns.errors);
    }
    
    /**
     * Extract success information from lines
     * @param {string[]} lines - Lines to analyze
     * @returns {Array} Extracted successes with confidence scores
     * @private
     */
    _extractSuccesses(lines) {
        return this._extractByPatterns(lines, this.patterns.successes);
    }
    
    /**
     * Extract metrics from lines
     * @param {string[]} lines - Lines to analyze
     * @returns {Array} Extracted metrics with confidence scores
     * @private
     */
    _extractMetrics(lines) {
        return this._extractByPatterns(lines, this.patterns.metrics);
    }
    
    /**
     * Extract paths from lines
     * @param {string[]} lines - Lines to analyze
     * @returns {Array} Extracted paths with confidence scores
     * @private
     */
    _extractPaths(lines) {
        return this._extractByPatterns(lines, this.patterns.paths);
    }
    
    /**
     * Extract commands from lines
     * @param {string[]} lines - Lines to analyze
     * @returns {Array} Extracted commands with confidence scores
     * @private
     */
    _extractCommands(lines) {
        return this._extractByPatterns(lines, this.patterns.commands);
    }
    
    /**
     * Generic pattern extraction method
     * @param {string[]} lines - Lines to analyze
     * @param {Array} patterns - Pattern definitions
     * @returns {Array} Extracted matches with metadata
     * @private
     */
    _extractByPatterns(lines, patterns) {
        const results = [];
        
        for (let lineIndex = 0; lineIndex < lines.length; lineIndex++) {
            const line = lines[lineIndex];
            
            for (const patternDef of patterns) {
                // Reset regex lastIndex for global patterns
                patternDef.pattern.lastIndex = 0;
                
                let match;
                while ((match = patternDef.pattern.exec(line)) !== null) {
                    const result = {
                        type: patternDef.type,
                        content: match[0].trim(),
                        match: match.slice(1), // Captured groups
                        confidence: patternDef.confidence,
                        line: lineIndex + 1,
                        context: line.trim()
                    };
                    
                    // Add unit information if available
                    if (patternDef.unit) {
                        result.unit = patternDef.unit;
                    }
                    
                    results.push(result);
                    
                    // Prevent infinite loops with global regex
                    if (!patternDef.pattern.global) break;
                }
            }
        }
        
        // Remove duplicates and sort by confidence
        return this._deduplicateAndSort(results);
    }
    
    /**
     * Remove duplicate extractions and sort by confidence
     * @param {Array} results - Raw extraction results
     * @returns {Array} Deduplicated and sorted results
     * @private
     */
    _deduplicateAndSort(results) {
        const seen = new Set();
        const unique = [];
        
        for (const result of results) {
            const key = `${result.type}:${result.content}`;
            if (!seen.has(key)) {
                seen.add(key);
                unique.push(result);
            }
        }
        
        return unique.sort((a, b) => b.confidence - a.confidence);
    }
    
    /**
     * Calculate overall confidence score for extraction
     * @param {Object} extraction - Extraction results
     * @returns {number} Overall confidence (0-1)
     * @private
     */
    _calculateOverallConfidence(extraction) {
        const categories = ['errors', 'successes', 'metrics', 'paths', 'commands'];
        let totalConfidence = 0;
        let totalItems = 0;
        
        for (const category of categories) {
            const items = extraction[category] || [];
            for (const item of items) {
                totalConfidence += item.confidence;
                totalItems++;
            }
        }
        
        // If no items found, return low confidence
        if (totalItems === 0) {
            return 0.1;
        }
        
        // Average confidence weighted by presence of different types
        const baseConfidence = totalConfidence / totalItems;
        const typesDiversityBonus = categories.filter(cat => 
            extraction[cat] && extraction[cat].length > 0
        ).length * 0.05;
        
        return Math.min(1.0, baseConfidence + typesDiversityBonus);
    }
    
    /**
     * Create empty extraction result
     * @returns {Object} Empty extraction result structure
     * @private
     */
    _createEmptyResult() {
        return {
            errors: [],
            successes: [],
            metrics: [],
            paths: [],
            commands: [],
            confidence: 0.1,
            metadata: {
                totalLines: 0,
                originalSize: 0,
                cleanedSize: 0,
                processingTime: 0
            }
        };
    }
    
    /**
     * Get extraction patterns for debugging/inspection
     * @returns {Object} Current pattern definitions
     */
    getPatterns() {
        return this.patterns;
    }
    
    /**
     * Add custom pattern to specific category
     * @param {string} category - Category (errors, successes, metrics, paths, commands)
     * @param {Object} patternDef - Pattern definition
     */
    addPattern(category, patternDef) {
        if (this.patterns[category]) {
            this.patterns[category].push(patternDef);
        }
    }
}

module.exports = { SemanticExtractor };