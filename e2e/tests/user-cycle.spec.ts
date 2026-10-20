import { test, expect } from '@playwright/test';
import { login, register, uniqueEmail } from './common';

const PASS = 'Password1A!';

test('register, log out, log in, delete account', async ({ page }) => {
	const email = uniqueEmail();

	// login failure - user does not exist yet
	await login(page, email, PASS);
	await expect(page.getByText('Invalid email or password')).toBeVisible();

	// register
	await register(page, email, PASS);
	await expect(page.getByRole('button', { name: 'Setup new apiary' })).toBeVisible();
	await expect(page.getByText('No apiaries here yet')).toBeVisible();
	await expect(page.getByRole('link', { name: 'Hives' })).toBeVisible();

	// logout
	await page.getByRole('link', { name: 'Log out' }).click();
	await expect(page).toHaveURL(/\/account\/authenticate/);

	// login
	await login(page, email, PASS);
	await expect(page.getByRole('link', { name: 'Hives' })).toBeVisible();
	await expect(page.getByRole('button', { name: 'Setup new apiary' })).toBeVisible();

	// delete account - the second button is the one in the confirm modal
	await page.getByRole('link', { name: 'Account' }).click();
	await page.getByRole('button', { name: 'Delete Account' }).click();
	await page.getByRole('button', { name: 'Delete Account' }).last().click();
	await expect(page).toHaveURL(/\/account\/authenticate/);

	// login failure - user is deleted
	await login(page, email, PASS);
	await expect(page.getByText('Invalid email or password')).toBeVisible();
});
