import { defineConfig, devices } from '@playwright/test';

// UI tests run against an already running local stack (see ../README.md):
// web-app on :8080 talking to graphql-router on :6100.
// Override with E2E_BASE_URL to point at another environment.
export default defineConfig({
	testDir: './tests',
	fullyParallel: true,
	forbidOnly: !!process.env.CI,
	retries: process.env.CI ? 2 : 0,
	workers: process.env.CI ? 1 : undefined,
	reporter: process.env.CI ? 'github' : 'html',
	use: {
		baseURL: process.env.E2E_BASE_URL || 'http://localhost:8080',
		trace: 'on-first-retry',
		screenshot: 'only-on-failure',
	},
	projects: [
		{
			name: 'chromium',
			use: { ...devices['Desktop Chrome'] },
		},
	],
});
