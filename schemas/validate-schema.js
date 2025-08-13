#!/usr/bin/env node

/**
 * Schema validation test script for the Claude Auto-Tee capture registry
 * Tests both valid and invalid examples against the JSON schema
 */

const fs = require('fs');
const path = require('path');
const Ajv = require('ajv');
const addFormats = require('ajv-formats');

// Initialize AJV with formats support
const ajv = new Ajv({ 
  allErrors: true, 
  verbose: true,
  strict: false,
  validateFormats: true
});
addFormats(ajv);

function validateSchema() {
  console.log('🔍 Claude Auto-Tee Registry Schema Validation\n');

  try {
    // Load the schema
    const schemaPath = path.join(__dirname, 'registry.json');
    const schema = JSON.parse(fs.readFileSync(schemaPath, 'utf8'));
    console.log('✅ Schema loaded successfully');

    // Compile the schema
    const validate = ajv.compile(schema);
    console.log('✅ Schema compiled successfully\n');

    // Test valid example
    console.log('📝 Testing valid example...');
    const validPath = path.join(__dirname, 'examples', 'valid-registry.json');
    const validData = JSON.parse(fs.readFileSync(validPath, 'utf8'));
    
    const isValidValid = validate(validData);
    if (isValidValid) {
      console.log('✅ Valid example passes validation\n');
    } else {
      console.log('❌ Valid example failed validation:');
      console.log(validate.errors);
      return false;
    }

    // Test invalid example
    console.log('📝 Testing invalid example...');
    const invalidPath = path.join(__dirname, 'examples', 'invalid-registry.json');
    const invalidData = JSON.parse(fs.readFileSync(invalidPath, 'utf8'));
    
    const isInvalidValid = validate(invalidData);
    if (!isInvalidValid) {
      console.log('✅ Invalid example correctly rejected with errors:');
      validate.errors.forEach((error, i) => {
        console.log(`  ${i + 1}. ${error.instancePath || 'root'}: ${error.message}`);
        if (error.params) {
          console.log(`     Details: ${JSON.stringify(error.params)}`);
        }
      });
      console.log();
    } else {
      console.log('❌ Invalid example incorrectly passed validation');
      return false;
    }

    // Test schema metadata
    console.log('📋 Schema Information:');
    console.log(`   Title: ${schema.title}`);
    console.log(`   Description: ${schema.description}`);
    console.log(`   Schema Version: ${schema.$schema}`);
    console.log(`   Required Fields: ${schema.required.join(', ')}`);
    console.log(`   Max Captures: ${schema.properties.captures.maxItems}`);
    console.log(`   Extensible: ${schema.properties.captures.items.additionalProperties ? 'Yes' : 'No'}`);

    console.log('\n🎉 All validation tests passed!');
    return true;

  } catch (error) {
    console.error('❌ Validation test failed:', error.message);
    return false;
  }
}

// Run validation if called directly
if (require.main === module) {
  const success = validateSchema();
  process.exit(success ? 0 : 1);
}

module.exports = { validateSchema };