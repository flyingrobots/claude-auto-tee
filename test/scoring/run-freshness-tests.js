#!/usr/bin/env node
/**
 * Simple test runner for FreshnessScorer tests
 * Compatible with existing test structure
 */

const { FreshnessScorer, CaptureMetadata, FreshnessResult, DEFAULT_CONFIG } = require('../../src/scoring/freshness-scorer');
const fs = require('fs').promises;
const path = require('path');
const os = require('os');
const assert = require('assert');

let testResults = {
  passed: 0,
  failed: 0,
  total: 0
};

// Simple test framework functions

function expect(actual) {
  return {
    toBe: (expected) => {
      assert.strictEqual(actual, expected);
    },
    toBeCloseTo: (expected, precision = 2) => {
      const diff = Math.abs(actual - expected);
      const tolerance = Math.pow(10, -precision);
      assert(diff < tolerance, `Expected ${actual} to be close to ${expected} within ${tolerance}`);
    },
    toBeGreaterThan: (expected) => {
      assert(actual > expected, `Expected ${actual} to be greater than ${expected}`);
    },
    toBeLessThan: (expected) => {
      assert(actual < expected, `Expected ${actual} to be less than ${expected}`);
    },
    toBeGreaterThanOrEqual: (expected) => {
      assert(actual >= expected, `Expected ${actual} to be >= ${expected}`);
    },
    toBeLessThanOrEqual: (expected) => {
      assert(actual <= expected, `Expected ${actual} to be <= ${expected}`);
    },
    toEqual: (expected) => {
      assert.deepEqual(actual, expected);
    },
    toBeDefined: () => {
      assert(actual !== undefined, 'Expected value to be defined');
    },
    toBeInstanceOf: (constructor) => {
      assert(actual instanceof constructor, `Expected ${actual} to be instance of ${constructor.name}`);
    }
  };
}

// Global test state
let scorer;
let tempDir;
let testMetadata;

async function beforeEach() {
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
}

async function afterEach() {
  try {
    await fs.rm(tempDir, { recursive: true, force: true });
  } catch (error) {
    // Ignore cleanup errors
  }
}

// Test suites
async function runBasicTests() {
  console.log('\n📦 Basic Functionality');
  
  const tests = [
    {
      name: 'should use default configuration',
      test: async () => {
        const scorer = new FreshnessScorer();
        expect(scorer.config.lambda).toBe(DEFAULT_CONFIG.lambda);
        expect(scorer.config.maxAge).toBe(DEFAULT_CONFIG.maxAge);
        expect(scorer.config.fileChangePenalty).toBe(DEFAULT_CONFIG.fileChangePenalty);
      }
    },
    {
      name: 'should allow custom configuration',
      test: async () => {
        const customConfig = { lambda: 0.2, fileChangePenalty: 15 };
        const scorer = new FreshnessScorer(customConfig);
        
        expect(scorer.config.lambda).toBe(0.2);
        expect(scorer.config.fileChangePenalty).toBe(15);
        expect(scorer.config.maxAge).toBe(DEFAULT_CONFIG.maxAge);
      }
    },
    {
      name: 'should handle complete metadata',
      test: async () => {
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
      }
    }
  ];

  for (const { name, test } of tests) {
    testResults.total++;
    try {
      await beforeEach();
      await test();
      await afterEach();
      console.log(`  ✅ ${name}`);
      testResults.passed++;
    } catch (error) {
      console.log(`  ❌ ${name}: ${error.message}`);
      testResults.failed++;
    }
  }
}

