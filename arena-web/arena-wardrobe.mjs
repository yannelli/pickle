export const WARDROBE_IDS = Object.freeze([
  'beanie', 'beret', 'headphones', 'sunhat', 'chef', 'cowboy',
  'pirate', 'mushroom', 'wizard', 'rainhat', 'halo', 'helmet'
]);

const ink = '#263E31', light = '#F2F7DA';
const path = (data, fill = 'accent', stroke = 'ink', width = 2.5) => ['path', data, fill, stroke, width];
const oval = (x, y, rx, ry, fill = 'accent', stroke = 'ink', width = 2.5) => ['oval', [x, y, rx, ry], fill, stroke, width];
const rect = (x, y, width, height, radius, fill = 'accent', stroke = 'ink', line = 2.5) =>
  ['rect', [x, y, width, height, radius], fill, stroke, line];

const looks = Object.freeze({
  beanie: { color: '#A26A87', parts: [
    path('M-22 6q0-25 22-25t22 25z'), path('M-24 5H24V12q-24 8-48 0z'),
    path('M-21 9q21 6 42 0', null, 'light'), oval(0, -22, 5, 5, 'light')
  ] },
  beret: { color: '#B85C52', parts: [
    path('M-24 5q-2-20 24-20t22 16q-2 8-23 8T-24 5Z'), path('m14-15 5-7', null)
  ] },
  headphones: { color: '#47677F', parts: [
    path('M-27 12q0-29 27-29t27 29', null, 'ink', 5),
    rect(-32, 6, 12, 21, 6), rect(20, 6, 12, 21, 6)
  ] },
  sunhat: { color: '#C9A55E', parts: [
    oval(0, 6, 30, 7), path('M-17 5q0-20 17-20t17 20z'), path('M-16 1q16 5 32 0', null, 'light')
  ] },
  chef: { color: '#C8553D', parts: [
    path('M-17 0a12 12 0 0 1 1-21 13 13 0 0 1 16-10 13 13 0 0 1 16 10 12 12 0 0 1 1 21z', 'light'),
    path('M-17 0H17V7q-17 8-34 0z')
  ] },
  cowboy: { color: '#986841', parts: [
    path('M-31 5q7-6 31-6t31 6q-7 8-31 8T-31 5Z'),
    path('M-17 5q1-21 9-22 4 4 8 4t8-4q8 1 9 22q-17 6-34 0Z')
  ] },
  pirate: { color: '#3D596B', parts: [
    path('M-26 10q2-25 26-25t26 25q-26 8-52 0Z'), path('m22 3 14 6-10 7z'),
    oval(0, -6, 5, 5, 'light'), path('m-7 1 14 5m-14 0 14-5', null, 'light')
  ] },
  mushroom: { color: '#C8553D', parts: [
    path('M-28 11q0-34 28-34t28 34q-28 9-56 0z'),
    oval(-13, -7, 4.5, 4.5, 'light', null), oval(6, -13, 5.5, 5.5, 'light', null),
    oval(18, -1, 3.5, 3.5, 'light', null)
  ] },
  wizard: { color: '#755B94', parts: [
    oval(0, 4, 27, 6), path('M-16 5Q-9-17 0-36 9-17 16 5Z'),
    path('m0-25 1.8 5 5.2.3-4 3.2 1.4 5L0-14.4l-4.4 3 1.4-5-4-3.2 5.2-.3z', 'light', null)
  ] },
  rainhat: { color: '#D7AD42', parts: [
    path('M-30 9q30 9 60 0-3 12-30 12T-30 9Z'), path('M-20 9q0-24 20-24t20 24q-20 6-40 0z')
  ] },
  halo: { color: '#E8BF5D', parts: [
    oval(0, -15, 15, 5, null, 'accent', 5.5), oval(0, -15, 15, 5, null, 'light', 2)
  ] },
  helmet: { color: '#708F9F', parts: [
    path('M-24 15q0-31 24-31t24 31q-24 8-48 0z'),
    path('M-9-16q12-19 23-8-8 14-23 8z', 'light'),
    path('M-19 4h38', null, 'ink', 4), oval(-16, 12, 2, 2, 'light'), oval(16, 12, 2, 2, 'light')
  ] }
});

const cachedPaths = new Map();
function shape(part) {
  const key = JSON.stringify(part.slice(0, 2));
  if (cachedPaths.has(key)) return cachedPaths.get(key);
  const result = part[0] === 'path' ? new Path2D(part[1]) : new Path2D();
  if (part[0] === 'oval') {
    const [x, y, rx, ry] = part[1];
    result.ellipse(x, y, rx, ry, 0, 0, Math.PI * 2);
  } else {
    const [x, y, width, height, radius] = part[1];
    result.roundRect(x, y, width, height, radius);
  }
  cachedPaths.set(key, result);
  return result;
}

export function drawWardrobe(ctx, outfit) {
  const look = looks[outfit];
  if (!look) return false;
  ctx.save();
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  for (const part of look.parts) {
    const drawing = shape(part);
    const color = value => value === 'accent' ? look.color : value === 'light' ? light : ink;
    if (part[2]) { ctx.fillStyle = color(part[2]); ctx.fill(drawing); }
    if (part[3]) { ctx.strokeStyle = color(part[3]); ctx.lineWidth = part[4]; ctx.stroke(drawing); }
  }
  ctx.restore();
  return true;
}
