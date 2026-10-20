import { expect, type Page } from '@playwright/test';

// Unique per run so tests can be re-run against the same database.
export function uniqueEmail() {
	return `test+${Date.now()}-${Math.floor(Math.random() * 1e6)}@gratheon.com`;
}

export async function register(page: Page, email: string, password: string) {
	await page.goto('/account/register/');
	await page.getByRole('textbox', { name: 'Email*' }).fill(email);
	await page.getByRole('textbox', { name: 'Password*', exact: true }).fill(password);
	await page.getByRole('textbox', { name: 'Password repeat*' }).fill(password);

	// The register form computes a proof-of-work in the background and silently
	// ignores submits until it is ready, so keep clicking until we leave the page.
	await expect(async () => {
		await page.getByRole('button', { name: 'Sign Up' }).click();
		await expect(page).not.toHaveURL(/\/account\/register/, { timeout: 2000 });
	}).toPass({ timeout: 30_000 });
}

export async function login(page: Page, email: string, password: string) {
	await page.goto('/account/authenticate/');
	await page.getByRole('textbox', { name: 'Email' }).fill(email);
	await page.getByRole('textbox', { name: 'Password' }).fill(password);
	await page.getByRole('button', { name: 'Log In' }).click();
}
