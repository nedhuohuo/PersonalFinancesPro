import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { existsSync, mkdirSync, readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

assert.ok(existsSync(new URL('./index.html', import.meta.url)), 'Interactive UI prototype has not been implemented');
const require = createRequire(import.meta.url);
// Reuse an installed tool dependency; this is not an App runtime dependency.
const module = require(process.env.PUPPETEER_MODULE || 'puppeteer-core');
const puppeteer = module.default || module;
const allowed = new Map([
  ['/index.html', ['index.html', 'text/html; charset=utf-8']],
  ['/prototype-model.mjs', ['prototype-model.mjs', 'text/javascript; charset=utf-8']],
]);
const server = createServer((request, response) => {
  const asset = allowed.get(new URL(request.url, 'http://localhost').pathname);
  if (!asset) { response.writeHead(404).end(); return; }
  response.writeHead(200, { 'Content-Type': asset[1] });
  response.end(readFileSync(new URL(`./${asset[0]}`, import.meta.url)));
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
let browser;
const failures = [];
try {
  browser = await puppeteer.launch({ headless: true, executablePath: process.env.CHROME_PATH || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' });
  const page = await browser.newPage();
  page.on('pageerror', error => failures.push(error.message));
  page.on('request', request => {
    if (!request.url().startsWith('http://127.0.0.1:')) failures.push(`Unexpected external request: ${request.url()}`);
  });
  const shots = new URL('../screenshots/', import.meta.url);
  mkdirSync(shots, { recursive: true });
  await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 1 });
  await page.goto(`http://127.0.0.1:${server.address().port}/index.html`, { waitUntil: 'networkidle0' });
  await page.waitForSelector('#home:not([hidden])');
  assert.equal(await page.$eval('[data-stat="net"]', element => element.textContent.trim()), '-2,960.00');
  await page.screenshot({ path: fileURLToPath(new URL('home.png', shots)) });
  for (const width of [320, 390, 430]) {
    await page.setViewport({ width, height: 844 });
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true, `Horizontal overflow at ${width}px`);
  }
  await page.setViewport({ width: 390, height: 844 });
  await page.select('#shop-filter', 'shop1');
  assert.equal(await page.$eval('[data-stat="net"]', element => element.textContent.trim()), '-1,660.00');
  await page.select('#shop-filter', 'all');
  await page.click('nav [data-page="ledger"]');
  await page.select('#kind-filter', 'income');
  assert.equal(await page.$$('.ledger-row').then(rows => rows.length), 2);
  await page.select('#kind-filter', 'all');
  await page.screenshot({ path: fileURLToPath(new URL('ledger.png', shots)) });

  // A third fractional digit must not silently become a stored amount.
  await page.click('#manual-open');
  await page.type('#entry-title', '<img src=x onerror=alert(1)>');
  await page.type('#entry-amount', '18.005');
  await page.click('#save-entry');
  assert.equal(await page.$eval('#entry-dialog', dialog => dialog.open), true);
  assert.ok(await page.$eval('#form-error', element => element.textContent.includes('两位小数')));
  await page.$eval('#entry-amount', element => { element.value = '280.01'; });
  await page.click('#save-entry');
  assert.equal(await page.$eval('#entry-dialog', dialog => dialog.open), false);
  assert.equal(await page.$$('.ledger-row').then(rows => rows.length), 8);
  assert.equal(await page.$$('img').then(images => images.length), 0, 'User text must not become markup');

  // Demo AI confirmation must add both records exactly once.
  await page.click('nav [data-page="ai"]');
  assert.equal(await page.$eval('#toast', element => element.hidden), true, 'Old-page feedback must not cover a new page');
  await page.click('#use-example');
  await page.click('#generate-draft');
  await page.waitForSelector('#draft-card:not([hidden])');
  // Resize for a long-screen handoff image so fixed navigation does not mask the draft.
  const fullHeight = await page.evaluate(() => document.documentElement.scrollHeight);
  await page.setViewport({ width: 390, height: fullHeight });
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.screenshot({ path: fileURLToPath(new URL('ai-draft.png', shots)) });
  await page.setViewport({ width: 390, height: 844 });
  await page.click('#confirm-draft');
  if (!await page.$eval('#confirm-draft', button => button.disabled)) {
    console.log('Confirmation tap diagnostic:', await page.$eval('#confirm-draft', button => {
      const rect = button.getBoundingClientRect();
      const hit = document.elementFromPoint(rect.x + rect.width / 2, rect.y + rect.height / 2);
      return { button: { x: rect.x, y: rect.y, width: rect.width, height: rect.height }, hit: hit?.id || hit?.tagName };
    }));
  }
  assert.equal(await page.$eval('#confirm-draft', button => button.disabled), true);
  await page.$eval('#confirm-draft', button => button.click());
  await page.click('nav [data-page="ledger"]');
  assert.equal(await page.$$('.ledger-row').then(rows => rows.length), 10);
  await page.select('#preview-state', 'empty');
  assert.equal(await page.$$('.ledger-row').then(rows => rows.length), 0);
  await page.select('#preview-state', 'error');
  assert.equal(await page.$eval('#view-error', element => element.hidden), false);
  await page.click('#retry-view');
  assert.equal(await page.$$('.ledger-row').then(rows => rows.length), 10);
  await page.click('nav [data-page="settings"]');
  assert.equal(await page.$eval('#api-key', input => input.disabled), true);
  await page.screenshot({ path: fileURLToPath(new URL('settings.png', shots)) });
  await page.click('#theme-toggle');
  assert.equal(await page.$eval('html', element => element.dataset.theme), 'dark');
  assert.deepEqual(failures, []);
  console.log('PASS: four-page navigation, mobile widths, filtering, exact manual input, escaped text, one-time AI confirmation, state preview and disabled credentials');
  console.log('Screenshots: docs/ui/screenshots/{home,ledger,ai-draft,settings}.png');
} finally {
  await browser?.close();
  await new Promise(resolve => server.close(resolve));
}
