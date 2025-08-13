#!/usr/bin/env node
/**
 * Environment Exporter for Claude Auto-Tee
 * 
 * Sets CLAUDE_LAST_CAPTURE and CLAUDE_CAPTURES environment variables
 * with proper shell escaping and compatibility across shell types.
 * 
 * Interfaces produced: EnvExporter:v1
 */

const fs = require('fs');
const path = require('path');

/**
 * Custom error types for environment export operations
 */
class EnvironmentExportError extends Error {
    constructor(message, operation = 'unknown') {
        super(message);
        this.name = 'EnvironmentExportError';
        this.operation = operation;
        this.timestamp = new Date().toISOString();
    }
}

class ShellCompatibilityError extends EnvironmentExportError {
    constructor(message, shell = 'unknown') {
        super(message, 'shell_compatibility');
        this.name = 'ShellCompatibilityError';
        this.shell = shell;
    }
}

class PathEscapingError extends EnvironmentExportError {
    constructor(message, path = '') {
        super(message, 'path_escaping');
        this.name = 'PathEscapingError';
        this.path = path;
    }
}

/**
 * Environment Exporter class that generates shell-compatible export commands
 * for CLAUDE_LAST_CAPTURE and CLAUDE_CAPTURES environment variables.
 */
class EnvExporter {
    constructor(options = {}) {
        this.maxCapturesHistory = options.maxCapturesHistory || 10;
        this.enableAtomicOperations = options.enableAtomicOperations !== false;
        this.verbose = options.verbose || false;
        
        // Track captures with metadata
        this.capturesHistory = [];
        
        // Supported shell types
        this.supportedShells = ['bash', 'zsh', 'fish', 'sh'];
        
        this.log('EnvExporter initialized', {
            maxCapturesHistory: this.maxCapturesHistory,
            enableAtomicOperations: this.enableAtomicOperations
        });
    }

    /**
     * Internal logging method
     */
    log(message, data = null) {
        if (this.verbose) {
            const timestamp = new Date().toISOString();
            const logData = data ? ` ${JSON.stringify(data)}` : '';
            console.error(`[EnvExporter] ${timestamp} ${message}${logData}`);
        }
    }

    /**
     * Validates if a shell type is supported
     */
    validateShellType(shell) {
        if (!shell || typeof shell !== 'string') {
            throw new ShellCompatibilityError('Shell type must be a non-empty string', shell);
        }
        
        const normalizedShell = shell.toLowerCase().trim();
        if (!this.supportedShells.includes(normalizedShell)) {
            throw new ShellCompatibilityError(
                `Unsupported shell type: ${shell}. Supported: ${this.supportedShells.join(', ')}`,
                shell
            );
        }
        
        return normalizedShell;
    }

