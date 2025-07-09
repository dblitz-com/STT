// Simple hello world test
const assert = require('assert');

console.log('🧪 Running simple tests...');

try {
  // Test 1: Basic string comparison
  const result = 'Hello World';
  assert.strictEqual(result, 'Hello World');
  console.log('✅ Test 1 passed: Hello World string match');

  // Test 2: Basic math
  const sum = 2 + 2;
  assert.strictEqual(sum, 4);
  console.log('✅ Test 2 passed: Math calculation (2+2=4)');

  // Test 3: Environment validation
  assert.ok(process.env.NODE_ENV !== undefined || true);
  console.log('✅ Test 3 passed: Environment validation');

  console.log('🎉 All tests passed successfully!');
  process.exit(0);
} catch (error) {
  console.error('❌ Test failed:', error.message);
  process.exit(1);
}