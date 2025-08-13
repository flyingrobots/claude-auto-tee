#!/usr/bin/env node
/**
 * Demo script for Environment Exporter
 * Shows how to use the EnvExporter class for PostToolUse hook integration
 */

const { EnvExporter } = require('../../src/env/environment-exporter.js');
const fs = require('fs');
const path = require('path');
const os = require('os');

console.log('🎯 Claude Auto-Tee Environment Exporter Demo\n');

// Create a demo exporter
const exporter = new EnvExporter({
    maxCapturesHistory: 5,
    verbose: true
});

// Simulate some captures (creating actual temp files for realism)
const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'claude-demo-'));
const captures = [
    'build-output.log',
    'test-results.log', 
    'npm-install.log'
];

console.log('📝 Adding sample captures...\n');

for (let i = 0; i < captures.length; i++) {
    const filePath = path.join(tempDir, captures[i]);
    fs.writeFileSync(filePath, `Sample output for ${captures[i]}\nGenerated at: ${new Date().toISOString()}\n`);
    
    exporter.addCapture(filePath, {
        command: `example-command-${i + 1}`,
        duration: Math.floor(Math.random() * 1000) + 100
    });
    
    console.log(`Added: ${captures[i]}`);
}

console.log('\n🔧 Generated Export Commands:\n');

// Show bash exports
console.log('--- Bash/Zsh/Sh Exports ---');
const bashExports = exporter.generateAllExports('bash');
console.log(bashExports.lastCapture);
console.log(bashExports.captures);
console.log('');

// Show fish exports
console.log('--- Fish Shell Exports ---');
const fishExports = exporter.generateAllExports('fish');
console.log(fishExports.lastCapture);
console.log(fishExports.captures);
console.log('');

// Show complete bash script
console.log('--- Complete Export Script (Bash) ---');
const bashScript = exporter.generateExportScript('bash');
console.log(bashScript);

// Show edge case handling
console.log('🔒 Edge Case Handling:\n');

// Test special characters
const specialFile = path.join(tempDir, 'test "with quotes" & $pecial.log');
fs.writeFileSync(specialFile, 'Special character test');
exporter.addCapture(specialFile);

console.log('File with special characters:');
console.log(`  Original: ${specialFile}`);
console.log(`  Bash escaped: ${exporter.escapePath(specialFile, 'bash')}`);
console.log(`  Fish escaped: ${exporter.escapePath(specialFile, 'fish')}`);
console.log('');

// Show JSON structure
console.log('📊 Current Captures JSON:\n');
const capturesData = exporter.getCaptures();
console.log(JSON.stringify(capturesData, null, 2));

// Show history management
console.log('\n🗂️  History Management:\n');
console.log(`Total captures: ${capturesData.length}`);
console.log(`Max history limit: ${exporter.maxCapturesHistory}`);
console.log(`Last capture: ${exporter.getLastCapture()?.path || 'None'}`);

// Show atomic operations
console.log('\n⚛️  Atomic Operations:\n');
console.log(`Atomic operations enabled: ${exporter.enableAtomicOperations}`);

// Update a capture atomically
exporter.updateCapture(capturesData[0].path, { 
    status: 'processed',
    processingTime: 500
});
console.log('Updated first capture with processing metadata');

// Cleanup
console.log('\n🧹 Cleaning up demo files...');
try {
    fs.rmSync(tempDir, { recursive: true, force: true });
    console.log('Demo cleanup completed successfully');
} catch (error) {
    console.log('Note: Some demo files may remain in temp directory');
}

console.log('\n✨ Demo completed! The EnvExporter is ready for PostToolUse hook integration.');
console.log('\n📖 Usage in PostToolUse hook:');
console.log(`
const { EnvExporter } = require('./src/env/environment-exporter.js');

// Create exporter instance
const exporter = new EnvExporter();

// Add capture when a tool completes
exporter.addCapture('/path/to/capture.log', {
    toolName: 'Bash',
    command: 'npm run build | tee /path/to/capture.log',
    timestamp: new Date().toISOString()
});

// Generate environment exports for shell integration
const exports = exporter.generateAllExports(process.env.SHELL || 'bash');
console.log(exports.lastCapture);  // export CLAUDE_LAST_CAPTURE="/path/to/capture.log"
console.log(exports.captures);     // export CLAUDE_CAPTURES="[...]"
`);