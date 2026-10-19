import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';

const html = await readFile(new URL('../public/index.html', import.meta.url), 'utf8');
const TESTFLIGHT = 'https://testflight.apple.com/join/74Z3huCa';

test('landing page links the iPhone public beta', () => {
  assert.ok(html.includes(`<section class="section wrap" id="iphone"`));
  assert.ok(html.split(`href="${TESTFLIGHT}"`).length - 1 >= 3, 'hero, iPhone section, and FAQ link to TestFlight');
});

test('landing page features Brine Royale and its events', () => {
  assert.ok(html.includes('id="brine-royale"'));
  assert.ok(html.includes('href="https://arena.littledill.app/"'));
  for (const text of ['Jar drops', 'Leader bounty', 'Can I play with friends?', 'Is there an iPhone app?']) assert.ok(html.includes(text), text);
  assert.ok(html.includes('<a href="#brine-royale">Arena</a>') && html.includes('<a href="#iphone">iPhone</a>'));
});

test('legal pages exist and the landing page links them', async () => {
  for (const slug of ['privacy', 'privacy-choices', 'terms']) {
    const page = await readFile(new URL(`../public/${slug}.html`, import.meta.url), 'utf8');
    assert.ok(page.includes(`<link rel="canonical" href="https://littledill.app/${slug}">`), slug);
    assert.ok(page.includes('href="/privacy"') && page.includes('href="/privacy-choices"') && page.includes('href="/terms"'), slug);
    assert.ok(!page.includes('data-canonical'), `${slug} keeps its own canonical URL`);
    assert.ok(html.includes(`<a href="/${slug}">`), `landing footer links ${slug}`);
  }
});
