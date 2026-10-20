import { test, expect } from '@playwright/test';
import { register, uniqueEmail } from './common';

test('create, rename and delete apiary', async ({ page }) => {
	await register(page, uniqueEmail(), 'Password1A!');
	await expect(page.getByText('No apiaries here yet')).toBeVisible();

	// create
	await page.getByRole('button', { name: 'Setup new apiary' }).click();
	await page.getByRole('textbox', { name: 'Name' }).fill('my-apiary');
	await page.getByRole('button', { name: 'Create' }).click();
	await expect(page.getByRole('heading', { name: 'my-apiary' })).toBeVisible();
	await expect(page.getByText('No hives here yet')).toBeVisible();
	await expect(page.getByRole('button', { name: 'Add hive' })).toBeVisible();

	// update (apiary name in the list is an <a> without href, so it has no link role)
	await page.getByRole('heading', { name: 'my-apiary' }).getByText('my-apiary').click();
	await page.getByRole('button', { name: 'Edit' }).click();
	await page.getByRole('textbox', { name: 'Name' }).fill('my-apiary 234');
	await page.getByRole('button', { name: 'Save' }).click();
	// saving redirects back to the apiary view
	await expect(page.getByRole('heading', { name: 'my-apiary 234', level: 1 })).toBeVisible();

	await page.getByRole('link', { name: 'Hives' }).click();
	await expect(page.getByRole('heading', { name: 'my-apiary 234' })).toBeVisible();

	// delete - the second "Delete" button is the one in the confirm modal
	await page.getByRole('heading', { name: 'my-apiary 234' }).getByText('my-apiary 234').click();
	await page.getByRole('button', { name: 'Edit' }).click();
	await page.getByRole('button', { name: 'Delete', exact: true }).click();
	await page.getByRole('button', { name: 'Delete', exact: true }).last().click();
	await expect(page.getByText('No apiaries here yet')).toBeVisible();
});
