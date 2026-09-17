(function (root) {
  'use strict';
  const FORMATS = { square: { width: 1080, height: 1080 }, story: { width: 1080, height: 1920 } };
  const PLAY_URL = 'https://littledill.app/';
  const INK = '#304a35', PAPER = '#f7f5e9';

  function describe(pet, now = Date.now()) {
    const life = root.LittleDillLife;
    const stage = life.stage(pet, now), look = life.elder(pet, now) || life.teen(pet, now);
    const days = Math.floor(life.age(pet, now) / life.DAY);
    const hours = Math.floor(life.age(pet, now) / life.HOUR);
    const age = days ? days + (days === 1 ? ' day old' : ' days old') : hours ? hours + (hours === 1 ? ' hour old' : ' hours old') : 'Just hatched';
    const variety = life.VARIETIES.find(item => item.id === pet.variety).name;
    const badge = look?.name || { baby: 'Baby dill. Big feelings.', young: 'Growing into a big dill.', adult: 'Officially a big dill.' }[stage];
    const slug = pet.name.normalize('NFKD').replace(/[^a-z0-9]+/gi, '-').replace(/^-|-$/g, '').toLowerCase() || 'pickle';
    return { name: pet.name, age, variety, badge, slug, caption: 'Meet ' + pet.name + ', my little dill. Raise yours at ' + PLAY_URL };
  }

  function canvas(width, height) {
    const element = document.createElement('canvas');
    element.width = width; element.height = height;
    const context = element.getContext('2d');
    if (!context) throw new Error('Photos need canvas support.');
    return [element, context];
  }
  function rounded(context, x, y, width, height, radius, fill) {
    context.beginPath(); context.roundRect(x, y, width, height, radius);
    context.fillStyle = fill; context.fill();
  }
  function svgImage(element) {
    const style = getComputedStyle(element);
    if (element.hidden || style.display === 'none' || !element.innerHTML) return Promise.resolve(null);
    const source = '<svg xmlns="http://www.w3.org/2000/svg" width="150" height="160" viewBox="-40 -40 150 160" fill="none" stroke="' + style.color + '" color="' + style.color + '" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">' + element.innerHTML + '</svg>';
    return new Promise((resolve, reject) => {
      const image = new Image();
      image.onload = () => resolve(image);
      image.onerror = () => reject(new Error('Could not draw this outfit.'));
      image.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(source);
    });
  }
  const px = value => parseFloat(value) || 0;
  const TRANSPARENT = 'rgba(0, 0, 0, 0)';
  function corners(style, width, height, border = [0, 0, 0, 0]) {
    return ['TopLeft', 'TopRight', 'BottomRight', 'BottomLeft'].map((corner, index) => {
      const values = style['border' + corner + 'Radius'].split(' ');
      const size = (value, total) => px(value) * (value.includes('%') ? total / 100 : 1);
      const horizontal = index === 0 || index === 3 ? border[3] : border[1], vertical = index < 2 ? border[0] : border[2];
      return { x: Math.max(0, size(values[0], width) - horizontal), y: Math.max(0, size(values[1] || values[0], height) - vertical) };
    });
  }
  function shadows(style) {
    const pattern = /(rgba?\([^)]*\)) (-?[\d.]+)px (-?[\d.]+)px [\d.]+px [\d.]+px( inset)?/g;
    return [...style.boxShadow.matchAll(pattern)].map(match => ({ color: match[1], x: +match[2], y: +match[3], inset: !!match[4] })).reverse();
  }
  /* Paints one CSS box the way the browser does: outer shadows, background, inset shadows, border. */
  function paintBox(ctx, style, box) {
    const border = ['Top', 'Right', 'Bottom', 'Left'].map(side => px(style['border' + side + 'Width']));
    const outer = corners(style, box.w, box.h), inner = corners(style, box.w, box.h, border);
    const pad = { x: box.x + border[3], y: box.y + border[0], w: box.w - border[1] - border[3], h: box.h - border[0] - border[2] };
    const shape = (rect, radii) => { ctx.beginPath(); ctx.roundRect(rect.x, rect.y, rect.w, rect.h, radii); };
    const list = shadows(style);
    for (const shadow of list.filter(item => !item.inset)) {
      ctx.save(); ctx.beginPath(); ctx.rect(box.x - 200, box.y - 200, box.w + 400, box.h + 400);
      ctx.roundRect(box.x, box.y, box.w, box.h, outer); ctx.clip('evenodd');
      shape({ x: box.x + shadow.x, y: box.y + shadow.y, w: box.w, h: box.h }, outer); ctx.fillStyle = shadow.color; ctx.fill(); ctx.restore();
    }
    if (style.backgroundColor !== TRANSPARENT) { shape(box, outer); ctx.fillStyle = style.backgroundColor; ctx.fill(); }
    for (const shadow of list.filter(item => item.inset)) {
      ctx.save(); shape(pad, inner); ctx.clip(); shape(pad, inner);
      ctx.roundRect(pad.x + shadow.x, pad.y + shadow.y, pad.w, pad.h, inner); ctx.fillStyle = shadow.color; ctx.fill('evenodd'); ctx.restore();
    }
    const gradient = style.backgroundImage.match(/linear-gradient\(90deg, transparent (\d+)%, (rgba?\([^)]*\)) \d+% (\d+)%/);
    if (gradient) { ctx.fillStyle = gradient[2]; ctx.fillRect(pad.x + pad.w * gradient[1] / 100, pad.y, pad.w * (gradient[3] - gradient[1]) / 100, pad.h); }
    const side = ['Top', 'Right', 'Bottom', 'Left'].find((name, index) => border[index]);
    if (side) { shape(box, outer); ctx.roundRect(pad.x, pad.y, pad.w, pad.h, inner); ctx.fillStyle = style['border' + side + 'Color']; ctx.fill('evenodd'); }
    return pad;
  }
  function transformed(ctx, style, box, draw) {
    const matrix = style.transform.match(/^matrix\(([^)]+)\)/);
    ctx.save();
    ctx.globalAlpha *= px(style.opacity);
    if (matrix) {
      const [ox, oy] = style.transformOrigin.split(' ').map(px);
      ctx.translate(box.x + ox, box.y + oy); ctx.transform(...matrix[1].split(',').map(Number)); ctx.translate(-box.x - ox, -box.y - oy);
    }
    draw(); ctx.restore();
  }
  function visible(style) { return style.display !== 'none' && style.content !== 'none'; }
  function element(ctx, node, children) {
    if (!node || node.hidden) return;
    const style = getComputedStyle(node);
    if (!visible(style)) return;
    const box = { x: node.offsetLeft, y: node.offsetTop, w: node.offsetWidth, h: node.offsetHeight };
    transformed(ctx, style, box, () => {
      const pad = paintBox(ctx, style, box);
      if (children) { ctx.save(); ctx.translate(pad.x, pad.y); children(); ctx.restore(); }
    });
  }
  function pseudo(ctx, node, which) {
    const style = getComputedStyle(node, which);
    if (!visible(style)) return;
    const content = style.boxSizing === 'border-box';
    const box = { x: px(style.left), y: px(style.top), w: px(style.width), h: px(style.height) };
    if (!content) { box.w += px(style.borderLeftWidth) + px(style.borderRightWidth); box.h += px(style.borderTopWidth) + px(style.borderBottomWidth); }
    transformed(ctx, style, box, () => paintBox(ctx, style, box));
  }
  function overlay(ctx, node, image, parent) {
    const style = getComputedStyle(node);
    if (!image) return;
    const height = px(style.height), top = style.top === 'auto' ? parent.offsetHeight - px(style.bottom) - height : px(style.top);
    ctx.drawImage(image, px(style.left), top, px(style.width), height);
  }
  function text(ctx, node) {
    const style = getComputedStyle(node);
    if (!visible(style)) return;
    const box = { x: node.offsetLeft, y: node.offsetTop, w: node.offsetWidth, h: node.offsetHeight };
    transformed(ctx, style, box, () => {
      ctx.font = style.fontWeight + ' ' + style.fontSize + ' ' + style.fontFamily; ctx.fillStyle = style.color; ctx.textAlign = 'left';
      ctx.fillText(node.textContent, box.x, box.y + (ctx.measureText(node.textContent).fontBoundingBoxAscent || px(style.fontSize) * .8));
    });
  }
  /* Repaints the live pickle DOM at 4x: same boxes, radii, shadows, and current transforms. */
  async function portrait(room) {
    const $ = selector => room.querySelector(selector);
    const size = $('.pet-size'), body = $('.pickle');
    const [scene, outfit] = await Promise.all([svgImage($('#scene-art')), svgImage($('#elder-art'))]);
    const [image, ctx] = canvas(800, 720);
    ctx.scale(4, 4);
    ctx.translate(100 - size.offsetLeft - size.offsetWidth / 2, 156 - size.offsetTop - size.offsetHeight);
    element(ctx, $('.pet-shadow'));
    element(ctx, size, () => {
      overlay(ctx, $('#scene-art'), scene, size);
      element(ctx, $('.pet-actor'), () => element(ctx, body, () => {
        pseudo(ctx, body, '::before');
        for (const selector of ['.arm.left', '.arm.right', '.foot.left', '.foot.right', '.sweat']) element(ctx, $(selector));
        pseudo(ctx, body, '::after');
        element(ctx, $('.face'), () => {
          element(ctx, $('.eye.left'));
          element(ctx, $('.eye.right'), () => { pseudo(ctx, $('.eye.right'), '::before'); pseudo(ctx, $('.eye.right'), '::after'); });
          for (const selector of ['.cheek.left', '.cheek.right', '.mouth']) element(ctx, $(selector));
          pseudo(ctx, $('.face'), '::after');
        });
        overlay(ctx, $('#elder-art'), outfit, body);
      }));
    });
    for (const node of room.querySelectorAll('.sleep-z')) text(ctx, node);
    return image;
  }

  async function renderCard(details, pickle, format) {
    const { width, height } = FORMATS[format];
    const [image, ctx] = canvas(width, height), story = format === 'story';
    ctx.fillStyle = PAPER; ctx.fillRect(0, 0, width, height);
    ctx.strokeStyle = '#cbd3b6'; ctx.lineWidth = 2; ctx.strokeRect(34, 34, width - 68, height - 68);
    const text = (value, y, size, color = INK, weight = 600) => {
      ctx.textAlign = 'center'; ctx.fillStyle = color;
      do { ctx.font = weight + ' ' + size-- + 'px "Avenir Next", Avenir, "Segoe UI", sans-serif'; } while (ctx.measureText(value).width > 880 && size > 22);
      ctx.fillText(value, width / 2, y);
    };
    text('meet my pickle.', story ? 260 : 100, 30, '#66764f');
    text(details.name, story ? 365 : 192, 86, INK, 800);
    text(details.variety + ' · ' + details.age, story ? 428 : 248, 28, '#66764f', 500);
    const top = story ? 505 : 292, panelHeight = story ? 820 : 470;
    rounded(ctx, 74, top, 932, panelHeight, 36, '#e5ebd1');
    ctx.strokeStyle = '#b9c898'; ctx.setLineDash([5, 12]); ctx.lineWidth = 2;
    ctx.beginPath(); ctx.ellipse(540, top + panelHeight / 2, 382, panelHeight / 2 - 36, -.08, 0, Math.PI * 2); ctx.stroke(); ctx.setLineDash([]);
    ctx.fillStyle = '#8da16d'; ctx.font = '34px serif';
    ctx.fillText('✦', 175, top + 95); ctx.fillText('+', 896, top + panelHeight - 72);
    const portraitHeight = panelHeight - 12, portraitWidth = portraitHeight * pickle.width / pickle.height;
    ctx.drawImage(pickle, (width - portraitWidth) / 2, top, portraitWidth, portraitHeight);
    const badgeY = story ? 1410 : 800;
    rounded(ctx, 180, badgeY - 34, 720, 64, 32, '#e8bd98');
    text(details.badge, badgeY + 8, 28);
    text('Yes, I am emotionally attached.', story ? 1555 : 906, 30, '#66764f', 500);
    text('little dill.', story ? 1690 : 978, 38, INK, 800);
    text('Raise your own → littledill.app', story ? 1748 : 1025, 24, '#66764f', 500);
    const blob = await new Promise(resolve => image.toBlob(resolve, 'image/png'));
    if (!blob) throw new Error('Could not save this photo.');
    return blob;
  }

  function create() {
    const $ = id => document.getElementById(id), dialog = $('photo-dialog');
    const preview = $('photo-image'), status = $('photo-status');
    const download = $('photo-download'), share = $('photo-share');
    const formats = ['square', 'story'];
    let details, pickle, file, photoUrl, format = 'square', operation = 0, sharing = false;
    function release() {
      if (photoUrl) URL.revokeObjectURL(photoUrl);
      photoUrl = null; file = null; preview.hidden = true; preview.removeAttribute('src');
    }
    function controls(ready) {
      download.disabled = !ready || sharing; share.disabled = !ready || sharing;
      for (const name of formats) $('photo-' + name).disabled = sharing;
    }
    async function generate() {
      const current = ++operation, selected = format;
      release(); controls(false); status.textContent = 'Getting your pickle camera-ready…';
      $('photo-preview').setAttribute('aria-busy', 'true');
      for (const name of formats) $('photo-' + name).setAttribute('aria-pressed', String(name === selected));
      try {
        const blob = await renderCard(details, await pickle, selected);
        if (current !== operation || !dialog.open) return;
        photoUrl = URL.createObjectURL(blob);
        file = typeof File === 'function' ? new File([blob], 'little-dill-' + details.slug + '-' + selected + '.png', { type: 'image/png' }) : null;
        preview.src = photoUrl; preview.alt = details.name + ', ' + details.variety + ', ' + details.age + '. ' + details.badge;
        preview.hidden = false;
        let canShare = false;
        try { canShare = !!file && !!navigator.share && !!navigator.canShare?.({ files: [file] }); } catch { /* Download remains available. */ }
        share.hidden = !canShare; controls(true);
        status.textContent = FORMATS[selected].width + ' × ' + FORMATS[selected].height + ' PNG. ' + (canShare ? 'Ready to share.' : 'Download your photo to post anywhere.');
      } catch {
        if (current === operation && dialog.open) status.textContent = 'Couldn’t make this photo. Close and try again.';
      } finally {
        if (current === operation) $('photo-preview').setAttribute('aria-busy', 'false');
      }
    }
    for (const name of formats) $('photo-' + name).addEventListener('click', () => { format = name; generate(); });
    $('photo-close').addEventListener('click', () => dialog.close());
    dialog.addEventListener('close', () => {
      if (dialog.open) return;
      operation++; release(); sharing = false; controls(false);
    });
    download.addEventListener('click', () => {
      if (!photoUrl || download.disabled) return;
      const link = document.createElement('a');
      link.href = photoUrl; link.download = 'little-dill-' + details.slug + '-' + format + '.png';
      document.body.append(link); link.click(); link.remove();
      status.textContent = 'Photo downloaded. Add it to your next post or story.';
    });
    share.addEventListener('click', async () => {
      if (!file || share.disabled) return;
      const current = operation;
      sharing = true; controls(true);
      try {
        await navigator.share({ files: [file], title: details.name + ' · little dill', text: details.caption });
        if (current === operation) status.textContent = 'Photo shared. A pretty big dill.';
      } catch (error) {
        if (current === operation) status.textContent = error.name === 'AbortError' ? 'Photo ready whenever you are.' : 'Sharing didn’t work. Download the PNG to share it.';
      } finally {
        if (current === operation) { sharing = false; controls(true); }
      }
    });
    return { open(pet, room) {
      details = describe(pet); pickle = portrait(room); sharing = false;
      dialog.showModal(); generate();
    } };
  }
  root.LittleDillPhotos = { create, describe, portrait, FORMATS };
})(globalThis);
