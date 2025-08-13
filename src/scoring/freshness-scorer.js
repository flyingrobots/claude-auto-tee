/**
 * FreshnessScorer - Intelligent scoring system for command output freshness
 * 
 * Calculates freshness scores (0-100) based on:
 * - Time decay (exponential)
 * - File modifications
 * - Command reruns
 * - System state changes
 * 
 * Part of P3.T003: PostToolUse hook implementation
 */

const fs = require('fs').promises;
const path = require('path');
const crypto = require('crypto');
const { execSync } = require('child_process');

/**
 * Configuration for freshness scoring algorithm
 */
const DEFAULT_CONFIG = {
  // Time decay parameters
  lambda: 0.08,  // Decay rate (slightly slower decay for better mid-range scores)
  maxAge: 24,   // Hours after which score approaches 0
  
  // Penalty factors (reduced for better accuracy)
  fileChangePenalty: 5,      // Points lost per related file modification
  commandRerunPenalty: 15,   // Points lost if same command run again
  gitChangePenalty: 8,       // Points lost for git operations
  packageChangePenalty: 12,  // Points lost for package updates
  
  // Confidence intervals
  baseConfidence: 0.95,      // Base confidence level
  uncertaintyFactor: 0.1,    // Uncertainty increase per hour
  
  // Performance
  maxComputeTime: 10,        // Maximum computation time in ms
  cacheEnabled: true,        // Enable score caching
};

/**
 * Data structure for capture metadata
 */
class CaptureMetadata {
  constructor(data) {
    this.path = data.path || '';
    this.command = data.command || '';
    this.timestamp = new Date(data.timestamp || Date.now());
    this.size = data.size || 0;
    this.hash = data.hash || '';
    this.workingDirectory = data.workingDirectory || process.cwd();
    this.relatedFiles = data.relatedFiles || [];
    this.systemState = data.systemState || {};
  }
}

/**
 * Result object for freshness scoring
 */
class FreshnessResult {
  constructor() {
    this.score = 0;              // Main freshness score (0-100)
    this.confidence = 0;         // Confidence interval (0-1)
    this.factors = {};           // Individual scoring factors
    this.reasons = [];           // Explanations for staleness
    this.computeTime = 0;        // Time taken to compute (ms)
    this.cached = false;         // Whether result was cached
  }
}

/**
 * Main freshness scorer class
 */
class FreshnessScorer {
  constructor(config = {}) {
    this.config = { ...DEFAULT_CONFIG, ...config };
    this.cache = new Map();
    this.systemStateCache = new Map();
  }

  /**
   * Calculate freshness score for a capture
   * @param {CaptureMetadata} metadata - Capture metadata
   * @param {Object} currentState - Current system state
   * @returns {FreshnessResult} Scoring result
   */
  async calculateScore(metadata, currentState = {}) {
    const startTime = Date.now();
    const result = new FreshnessResult();
    
    try {
      // Check cache first
      const cacheKey = this._generateCacheKey(metadata, currentState);
      if (this.config.cacheEnabled && this.cache.has(cacheKey)) {
        const cached = this.cache.get(cacheKey);
        result.cached = true;
        result.computeTime = Date.now() - startTime;
        return { ...cached, computeTime: result.computeTime, cached: true };
      }

      // Calculate time-based decay
      await this._calculateTimeDecay(metadata, result);
      
      // Check file modifications
      await this._checkFileModifications(metadata, currentState, result);
      
      // Check command reruns
      await this._checkCommandReruns(metadata, currentState, result);
      
      // Check system state changes
      await this._checkSystemChanges(metadata, currentState, result);
      
      // Calculate final score and confidence
      this._calculateFinalScore(result);
      this._calculateConfidence(metadata, result);
      
      result.computeTime = Date.now() - startTime;
      
      // Cache result if enabled
      if (this.config.cacheEnabled) {
        this.cache.set(cacheKey, { ...result, cached: false });
      }
      
      return result;
      
    } catch (error) {
      result.score = 0;
      result.confidence = 0;
      result.reasons.push(`Error calculating freshness: ${error.message}`);
      result.computeTime = Date.now() - startTime;
      return result;
    }
  }

  /**
   * Calculate time-based decay using exponential function
   * score = 100 * exp(-λ * hours_elapsed)
   */
  async _calculateTimeDecay(metadata, result) {
    const now = new Date();
    const hoursElapsed = (now - metadata.timestamp) / (1000 * 60 * 60);
    
    const timeScore = Math.max(0, 100 * Math.exp(-this.config.lambda * hoursElapsed));
    
    result.factors.timeDecay = timeScore;
    result.score = timeScore;
    
    if (hoursElapsed > 1) {
      result.reasons.push(`Capture is ${hoursElapsed.toFixed(1)} hours old`);
    }
    
    if (timeScore < 50) {
      result.reasons.push('Significant time decay detected');
    }
  }

