/**
 * Jest 設定。core ロジックは firebase/stripe SDK に依存しないため、
 * SDK 未インストールでもテストは走る（テストは src/__tests__ の core のみ import）。
 */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['**/__tests__/**/*.test.ts'],
  // index.ts は SDK を import するためテスト対象から除外（core のみ検証）。
  modulePathIgnorePatterns: ['<rootDir>/lib/'],
};
