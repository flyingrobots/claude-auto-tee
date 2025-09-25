/**
 * Comprehensive tests for FreshnessScorer
 * Testing P3.T003: Freshness scoring algorithm
 * 
 * Validates:
 * - Time decay calculations
 * - File modification penalties
 * - Command rerun detection
 * - System state changes
 * - Confidence intervals
 * - Performance requirements (<10ms)
 * - Explainable scoring
 */

const { FreshnessScorer, CaptureMetadata, FreshnessResult, DEFAULT_CONFIG } = require('../../src/scoring/freshness-scorer');
const fs = require('fs').promises;
const path = require('path');
const os = require('os');

describe('FreshnessScorer', () => {
  let scorer;
  let tempDir;
  let testMetadata;

  beforeEach(async () => {
    scorer = new FreshnessScorer();
    tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'freshness-test-'));
    
    testMetadata = new CaptureMetadata({
      path: path.join(tempDir, 'output.txt'),
      command: 'echo "test"',
      timestamp: new Date(),
      size: 100,
      hash: 'abc123',
      workingDirectory: tempDir,
      relatedFiles: [],
      systemState: {
        environmentHash: 'env123'
      }
    });

    // Create test output file
    await fs.writeFile(testMetadata.path, 'test output');
  });

  afterEach(async () => {
    try {
      await fs.rm(tempDir, { recursive: true, force: true });
    } catch (error) {
      // Ignore cleanup errors
    }
  });

  describe('Constructor and Configuration', () => {
    test('should use default configuration', () => {
      const scorer = new FreshnessScorer();
      expect(scorer.config.lambda).toBe(DEFAULT_CONFIG.lambda);
      expect(scorer.config.maxAge).toBe(DEFAULT_CONFIG.maxAge);
      expect(scorer.config.fileChangePenalty).toBe(DEFAULT_CONFIG.fileChangePenalty);
    });

    test('should allow custom configuration', () => {
      const customConfig = { lambda: 0.2, fileChangePenalty: 15 };
      const scorer = new FreshnessScorer(customConfig);
      
      expect(scorer.config.lambda).toBe(0.2);
      expect(scorer.config.fileChangePenalty).toBe(15);
      expect(scorer.config.maxAge).toBe(DEFAULT_CONFIG.maxAge); // Default preserved
    });
  });

  describe('CaptureMetadata', () => {
    test('should handle complete metadata', () => {
      const metadata = new CaptureMetadata({
        path: '/test/path',
        command: 'ls -la',
        timestamp: '2023-01-01T00:00:00Z',
        size: 1024,
        hash: 'hash123'
      });

      expect(metadata.path).toBe('/test/path');
      expect(metadata.command).toBe('ls -la');
      expect(metadata.timestamp).toBeInstanceOf(Date);
      expect(metadata.size).toBe(1024);
      expect(metadata.hash).toBe('hash123');
    });

    test('should handle partial metadata with defaults', () => {
      const metadata = new CaptureMetadata({
        command: 'test command'
      });

      expect(metadata.path).toBe('');
      expect(metadata.command).toBe('test command');
      expect(metadata.timestamp).toBeInstanceOf(Date);
      expect(metadata.size).toBe(0);
      expect(metadata.relatedFiles).toEqual([]);
    });
  });

  describe('Time Decay Calculation', () => {
    test('should give maximum score for fresh captures', async () => {
      const result = await scorer.calculateScore(testMetadata);
      
      expect(result.score).toBeGreaterThan(95);
      expect(result.factors.timeDecay).toBeGreaterThan(95);
      expect(result.confidence).toBeGreaterThan(0.9);
    });

    test('should apply exponential decay over time', async () => {
      // Test capture from 1 hour ago
      const oldTimestamp = new Date(Date.now() - 60 * 60 * 1000);
      const oldMetadata = new CaptureMetadata({
        ...testMetadata,
        timestamp: oldTimestamp
      });

      const result = await scorer.calculateScore(oldMetadata);
      const expectedScore = 100 * Math.exp(-DEFAULT_CONFIG.lambda * 1);
      
      expect(result.factors.timeDecay).toBeCloseTo(expectedScore, 1);
      expect(result.score).toBeLessThan(95);
      expect(result.reasons.some(r => r.includes('hours old'))).toBe(true);
    });

    test('should approach zero for very old captures', async () => {
      // Test capture from 24 hours ago
      const veryOldTimestamp = new Date(Date.now() - 24 * 60 * 60 * 1000);
      const veryOldMetadata = new CaptureMetadata({
        ...testMetadata,
        timestamp: veryOldTimestamp
      });

      const result = await scorer.calculateScore(veryOldMetadata);
      
      expect(result.score).toBeLessThan(10);
      expect(result.reasons.some(r => r.includes('Significant time decay'))).toBe(true);
    });
  });

  describe('File Modification Detection', () => {
    test('should penalize when output file is modified', async () => {
      // Modify the output file after capture time
      const pastTimestamp = new Date(Date.now() - 60 * 1000); // 1 minute ago
      const pastMetadata = new CaptureMetadata({
        ...testMetadata,
        timestamp: pastTimestamp
      });

      // Modify file (this will have a newer mtime than pastTimestamp)
      await fs.writeFile(testMetadata.path, 'modified content');

      const result = await scorer.calculateScore(pastMetadata);
      
      expect(result.factors.fileChanges).toBe(-DEFAULT_CONFIG.fileChangePenalty);
      expect(result.score).toBeLessThan(90); // Should be penalized
      expect(result.reasons.some(r => r.includes('file(s) modified'))).toBe(true);
    });

    test('should detect modifications in working directory', async () => {
      const pastTimestamp = new Date(Date.now() - 60 * 1000);
      const pastMetadata = new CaptureMetadata({
        ...testMetadata,
        timestamp: pastTimestamp
      });

      // Create new files in working directory
      await fs.writeFile(path.join(tempDir, 'new-file.txt'), 'new content');
      await fs.writeFile(path.join(tempDir, 'another-file.txt'), 'another content');

      const result = await scorer.calculateScore(pastMetadata);
      
      expect(result.factors.fileChanges).toBeLessThan(0);
      expect(result.reasons.some(r => r.includes('file(s) modified'))).toBe(true);
    });

    test('should check related files', async () => {
      const relatedFile = path.join(tempDir, 'related.txt');
      await fs.writeFile(relatedFile, 'related content');
      
      const pastTimestamp = new Date(Date.now() - 60 * 1000);
      const metadataWithRelated = new CaptureMetadata({
        ...testMetadata,
        timestamp: pastTimestamp,
        relatedFiles: [relatedFile]
      });

      // Modify the related file
      await fs.writeFile(relatedFile, 'modified related content');

      const result = await scorer.calculateScore(metadataWithRelated);
      
      expect(result.factors.fileChanges).toBeLessThan(0);
      expect(result.reasons.some(r => r.includes('file(s) modified'))).toBe(true);
    });
  });

  describe('Command Rerun Detection', () => {
    test('should penalize when same command is rerun', async () => {
      const currentState = {
        recentCommands: [
          {
            command: 'echo "test"', // Same command as in testMetadata
            timestamp: new Date(Date.now() - 30 * 1000) // 30 seconds ago
          }
        ]
      };

      const pastMetadata = new CaptureMetadata({
        ...testMetadata,
        timestamp: new Date(Date.now() - 60 * 1000) // 1 minute ago
      });

      const result = await scorer.calculateScore(pastMetadata, currentState);
      
      expect(result.factors.commandReruns).toBe(-DEFAULT_CONFIG.commandRerunPenalty);
      expect(result.reasons.some(r => r.includes('Same command run'))).toBe(true);
    });

    test('should handle multiple reruns', async () => {
      const currentState = {
        recentCommands: [
          {
            command: 'echo "test"',
            timestamp: new Date(Date.now() - 30 * 1000)
          },
          {
            command: 'echo "test"',
            timestamp: new Date(Date.now() - 15 * 1000)
          }
        ]
      };

      const pastMetadata = new CaptureMetadata({
        ...testMetadata,
        timestamp: new Date(Date.now() - 60 * 1000)
      });

      const result = await scorer.calculateScore(pastMetadata, currentState);
      
      expect(result.factors.commandReruns).toBe(-2 * DEFAULT_CONFIG.commandRerunPenalty);
      expect(result.reasons.some(r => r.includes('2 time(s)'))).toBe(true);
    });

    test('should not penalize different commands', async () => {
      const currentState = {
        recentCommands: [
          {
            command: 'ls -la', // Different command
            timestamp: new Date(Date.now() - 30 * 1000)
          }
        ]
      };

      const result = await scorer.calculateScore(testMetadata, currentState);
      
      expect(result.factors.commandReruns).toBeUndefined();
    });
  });

  describe('System State Changes', () => {
    test('should detect environment changes', async () => {
      const currentState = {
        environment: {
          NODE_ENV: 'production',
          PATH: '/different/path'
        }
      };

      const metadataWithEnv = new CaptureMetadata({
        ...testMetadata,
        systemState: {
          environmentHash: 'different-hash'
        }
      });

      const result = await scorer.calculateScore(metadataWithEnv, currentState);
      
      expect(result.factors.envChanges).toBe(-5);
      expect(result.reasons.some(r => r.includes('Environment variables changed'))).toBe(true);
    });

    test('should handle package.json changes', async () => {
      // Create a package.json file
      const packageJson = path.join(tempDir, 'package.json');
      await fs.writeFile(packageJson, JSON.stringify({ name: 'test' }));
      
      // Use old timestamp so package.json appears newer
      const oldMetadata = new CaptureMetadata({
        ...testMetadata,
        timestamp: new Date(Date.now() - 60 * 1000),
        workingDirectory: tempDir
      });

      const result = await scorer.calculateScore(oldMetadata);
      
      expect(result.factors.packageChanges).toBe(-DEFAULT_CONFIG.packageChangePenalty);
      expect(result.reasons.some(r => r.includes('package.json modified'))).toBe(true);
    });
  });

  describe('Confidence Calculation', () => {
    test('should have high confidence for recent complete metadata', async () => {
      const completeMetadata = new CaptureMetadata({
        path: testMetadata.path,
        command: 'test command',
        timestamp: new Date(),
        size: 100,
        hash: 'abc123',
        relatedFiles: ['file1.txt'],
        workingDirectory: tempDir
      });

      const result = await scorer.calculateScore(completeMetadata);
      
      expect(result.confidence).toBeGreaterThan(0.9);
    });

    test('should reduce confidence for missing metadata', async () => {
      const incompleteMetadata = new CaptureMetadata({
        path: testMetadata.path,
        command: 'test command',
        timestamp: new Date(),
        // Missing size, hash, relatedFiles
      });

      const result = await scorer.calculateScore(incompleteMetadata);
      
      expect(result.confidence).toBeLessThan(0.9);
    });

    test('should reduce confidence over time', async () => {
      const oldMetadata = new CaptureMetadata({
        ...testMetadata,
        timestamp: new Date(Date.now() - 5 * 60 * 60 * 1000) // 5 hours ago
      });

      const result = await scorer.calculateScore(oldMetadata);
      
      expect(result.confidence).toBeLessThan(0.7);
    });
  });

  describe('Performance Requirements', () => {
    test('should compute scores in under 10ms', async () => {
      const result = await scorer.calculateScore(testMetadata);
      
      expect(result.computeTime).toBeLessThan(10);
    });

    test('should handle large file lists efficiently', async () => {
      // Create many files to test performance
      const manyFiles = [];
      for (let i = 0; i < 50; i++) {
        const file = path.join(tempDir, `file${i}.txt`);
        await fs.writeFile(file, `content ${i}`);
        manyFiles.push(file);
      }

      const largeMetadata = new CaptureMetadata({
        ...testMetadata,
        relatedFiles: manyFiles
      });

      const result = await scorer.calculateScore(largeMetadata);
      
      expect(result.computeTime).toBeLessThan(50); // Allow more time for large datasets
      expect(result.score).toBeGreaterThan(0);
    });
  });

  describe('Caching', () => {
    test('should cache results when enabled', async () => {
      const scorer = new FreshnessScorer({ cacheEnabled: true });
      
      const result1 = await scorer.calculateScore(testMetadata);
      const result2 = await scorer.calculateScore(testMetadata);
      
      expect(result1.cached).toBe(false);
      expect(result2.cached).toBe(true);
      expect(result2.computeTime).toBeLessThan(result1.computeTime);
    });

    test('should not cache when disabled', async () => {
      const scorer = new FreshnessScorer({ cacheEnabled: false });
      
      const result1 = await scorer.calculateScore(testMetadata);
      const result2 = await scorer.calculateScore(testMetadata);
      
      expect(result1.cached).toBe(false);
      expect(result2.cached).toBe(false);
    });

    test('should clear cache properly', async () => {
      const scorer = new FreshnessScorer({ cacheEnabled: true });
      
      await scorer.calculateScore(testMetadata);
      expect(scorer.getStats().cacheSize).toBe(1);
      
      scorer.clearCache();
      expect(scorer.getStats().cacheSize).toBe(0);
    });
  });

  describe('Error Handling', () => {
    test('should handle missing files gracefully', async () => {
      const badMetadata = new CaptureMetadata({
        path: '/nonexistent/file.txt',
        command: 'test',
        timestamp: new Date(),
        workingDirectory: '/nonexistent/directory'
      });

      const result = await scorer.calculateScore(badMetadata);
      
      expect(result.score).toBeGreaterThanOrEqual(0);
      expect(result.confidence).toBeGreaterThan(0);
    });

    test('should handle malformed metadata', async () => {
      const malformedMetadata = new CaptureMetadata({
        timestamp: 'invalid-date',
        size: 'not-a-number'
      });

      const result = await scorer.calculateScore(malformedMetadata);
      
      expect(result.score).toBeGreaterThanOrEqual(0);
      expect(result.confidence).toBeGreaterThan(0);
    });

    test('should return error information in reasons', async () => {
      // Force an error by providing invalid working directory
      const errorMetadata = new CaptureMetadata({
        ...testMetadata,
        workingDirectory: null
      });

      const result = await scorer.calculateScore(errorMetadata);
      
      expect(result.score).toBeGreaterThanOrEqual(0);
      expect(result.reasons.length).toBeGreaterThan(0);
    });
  });

  describe('Explainable Scoring', () => {
    test('should provide clear explanations for score factors', async () => {
      const oldTimestamp = new Date(Date.now() - 2 * 60 * 60 * 1000); // 2 hours ago
      const oldMetadata = new CaptureMetadata({
        ...testMetadata,
        timestamp: oldTimestamp
      });

      // Modify a file to trigger file change penalty
      await fs.writeFile(testMetadata.path, 'modified content');

      const currentState = {
        recentCommands: [
          {
            command: 'echo "test"',
            timestamp: new Date(Date.now() - 30 * 1000)
          }
        ]
      };

      const result = await scorer.calculateScore(oldMetadata, currentState);
      
      expect(result.reasons.length).toBeGreaterThan(0);
      expect(result.reasons.some(r => r.includes('hours old'))).toBe(true);
      expect(result.reasons.some(r => r.includes('file(s) modified'))).toBe(true);
      expect(result.reasons.some(r => r.includes('Same command run'))).toBe(true);
    });

    test('should provide factor breakdown', async () => {
      const result = await scorer.calculateScore(testMetadata);
      
      expect(result.factors).toBeDefined();
      expect(result.factors.timeDecay).toBeDefined();
      expect(typeof result.factors.timeDecay).toBe('number');
    });
  });

  describe('Integration Tests', () => {
    test('should achieve >= 90% accuracy for freshness detection', async () => {
      const testCases = [
        // Fresh captures should score high
        { metadata: testMetadata, expectedRange: [90, 100] },
        
        // Old captures should score low
        { 
          metadata: new CaptureMetadata({
            ...testMetadata, 
            timestamp: new Date(Date.now() - 12 * 60 * 60 * 1000)
          }), 
          expectedRange: [0, 30] 
        },
        
        // Medium age captures should score medium
        { 
          metadata: new CaptureMetadata({
            ...testMetadata, 
            timestamp: new Date(Date.now() - 2 * 60 * 60 * 1000)
          }), 
          expectedRange: [40, 90] 
        }
      ];

      let correctPredictions = 0;
      
      for (const testCase of testCases) {
        const result = await scorer.calculateScore(testCase.metadata);
        const [minExpected, maxExpected] = testCase.expectedRange;
        
        if (result.score >= minExpected && result.score <= maxExpected) {
          correctPredictions++;
        }
      }

      const accuracy = correctPredictions / testCases.length;
      expect(accuracy).toBeGreaterThanOrEqual(0.9); // 90% accuracy requirement
    });

    test('should handle realistic capture scenarios', async () => {
      // Simulate a realistic development scenario
      const scenarios = [
        {
          name: 'Fresh test output',
          metadata: new CaptureMetadata({
            path: path.join(tempDir, 'test-output.txt'),
            command: 'npm test',
            timestamp: new Date(),
            size: 1024,
            hash: 'test123'
          })
        },
        {
          name: 'Build output after file changes',
          metadata: new CaptureMetadata({
            path: path.join(tempDir, 'build-output.txt'),
            command: 'npm run build',
            timestamp: new Date(Date.now() - 30 * 60 * 1000), // 30 minutes ago
            size: 5000,
            hash: 'build456'
          }),
          currentState: {
            recentCommands: [{
              command: 'npm run build',
              timestamp: new Date(Date.now() - 10 * 60 * 1000)
            }]
          }
        }
      ];

      for (const scenario of scenarios) {
        const result = await scorer.calculateScore(
          scenario.metadata, 
          scenario.currentState || {}
        );
        
        expect(result.score).toBeGreaterThanOrEqual(0);
        expect(result.score).toBeLessThanOrEqual(100);
        expect(result.confidence).toBeGreaterThan(0);
        expect(result.confidence).toBeLessThanOrEqual(1);
        expect(result.computeTime).toBeLessThan(10);
      }
    });
  });
});