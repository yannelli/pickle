export const WARDROBE_IDS = Object.freeze([
  'beanie', 'beret', 'headphones', 'sunhat', 'chef', 'cowboy',
  'pirate', 'mushroom', 'wizard', 'rainhat', 'halo', 'helmet',
  'cap', 'backcap', 'headband', 'antenna', 'captain', 'bonnet',
  'deerstalker', 'mortarboard', 'witch', 'tophat', 'headset', 'shako',
  'viking', 'tiara', 'jester', 'unicorn', 'phoenix', 'emperor'
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
  ] },
  cap: { color: '#4F7FA6', parts: [
    path('M-18 4q-21 0-18 8 8 5 18-2z'), path('M-22 9q0-26 22-26t22 26q-22 7-44 0z'), oval(0, -18, 2.6, 2.6, 'light')
  ] },
  backcap: { color: '#D2694B', parts: [
    path('M18 4q21 0 18 8-8 5-18-2z'), path('M-22 9q0-26 22-26t22 26q-22 7-44 0z'), path('M-14 7h28', null, 'light', 4)
  ] },
  headband: { color: '#D65A5A', parts: [
    path('M-26 9q26 13 52 0l2 7q-28 14-56 0z'), path('m25 13 11 5-4 4-3 6-6-6z')
  ] },
  antenna: { color: '#7FA3A8', parts: [
    path('M-22 12q0-27 22-27t22 27q-22 8-44 0z'), path('M0-16v-12', null), oval(0, -32, 5, 5, 'light')
  ] },
  captain: { color: '#2F4F6F', parts: [
    path('M-26 7q26 6 52 0 2 8-26 10T-26 7Z'), path('M-24 2H24V8H-24Z'),
    path('M-23 2q0-20 23-20t23 20z', 'light'), path('M0-14v9M-4-11h8', null)
  ] },
  bonnet: { color: '#E3A3B5', parts: [
    path('M-27 17q-6-35 27-35t27 35q-11-17-27-17t-27 17z'), path('M-25 17-26 28M25 17 26 28', null, 'ink', 3),
    path('m0-22 5 5-5 5-5-5z', 'light')
  ] },
  deerstalker: { color: '#8A6E4B', parts: [
    oval(0, 11, 28, 5), path('M-21 10q0-25 21-25t21 25q-21 6-42 0z'),
    path('M-27 5q-7 13 1 18 7-2 8-13zM27 5q7 13-1 18-7-2-8-13z')
  ] },
  mortarboard: { color: '#3A3F52', parts: [
    path('M-15 10q0-15 15-15t15 15q-15 5-30 0z'), path('M-29-6 0-15l29 9L0 4Z'),
    path('M23-8v13', null, 'light'), oval(23, 8, 2.8, 2.8, 'light')
  ] },
  witch: { color: '#5B4B7A', parts: [
    oval(0, 8, 29, 6), path('M-15 6Q-17-14-5-35 8-18 15 6Z'), path('M-7-3H7V5H-7Z', 'light')
  ] },
  tophat: { color: '#2E3A3F', parts: [
    path('M-15-32H15V2H-15Z'), path('M-15-9h30', null, 'light', 6), oval(0, 3, 25, 5)
  ] },
  headset: { color: '#3F7D74', parts: [
    path('M-27 12q0-29 27-29t27 29', null, 'ink', 5), rect(-32, 6, 12, 21, 6), rect(20, 6, 12, 21, 6),
    path('M-27 25q-5 14 8 19', null), oval(-16, 45, 3.5, 3.5)
  ] },
  shako: { color: '#B8473D', parts: [
    path('M-14-24H14V4H-14Z'), path('M-9-13h18', null, 'light', 5), oval(0, 5, 19, 4.5),
    path('M0-24v-6', null, 'ink', 3), oval(0, -34, 5, 5, 'light')
  ] },
  // Premium looks (500 to 3,000 native coins) use extra colours for gems and flames.
  viking: { color: '#8D9CA8', parts: [
    path('M-19-1Q-33-6-34-26Q-24-14-13-9Z', 'light'), path('M19-1Q33-6 34-26Q24-14 13-9Z', 'light'),
    path('M-22 9q0-27 22-27t22 27q-22 7-44 0z'), path('M0-18V4', null, 'light', 3), path('M-21 3q21 7 42 0', null, 'light', 3)
  ] },
  tiara: { color: '#E3B94E', parts: [
    path('M-21 6-15-9-7-1 0-19 7-1 15-9 21 6q-21 7-42 0z'),
    oval(0, -6, 4, 5, '#E0607E'), oval(-12, 1, 2.6, 2.6, '#6FA8DC'), oval(12, 1, 2.6, 2.6, '#6FA8DC'),
    oval(0, -20, 2.4, 2.4, 'light'), oval(-15, -10, 2, 2, 'light'), oval(15, -10, 2, 2, 'light')
  ] },
  jester: { color: '#7B52A8', parts: [
    path('M-20 8Q-26-10-37-9Q-22-24-4-10Z'), path('M20 8Q26-10 37-9Q22-24 4-10Z'),
    path('M-12 6Q-10-22 0-35Q10-22 12 6Z', '#E9B949'), path('M-23 5q23 8 46 0l1 6q-24 9-48 0z', 'light'),
    oval(-37, -9, 3.5, 3.5, '#E9B949'), oval(37, -9, 3.5, 3.5, '#E9B949'), oval(0, -35, 3.5, 3.5)
  ] },
  unicorn: { color: '#E79BBE', parts: [
    path('M-20 7l-4-18 13 10z'), path('M20 7l4-18-13 10z'),
    path('M-6 2 0-32 6 2z', '#F3D46B'), path('M-4.5-4l8-3M-3-12l6-2.4M-1.6-20l3.4-1.2', null, 'ink', 1.6)
  ] },
  phoenix: { color: '#E4683A', parts: [
    path('M-22 8Q-30-8-20-22Q-18-12-12-10Q-14-24-4-34Q-4-20 0-16Q4-20 4-34Q14-24 12-10Q18-12 20-22Q30-8 22 8Q0 15-22 8Z'),
    path('M-12 7Q-16-4-8-14Q-6-6-2-5Q-2-14 2-22Q6-12 4-5Q8-6 10-14Q16-4 12 7Q0 11-12 7Z', '#F4C34E', null),
    path('M-23 6q23 8 46 0l1 5q-24 9-48 0z', '#9C3D2A')
  ] },
  emperor: { color: '#E8BF3F', parts: [
    path('M-20 4q0-26 20-26t20 26z', '#B23A48'), path('M-25 9-27-14-15-4-8-20 0-8 8-20 15-4 27-14 25 9q-25 8-50 0z'),
    path('M-24 4q24 8 48 0', null, 'light', 3),
    oval(0, 2, 4, 4.5, '#4FA3D9'), oval(-14, 1, 3, 3, '#3FA76A'), oval(14, 1, 3, 3, '#3FA76A'),
    oval(-27, -14, 2.4, 2.4, 'light'), oval(27, -14, 2.4, 2.4, 'light'), oval(-8, -20, 2.4, 2.4, 'light'), oval(8, -20, 2.4, 2.4, 'light'),
    oval(0, -27, 3.5, 3.5), path('M0-31v-6M-3-34h6', null, 'ink', 2)
  ] }
});
export const WARDROBE_LOOKS = looks;

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
    const color = value => value === 'accent' ? look.color : value === 'light' ? light : value === 'ink' ? ink : value;
    if (part[2]) { ctx.fillStyle = color(part[2]); ctx.fill(drawing); }
    if (part[3]) { ctx.strokeStyle = color(part[3]); ctx.lineWidth = part[4]; ctx.stroke(drawing); }
  }
  ctx.restore();
  return true;
}
