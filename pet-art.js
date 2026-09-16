(function (root) {
  'use strict';
  const HATS = {
    cap: '<path d="M8-3Q10-21 33-19Q51-17 54-3Z" fill="currentColor"/><path d="M6-2H64"/>',
    headphones: '<path d="M-3 23V3Q30-27 65 3V23" stroke-width="5"/><rect x="-8" y="13" width="10" height="20" rx="4" fill="currentColor"/><rect x="60" y="13" width="10" height="20" rx="4" fill="currentColor"/>',
    wizard: '<path d="M8-4 30-39 53-4Z" fill="currentColor"/><path d="M1-3H62" stroke-width="5"/><path d="m31-23 1 4 4 1-4 1-1 4-1-4-4-1 4-1Z" fill="#dce7ac"/>',
    sunhat: '<path d="M10-6Q11-26 32-26Q50-25 54-6Z" fill="currentColor"/><ellipse cx="32" cy="-3" rx="39" ry="7" fill="currentColor"/>',
    turban: '<path d="M0 0Q-2-30 30-29Q65-30 64 0Z" fill="currentColor"/><path d="M5-9 53-25M13-23 54-6" stroke="#dce7ac"/><circle cx="32" cy="-4" r="5" fill="#dce7ac"/>',
    afro: '<path d="M-5 8Q-18-4-5-14Q-9-29 7-28Q14-41 29-33Q47-42 54-27Q71-27 68-11Q82 0 65 10Q33-2-5 8Z" fill="currentColor"/>',
    captain: '<path d="M8-5 1-25Q33-37 63-25L56-5Z" fill="#dce7ac"/><path d="M7-3H59" stroke-width="7"/><path d="M32-25V-10M26-20H38M24-15Q32-5 40-15"/>',
    mortarboard: '<path d="m-8-14 40-17 39 17-39 16Z" fill="currentColor"/><path d="M60-9V14"/><circle cx="60" cy="16" r="3" fill="currentColor"/>',
    crown: '<path d="M7-2 1-26 21-14 32-33 43-14 64-26 58-2Z" fill="currentColor"/><path d="M14-8H51" stroke="#dce7ac"/>',
    cowboy: '<path d="M8-10 17-32Q31-20 47-32L55-10Q77-21 69-5Q32 8-5-5Q-15-21 8-10Z" fill="currentColor"/>',
    bonnet: '<path d="M-2 12Q-14-36 31-35Q77-36 65 12L56-5Q32-20 7-5Z" fill="currentColor"/><path d="M2 5 9 30M62 5 55 30"/><path d="m24-22 7-7 8 7-8 6Z" fill="#dce7ac"/>',
    antenna: '<path d="M8-1Q7-28 31-28Q57-28 57-1Z" fill="currentColor"/><path d="M31-28V-38"/><circle cx="31" cy="-40" r="5" fill="#dce7ac"/>',
    headband: '<path d="M1 3Q32-7 62 3" stroke-width="9"/><path d="M60 2 78 12 67 17Z" fill="currentColor"/>',
    pirate: '<path d="M-4-3 10-31Q31-19 53-31L68-3Z" fill="currentColor"/><circle cx="32" cy="-15" r="5" fill="#dce7ac"/><path d="m25-8 14 4m-14 0 14-4" stroke="#dce7ac"/>',
    deerstalker: '<path d="M4-2Q3-27 31-28Q61-27 60-2Z" fill="currentColor"/><path d="M-9-1H72M31-26V-3M10-13H55"/>',
    sunglasses: '<g transform="translate(0 10)"><path d="M-1 26H64" stroke-width="4"/><path d="M2 23H25V36H7ZM38 23H62L57 36H38Z" fill="currentColor"/></g>',
    witch: '<path d="m8-5 25-35 2 14 21 21Z" fill="currentColor"/><ellipse cx="32" cy="-3" rx="37" ry="5" fill="currentColor"/>',
    top: '<path d="M12-5V-36H51V-5Z" fill="currentColor"/><path d="M12-13H51" stroke="#dce7ac" stroke-width="6"/><path d="M2-3H62" stroke-width="6"/>',
    mushroom: '<path d="M-4 0Q1-38 31-38Q62-38 69 0Z" fill="currentColor"/><g fill="#dce7ac"><circle cx="19" cy="-19" r="5"/><circle cx="43" cy="-23" r="6"/><circle cx="53" cy="-7" r="4"/></g>',
    chef: '<path d="M10-4V-17Q-6-34 13-35Q23-51 35-36Q57-47 60-28Q72-19 54-14V-4Z" fill="#e6ecc5"/>',
    helmet: '<path d="M3 9V-9Q32-37 61-9V9Z" fill="currentColor"/><path d="M5 1H58M32-21V9" stroke="#dce7ac" stroke-width="4"/>',
    rainhat: '<path d="M9-7Q10-28 32-28Q53-28 54-7L65 1H-3Z" fill="currentColor"/>',
    mohawk: '<path d="m18-4 2-21 6 4 4-23 7 20 8-9 2 29Z" fill="currentColor"/>',
    vampire: '<path d="M2 19-9 4 0 62 15 73M61 19 73 4 65 62 51 73" fill="currentColor"/><path d="m13-7 19 14 17-14" fill="currentColor"/>',
    halo: '<ellipse cx="32" cy="-22" rx="27" ry="7" stroke-width="5"/><path d="M-12 40Q-28 12-18 66L-1 59M76 40Q91 12 83 66L66 59" fill="#e6ecc5"/>',
    beret: '<ellipse cx="31" cy="-13" rx="34" ry="14" fill="currentColor"/><path d="M34-25 38-33" stroke-width="4"/>',
    nerdglasses: '<circle cx="13.5" cy="33.5" r="7.5" fill="#dce7ac" fill-opacity=".35"/><circle cx="38.5" cy="33.5" r="7.5" fill="#dce7ac" fill-opacity=".35"/><path d="M21 33H31M-3 31 6 33M46 33 55 31"/><rect x="23.5" y="30" width="5" height="6" fill="#e6ecc5" stroke="none"/>',
    fringe: '<path d="M0 8Q-5-26 30-27Q62-27 63 2Q56-12 40-9L54 34Q42 8 24-1Q8-1 0 8Z" fill="currentColor"/>',
    backcap: '<path d="M8-3Q10-21 33-19Q51-17 54-3Z" fill="currentColor"/><path d="M-16-3H56" stroke-width="4"/><circle cx="33" cy="-19" r="2.5" fill="#dce7ac"/>',
    beanie: '<path d="M6 2Q4-24 31-25Q58-24 56 2Z" fill="currentColor"/><path d="M3-1H59" stroke-width="7"/><circle cx="31" cy="-27" r="4" fill="#dce7ac"/>',
    headset: '<path d="M-3 23V3Q30-27 65 3V23" stroke-width="5"/><rect x="-8" y="13" width="10" height="20" rx="4" fill="currentColor"/><rect x="60" y="13" width="10" height="20" rx="4" fill="currentColor"/><path d="M-3 30Q-3 45 12 46"/><circle cx="14" cy="46" r="3" fill="currentColor"/>',
    shako: '<path d="M12-4V-34H51V-4Z" fill="currentColor"/><path d="M8-4H55" stroke-width="5"/><path d="M31-34V-44" stroke-width="4"/><circle cx="31" cy="-47" r="4" fill="#dce7ac"/><path d="M20-20H43" stroke="#dce7ac"/>',
    collar: '<path d="M4 61 13 49 24 65ZM58 61 49 49 38 65Z" fill="#e6ecc5"/>'
  };
  const PROPS = {
    cane: '<path d="M76 100V57Q76 44 86 52" stroke-width="5"/>',
    record: '<circle cx="83" cy="65" r="17" fill="currentColor"/><circle cx="83" cy="65" r="7" fill="#dce7ac"/><circle cx="83" cy="65" r="2"/>',
    scroll: '<path d="M69 47H92V85H69Z" fill="#dce7ac"/><path d="M72 55H87M72 62H87M72 69H84"/>',
    rake: '<path d="M78 100V40M65 42H91M65 33V42M73 33V42M82 33V42M91 33V42"/>',
    bowl: '<path d="M63 63H100Q96 87 82 87Q66 87 63 63Z" fill="currentColor"/><path d="M76 55Q70 50 76 45M87 55Q81 50 87 45"/>',
    anchor: '<path d="M83 50V88M70 66H96M65 76Q81 103 101 76M65 76V86M101 76V86"/><circle cx="83" cy="45" r="5"/>',
    book: '<path d="M62 52Q75 48 81 55Q91 48 102 52V85Q90 81 81 88Q72 81 62 85Z" fill="#dce7ac"/><path d="M81 55V88"/>',
    mug: '<path d="M67 57H89V82H67Z" fill="#dce7ac"/><path d="M89 60Q109 58 94 75H89M74 51Q70 45 76 41"/>',
    planet: '<circle cx="81" cy="65" r="15" fill="#dce7ac"/><ellipse cx="81" cy="65" rx="26" ry="6" transform="rotate(-25 81 65)"/>',
    flower: '<path d="M79 93V60M79 83 69 74"/><g fill="currentColor"><circle cx="79" cy="48" r="7"/><circle cx="69" cy="58" r="7"/><circle cx="90" cy="58" r="7"/><circle cx="79" cy="68" r="7"/></g><circle cx="79" cy="58" r="7" fill="#dce7ac"/>',
    lens: '<circle cx="85" cy="53" r="14" fill="#dce7ac" fill-opacity=".5"/><path d="M76 64 65 83" stroke-width="6"/>',
    phone: '<rect x="71" y="47" width="21" height="38" rx="4" fill="currentColor"/><rect x="75" y="52" width="13" height="23" fill="#dce7ac"/><circle cx="81" cy="80" r="1" fill="#dce7ac"/>',
    coin: '<circle cx="82" cy="65" r="16" fill="#dce7ac"/><path d="M82 54V77M90 57H78Q71 65 82 65Q94 65 85 74H73"/>',
    shield: '<path d="m64 53 17-6 18 6v18q-2 14-18 20-16-6-17-20Z" fill="#dce7ac"/><path d="M81 54V82M70 63H92"/>',
    umbrella: '<path d="M81 100V38M58 46Q80 7 105 46Z" fill="currentColor"/><path d="M81 100Q71 110 69 98"/>',
    wand: '<path d="m66 91 26-41" stroke-width="4"/><path d="m95 33 3 8 9 1-7 6 2 9-8-5-8 5 2-9-7-6 10-1Z" fill="#dce7ac"/>',
    palette: '<path d="M66 50Q98 37 102 64Q103 89 81 87L79 74Q54 73 66 50Z" fill="#dce7ac"/><g fill="currentColor"><circle cx="76" cy="54" r="3"/><circle cx="91" cy="52" r="3"/><circle cx="96" cy="66" r="3"/></g><path d="m70 99 18-36"/>',
    scepter: '<path d="M81 100V45" stroke-width="4"/><path d="m71 37 10-11 11 11-11 11Z" fill="#dce7ac"/>',
    clock: '<circle cx="82" cy="66" r="19" fill="#dce7ac"/><path d="M82 52V66L91 73M77 41H88"/>',
    infinity: '<path d="M82 64C53 27 52 98 82 64C112 27 113 98 82 64Z" stroke-width="5"/>',
    journal: '<rect x="68" y="50" width="22" height="30" rx="2" fill="currentColor"/><path d="M79 70 73 64Q70 60 74 58Q77 57 79 60Q81 57 84 58Q88 60 85 64Z" fill="#dce7ac" stroke="none"/>',
    ball: '<circle cx="83" cy="70" r="15" fill="currentColor"/><path d="M68 70H98M83 55V85M72 60Q83 70 72 80M94 60Q83 70 94 80" stroke="#dce7ac"/>',
    skateboard: '<rect x="74" y="30" width="12" height="62" rx="6" fill="currentColor"/><circle cx="90" cy="44" r="3.5" fill="#dce7ac"/><circle cx="90" cy="78" r="3.5" fill="#dce7ac"/>',
    controller: '<path d="M66 60Q66 50 76 50H92Q102 50 102 60L104 74Q100 82 94 76L90 70H78L74 76Q68 82 64 74Z" fill="currentColor"/><path d="M73 60H79M76 57V63" stroke="#dce7ac"/><circle cx="91" cy="58" r="2" fill="#dce7ac"/><circle cx="96" cy="63" r="2" fill="#dce7ac"/>',
    masks: '<path d="M64 50Q79 44 80 60Q79 76 72 76Q64 76 64 50Z" fill="#dce7ac"/><path d="M68 58h4M76 58h1M68 68q4 4 8 0"/><path d="M84 50Q99 44 100 60Q99 76 92 76Q84 76 84 50Z" fill="currentColor"/><path d="M88 58h4M96 58h1M88 70q4-4 8 0" stroke="#dce7ac"/>',
    trumpet: '<path d="M64 62H88" stroke-width="4"/><path d="M88 54 104 48V76L88 70Z" fill="currentColor"/><path d="M70 62V56M76 62V56M82 62V56"/><circle cx="64" cy="62" r="3"/>'
  };
  // A content pickle rotates through vibes. Worn items ride on the body; scenery sits on the ground beside it.
  const WORN = {
    shades: { face: HATS.sunglasses },
    lounge: { face: HATS.sunglasses },
    book: { face: '<path d="M8 60Q20 56 31 63Q42 56 54 60V80Q42 76 31 83Q20 76 8 80Z" fill="#dce7ac"/><path d="M31 63V83M14 66h10M14 71h10M38 66h10M38 71h10" stroke="#8b754a" stroke-width="1.5"/>' },
    fire: { arm: '<path d="M-6 66-30 54" stroke="#7a5a3a"/><rect x="-35" y="49" width="8" height="8" fill="#fffde9" stroke="#263f29" stroke-width="1.5"/>' }
  };
  const SCENES = {
    lounge: '<g stroke="#c9a53a"><circle cx="-26" cy="2" r="9" fill="#e6c95a"/><path d="M-26-14V-10M-26 12V16M-42 2H-38M-14 2H-10M-37-9 -34-6M-18 10 -15 13M-37 13 -34 10M-18-6 -15-9"/></g><path d="M-16 100H84" stroke="#d9a066" stroke-width="7"/><path d="M-12 100H80" stroke="#e6ecc5" stroke-width="2" stroke-dasharray="6 6"/><rect x="70" y="80" width="12" height="18" fill="#dce7ac"/><path d="M76 80V66"/><path d="M64 66H88L76 58Z" fill="#c96a6a"/>',
    fire: '<g stroke="none"><path d="M-38 100 -12 92M-38 92 -12 100" stroke="#7a5a3a" stroke-width="5" stroke-linecap="round"/><g class="flame"><path d="M-25 90Q-40 76-27 58Q-24 68-19 66Q-14 74-25 90Z" fill="#e0893a"/><path d="M-25 88Q-32 78-26 68Q-23 74-20 72Q-18 80-25 88Z" fill="#f1c85c"/></g></g>'
  };
  // Worn art is authored for the adult face (12, 34) and arm (top 53); smaller bodies shift it.
  const FACE_OFFSET = { baby: [-7, -19], young: [-4, -9], teen: [-2, -4] };
  const ARM_OFFSET = { baby: -24, young: -11, teen: -5 };
  const WRAP = '<g fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">';
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
    room.dataset.hat = look?.hat || '';
    const worn = WORN[vibe] || {}, [fx, fy] = FACE_OFFSET[stage] || [0, 0], ay = ARM_OFFSET[stage] || 0;
    const wornArt = (look ? HATS[look.hat] + PROPS[look.prop] : '') +
      (worn.face ? '<g transform="translate(' + fx + ' ' + fy + ')">' + worn.face + '</g>' : '') +
      (worn.arm ? '<g transform="translate(0 ' + ay + ')">' + worn.arm + '</g>' : '');
    const art = document.getElementById('elder-art');
    paint(art, (look?.id || '') + ':' + (worn.face || worn.arm ? vibe + ':' + stage : ''), wornArt);
    art.style.color = look?.accent || '';
    paint(document.getElementById('scene-art'), SCENES[vibe] ? vibe : '', SCENES[vibe] || '');
  }
  root.LittleDillArt = { render };
})(globalThis);