async function runTimeDecayTests() {
  console.log('\n📦 Time Decay');
  
  const tests = [
    {
      name: 'should give maximum score for fresh captures',
      test: async () => {
        const result = await scorer.calculateScore(testMetadata);
        
        expect(result.score).toBeGreaterThan(95);
        expect(result.factors.timeDecay).toBeGreaterThan(95);
        expect(result.confidence).toBeGreaterThan(0.9);
      }
    },
    {
      name: 'should apply exponential decay over time',
      test: async () => {
        const oldTimestamp = new Date(Date.now() - 60 * 60 * 1000);
        const oldMetadata = new CaptureMetadata({
          ...testMetadata,
          timestamp: oldTimestamp
        });

        const result = await scorer.calculateScore(oldMetadata);
        const expectedScore = 100 * Math.exp(-DEFAULT_CONFIG.lambda * 1);
        
        expect(result.factors.timeDecay).toBeCloseTo(expectedScore, 1);
        expect(result.score).toBeLessThan(95);
      }
    },
    {
      name: 'should approach zero for very old captures',
      test: async () => {
        const veryOldTimestamp = new Date(Date.now() - 24 * 60 * 60 * 1000);
        const veryOldMetadata = new CaptureMetadata({
          ...testMetadata,
          timestamp: veryOldTimestamp
        });

        const result = await scorer.calculateScore(veryOldMetadata);
        
        expect(result.score).toBeLessThan(10);
      }
    }
  ];

  for (const { name, test } of tests) {
    testResults.total++;
    try {
      await beforeEach();
      await test();
      await afterEach();
      console.log(`  ✅ ${name}`);
      testResults.passed++;
    } catch (error) {
      console.log(`  ❌ ${name}: ${error.message}`);
      testResults.failed++;
    }
  }
}

async function runPerformanceTests() {
  console.log('\n📦 Performance');
  
  const tests = [
    {
      name: 'should compute scores in under 10ms',
      test: async () => {
        const result = await scorer.calculateScore(testMetadata);
        
        expect(result.computeTime).toBeLessThan(10);
      }
    },
    {
      name: 'should handle caching properly',
      test: async () => {
        const cachingScorer = new FreshnessScorer({ cacheEnabled: true });
        
        const result1 = await cachingScorer.calculateScore(testMetadata);
        const result2 = await cachingScorer.calculateScore(testMetadata);
        
        expect(result1.cached).toBe(false);
        expect(result2.cached).toBe(true);
        // Either result2 is faster than result1, or both are very fast (0ms)
        assert(result2.computeTime <= result1.computeTime, 'Cached result should be faster or equal');
      }
    }
  ];

  for (const { name, test } of tests) {
    testResults.total++;
    try {
      await beforeEach();
      await test();
      await afterEach();
      console.log(`  ✅ ${name}`);
      testResults.passed++;
    } catch (error) {
      console.log(`  ❌ ${name}: ${error.message}`);
      testResults.failed++;
    }
  }
}

async function runAccuracyTests() {
  console.log('\n📦 Accuracy Requirements');
  
  const tests = [
    {
      name: 'should achieve >= 90% accuracy for freshness detection',
      test: async () => {
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
      }
    }
  ];

  for (const { name, test } of tests) {
    testResults.total++;
    try {
      await beforeEach();
      await test();
      await afterEach();
      console.log(`  ✅ ${name}`);
      testResults.passed++;
    } catch (error) {
      console.log(`  ❌ ${name}: ${error.message}`);
      testResults.failed++;
    }
  }
}

// Main test runner
async function runAllTests() {
  console.log('🧪 Running FreshnessScorer Tests\n');
  
  await runBasicTests();
  await runTimeDecayTests(); 
  await runPerformanceTests();
  await runAccuracyTests();

  console.log('\n📊 Test Results:');
  console.log(`  Total: ${testResults.total}`);
  console.log(`  Passed: ${testResults.passed}`);
  console.log(`  Failed: ${testResults.failed}`);
  
  if (testResults.failed === 0) {
    console.log('\n✅ All tests passed!');
    
    // Check 90% pass rate requirement
    const passRate = (testResults.passed / testResults.total) * 100;
    console.log(`📈 Pass rate: ${passRate.toFixed(1)}%`);
    
    if (passRate >= 90) {
      console.log('✅ Meets 90% pass rate requirement');
    } else {
      console.log('❌ Does not meet 90% pass rate requirement');
      process.exit(1);
    }
  } else {
    console.log('\n❌ Some tests failed');
    process.exit(1);
  }
}

// Run tests if called directly
if (require.main === module) {
  runAllTests().catch(console.error);
}

module.exports = { runAllTests };