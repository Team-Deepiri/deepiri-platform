module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['**/__tests__/**/*.test.ts'],
  moduleFileExtensions: ['ts', 'js', 'json'],
  moduleNameMapper: {
    '^@team-deepiri/shared-utils$': '<rootDir>/../../shared/deepiri-shared-utils/src/index.ts',
  },
  transform: {
    '^.+\\.ts$': ['ts-jest', {
      tsconfig: {
        types: ['jest', 'node'],
        esModuleInterop: true,
        skipLibCheck: true,
        // isolatedModules skips cross-file type checking so tests run even when
        // optional packages (e.g. @influxdata/influxdb-client) are not installed
        isolatedModules: true,
      }
    }]
  }
};
