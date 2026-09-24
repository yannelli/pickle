(function (root) {
  'use strict';
  // The body is a border-box element with a 3px border, so the art SVG (viewBox "-40 -40 150 160",
  // one unit per pixel, pinned at left/top -40) shares coordinates with the body's padding box.
  // Every accessory is authored in a local space that render() maps onto the body:
  //   HATS   x 0 at the head centre, y 0 at the crown. Scaled by body width / 56.
  //   FACES  x 0 at the face centre, y 0 at the eye line. The face box is 32x27 at every stage, so no scale.
  //   PROPS  x 0 sixteen pixels right of the body, y 0 on the ground. The right hand lands at (-3, -20).
  //   HELD   like FACES, but scaled with the body: a held object grows with the pickle.
  //   HAND   x 0, y 0 at the bottom outer corner of the left arm.
  // The head reads as a dome of radius 28 centred at (0, 28): its surface drops to y 3.8 at x 14,
  // y 8.4 at x 20 and y 13.6 at x 24, which is the line hat brims follow.
  const BODY = {
    baby: { w: 42, h: 51, face: 15, arm: 29 },
    young: { w: 48, h: 70, face: 25, arm: 42 },
    teen: { w: 52, h: 78, face: 30, arm: 48 },
    adult: { w: 56, h: 86, face: 34, arm: 53 },
    elder: { w: 60, h: 82, face: 34, arm: 53 }
  };
  const LIGHT = '#f2f7da';
  const HEADPHONES = '<path d="M-27 12q0-29 27-29t27 29" stroke-width="5"/><rect x="-32" y="6" width="12" height="21" rx="6" fill="currentColor"/><rect x="20" y="6" width="12" height="21" rx="6" fill="currentColor"/>';
  const HATS = {
    cap: '<path d="M-18 4q-21 0-18 8 8 5 18-2z" fill="currentColor"/><path d="M-22 9q0-26 22-26t22 26q-22 7-44 0z" fill="currentColor"/><circle cx="0" cy="-18" r="2.6" fill="' + LIGHT + '"/>',
    headphones: HEADPHONES,
    wizard: '<ellipse cx="0" cy="4" rx="27" ry="6" fill="currentColor"/><path d="M-16 5Q-9-17 0-36 9-17 16 5Z" fill="currentColor"/><path d="m0-25 1.8 5 5.2.3-4 3.2 1.4 5L0-14.4l-4.4 3 1.4-5-4-3.2 5.2-.3z" fill="' + LIGHT + '" stroke="none"/>',
    sunhat: '<ellipse cx="0" cy="6" rx="30" ry="7" fill="currentColor"/><path d="M-17 5q0-20 17-20t17 20z" fill="currentColor"/><path d="M-16 1q16 5 32 0" stroke="' + LIGHT + '"/>',
    turban: '<path d="M-26 14q0-31 26-31t26 31q-26 9-52 0z" fill="currentColor"/><path d="M-25 9q15-22 38-20M-24 16q19-25 46-17M-13 18q13-13 33-11"/><circle cx="-3" cy="-2" r="5" fill="' + LIGHT + '"/>',
    afro: '<path d="M-28 12a9 9 0 0 1-1-14 10 10 0 0 1 8-12 10 10 0 0 1 12-8 11 11 0 0 1 18 0 10 10 0 0 1 12 8 10 10 0 0 1 8 12 9 9 0 0 1-1 14q-28 9-56 0z" fill="currentColor"/>',
    captain: '<path d="M-26 7q26 6 52 0 2 8-26 10T-26 7Z" fill="currentColor"/><path d="M-24 2H24V8H-24Z" fill="currentColor"/><path d="M-23 2q0-20 23-20t23 20z" fill="' + LIGHT + '"/><path d="M0-14v9M-4-11h8"/>',
    mortarboard: '<path d="M-15 10q0-15 15-15t15 15q-15 5-30 0z" fill="currentColor"/><path d="M-29-6 0-15l29 9L0 4Z" fill="currentColor"/><path d="M23-8v13" stroke="' + LIGHT + '"/><circle cx="23" cy="8" r="2.8" fill="' + LIGHT + '"/>',
    crown: '<path d="M-23 8-26-20-13-8 0-25l13 17 13-12-3 28q-23 7-46 0z" fill="currentColor"/><path d="M-21 2q21 6 42 0" stroke="' + LIGHT + '" stroke-width="3"/><circle cx="0" cy="-19" r="2.6" fill="' + LIGHT + '"/><circle cx="-18" cy="-14" r="2.2" fill="' + LIGHT + '"/><circle cx="18" cy="-14" r="2.2" fill="' + LIGHT + '"/>',
    cowboy: '<path d="M-31 5q7-6 31-6t31 6q-7 8-31 8T-31 5Z" fill="currentColor"/><path d="M-17 5q1-21 9-22 4 4 8 4t8-4q8 1 9 22q-17 6-34 0Z" fill="currentColor"/>',
    bonnet: '<path d="M-27 17q-6-35 27-35t27 35q-11-17-27-17t-27 17z" fill="currentColor"/><path d="M-25 17-26 28M25 17 26 28" stroke-width="3"/><path d="m0-22 5 5-5 5-5-5z" fill="' + LIGHT + '"/>',
    antenna: '<path d="M-22 12q0-27 22-27t22 27q-22 8-44 0z" fill="currentColor"/><path d="M0-16v-12"/><circle cx="0" cy="-32" r="5" fill="' + LIGHT + '"/>',
    headband: '<path d="M-26 9q26 13 52 0l2 7q-28 14-56 0z" fill="currentColor"/><path d="m25 13 11 5-4 4-3 6-6-6z" fill="currentColor"/>',
    pirate: '<path d="M-26 10q2-25 26-25t26 25q-26 8-52 0Z" fill="currentColor"/><path d="m22 3 14 6-10 7z" fill="currentColor"/><circle cx="0" cy="-6" r="5" fill="' + LIGHT + '"/><path d="m-7 1 14 5m-14 0 14-5" stroke="' + LIGHT + '"/>',
    deerstalker: '<ellipse cx="0" cy="11" rx="28" ry="5" fill="currentColor"/><path d="M-21 10q0-25 21-25t21 25q-21 6-42 0z" fill="currentColor"/><path d="M-27 5q-7 13 1 18 7-2 8-13zM27 5q7 13-1 18-7-2-8-13z" fill="currentColor"/>',
    witch: '<ellipse cx="0" cy="8" rx="29" ry="6" fill="currentColor"/><path d="M-15 6Q-17-14-5-35 8-18 15 6Z" fill="currentColor"/><path d="M-7-3H7V5H-7Z" fill="' + LIGHT + '"/>',
    top: '<path d="M-15-32H15V2H-15Z" fill="currentColor"/><path d="M-15-9h30" stroke="' + LIGHT + '" stroke-width="6"/><ellipse cx="0" cy="3" rx="25" ry="5" fill="currentColor"/>',
    mushroom: '<path d="M-28 11q0-34 28-34t28 34q-28 9-56 0z" fill="currentColor"/><g fill="' + LIGHT + '" stroke="none"><circle cx="-13" cy="-7" r="4.5"/><circle cx="6" cy="-13" r="5.5"/><circle cx="18" cy="-1" r="3.5"/></g>',
    chef: '<path d="M-17 0a12 12 0 0 1 1-21 13 13 0 0 1 16-10 13 13 0 0 1 16 10 12 12 0 0 1 1 21z" fill="' + LIGHT + '"/><path d="M-17 0H17V7q-17 8-34 0z" fill="currentColor"/>',
    helmet: '<path d="M-24 15q0-31 24-31t24 31q-24 8-48 0z" fill="currentColor"/><path d="M-9-16q12-19 23-8-8 14-23 8z" fill="' + LIGHT + '"/><path d="M-19 4h38" stroke-width="4"/><circle cx="-16" cy="12" r="2" fill="' + LIGHT + '"/><circle cx="16" cy="12" r="2" fill="' + LIGHT + '"/>',
    rainhat: '<path d="M-30 9q30 9 60 0-3 12-30 12T-30 9Z" fill="currentColor"/><path d="M-20 9q0-24 20-24t20 24q-20 6-40 0z" fill="currentColor"/>',
    mohawk: '<path d="m-15 9 3-18 5 5 4-22 5 20 6-13 7 28q-15 6-30 0z" fill="currentColor"/>',
    vampire: '<path d="M-24 14q0-29 24-29t24 29q-6-10-14-8L0 17-10 6q-8-2-14 8z" fill="currentColor"/><path d="M-14-11q9-6 19-2" stroke="' + LIGHT + '"/>',
    halo: '<ellipse cx="0" cy="-15" rx="15" ry="5" stroke-width="5.5"/><ellipse cx="0" cy="-15" rx="15" ry="5" stroke="' + LIGHT + '" stroke-width="2"/>',
    beret: '<path d="M-24 5q-2-20 24-20t22 16q-2 8-23 8T-24 5Z" fill="currentColor"/><path d="m14-15 5-7"/>',
    fringe: '<path d="M-25 7q-3-32 25-32 27 0 27 26-8-14-21-12l8 22q-10-16-24-18-9 0-15 14z" fill="currentColor"/>',
    backcap: '<path d="M18 4q21 0 18 8-8 5-18-2z" fill="currentColor"/><path d="M-22 9q0-26 22-26t22 26q-22 7-44 0z" fill="currentColor"/><path d="M-14 7h28" stroke="' + LIGHT + '" stroke-width="4"/>',
    beanie: '<path d="M-22 6q0-25 22-25t22 25z" fill="currentColor"/><path d="M-24 5H24V12q-24 8-48 0z" fill="currentColor"/><path d="M-21 9q21 6 42 0" stroke="' + LIGHT + '"/><circle cx="0" cy="-22" r="5" fill="' + LIGHT + '"/>',
    headset: HEADPHONES + '<path d="M-27 25q-5 14 8 19"/><circle cx="-16" cy="45" r="3.5" fill="currentColor"/>',
    shako: '<path d="M-14-24H14V4H-14Z" fill="currentColor"/><path d="M-9-13h18" stroke="' + LIGHT + '" stroke-width="5"/><ellipse cx="0" cy="5" rx="19" ry="4.5" fill="currentColor"/><path d="M0-24v-6" stroke-width="3"/><circle cx="0" cy="-34" r="5" fill="' + LIGHT + '"/>'
  };
  const FACES = {
    sunglasses: '<path d="M-20 1H-4q0 11-8 11t-8-11z" fill="currentColor"/><path d="M20 1H4q0 11 8 11t8-11z" fill="currentColor"/><path d="M-4 3h8M-20 2-27 0M20 2 27 0"/>',
    nerdglasses: '<circle cx="-12.5" cy="3.5" r="7.5" fill="' + LIGHT + '" fill-opacity=".45"/><circle cx="12.5" cy="3.5" r="7.5" fill="' + LIGHT + '" fill-opacity=".45"/><path d="M-5 3h10M-20 2-26 4M20 3l6-2"/><path d="M0 0v7" stroke-width="4"/>',
    readers: '<ellipse cx="-12" cy="4" rx="9" ry="6.5" fill="#e4ecc0" fill-opacity=".55"/><ellipse cx="12" cy="4" rx="9" ry="6.5" fill="#e4ecc0" fill-opacity=".55"/><path d="M-3 4h6M-21 2-27 0M21 2 27 0"/>',
    book: '<path d="M-23 21q11-4 22 4 11-8 22-4v18q-11-4-22 4-11-8-22-4z" fill="' + LIGHT + '"/><path d="M-1 25v18M-18 26h11M-18 32h11M4 26h11M4 32h11" stroke-width="1.6"/>'
  };
  const PROPS = {
    cane: '<path d="M3 0v-30q0-10 9-10t8 9" stroke-width="5"/>',
    record: '<circle cx="8" cy="-16" r="15" fill="currentColor"/><circle cx="8" cy="-16" r="5.5" fill="' + LIGHT + '"/><circle cx="8" cy="-16" r="1.8" stroke="none"/>',
    scroll: '<path d="M0-40H20V-4H0Z" fill="' + LIGHT + '"/><path d="M3-33h14M3-25h14M3-17h11" stroke-width="1.8"/><rect x="-4" y="-44" width="28" height="6" rx="3" fill="currentColor"/><rect x="-4" y="-6" width="28" height="6" rx="3" fill="currentColor"/>',
    rake: '<path d="M5 0v-36M-7-36H19M-7-45v9M-1-45v9M5-45v9M11-45v9M19-45v9"/>',
    bowl: '<path d="M-9-15H25q-3 15-17 15T-9-15Z" fill="currentColor"/><path d="M-11-15H27" stroke-width="3"/><path d="M2-22q-5-5 0-9M14-22q-5-5 0-9"/>',
    anchor: '<path d="M8-40V-5M-2-31h20M-7-17q15 23 30 0M-7-17v9M23-17v9"/><circle cx="8" cy="-44" r="4.5"/>',
    book: '<path d="M-8-24q10-4 17 3 7-7 17-3v22q-10-4-17 3-7-7-17-3z" fill="' + LIGHT + '"/><path d="M9-21v22M-4-18h8M-4-12h8M14-18h8M14-12h8" stroke-width="1.6"/>',
    mug: '<path d="M-2-26H18V0H-2Z" fill="' + LIGHT + '"/><path d="M18-21q14-2 4 12h-4"/><path d="M3-32q-5-5 0-9M12-32q-5-5 0-9"/>',
    planet: '<circle cx="9" cy="-24" r="13" fill="' + LIGHT + '"/><ellipse cx="9" cy="-24" rx="21" ry="6" transform="rotate(-22 9 -24)"/>',
    flower: '<path d="M9 0v-26M9-13 1-20"/><g fill="currentColor"><circle cx="9" cy="-41" r="7.5"/><circle cx="1" cy="-33" r="7.5"/><circle cx="17" cy="-33" r="7.5"/><circle cx="9" cy="-25" r="7.5"/></g><circle cx="9" cy="-33" r="6" fill="' + LIGHT + '"/>',
    lens: '<circle cx="14" cy="-33" r="13" fill="' + LIGHT + '" fill-opacity=".55"/><path d="M5-23 0-3" stroke-width="5"/>',
    phone: '<rect x="0" y="-36" width="21" height="36" rx="3.5" fill="currentColor"/><rect x="3.5" y="-31.5" width="14" height="24" fill="' + LIGHT + '"/><circle cx="10.5" cy="-4" r="1.6" fill="' + LIGHT + '"/>',
    coin: '<circle cx="10" cy="-16" r="15" fill="' + LIGHT + '"/><path d="M10-28v24M17-25H7q-7 0-7 5.5t10 3.5q10 0 10 5.5T13-6H4"/>',
    shield: '<path d="M-6-40 9-45l15 5v18q-2 14-15 21-13-7-15-21z" fill="' + LIGHT + '"/><path d="M9-44V-2M-5-29h28"/>',
    umbrella: '<path d="M-13-30q8-24 21-24t21 24q-5 6-10.5 0-5 6-10.5 0-5 6-10.5 0-5 6-10.5 0z" fill="currentColor"/><path d="M8-54v-5M8-30v25q0 5 6 3"/><path d="M-2-33q5-19 10-19M18-33q-5-19-10-19" stroke="' + LIGHT + '"/>',
    wand: '<path d="M0-3 15-32" stroke-width="5"/><path d="m19-50 2.8 8.4h8.8l-7.1 5.2 2.7 8.4-7.2-5.2-7.2 5.2 2.7-8.4-7.1-5.2h8.8z" fill="' + LIGHT + '"/>',
    palette: '<path d="M-6-27q3-21 22-17 17 4 13 20-3 15-16 12l-1-9q-19 3-18-6z" fill="' + LIGHT + '"/><g fill="currentColor" stroke="none"><circle cx="3" cy="-33" r="3"/><circle cx="16" cy="-35" r="3"/><circle cx="23" cy="-24" r="3"/></g><path d="M0 0 13-21"/>',
    scepter: '<path d="M9 0v-36" stroke-width="5"/><path d="m-1-46 10-12 10 12-10 12z" fill="' + LIGHT + '"/>',
    clock: '<circle cx="10" cy="-18" r="16" fill="' + LIGHT + '"/><path d="M10-29v11l8 5M3-37h14"/>',
    infinity: '<path d="M10-26C-16-52-19 2 10-26 39-52 36 2 10-26Z" stroke-width="6"/>',
    journal: '<rect x="-2" y="-34" width="24" height="34" rx="2.5" fill="currentColor"/><path d="M10-12 3.5-19q-3.5-4.5 1-6.5 3.5-1.5 5.5 2 2-3.5 5.5-2 4.5 2 1 6.5z" fill="' + LIGHT + '" stroke="none"/>',
    ball: '<circle cx="10" cy="-15" r="15" fill="currentColor"/><path d="M-5-15h30M10-30v30M-2-26q12 11 0 22M22-26q-12 11 0 22" stroke="' + LIGHT + '"/>',
    skateboard: '<path d="M-8-14q-4 0-4-4t4-4h34q4 0 4 4t-4 4z" fill="currentColor"/><path d="M-6-20q6-4 12-2M-2-14v4M24-14v4"/><circle cx="-2" cy="-5" r="5" fill="' + LIGHT + '"/><circle cx="24" cy="-5" r="5" fill="' + LIGHT + '"/>',
    controller: '<path d="M-7-34q0-9 9-9h16q9 0 9 9l2 12q-3 8-9 2l-4-5H0l-4 5q-6 6-9-2z" fill="currentColor"/><path d="M-1-31h6M2-34v6" stroke="' + LIGHT + '"/><circle cx="17" cy="-32" r="2.2" fill="' + LIGHT + '"/><circle cx="22" cy="-27" r="2.2" fill="' + LIGHT + '"/>',
    masks: '<path d="M-7-34q14-6 15 9 0 15-8 15t-7-24z" fill="' + LIGHT + '"/><path d="M-4-25h3M2-25h1M-4-16q5 4 8 0" stroke-width="1.8"/><path d="M13-34q14-6 15 9 0 15-8 15t-7-24z" fill="currentColor"/><path d="M16-25h3M22-25h1M16-13q5-4 8 0" stroke="' + LIGHT + '" stroke-width="1.8"/>',
    trumpet: '<path d="M-3-25h17" stroke-width="4"/><path d="M14-35 30-41v32l-16-6z" fill="currentColor"/><path d="M1-25v-7M8-25v-7"/><circle cx="-4" cy="-25" r="3.5"/>'
  };
  // A content pickle rotates through vibes. Worn items ride on the body; scenery sits on the ground beside it.
  const WORN = {
    shades: { face: FACES.sunglasses },
    lounge: { face: FACES.sunglasses },
    book: { held: FACES.book },
    fire: { hand: '<path d="M7-2-17-14" stroke="#7a5a3a"/><rect x="-22" y="-19" width="8" height="8" fill="#fffde9" stroke="#263f29" stroke-width="1.5"/>' }
  };
  const SCENES = {
    lounge: '<g stroke="#c9a53a"><circle cx="-26" cy="2" r="9" fill="#e6c95a"/><path d="M-26-14V-10M-26 12V16M-42 2H-38M-14 2H-10M-37-9 -34-6M-18 10 -15 13M-37 13 -34 10M-18-6 -15-9"/></g><path d="M-16 100H84" stroke="#d9a066" stroke-width="7"/><path d="M-12 100H80" stroke="#e6ecc5" stroke-width="2" stroke-dasharray="6 6"/><rect x="70" y="80" width="12" height="18" fill="#dce7ac"/><path d="M76 80V66"/><path d="M64 66H88L76 58Z" fill="#c96a6a"/>',
    fire: '<g stroke="none"><path d="M-38 100 -12 92M-38 92 -12 100" stroke="#7a5a3a" stroke-width="5" stroke-linecap="round"/><g class="flame"><path d="M-25 90Q-40 76-27 58Q-24 68-19 66Q-14 74-25 90Z" fill="#e0893a"/><path d="M-25 88Q-32 78-26 68Q-23 74-20 72Q-18 80-25 88Z" fill="#f1c85c"/></g></g>'
  };
  const WRAP = '<g fill="none" stroke="var(--pixel)" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">';
  function anchors(stage) {
    const body = BODY[stage] || BODY.adult;
    return {
      hat: 'translate(' + body.w / 2 + ' 0) scale(' + (body.w / BODY.adult.w).toFixed(3) + ')',
      face: 'translate(' + body.w / 2 + ' ' + body.face + ')',
      held: 'translate(' + body.w / 2 + ' ' + body.face + ') scale(' + (body.w / BODY.adult.w).toFixed(3) + ')',
      prop: 'translate(' + (body.w + 16) + ' ' + (body.h + 6) + ')',
      hand: 'translate(-13 ' + (body.arm + 15) + ')'
    };
  }
  function place(transform, markup) {
    return markup ? '<g transform="' + transform + '">' + markup + '</g>' : '';
  }
  function paint(svg, key, markup) {
    svg.toggleAttribute('hidden', !markup);
    if (svg.dataset.form === key) return;
    svg.dataset.form = key;
    svg.innerHTML = markup ? WRAP + markup + '</g>' : '';
  }
  function render(pet, room, now = Date.now(), vibe = '') {
    const life = root.LittleDillLife;
    const variety = life.VARIETIES.find(item => item.id === pet.variety);
    room.dataset.shape = variety.shape;
    room.style.setProperty('--skin', variety.color); room.style.setProperty('--highlight', variety.light); room.style.setProperty('--shade', variety.dark);
    const stage = life.stage(pet, now);
    const elder = life.elder(pet, now), teen = life.teen(pet, now), look = elder || teen;
    const worn = WORN[vibe] || {}, at = anchors(stage);
    room.dataset.hat = worn.face === FACES.sunglasses ? 'sunglasses' : look?.hat || '';
    const readers = elder && HATS[look.hat] && worn.face !== FACES.sunglasses ? FACES.readers : '';
    const wornArt = (look ? place(HATS[look.hat] ? at.hat : at.face, HATS[look.hat] || FACES[look.hat]) : '') +
      place(at.face, readers + (worn.face || '')) + place(at.held, worn.held) + place(at.hand, worn.hand);
    const art = document.getElementById('elder-art');
    paint(art, (look?.id || '') + ':' + stage + ':' + (worn.face || worn.held || worn.hand ? vibe : ''), wornArt);
    art.style.color = look?.accent || '';
    const prop = document.getElementById('prop-art');
    paint(prop, (look?.id || '') + ':' + stage, look ? place(at.prop, PROPS[look.prop]) : '');
    prop.style.color = look?.accent || '';
    paint(document.getElementById('scene-art'), SCENES[vibe] ? vibe : '', SCENES[vibe] || '');
  }
  root.LittleDillArt = { render };
})(globalThis);
