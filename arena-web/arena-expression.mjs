export const EAT_OVERLAP = .6;
export const SMILES = Object.freeze({ dill: 'smile', gherkin: 'beam', garlic: 'smirk', butter: 'dimples', chili: 'grin', pepper: 'crooked' });
export const skinSmile = variety => SMILES[variety] || SMILES.dill;

export function pickupCue(previous, now) {
  const streak = previous && now - previous.at <= 1 ? Math.min(5, previous.streak + 1) : 0;
  if (previous && now - previous.at < .3 + Math.min(4, previous.streak) * .04) return null;
  const index = previous ? (previous.index + 1) % 4 : 0;
  return { at: now, index, streak, volume: .7 * (1 - streak * .08) };
}

export function drawSmile(ctx, variety, size) {
  ctx.save(); ctx.scale(size, size); ctx.lineWidth /= size; ctx.beginPath();
  switch (skinSmile(variety)) {
    case 'beam':
      ctx.moveTo(-.15, .19); ctx.quadraticCurveTo(0, .24, .15, .19);
      ctx.quadraticCurveTo(.14, .43, 0, .4); ctx.quadraticCurveTo(-.14, .43, -.15, .19);
      ctx.fill(); break;
    case 'smirk':
      ctx.moveTo(-.13, .26); ctx.quadraticCurveTo(.03, .35, .17, .16); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(.135, .15); ctx.lineTo(.19, .17); ctx.stroke(); break;
    case 'dimples':
      ctx.moveTo(-.18, .23); ctx.quadraticCurveTo(-.09, .38, 0, .23);
      ctx.quadraticCurveTo(.09, .38, .18, .23); ctx.stroke(); break;
    case 'grin':
      ctx.moveTo(-.19, .2); ctx.lineTo(.19, .2); ctx.quadraticCurveTo(.13, .43, 0, .4);
      ctx.quadraticCurveTo(-.13, .43, -.19, .2); ctx.fill();
      ctx.save(); ctx.fillStyle = '#F8F6ED'; ctx.fillRect(-.13, .205, .26, .055); ctx.restore(); break;
    case 'crooked':
      ctx.moveTo(-.16, .16); ctx.quadraticCurveTo(-.05, .39, .13, .28); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(-.195, .175); ctx.lineTo(-.135, .15); ctx.stroke(); break;
    default:
      ctx.moveTo(-.13, .19); ctx.quadraticCurveTo(0, .42, .13, .19); ctx.stroke();
  }
  ctx.restore();
}
