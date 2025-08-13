#!/usr/bin/env node

/**
 * Demonstration script for SemanticExtractor
 * Shows real-world examples of semantic extraction
 */

const { SemanticExtractor } = require('./semantic-extractor');

console.log('🧠 SemanticExtractor Demo\n');
console.log('=' * 50);

const extractor = new SemanticExtractor();

// Example 1: NPM Test Output
const npmOutput = `
npm test

> myapp@1.0.0 test
> jest --coverage

PASS src/utils/helper.test.js
  ✓ should format dates correctly (5ms)
  ✓ should validate emails (12ms)

PASS src/components/Button.test.js
  ✓ should render button with text (23ms)
  ✓ should handle click events (8ms)

FAIL src/api/client.test.js
  ✗ should handle network errors (45ms)

    TypeError: Cannot read properties of undefined (reading 'data')
        at handleResponse (/Users/dev/myapp/src/api/client.js:34:12)
        at processResponse (/Users/dev/myapp/src/api/client.js:67:8)

Test Suites: 2 passed, 1 failed, 3 total
Tests:       4 passed, 1 failed, 5 total
Coverage:    87.3% of statements
Time:        2.345s
`;

console.log('📝 Example 1: NPM Test Output');
console.log('-'.repeat(30));
const result1 = extractor.extract(npmOutput);
console.log(`✓ Found ${result1.successes.length} success indicators`);
console.log(`✗ Found ${result1.errors.length} error indicators`);
console.log(`📊 Found ${result1.metrics.length} metrics`);
console.log(`📁 Found ${result1.paths.length} file paths`);
console.log(`🎯 Overall confidence: ${(result1.confidence * 100).toFixed(1)}%`);
console.log(`⏱️  Processing time: ${result1.metadata.processingTime}ms\n`);

// Example 2: Build Output
const buildOutput = `
Building production bundle...

✓ Compiling TypeScript sources
✓ Bundling JavaScript modules
⚠ Warning: Large bundle detected (2.1 MB)
✓ Generating source maps (150 KB)
✓ Minifying assets: 2.1 MB → 800 KB (62% reduction)

Build completed successfully in 15.7 seconds
Output: /dist/bundle.js
Ready for deployment at https://myapp.vercel.app
`;

console.log('📝 Example 2: Build Output');
console.log('-'.repeat(30));
const result2 = extractor.extract(buildOutput);
console.log(`✓ Found ${result2.successes.length} success indicators`);
console.log(`✗ Found ${result2.errors.length} error indicators`);
console.log(`📊 Found ${result2.metrics.length} metrics`);
console.log(`📁 Found ${result2.paths.length} file paths`);
console.log(`🌐 Found ${result2.paths.filter(p => p.type === 'url').length} URLs`);
console.log(`🎯 Overall confidence: ${(result2.confidence * 100).toFixed(1)}%`);
console.log(`⏱️  Processing time: ${result2.metadata.processingTime}ms\n`);

// Example 3: Git Output
const gitOutput = `
$ git status
On branch feature/semantic-extractor
Changes to be committed:
  (use "git reset HEAD <file>..." to unstage)

	new file:   src/semantic/semantic-extractor.js
	new file:   test/semantic/semantic-extractor.test.js
	modified:   package.json

$ git commit -m "feat: implement semantic extractor (P3.T005)"
[feature/semantic-extractor 1a2b3c4] feat: implement semantic extractor (P3.T005)
 3 files changed, 847 insertions(+), 2 deletions(-)
 create mode 100644 src/semantic/semantic-extractor.js
 create mode 100644 test/semantic/semantic-extractor.test.js
`;

console.log('📝 Example 3: Git Output');  
console.log('-'.repeat(30));
const result3 = extractor.extract(gitOutput);
console.log(`✓ Found ${result3.successes.length} success indicators`);
console.log(`📁 Found ${result3.paths.length} file paths`);
console.log(`💻 Found ${result3.commands.length} commands`);
console.log(`🎯 Overall confidence: ${(result3.confidence * 100).toFixed(1)}%`);
console.log(`⏱️  Processing time: ${result3.metadata.processingTime}ms\n`);

// Performance test
console.log('🚀 Performance Test');
console.log('-'.repeat(30));
const largeSample = npmOutput.repeat(100); // ~10KB sample
const startTime = Date.now();
const largeResult = extractor.extract(largeSample);
const endTime = Date.now();
console.log(`📏 Input size: ${largeSample.length} bytes (~${(largeSample.length/1024).toFixed(1)}KB)`);
console.log(`⏱️  Processing time: ${endTime - startTime}ms`);
console.log(`✅ Performance requirement: ${endTime - startTime < 50 ? 'PASS' : 'FAIL'} (<50ms)`);
console.log(`🎯 Maintained confidence: ${(largeResult.confidence * 100).toFixed(1)}%\n`);

console.log('🎉 Demo completed successfully!');
console.log('\n📚 See docs/semantic/semantic-patterns.md for full pattern documentation');