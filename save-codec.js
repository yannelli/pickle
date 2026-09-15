(function (root) {
  'use strict';

  const MAX_FILE_BYTES = 16384;
  const FORMAT = 'little-dill-save';
  const encoder = new TextEncoder();
  const decoder = new TextDecoder('utf-8', { fatal: true });
  const context = encoder.encode(FORMAT + '/1/AES-256-GCM');
  // This format key travels with the client so backups work across devices without
  // accounts or passwords. It deters casual edits, but is not a security secret.
  // Keep it stable for v1 files; a future key change needs a new format version.
  const formatKey = new Uint8Array([185, 74, 216, 57, 134, 211, 99, 244, 68, 143, 31, 167, 29, 200, 116, 5,
    162, 45, 228, 83, 174, 149, 63, 233, 120, 20, 98, 203, 75, 186, 47, 156]);
  const stats = ['fullness', 'happiness', 'energy', 'hygiene'];

  function validateState(value) {
    if (value?.version === 2) {
      const life = root.LittleDillLife || (typeof require === 'function' ? require('./pet-life.js') : null);
      if (!life) throw new Error('Reload little dill to open this newer save.');
      return life.validate(value);
    }
    if (!value || value.version !== 1 ||
        !stats.every(key => Number.isFinite(value[key]) && value[key] >= 0 && value[key] <= 100) ||
        !Number.isSafeInteger(value.ageTicks) || value.ageTicks < 0 || value.ageTicks > 1e9 ||
        !Number.isSafeInteger(value.neglect) || value.neglect < 0 || value.neglect > 60 ||
        !Number.isSafeInteger(value.updatedAt) || value.updatedAt < 0 || value.updatedAt > 8640000000000000 ||
        !['sleeping', 'sick', 'dead'].every(key => typeof value[key] === 'boolean') ||
        (value.dead && value.sleeping)) {
      throw new Error('This file contains invalid pickle progress.');
    }
    return { version: 1, ...Object.fromEntries(stats.map(key => [key, value[key]])),
      ageTicks: value.ageTicks, neglect: value.neglect, sleeping: value.sleeping,
      sick: value.sick, dead: value.dead, updatedAt: value.updatedAt };
  }

  function available() { return !!root.crypto?.subtle && typeof root.crypto.getRandomValues === 'function'; }
  function requireCrypto() {
    if (!available()) throw new Error('Encrypted backups need a secure browser connection. Open this site over HTTPS or localhost; local autosave still works.');
  }
  function base64(bytes) { return btoa(String.fromCharCode(...bytes)); }
  function bytes(value, size) {
    if (typeof value !== 'string' || !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(value)) {
      throw new Error('This save file is damaged or incomplete.');
    }
    const result = Uint8Array.from(atob(value), char => char.charCodeAt(0));
    if ((size && result.length !== size) || (!size && (result.length < 17 || result.length > 4096))) {
      throw new Error('This save file is damaged or incomplete.');
    }
    return result;
  }
  const importKey = () => root.crypto.subtle.importKey('raw', formatKey, 'AES-GCM', false, ['encrypt', 'decrypt']);

  async function encode(state) {
    requireCrypto();
    const pet = validateState(state);
    const iv = root.crypto.getRandomValues(new Uint8Array(12));
    const key = await importKey();
    const payload = encoder.encode(JSON.stringify({ version: 1, savedAt: Date.now(), pet }));
    const encrypted = await root.crypto.subtle.encrypt({ name: 'AES-GCM', iv, additionalData: context, tagLength: 128 }, key, payload);
    return JSON.stringify({ format: FORMAT, version: 1, cipher: 'AES-256-GCM', iv: base64(iv), data: base64(new Uint8Array(encrypted)) });
  }

  async function decode(raw) {
    requireCrypto();
    if (typeof raw !== 'string' || raw.length > MAX_FILE_BYTES || encoder.encode(raw).length > MAX_FILE_BYTES) {
      throw new Error('This file is too large to be a little dill. save. Choose a .dill backup under 16 KB.');
    }
    let envelope;
    try { envelope = JSON.parse(raw); }
    catch { throw new Error('This is not a readable .dill save file.'); }
    if (!envelope || envelope.format !== FORMAT || envelope.version !== 1 || envelope.cipher !== 'AES-256-GCM' ||
        Object.keys(envelope).some(key => !['format', 'version', 'cipher', 'iv', 'data'].includes(key))) {
      throw new Error('This save format is not supported. Choose an encrypted .dill backup from little dill.');
    }
    const iv = bytes(envelope.iv, 12);
    const encrypted = bytes(envelope.data);
    const key = await importKey();
    let payload;
    try {
      const decrypted = await root.crypto.subtle.decrypt({ name: 'AES-GCM', iv, additionalData: context, tagLength: 128 }, key, encrypted);
      payload = JSON.parse(decoder.decode(decrypted));
    } catch {
      throw new Error('This save has been changed or damaged. Your current pickle is safe.');
    }
    if (!payload || payload.version !== 1 || !Number.isSafeInteger(payload.savedAt) || payload.savedAt < 0 || payload.savedAt > 8640000000000000) {
      throw new Error('This file contains invalid pickle progress.');
    }
    return { savedAt: payload.savedAt, pet: validateState(payload.pet) };
  }

  const api = Object.freeze({ encode, decode, validateState, available, MAX_FILE_BYTES });
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.LittleDillSaves = api;
})(globalThis);
