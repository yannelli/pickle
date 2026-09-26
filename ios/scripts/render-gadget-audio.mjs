import { createHash } from 'node:crypto';
import { readFile, mkdir, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { tmpdir } from 'node:os';
import { resolve, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ios = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const [webDirectory, chrome] = process.argv.slice(2);
if (!webDirectory || !chrome) throw new Error('Usage: node ios/scripts/render-gadget-audio.mjs <arena-web directory> <Chrome executable>');
const source = await readFile(resolve(webDirectory, 'arena.js'), 'utf8');
const core = await readFile(resolve(webDirectory, 'arena-core.mjs'), 'utf8');
function extract(text, start, end) {
  const a = text.indexOf(start), b = text.indexOf(end, a);
  if (a < 0 || b < 0) throw new Error(`Web audio source missing: ${start}`);
  return text.slice(a, b);
}
const synthesis = extract(source, 'function audioOutput()', 'const sounds =');
const strokes = extract(source, 'const gadgetStrokes =', 'function drainSound');
const periods = extract(core, 'export const GADGET_STROKE_SECONDS', 'export function scheduleStrokes').replace('export ', '');
const sampleRate = 48000, strokeCount = 8;
const html = `<!doctype html><script>
let seed = 0xD111;
Math.random = () => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 4294967296; };
let audio, audioOut, noiseBuffer;
${synthesis}
${strokes}
${periods}
(async () => {
  const result = {};
  for (const [kind, period] of Object.entries(GADGET_STROKE_SECONDS)) {
    const frames = Math.round(period * ${strokeCount} * ${sampleRate});
    audio = new OfflineAudioContext(1, frames, ${sampleRate}); audioOut = null; noiseBuffer = null;
    audioOutput();
    for (let n = 0; n < ${strokeCount}; n++) gadgetStrokes[kind](.01 + n * period);
    const samples = (await audio.startRendering()).getChannelData(0);
    const pcm = new Uint8Array(frames * 2), view = new DataView(pcm.buffer);
    let peak = 0, energy = 0;
    for (let n = 0; n < frames; n++) {
      peak = Math.max(peak, Math.abs(samples[n])); energy += samples[n] ** 2;
      view.setInt16(n * 2, Math.round(Math.max(-1, Math.min(1, samples[n])) * 32767), true);
    }
    let binary = '';
    for (let n = 0; n < pcm.length; n += 8192) binary += String.fromCharCode(...pcm.subarray(n, n + 8192));
    result[kind] = { period, frames, peak, rms: Math.sqrt(energy / frames), pcm: btoa(binary) };
  }
  await fetch('/result', { method: 'POST', body: JSON.stringify(result) });
})().catch(error => fetch('/result', { method: 'POST', body: JSON.stringify({ error: String(error) }) }));
</script>`;
let accept, reject;
const rendered = new Promise((yes, no) => { accept = yes; reject = no; });
const server = createServer(async (request, response) => {
  if (request.method === 'POST' && request.url === '/result') {
    let body = '';
    for await (const chunk of request) body += chunk;
    response.end('ok');
    try { accept(JSON.parse(body)); } catch (error) { reject(error); }
  } else { response.setHeader('Content-Type', 'text/html'); response.end(html); }
});
await new Promise(ready => server.listen(0, '127.0.0.1', ready));
const profile = await mkdtemp(join(tmpdir(), 'dill-audio-render-'));
const processHandle = spawn(chrome, ['--headless', '--disable-gpu', '--no-first-run', `--user-data-dir=${profile}`, `http://127.0.0.1:${server.address().port}`], { stdio: 'ignore' });
processHandle.on('error', reject);
const timeout = setTimeout(() => reject(new Error('Web audio render timed out')), 30000);
try {
  const clips = await rendered;
  if (clips.error) throw new Error(clips.error);
  const output = join(ios, 'LittleDill', 'Audio');
  await mkdir(output, { recursive: true });
  const sha256 = data => createHash('sha256').update(data).digest('hex');
  const manifest = { sampleRate, strokeCount, webSourceSHA256: sha256(source), webCoreSHA256: sha256(core), clips: {} };
  for (const [kind, clip] of Object.entries(clips)) {
    const pcm = Buffer.from(clip.pcm, 'base64'), header = Buffer.alloc(44);
    header.write('RIFF'); header.writeUInt32LE(36 + pcm.length, 4); header.write('WAVEfmt ', 8);
    header.writeUInt32LE(16, 16); header.writeUInt16LE(1, 20); header.writeUInt16LE(1, 22);
    header.writeUInt32LE(sampleRate, 24); header.writeUInt32LE(sampleRate * 2, 28);
    header.writeUInt16LE(2, 32); header.writeUInt16LE(16, 34); header.write('data', 36); header.writeUInt32LE(pcm.length, 40);
    const wav = Buffer.concat([header, pcm]);
    await writeFile(join(output, `arena-${kind}.wav`), wav);
    const { pcm: ignored, ...metrics } = clip;
    manifest.clips[kind] = { ...metrics, sha256: sha256(wav) };
  }
  await writeFile(join(output, 'gadget-audio.json'), JSON.stringify(manifest, null, 2) + '\n');
  console.log(JSON.stringify(manifest, null, 2));
} finally {
  clearTimeout(timeout);
  processHandle.kill();
  await new Promise(done => processHandle.exitCode !== null ? done() : processHandle.once('exit', done));
  server.closeAllConnections(); server.close();
  await rm(profile, { recursive: true, force: true });
}