    /**
     * Escapes a path for safe use in shell commands
     * Handles special characters and different shell quoting rules
     */
    escapePath(filePath, shell = 'bash') {
        if (!filePath || typeof filePath !== 'string') {
            throw new PathEscapingError('Path must be a non-empty string', filePath);
        }

        const normalizedShell = this.validateShellType(shell);

        try {
            // Normalize path to absolute path
            const absolutePath = path.resolve(filePath);
            
            switch (normalizedShell) {
                case 'fish':
                    // Fish shell uses single quotes and escapes single quotes differently
                    return `'${absolutePath.replace(/'/g, "\\'")}'`;
                
                case 'bash':
                case 'zsh':
                case 'sh':
                default:
                    // POSIX shells: use double quotes and escape special characters
                    return `"${absolutePath
                        .replace(/\\/g, '\\\\')    // Escape backslashes first
                        .replace(/"/g, '\\"')      // Escape double quotes
                        .replace(/`/g, '\\`')      // Escape backticks
                        .replace(/\$/g, '\\$')     // Escape dollar signs
                        .replace(/!/g, '\\!')      // Escape exclamation marks (bash history expansion)
                    }"`;
            }
        } catch (error) {
            throw new PathEscapingError(`Failed to escape path: ${error.message}`, filePath);
        }
    }

    /**
     * Escapes a JSON string for safe use in shell export commands
     */
    escapeJsonForShell(jsonString, shell = 'bash') {
        if (!jsonString || typeof jsonString !== 'string') {
            return '""';
        }

        const normalizedShell = this.validateShellType(shell);

        try {
            switch (normalizedShell) {
                case 'fish':
                    return `'${jsonString.replace(/'/g, "\\'")}'`;
                
                case 'bash':
                case 'zsh':
                case 'sh':
                default:
                    return `"${jsonString
                        .replace(/\\/g, '\\\\')
                        .replace(/"/g, '\\"')
                        .replace(/`/g, '\\`')
                        .replace(/\$/g, '\\$')
                        .replace(/!/g, '\\!')
                    }"`;
            }
        } catch (error) {
            throw new PathEscapingError(`Failed to escape JSON for shell: ${error.message}`, jsonString);
        }
    }

    /**
     * Adds a capture to the history with metadata
     */
    addCapture(filePath, metadata = {}) {
        if (!filePath) {
            throw new EnvironmentExportError('Capture file path is required', 'add_capture');
        }

        // Verify file exists if not in test mode
        if (!metadata.testMode && !fs.existsSync(filePath)) {
            throw new EnvironmentExportError(`Capture file does not exist: ${filePath}`, 'add_capture');
        }

        const captureEntry = {
            path: path.resolve(filePath),
            timestamp: new Date().toISOString(),
            size: metadata.testMode ? metadata.size || 0 : this.getFileSize(filePath),
            ...metadata
        };

        if (this.enableAtomicOperations) {
            // Atomic operation: create new array rather than modifying in place
            const newHistory = [...this.capturesHistory];
            newHistory.push(captureEntry);
            
            // Keep only the most recent entries
            if (newHistory.length > this.maxCapturesHistory) {
                newHistory.splice(0, newHistory.length - this.maxCapturesHistory);
            }
            
            this.capturesHistory = newHistory;
        } else {
            this.capturesHistory.push(captureEntry);
            
            // Keep only the most recent entries
            if (this.capturesHistory.length > this.maxCapturesHistory) {
                this.capturesHistory.shift();
            }
        }

        this.log('Added capture to history', {
            path: captureEntry.path,
            historyLength: this.capturesHistory.length
        });

        return captureEntry;
    }

    /**
     * Gets file size safely
     */
    getFileSize(filePath) {
        try {
            return fs.statSync(filePath).size;
        } catch (error) {
            this.log('Failed to get file size', { path: filePath, error: error.message });
            return 0;
        }
    }

    /**
     * Gets the most recent capture path
     */
    getLastCapture() {
        if (this.capturesHistory.length === 0) {
            return null;
        }
        return this.capturesHistory[this.capturesHistory.length - 1];
    }

    /**
     * Gets the captures history array
     */
    getCaptures() {
        return [...this.capturesHistory]; // Return copy to prevent external modification
    }

    /**
     * Generates export command for CLAUDE_LAST_CAPTURE
     */
    generateLastCaptureExport(shell = 'bash') {
        const normalizedShell = this.validateShellType(shell);
        const lastCapture = this.getLastCapture();

        if (!lastCapture) {
            return this.generateUnsetCommand('CLAUDE_LAST_CAPTURE', normalizedShell);
        }

        const escapedPath = this.escapePath(lastCapture.path, normalizedShell);
        
        switch (normalizedShell) {
            case 'fish':
                return `set -gx CLAUDE_LAST_CAPTURE ${escapedPath}`;
            
            case 'bash':
            case 'zsh':
            case 'sh':
            default:
                return `export CLAUDE_LAST_CAPTURE=${escapedPath}`;
        }
    }

    /**
     * Generates export command for CLAUDE_CAPTURES
     */
    generateCapturesExport(shell = 'bash') {
        const normalizedShell = this.validateShellType(shell);
        
        if (this.capturesHistory.length === 0) {
            return this.generateUnsetCommand('CLAUDE_CAPTURES', normalizedShell);
        }

        // Create simplified array for environment variable (just paths and timestamps)
        const capturesArray = this.capturesHistory.map(capture => ({
            path: capture.path,
            timestamp: capture.timestamp,
            size: capture.size
        }));

        const jsonString = JSON.stringify(capturesArray);
        const escapedJson = this.escapeJsonForShell(jsonString, normalizedShell);

        switch (normalizedShell) {
            case 'fish':
                return `set -gx CLAUDE_CAPTURES ${escapedJson}`;
            
            case 'bash':
            case 'zsh':
            case 'sh':
            default:
                return `export CLAUDE_CAPTURES=${escapedJson}`;
        }
    }

    /**
     * Generates unset command for environment variables
     */
    generateUnsetCommand(varName, shell = 'bash') {
        const normalizedShell = this.validateShellType(shell);
        
        switch (normalizedShell) {
            case 'fish':
                return `set -e ${varName}`;
            
            case 'bash':
            case 'zsh':
            case 'sh':
            default:
                return `unset ${varName}`;
        }
    }

    /**
     * Generates both export commands for a shell
     */
    generateAllExports(shell = 'bash') {
        const normalizedShell = this.validateShellType(shell);
        
        return {
            lastCapture: this.generateLastCaptureExport(normalizedShell),
            captures: this.generateCapturesExport(normalizedShell),
            shell: normalizedShell
        };
    }

    /**
     * Generates a complete shell script to export both variables
     */
    generateExportScript(shell = 'bash') {
        const exports = this.generateAllExports(shell);
        
        const header = `#!/usr/bin/env ${exports.shell}`;
        const comment = `# Claude Auto-Tee Environment Variables Export`;
        const timestamp = `# Generated: ${new Date().toISOString()}`;
        
        return [
            header,
            comment,
            timestamp,
            '',
            exports.lastCapture,
            exports.captures,
            ''
        ].join('\n');
    }

    /**
     * Clears the captures history
     */
    clearHistory() {
        this.capturesHistory = [];
        this.log('Cleared captures history');
    }

    /**
     * Updates an existing capture entry (atomic operation)
     */
    updateCapture(filePath, updates = {}) {
        if (!filePath) {
            throw new EnvironmentExportError('File path is required for update', 'update_capture');
        }

        const absolutePath = path.resolve(filePath);
        
        if (this.enableAtomicOperations) {
            // Atomic operation: create new array with updated entry
            const newHistory = this.capturesHistory.map(capture => {
                if (capture.path === absolutePath) {
                    return {
                        ...capture,
                        ...updates,
                        updatedAt: new Date().toISOString()
                    };
                }
                return capture;
            });
            
            this.capturesHistory = newHistory;
        } else {
            // Non-atomic update
            const captureIndex = this.capturesHistory.findIndex(capture => capture.path === absolutePath);
            if (captureIndex >= 0) {
                this.capturesHistory[captureIndex] = {
                    ...this.capturesHistory[captureIndex],
                    ...updates,
                    updatedAt: new Date().toISOString()
                };
            }
        }

        this.log('Updated capture', { path: absolutePath, updates });
    }

    /**
     * Removes a capture from history (atomic operation)
     */
    removeCapture(filePath) {
        if (!filePath) {
            throw new EnvironmentExportError('File path is required for removal', 'remove_capture');
        }

        const absolutePath = path.resolve(filePath);
        const originalLength = this.capturesHistory.length;
        
        if (this.enableAtomicOperations) {
            // Atomic operation: create new array without the entry
            this.capturesHistory = this.capturesHistory.filter(capture => capture.path !== absolutePath);
        } else {
            // Non-atomic removal
            const captureIndex = this.capturesHistory.findIndex(capture => capture.path === absolutePath);
            if (captureIndex >= 0) {
                this.capturesHistory.splice(captureIndex, 1);
            }
        }

        const removed = this.capturesHistory.length < originalLength;
        this.log('Remove capture result', { path: absolutePath, removed });
        
        return removed;
    }
}

// Export the class and error types
module.exports = {
    EnvExporter,
    EnvironmentExportError,
    ShellCompatibilityError,
    PathEscapingError
};