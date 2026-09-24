(function (root) {
  'use strict';
  function create(getPet) {
    const $ = id => document.getElementById(id);
    const KEY = 'little-dill.reminders.v1';
    let enabled = false, available = false, busy = false, publicKey, registration, pending, status = '';
    try { enabled = localStorage.getItem(KEY) === 'on'; } catch { /* Reminders can still work this visit. */ }
    const persist = value => { enabled = value; try { localStorage.setItem(KEY, value ? 'on' : 'off'); } catch { /* Optional preference. */ } };
    function render() {
      $('reminder-toggle').textContent = enabled ? 'Turn reminders off' : 'Enable reminders';
      $('reminder-toggle').disabled = busy || (!enabled && (!available || getPet().phase !== 'living' || getPet().dead));
      $('reminder-test').hidden = !enabled || getPet().phase !== 'living' || getPet().dead;
      $('reminder-test').disabled = busy || !available;
      $('reminder-status').textContent = status || (getPet().phase !== 'living' ? 'Once your pickle hatches, you can choose a gentle reminder.' : 'Your pickle is happy with a daily check-in.');
    }
    async function request(method, subscription, extra = {}) {
      const pet = getPet();
      const response = await fetch('./api/reminders', { method, headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ subscription: subscription.toJSON(), dueAt: root.LittleDillLife.nextCareAt(pet),
          cycleAt: pet.lastCareAt, timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone, ...extra }), signal: AbortSignal.timeout(12000) });
      let result;
      try { result = await response.json(); } catch { throw new Error('Reminders are temporarily unavailable. Your pickle is still saved here.'); }
      if (!response.ok) throw new Error(result.error || 'The reminder could not be updated.');
      return result;
    }
    async function update() {
      if (!enabled || !registration || !available) return;
      try {
        const subscription = await registration.pushManager.getSubscription();
        if (!subscription || Notification.permission !== 'granted') { persist(false); status = 'Reminders need to be enabled again on this device.'; render(); return; }
        if (getPet().dead || getPet().phase !== 'living') {
          await request('DELETE', subscription); status = 'Reminders are resting until your next pickle is ready.';
        } else {
          const result = await request('PUT', subscription);
          status = result.dueAt ? 'On · next gentle nudge ' + new Date(result.dueAt).toLocaleString([], { weekday: 'short', hour: 'numeric', minute: '2-digit' }) + '.' : 'On · no more nudges until your next care visit.';
        }
      } catch (error) { status = navigator.onLine === false ? 'Your reminder will update when you’re back online.' : error.message; }
      render();
    }
    function sync() {
      render(); clearTimeout(pending);
      if (enabled) pending = setTimeout(update, 1200);
    }
    async function init() {
      render();
      if (!root.isSecureContext || !('serviceWorker' in navigator) || !('PushManager' in root) || !('Notification' in root)) {
        const ios = /iPhone|iPad|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
        status = ios ? 'For reminders on iPhone or iPad, add little dill to your Home Screen and open it there.' : 'This browser does not support push reminders. Daily check-ins still work offline.';
        render(); return;
      }
      try {
        const response = await fetch('./api/reminders/config', { cache: 'no-store', signal: AbortSignal.timeout(10000) });
        if (!response.ok) throw new Error('Reminders aren’t available on this version yet. Your pickle doesn’t need them to thrive.');
        const config = await response.json();
        if (!/^[A-Za-z0-9_-]{87}$/.test(config.publicKey)) throw new Error('The reminder service is temporarily unavailable.');
        publicKey = Uint8Array.from(atob(config.publicKey.replace(/-/g, '+').replace(/_/g, '/')), char => char.charCodeAt(0));
        registration = await navigator.serviceWorker.ready;
        available = true;
        if (Notification.permission === 'denied') status = 'Notifications are blocked. You can change that in your browser or app settings.';
        else if (enabled) await update();
      } catch (error) { status = navigator.onLine === false ? 'Connect once to set up push reminders. Your pickle works offline.' : error.message; }
      render();
    }
    $('reminder-toggle').addEventListener('click', async () => {
      if (busy || (!enabled && (!available || !registration || getPet().phase !== 'living' || getPet().dead))) return;
      busy = true; render();
      try {
        if (enabled) {
          clearTimeout(pending);
          const currentRegistration = registration || await navigator.serviceWorker?.getRegistration();
          const subscription = await currentRegistration?.pushManager.getSubscription();
          if (subscription) {
            // Unsubscribe locally first, including when the API is offline.
            const snapshot = subscription.toJSON();
            await subscription.unsubscribe();
            await request('DELETE', { toJSON: () => snapshot }).catch(() => {});
          }
          persist(false);
          status = 'Off. Just you and your pickle, on your schedule.';
        } else {
          // Permission is requested only by this explicit button gesture.
          const permission = await Notification.requestPermission();
          if (permission !== 'granted') { status = 'No problem. Reminders stay off; daily check-ins still work.'; return; }
          let subscription = await registration.pushManager.getSubscription();
          const created = !subscription;
          subscription ||= await registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: publicKey });
          try { await request('PUT', subscription); }
          catch (error) { if (created) await subscription.unsubscribe(); throw error; }
          persist(true); await update();
        }
      } catch (error) { status = error.message || 'Reminders could not be enabled. Try again when you’re online.'; }
      finally { busy = false; render(); }
    });
    $('reminder-test').addEventListener('click', async () => {
      if (busy || !enabled) return;
      busy = true; render();
      try {
        const subscription = await registration.pushManager.getSubscription();
        if (!subscription) throw new Error('Enable reminders again before sending a test.');
        await request('PUT', subscription, { test: true });
        status = 'Test sent. Your device’s notification settings control how it appears.';
      } catch (error) { status = error.message; }
      finally { busy = false; render(); }
    });
    root.addEventListener('online', () => { if (!available) init(); else sync(); });
    document.addEventListener('visibilitychange', () => { if (!document.hidden) sync(); });
    return { init, sync };
  }
  root.LittleDillReminders = { create };
})(globalThis);
