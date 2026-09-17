const DEFAULT_GAME_URL = 'https://play.littledill.app';

export function gameUrl(value = DEFAULT_GAME_URL) {
  try {
    const url = new URL(value);
    if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password) {
      throw new Error('Invalid game URL');
    }
    return url.href;
  } catch {
    throw new Error('GAME_URL must be an absolute HTTP or HTTPS URL without credentials.');
  }
}

function attribute(name, value) {
  return { element(element) { element.setAttribute(name, value); } };
}

export default {
  async fetch(request, env) {
    const asset = await env.ASSETS.fetch(request);
    if (!asset.headers.get('content-type')?.toLowerCase().includes('text/html')) {
      return asset;
    }

    let destination;
    try {
      destination = gameUrl(env.GAME_URL);
    } catch (error) {
      return new Response(request.method === 'HEAD' ? null : error.message, {
        status: 500,
        headers: { 'content-type': 'text/plain; charset=utf-8', 'cache-control': 'no-store' },
      });
    }

    const origin = new URL(request.url).origin;
    const headers = new Headers(asset.headers);
    for (const header of ['content-length', 'etag', 'last-modified']) headers.delete(header);
    headers.set('cache-control', 'no-store');
    const response = new Response(request.method === 'HEAD' ? null : asset.body, {
      status: asset.status,
      statusText: asset.statusText,
      headers,
    });
    if (request.method === 'HEAD' || !asset.body) return response;

    return new HTMLRewriter()
      .on('a[data-game-link]', attribute('href', destination))
      .on('link[data-canonical]', attribute('href', `${origin}/`))
      .on('meta[property="og:url"]', attribute('content', `${origin}/`))
      .on('meta[property="og:image"]', attribute('content', `${origin}/assets/og.png`))
      .transform(response);
  },
};
