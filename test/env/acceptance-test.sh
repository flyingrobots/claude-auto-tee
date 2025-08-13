#!/usr/bin/env bash
# Acceptance test for P1.T004: Environment Exporter
# Tests that CLAUDE_LAST_CAPTURE and CLAUDE_CAPTURES are properly set

set -euo pipefail

# Create temporary files
TEMP_DIR=$(mktemp -d)
TEST_CAPTURE="/tmp/claude-acceptance-test-$(date +%s%N).log"
EXPORT_SCRIPT="$TEMP_DIR/claude-env-export.sh"

# Cleanup function
cleanup() {
    rm -f "$TEST_CAPTURE" "$EXPORT_SCRIPT" 2>/dev/null || true
    rm -rf "$TEMP_DIR" 2>/dev/null || true
}
trap cleanup EXIT

echo "🧪 Running P1.T004 Acceptance Test"

# Create test capture file
echo "Test capture content for P1.T004 acceptance test" > "$TEST_CAPTURE"

# Generate export script using our EnvExporter
node -e "
const { EnvExporter } = require('./src/env/environment-exporter.js');
const fs = require('fs');

const exporter = new EnvExporter();
exporter.addCapture('$TEST_CAPTURE');

const exportScript = exporter.generateExportScript('bash');
fs.writeFileSync('$EXPORT_SCRIPT', exportScript);
"

# Make script executable
chmod +x "$EXPORT_SCRIPT"

echo "📝 Generated export script:"
cat "$EXPORT_SCRIPT"
echo ""

# Source the script and test environment variables
echo "🔍 Testing environment variable access..."

# Test CLAUDE_LAST_CAPTURE
if source "$EXPORT_SCRIPT" && test -n "$CLAUDE_LAST_CAPTURE"; then
    echo "✅ SUCCESS: CLAUDE_LAST_CAPTURE is set to: $CLAUDE_LAST_CAPTURE"
    
    # Verify it contains our test file path
    if [[ "$CLAUDE_LAST_CAPTURE" == *"claude-acceptance-test"* ]]; then
        echo "✅ SUCCESS: CLAUDE_LAST_CAPTURE contains correct file path"
    else
        echo "❌ FAILURE: CLAUDE_LAST_CAPTURE does not contain expected path"
        exit 1
    fi
else
    echo "❌ FAILURE: CLAUDE_LAST_CAPTURE is not set or is empty"
    exit 1
fi

# Test CLAUDE_CAPTURES
source "$EXPORT_SCRIPT"
if test -n "$CLAUDE_CAPTURES"; then
    echo "✅ SUCCESS: CLAUDE_CAPTURES is set"
    
    # Verify it's valid JSON
    if echo "$CLAUDE_CAPTURES" | node -e "
        const data = JSON.parse(require('fs').readFileSync(0, 'utf8'));
        if (Array.isArray(data) && data.length > 0 && data[0].path) {
            console.log('✅ SUCCESS: CLAUDE_CAPTURES contains valid JSON array with path');
            process.exit(0);
        } else {
            console.log('❌ FAILURE: CLAUDE_CAPTURES does not contain expected JSON structure');
            process.exit(1);
        }
    "; then
        echo "✅ SUCCESS: CLAUDE_CAPTURES JSON structure is valid"
    else
        echo "❌ FAILURE: CLAUDE_CAPTURES JSON structure is invalid"
        exit 1
    fi
else
    echo "❌ FAILURE: CLAUDE_CAPTURES is not set or is empty"
    exit 1
fi

echo ""
echo "🎉 P1.T004 Acceptance Test: ALL TESTS PASSED"
echo "✅ test -n \"\$CLAUDE_LAST_CAPTURE\" succeeds"
echo "✅ CLAUDE_CAPTURES environment variable is properly set"
echo "✅ Shell escaping and quoting works correctly"
echo "✅ Generated export commands are compatible with bash"