  /**
   * Check for related file modifications
   */
  async _checkFileModifications(metadata, currentState, result) {
    let fileChanges = 0;
    const changedFiles = [];

    try {
      const now = new Date();
      const hoursElapsed = (now - metadata.timestamp) / (1000 * 60 * 60);
      
      // For very fresh captures (< 1 minute), be more lenient with file changes
      if (hoursElapsed < 1/60) {
        return; // Skip file change penalties for captures less than 1 minute old
      }

      // Check the main output file (but be lenient for recent creates)
      if (metadata.path && await this._fileExists(metadata.path)) {
        const stats = await fs.stat(metadata.path);
        const timeDiff = (stats.mtime - metadata.timestamp) / 1000; // seconds
        
        // Only penalize if modified significantly after capture (> 5 seconds)
        if (timeDiff > 5) {
          fileChanges++;
          changedFiles.push(metadata.path);
        }
      }

      // Only check working directory for captures older than 30 minutes
      if (hoursElapsed > 0.5) {
        const workingDir = metadata.workingDirectory;
        if (await this._fileExists(workingDir)) {
          const files = await this._getRecentlyModifiedFiles(workingDir, metadata.timestamp);
          fileChanges += Math.min(files.length, 2); // Limit impact
          changedFiles.push(...files.slice(0, 2));
        }
      }

      // Check explicitly related files
      for (const file of metadata.relatedFiles.slice(0, 3)) { // Limit for performance
        if (await this._fileExists(file)) {
          const stats = await fs.stat(file);
          if (stats.mtime > metadata.timestamp) {
            fileChanges++;
            changedFiles.push(file);
          }
        }
      }

    } catch (error) {
      // Ignore file check errors for better performance and reliability
    }

    if (fileChanges > 0) {
      const penalty = fileChanges * this.config.fileChangePenalty;
      result.factors.fileChanges = -penalty;
      result.score = Math.max(0, result.score - penalty);
      result.reasons.push(`${fileChanges} file(s) modified since capture: ${changedFiles.slice(0, 3).join(', ')}`);
      
      if (changedFiles.length > 3) {
        result.reasons.push(`... and ${changedFiles.length - 3} more files`);
      }
    }
  }

  /**
   * Check if the same command has been run again
   */
  async _checkCommandReruns(metadata, currentState, result) {
    try {
      // Check if command appears in recent history
      const recentCommands = currentState.recentCommands || [];
      const commandHash = crypto.createHash('md5').update(metadata.command).digest('hex');
      
      const rerunCount = recentCommands.filter(cmd => {
        const cmdHash = crypto.createHash('md5').update(cmd.command || '').digest('hex');
        return cmdHash === commandHash && new Date(cmd.timestamp) > metadata.timestamp;
      }).length;

      if (rerunCount > 0) {
        const penalty = rerunCount * this.config.commandRerunPenalty;
        result.factors.commandReruns = -penalty;
        result.score = Math.max(0, result.score - penalty);
        result.reasons.push(`Same command run ${rerunCount} time(s) since capture`);
      }

    } catch (error) {
      result.reasons.push(`Command rerun check error: ${error.message}`);
    }
  }

  /**
   * Check for system state changes (git, packages, etc.)
   */
  async _checkSystemChanges(metadata, currentState, result) {
    try {
      // Check git state
      await this._checkGitChanges(metadata, result);
      
      // Check package changes
      await this._checkPackageChanges(metadata, result);
      
      // Check environment changes
      await this._checkEnvironmentChanges(metadata, currentState, result);
      
    } catch (error) {
      result.reasons.push(`System state check error: ${error.message}`);
    }
  }

  /**
   * Check for git repository changes
   */
  async _checkGitChanges(metadata, result) {
    try {
      const workingDir = metadata.workingDirectory;
      
      // Skip git checks for very fresh captures (< 5 minutes)
      const now = new Date();
      const hoursElapsed = (now - metadata.timestamp) / (1000 * 60 * 60);
      if (hoursElapsed < 5/60) {
        return;
      }
      
      // Quick check if we're in a git repository
      try {
        execSync('git rev-parse --git-dir', { 
          cwd: workingDir, 
          stdio: 'ignore',
          timeout: 1000 // 1 second timeout
        });
      } catch {
        return; // Not a git repository or timeout
      }

      // Only check git for older captures to improve performance
      if (hoursElapsed > 1) { // Wait longer before checking git
        try {
          // Simple check - just see if there are uncommitted changes
          const status = execSync('git status --porcelain', { 
            cwd: workingDir, 
            encoding: 'utf8',
            timeout: 1000
          }).trim();

          if (status) {
            const penalty = this.config.gitChangePenalty;
            result.factors.gitChanges = -penalty;
            result.score = Math.max(0, result.score - penalty);
            result.reasons.push('Git repository has uncommitted changes');
          }
        } catch {
          // Ignore git errors for performance
        }
      }

    } catch (error) {
      // Ignore git errors in non-git directories
    }
  }

