import assert from 'node:assert/strict';
import { after, test } from 'node:test';
import worker, { gameUrl } from '../worker.mjs';

const originalRewriter = globalThis.HTMLRewriter;
const rewrites = [];

class TestHTMLRewriter {
  handlers = [];

  on(selector, handler) {
    this.handlers.push({ selector, handler });
    return this;
  }

  transform(response) {
    for (const { selector, handler } of this.handlers) {
      handler.element({ setAttribute: (name, value) => rewrites.push({ selector, name, value }) });
    }
    return response;
  }
}

globalThis.HTMLRewriter = TestHTMLRewriter;
after(() => {
  if (originalRewriter === undefined) delete globalThis.HTMLRewriter;
  else globalThis.HTMLRewriter = originalRewriter;
});

function environment(body = '<html></html>', options = {}, config = {}) {
  const response = new Response(body, {
    headers: { 'content-type': 'text/html; charset=utf-8' },
    ...options,
  });
  let receivedRequest;
  return {
    env: {
      ASSETS: { fetch: async request => { receivedRequest = request; return response; } },
      ...config,
    },
    response,
    receivedRequest: () => receivedRequest,
  };
}

test('game URL defaults and preserves configured paths, queries, and fragments', () => {
  assert.equal(gameUrl(), 'https://play.littledill.app/');
  assert.equal(gameUrl('https://play.example.com/game?mode=cozy#start'), 'https://play.example.com/game?mode=cozy#start');
  assert.equal(gameUrl('http://localhost:4178'), 'http://localhost:4178/');
});

test('game URL rejects unsafe protocols, relative URLs, blank values, and credentials', () => {
  for (const value of ['', null, '/play', '//example.com', 'javascript:alert(1)', 'data:text/html,hi', 'https://user:secret@example.com']) {
    assert.throws(() => gameUrl(value), /GAME_URL must be an absolute HTTP or HTTPS URL without credentials/);
  }
});

test('HTML rewrites game links and uses the website origin for share metadata', async () => {
  rewrites.length = 0;
  const request = new Request('https://preview.example.com/?campaign=launch');
  const fixture = environment('<html>little dill</html>', {
    headers: {
      'content-type': 'text/html; charset=utf-8',
      'content-length': '24',
      'etag': 'static-etag',
      'last-modified': 'Tue, 01 Sep 2026 00:00:00 GMT',
    },
  }, { GAME_URL: 'https://play.example.com/start?one=1&two=2' });
  const response = await worker.fetch(request, fixture.env);
  assert.equal(fixture.receivedRequest(), request);
  assert.equal(response.status, 200);
  assert.equal(await response.text(), '<html>little dill</html>');
  assert.deepEqual(rewrites, [
    { selector: 'a[data-game-link]', name: 'href', value: 'https://play.example.com/start?one=1&two=2' },
    { selector: 'link[data-canonical]', name: 'href', value: 'https://preview.example.com/' },
    { selector: 'meta[property="og:url"]', name: 'content', value: 'https://preview.example.com/' },
    { selector: 'meta[property="og:image"]', name: 'content', value: 'https://preview.example.com/assets/og.png' },
  ]);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  for (const header of ['content-length', 'etag', 'last-modified']) assert.equal(response.headers.get(header), null);
});

test('missing configuration uses the default game URL', async () => {
  rewrites.length = 0;
  const fixture = environment();
  await worker.fetch(new Request('https://website.example.com/'), fixture.env);
  assert.equal(rewrites[0].value, 'https://play.littledill.app/');
});

test('non-HTML assets and redirects pass through unchanged', async () => {
  for (const options of [
    { headers: { 'content-type': 'text/css', 'cache-control': 'public, max-age=3600' } },
    { status: 301, headers: { location: '/about/' } },
    { status: 304, headers: { etag: 'unchanged' } },
  ]) {
    const fixture = environment(null, options, { GAME_URL: 'invalid' });
    assert.equal(await worker.fetch(new Request('https://website.example.com/style.css'), fixture.env), fixture.response);
  }
});

test('HTML error status survives rewriting', async () => {
  const fixture = environment('<html>Page missing</html>', { status: 404 });
  const response = await worker.fetch(new Request('https://website.example.com/missing'), fixture.env);
  assert.equal(response.status, 404);
  assert.equal(await response.text(), '<html>Page missing</html>');
});

test('HEAD returns headers and status without a body or rewriter', async () => {
  rewrites.length = 0;
  const fixture = environment(null, { status: 404, headers: { 'content-type': 'text/html', 'content-length': '120' } });
  const response = await worker.fetch(new Request('https://website.example.com/missing', { method: 'HEAD' }), fixture.env);
  assert.equal(response.status, 404);
  assert.equal(await response.text(), '');
  assert.equal(response.headers.get('content-length'), null);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  assert.deepEqual(rewrites, []);
});

test('invalid configuration produces a clear uncached error and honors HEAD', async () => {
  for (const method of ['GET', 'HEAD']) {
    const fixture = environment(method === 'HEAD' ? null : '<html></html>', {}, { GAME_URL: 'javascript:alert(1)' });
    const response = await worker.fetch(new Request('https://website.example.com/', { method }), fixture.env);
    assert.equal(response.status, 500);
    assert.equal(response.headers.get('cache-control'), 'no-store');
    assert.equal(await response.text(), method === 'HEAD' ? '' : 'GAME_URL must be an absolute HTTP or HTTPS URL without credentials.');
  }
});
