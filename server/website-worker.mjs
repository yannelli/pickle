// Official landing-site Worker, recovered from the deployed pickle-website module.
// Keep its existing static assets when deploying this narrow content update.
const ARENA_URL = 'https://arena.littledill.app/';
const arrow = '<svg aria-hidden="true"><use href="#arrow"/></svg>';
const arenaStyles = `<style>
.arena-entry{margin-top:22px;font-size:14px}.arena-entry a{display:inline-flex;align-items:center;gap:10px;text-decoration:underline;text-underline-offset:5px;font-weight:700}.arena-entry svg{width:19px;height:19px}
.arena-feature{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:48px;align-items:center;padding:40px;border:1px solid var(--line);border-radius:30px;background:#edf1e3}.arena-feature>div{min-width:0}.arena-feature h2{margin-bottom:20px}.arena-feature p:not(.eyebrow){color:var(--muted);margin-bottom:24px}.arena-feature .arena-art{width:100%;height:auto;border-radius:24px;overflow:hidden}.arena-features{display:flex;flex-wrap:wrap;gap:8px;list-style:none;padding:0;margin:0 0 25px;font-size:12px;font-weight:700}.arena-features li{padding:7px 11px;border:1px solid var(--line);border-radius:30px;background:var(--cream)}.arena-feature .button{max-width:100%;white-space:normal;text-align:center}.arena-feature .button svg{flex-shrink:0}
@media(max-width:760px){.arena-feature{grid-template-columns:minmax(0,1fr);gap:28px;padding:26px}.arena-feature .arena-art{max-height:260px}.arena-feature h2{font-size:38px}}
@media(max-width:420px){.arena-feature{padding:20px}.arena-feature h2{font-size:32px}.arena-feature .button{padding:12px 17px;font-size:14px;gap:12px}.arena-features{font-size:11px}}
</style>`;

function pickle(x, y, scale, color) {
  return `<g transform="translate(${x} ${y}) scale(${scale})"><ellipse cx="1" cy="5" rx="42.5" ry="50" fill="#263e31" opacity=".1"/><rect x="-42.5" y="-50" width="85" height="100" rx="42.5" fill="${color}" stroke="#263e31" stroke-width="2.5"/><rect x="-27.5" y="-30" width="11" height="25" rx="5" fill="white" opacity=".3"/><g fill="#263e31"><ellipse cx="-13.5" cy="-6.2" rx="3.75" ry="5.06"/><ellipse cx="13.5" cy="-6.2" rx="3.75" ry="5.06"/></g><g fill="#f1c9b4"><ellipse cx="-23.5" cy="7.8" rx="6.375" ry="2.8"/><ellipse cx="23.5" cy="7.8" rx="6.375" ry="2.8"/></g><path d="M-6.5 9.5Q0 21 6.5 9.5" fill="none" stroke="#263e31" stroke-width="1.75" stroke-linecap="round"/></g>`;
}
const arenaFeature = `<section class="section wrap" id="brine-royale" aria-labelledby="arena-title"><div class="arena-feature"><div>
<p class="eyebrow">BRINE ROYALE · ONLINE MULTIPLAYER</p><h2 id="arena-title">Little pickle.<br><em>Huge playground.</em></h2>
<p>Snack your way up the food chain. Split to chase, dash to escape, and regroup to grow. Bring your friends into one big, shared garden.</p>
<ul class="arena-features"><li>Up to 64 players</li><li>Split &amp; regroup</li><li>Web + iOS</li></ul>
<a class="button" href="${ARENA_URL}">Play Brine Royale ${arrow}</a><p class="hero-note" style="margin:18px 0 0">Free to play. No account. Jump straight in.</p></div>
<svg class="arena-art" viewBox="0 0 480 350" role="img" aria-label="Smiling green pickles split into a team in the Brine Royale garden"><defs><pattern id="arena-grid" width="60" height="60" patternUnits="userSpaceOnUse"><path d="M60 0H0V60" fill="none" stroke="#263e31" stroke-opacity=".045"/></pattern></defs><rect width="480" height="350" fill="#edf1e3"/><ellipse cx="250" cy="185" rx="200" ry="135" fill="#dde7cc" opacity=".35"/><rect width="480" height="350" fill="url(#arena-grid)"/><g fill="#a6bf70"><circle cx="56" cy="60" r="5"/><circle cx="98" cy="283" r="5"/><circle cx="329" cy="263" r="5"/><circle cx="207" cy="69" r="5"/><circle cx="430" cy="157" r="5"/></g><g fill="#d1bc74"><circle cx="151" cy="71" r="5"/><circle cx="287" cy="310" r="5"/><circle cx="405" cy="266" r="5"/></g><g fill="#a4b8a0"><circle cx="65" cy="203" r="5"/><circle cx="369" cy="51" r="5"/><circle cx="235" cy="289" r="5"/></g><circle cx="288" cy="81" r="8" fill="#f1c9b4"/><circle cx="288" cy="81" r="12" fill="none" stroke="#f1c9b4" stroke-opacity=".5" stroke-width="2"/>
${pickle(181, 164, 1.1, '#91b65a')}${pickle(265, 226, .67, '#91b65a')}${pickle(357, 129, .68, '#d6a05b')}
<text x="180" y="242" text-anchor="middle" fill="#263e31" font-size="12" font-weight="700">you</text></svg></div></section>`;

