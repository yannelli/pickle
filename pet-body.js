(function (root) {
  'use strict';
  const BODY_PROFILES = Object.freeze({
    long: { width: .8, height: 1 },
    gherkin: { width: .84, height: .82 },
    pear: { width: .9, height: 1 },
    round: { width: 1.04, height: .78 },
    tapered: { width: .76, height: 1.08 },
    ribbed: { width: .86, height: 1.02 }
  });

  function profile(shape) { return Object.hasOwn(BODY_PROFILES, shape) ? BODY_PROFILES[shape] : BODY_PROFILES.long; }

  function radius(shape, angle, width, height) {
    const c = Math.abs(Math.cos(angle)), s = Math.sin(angle), sy = Math.abs(s);
    if (shape === 'long') {
      const k = Math.max(0, height - width);
      if (c > 1e-9 && sy * width / c <= k) return width / c;
      return sy * k + Math.sqrt(Math.max(0, (sy * k) ** 2 - k * k + width * width));
    }
    if (shape === 'gherkin') return 1 / ((c / width) ** 3 + (sy / height) ** 3) ** (1 / 3);
    const oval = 1 / Math.hypot(c / width, sy / height);
    if (shape === 'pear') return oval * (1 + .28 * s * c * c);
    if (shape === 'tapered') return oval * (1 - .32 * s * c * c);
    if (shape === 'ribbed') return oval * (1 + .1 * Math.cos(3 * Math.PI * s) * c * c);
    return oval;
  }

  function points(shape, width, height, count = 72) {
    return Array.from({ length: count }, (_, i) => {
      const angle = i * Math.PI * 2 / count, r = radius(shape, angle, width, height);
      return [Math.cos(angle) * r, Math.sin(angle) * r];
    });
  }
  const api = Object.freeze({ profiles: BODY_PROFILES, profile, radius, points });
  root.LittleDillBody = api;
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
})(globalThis);
