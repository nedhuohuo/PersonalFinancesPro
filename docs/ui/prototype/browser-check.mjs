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
  ['/prototype-chat.mjs', ['prototype-chat.mjs', 'text/javascript; charset=utf-8']],
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
  assert.equal(await page.$eval('#home [data-stat="expense"]', element => element.textContent.trim()), '4,600.00');
  assert.equal(await page.$eval('#home [data-stat="resale"]', element => element.textContent.trim()), '1,640.00');
  assert.equal(await page.$('#home [data-stat="net"]'), null, 'Incomplete cash difference must not be the homepage headline');
  for (const width of [320, 390, 430]) {
    await page.setViewport({ width, height: 844 });
    for (const [top, bottom] of [[0, 0], [24, 24], [54, 34]]) {
      await page.evaluate(([top, bottom]) => {
        document.documentElement.style.setProperty('--safe-top', `${top}px`);
        document.documentElement.style.setProperty('--safe-bottom', `${bottom}px`);
      }, [top, bottom]);
      const positions = await page.evaluate(() => ({
        headerTop: document.querySelector('header').getBoundingClientRect().top,
        tabBottom: Math.max(...Array.from(document.querySelectorAll('nav button'), button => button.getBoundingClientRect().bottom)),
        contentBottom: document.querySelector('main').getBoundingClientRect().bottom,
        navTop: document.querySelector('nav').getBoundingClientRect().top,
        overflows: document.documentElement.scrollWidth > innerWidth,
      }));
      assert.equal(positions.overflows, false, `Horizontal overflow at ${width}px`);
      assert.ok(positions.headerTop >= top, `Header enters status area at ${width}/${top}/${bottom}`);
      assert.ok(positions.tabBottom <= 844 - bottom, `Tab target enters system navigation at ${width}/${top}/${bottom}`);
      assert.ok(positions.contentBottom <= positions.navTop, 'App content must not sit behind the tab bar');
    }
  }
  await page.setViewport({ width: 390, height: 844 });
  await page.screenshot({ path: fileURLToPath(new URL('home.png', shots)) });
  await page.select('#shop-filter', 'shop1');
  assert.equal(await page.$eval('#home [data-stat="expense"]', element => element.textContent.trim()), '2,020.00');
  assert.equal(await page.$eval('#home [data-stat="resale"]', element => element.textContent.trim()), '360.00');
  await page.select('#shop-filter', 'all');

  // Ordinary income must not be mislabelled as problem-item recovery.
  await page.click('#manual-open');
  await page.select('#entry-kind', 'income');
  await page.type('#entry-title', '其他经营收入');
  await page.type('#entry-amount', '100');
  await page.click('#save-entry');
  assert.equal(await page.$eval('#home [data-stat="resale"]', element => element.textContent.trim()), '1,640.00');
  assert.equal(await page.$eval('#home [data-stat="expense"]', element => element.textContent.trim()), '4,600.00');
  await page.click('nav [data-page="ledger"]');
  await page.select('#kind-filter', 'income');
  assert.equal(await page.$$('.ledger-row').then(rows => rows.length), 3);
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
  assert.equal(await page.$$('.ledger-row').then(rows => rows.length), 9);
  assert.equal(await page.$$('img').then(images => images.length), 0, 'User text must not become markup');

  // AI is a conversation: table drafts, revisions and two shared confirmation routes.
  await page.click('nav [data-page="ai"]');
  assert.equal(await page.$eval('#toast', element => element.hidden), true, 'Old-page feedback must not cover a new page');
  const send = async text => {
    await page.$eval('#ai-input', (input, text) => { input.value = text; input.dispatchEvent(new Event('input', { bubbles: true })); }, text);
    await page.click('#chat-send');
  };
  await page.click('#use-example');
  await page.click('#chat-send');
  await page.waitForSelector('.draft-message.pending table');
  const oldMessage = await page.$eval('.draft-message.pending', element => element.dataset.message);
  assert.match(await page.$eval('.draft-message.pending', element => element.textContent), /360\.00/);
  // Capture a complete conversation screen without masking messages under the input bar.
  const fullHeight = await page.evaluate(() => {
    const messages = document.querySelector('#chat-messages');
    return innerHeight + messages.scrollHeight - messages.clientHeight;
  });
  await page.setViewport({ width: 390, height: fullHeight });
  await page.$eval('#chat-messages', messages => { messages.scrollTop = 0; });
  await page.screenshot({ path: fileURLToPath(new URL('ai-draft.png', shots)) });
  await page.setViewport({ width: 390, height: 844 });
  await send('先别确认');
  assert.equal(await page.$$('.draft-message.committed').then(rows => rows.length), 0);
  await send('改成二店，运费改成25元');
  assert.equal(await page.$eval(`button[data-confirm-message="${oldMessage}"]`, button => button.disabled), true);
  assert.match(await page.$eval('.draft-message.pending', element => element.textContent), /25\.00/);
  await send('确认这笔');
  assert.equal(await page.$$('.draft-message.committed').then(rows => rows.length), 1);
  assert.equal(await page.$$('.draft-message.pending').then(rows => rows.length), 0);
  await send('记上吧');
  await send('二店买纸箱280元，微信支付');
  await page.click('.draft-message.pending [data-confirm-message]');
  assert.equal(await page.$$('.draft-message.committed').then(rows => rows.length), 2);
  assert.equal(await page.$$('.draft-message.pending').then(rows => rows.length), 0);
  // Submitted messages and stale messages must retain disabled actions.
  assert.equal(await page.$$eval('[data-confirm-message]', buttons => buttons.every(button => button.disabled)), true);
  await send('<img src=x onerror=alert(1)>');
  assert.equal(await page.$$('img').then(images => images.length), 0, 'Chat text must not execute markup');
  for (const width of [320, 390, 430]) {
    await page.setViewport({ width, height: 844 });
    const composer = await page.$eval('#chat-composer', element => element.getBoundingClientRect().bottom);
    const nav = await page.$eval('nav', element => element.getBoundingClientRect().top);
    assert.ok(composer <= nav, 'Conversation input must stay above the tab bar');
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
  }
  await page.setViewport({ width: 390, height: 844 });
  await page.click('nav [data-page="ledger"]');
  assert.equal(await page.$$('.ledger-row').then(rows => rows.length), 12);
  await page.$eval('main', main => { main.scrollTop = main.scrollHeight; });
  const lastRowBottom = await page.$eval('.ledger-row:last-child', row => row.getBoundingClientRect().bottom);
  const navTop = await page.$eval('nav', nav => nav.getBoundingClientRect().top);
  assert.ok(lastRowBottom <= navTop, 'Last transaction must scroll clear of the app tab bar');
  await page.select('#preview-state', 'empty');
  assert.equal(await page.$$('.ledger-row').then(rows => rows.length), 0);
  await page.select('#preview-state', 'error');
  assert.equal(await page.$eval('#view-error', element => element.hidden), false);
  await page.click('#retry-view');
  assert.equal(await page.$$('.ledger-row').then(rows => rows.length), 12);
  await page.click('nav [data-page="settings"]');
  assert.equal(await page.$eval('#api-key', input => input.disabled), true);
  await page.screenshot({ path: fileURLToPath(new URL('settings.png', shots)) });
  await page.click('#theme-toggle');
  assert.equal(await page.$eval('html', element => element.dataset.theme), 'dark');
  assert.deepEqual(failures, []);
  console.log('PASS: spending-first metrics, recovery isolation, 9 safe-area/width scenarios, last-row visibility, manual input, conversation tables, revisions, intent safety and exactly-once text/button confirmation');
  console.log('Screenshots: docs/ui/screenshots/{home,ledger,ai-draft,settings}.png');
} finally {
  await browser?.close();
  await new Promise(resolve => server.close(resolve));
}