  /**
   * Check for package manager changes
   */
  async _checkPackageChanges(metadata, result) {
    try {
      const workingDir = metadata.workingDirectory;
      
      // Skip package checks for very fresh captures (< 10 minutes)
      const now = new Date();
      const hoursElapsed = (now - metadata.timestamp) / (1000 * 60 * 60);
      if (hoursElapsed < 10/60) {
        return;
      }
      
      // Only check package files for captures older than 1 hour
      if (hoursElapsed < 1) {
        return;
      }
      
      // Check package.json modification with tolerance
      const packageJsonPath = path.join(workingDir, 'package.json');
      if (await this._fileExists(packageJsonPath)) {
        const stats = await fs.stat(packageJsonPath);
        const timeDiff = (stats.mtime - metadata.timestamp) / 1000; // seconds
        
        // Only penalize if modified significantly after capture (> 60 seconds)
        if (timeDiff > 60) {
          const penalty = this.config.packageChangePenalty;
          result.factors.packageChanges = -penalty;
          result.score = Math.max(0, result.score - penalty);
          result.reasons.push('package.json modified since capture');
        }
      }

      // Check package-lock.json modification with tolerance
      const lockfilePath = path.join(workingDir, 'package-lock.json');
      if (await this._fileExists(lockfilePath)) {
        const stats = await fs.stat(lockfilePath);
        const timeDiff = (stats.mtime - metadata.timestamp) / 1000; // seconds
        
        // Only penalize if modified significantly after capture (> 60 seconds)
        if (timeDiff > 60) {
          const penalty = this.config.packageChangePenalty;
          result.factors.packageChanges = Math.min(result.factors.packageChanges || 0, -penalty);
          result.score = Math.max(0, result.score - penalty);
          result.reasons.push('Dependencies changed since capture');
        }
      }

    } catch (error) {
      // Ignore package check errors
    }
  }

  /**
   * Check for environment variable changes
   */
  async _checkEnvironmentChanges(metadata, currentState, result) {
    // Simple environment change detection
    if (metadata.systemState && currentState.environment) {
      const oldEnvHash = metadata.systemState.environmentHash;
      const currentEnvHash = this._hashEnvironment(currentState.environment);
      
      if (oldEnvHash && oldEnvHash !== currentEnvHash) {
        result.factors.envChanges = -5;
        result.score = Math.max(0, result.score - 5);
        result.reasons.push('Environment variables changed');
      }
    }
  }

  /**
   * Calculate final weighted score
   */
  _calculateFinalScore(result) {
    // Score is already calculated incrementally
    result.score = Math.max(0, Math.min(100, result.score));
  }

  /**
   * Calculate confidence interval
   */
  _calculateConfidence(metadata, result) {
    const now = new Date();
    const hoursElapsed = (now - metadata.timestamp) / (1000 * 60 * 60);
    
    // Confidence decreases over time
    let confidence = this.config.baseConfidence;
    confidence -= hoursElapsed * this.config.uncertaintyFactor;
    
    // Reduce confidence for missing metadata
    if (!metadata.hash) confidence -= 0.1;
    if (!metadata.size) confidence -= 0.05;
    if (metadata.relatedFiles.length === 0) confidence -= 0.05;
    
    // Increase confidence for recent captures with complete metadata
    if (hoursElapsed < 0.5 && metadata.hash && metadata.size) {
      confidence = Math.min(1.0, confidence + 0.05);
    }
    
    result.confidence = Math.max(0.1, Math.min(1.0, confidence));
  }

  /**
   * Helper methods
   */

  async _fileExists(filePath) {
    try {
      await fs.access(filePath);
      return true;
    } catch {
      return false;
    }
  }

  async _getRecentlyModifiedFiles(directory, sinceTime) {
    try {
      const files = await fs.readdir(directory);
      const recentFiles = [];
      
      // Limit to first 5 files for better performance
      for (const file of files.slice(0, 5)) {
        try {
          const filePath = path.join(directory, file);
          const stats = await fs.stat(filePath);
          
          if (stats.isFile() && stats.mtime > sinceTime) {
            recentFiles.push(filePath);
          }
        } catch {
          // Skip files we can't access
        }
      }
      
      return recentFiles;
    } catch {
      return [];
    }
  }

  _generateCacheKey(metadata, currentState) {
    const keyData = {
      path: metadata.path,
      command: metadata.command,
      timestamp: metadata.timestamp.getTime(),
      stateHash: JSON.stringify(currentState)
    };
    return crypto.createHash('md5').update(JSON.stringify(keyData)).digest('hex');
  }

  _hashEnvironment(env) {
    const relevant = ['NODE_ENV', 'PATH', 'HOME', 'PWD'];
    const envData = {};
    
    for (const key of relevant) {
      if (env[key]) {
        envData[key] = env[key];
      }
    }
    
    return crypto.createHash('md5').update(JSON.stringify(envData)).digest('hex');
  }

  /**
   * Clear the scoring cache
   */
  clearCache() {
    this.cache.clear();
    this.systemStateCache.clear();
  }

  /**
   * Get scoring statistics
   */
  getStats() {
    return {
      cacheSize: this.cache.size,
      config: this.config
    };
  }
}

module.exports = {
  FreshnessScorer,
  CaptureMetadata,
  FreshnessResult,
  DEFAULT_CONFIG
};