export function gameUrl(value = 'https://play.littledill.app') {
  try {
    const url = new URL(value);
    if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password) throw new Error('Invalid game URL');
    return url.href;
  } catch { throw new Error('GAME_URL must be an absolute HTTP or HTTPS URL without credentials.'); }
}
function attribute(name, value) { return { element(element) { element.setAttribute(name, value); } }; }

export default {
  async fetch(request, env) {
    const asset = await env.ASSETS.fetch(request);
    if (!asset.headers.get('content-type')?.toLowerCase().includes('text/html')) return asset;
    let destination;
    try { destination = gameUrl(env.GAME_URL); }
    catch (error) { return new Response(request.method === 'HEAD' ? null : error.message, { status: 500, headers: { 'content-type': 'text/plain; charset=utf-8', 'cache-control': 'no-store' } }); }
    const origin = new URL(request.url).origin, headers = new Headers(asset.headers);
    for (const header of ['content-length', 'etag', 'last-modified']) headers.delete(header);
    headers.set('cache-control', 'no-store');
    const response = new Response(request.method === 'HEAD' ? null : asset.body, { status: asset.status, statusText: asset.statusText, headers });
    if (request.method === 'HEAD' || !asset.body) return response;
    return new HTMLRewriter()
      .on('a[data-game-link]', attribute('href', destination))
      .on('link[data-canonical]', attribute('href', `${origin}/`))
      .on('meta[property="og:url"]', attribute('content', `${origin}/`))
      .on('meta[property="og:image"]', attribute('content', `${origin}/assets/og.png`))
      .on('head', { element(element) { element.append(arenaStyles, { html: true }); } })
      .on('.site-header nav a[href="#pickle-pals"]', { element(element) { element.setAttribute('href', '#brine-royale'); element.setInnerContent('Arena'); } })
      .on('.hero-copy .hero-note', { element(element) { element.after(`<p class="arena-entry"><a href="${ARENA_URL}">Play the multiplayer arena ${arrow}</a></p>`, { html: true }); } })
      .on('#how-it-works', { element(element) { element.before(arenaFeature, { html: true }); } })
      .on('#faq .questions', { element(element) { element.prepend(`<details><summary>Can I play with friends?<span aria-hidden="true">+</span></summary><p>Yes! <a href="${ARENA_URL}">Brine Royale</a> is our online survival arena. Play in shared rooms with up to 64 players across web and iOS, or invite friends with a private room link. Collect food, split into smaller pickles, and regroup after 12 seconds. The arena needs an internet connection.</p></details>`, { html: true }); } })
      .transform(response);
  }
};
