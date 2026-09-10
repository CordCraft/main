(() => {
  'use strict';

  const $ = (id) => document.getElementById(id);
  const statusDot = $('statusDot');
  const statusText = $('statusText');
  const nowPlaying = $('nowPlaying');
  const led = $('led');
  const sheet = $('sheet');
  const backdrop = $('sheetBackdrop');
  const hostInput = $('hostInput');
  const codeInput = $('codeInput');
  const pairBox = $('pairBox');
  const errorText = $('errorText');
  const deviceList = $('deviceList');
  const toast = $('toast');

  let state = {};
  let toastTimer = null;

  // ---------- helpers ----------
  async function api(path, body) {
    const res = await fetch('/api/' + path, {
      method: body === undefined ? 'GET' : 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const data = await res.json().catch(() => ({ ok: false, error: 'Bad response from server' }));
    if (!res.ok || data.ok === false) throw new Error(data.error || 'Request failed');
    return data;
  }

  function showToast(msg) {
    toast.textContent = msg;
    toast.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { toast.hidden = true; }, 2200);
  }

  function buzz() {
    if (navigator.vibrate) navigator.vibrate(10);
  }

  function prettyApp(pkg) {
    if (!pkg) return '';
    const known = {
      'com.netflix.ninja': 'Netflix',
      'com.google.android.youtube.tv': 'YouTube',
      'com.amazon.amazonvideo.livingroom': 'Prime Video',
      'com.google.android.apps.tv.launcherx': 'Home',
      'com.google.android.tvlauncher': 'Home',
      'com.android.tv.settings': 'Settings',
    };
    return known[pkg] || pkg.split('.').pop();
  }

  // ---------- state / status ----------
  function render() {
    statusDot.className = 'dot';
    if (state.connected) {
      statusDot.classList.add('on');
      statusText.textContent = 'Connected' + (state.host ? ' · ' + state.host : '');
    } else if (state.pairing) {
      statusDot.classList.add('busy');
      statusText.textContent = 'Enter code from TV';
    } else if (state.connecting) {
      statusDot.classList.add('busy');
      statusText.textContent = 'Connecting…';
    } else if (state.lastError) {
      statusDot.classList.add('err');
      statusText.textContent = 'Not connected';
    } else {
      statusText.textContent = state.host ? 'Disconnected' : 'Tap to connect';
    }

    led.classList.toggle('on', state.powered === true);

    const parts = [];
    if (state.currentApp) parts.push(prettyApp(state.currentApp));
    if (state.volume) parts.push(state.volume.muted ? 'Muted' : 'Vol ' + state.volume.level);
    nowPlaying.textContent = parts.join(' · ');

    pairBox.hidden = !state.pairing;
    errorText.textContent = state.lastError || '';
    if (state.host && !hostInput.value) hostInput.value = state.host;
    if (state.pairing && !sheet.hidden) codeInput.focus();
    if (state.connected && !sheet.hidden && sheetOpenedForPairing) closeSheet();
  }

  let sheetOpenedForPairing = false;

  function listen() {
    const es = new EventSource('/api/events');
    es.onmessage = (e) => {
      state = JSON.parse(e.data);
      render();
    };
    es.onerror = () => {
      // The browser reconnects on its own; just reflect that we lost the server.
      statusDot.className = 'dot err';
      statusText.textContent = 'Server unreachable';
    };
  }

  // ---------- sending keys ----------
  async function sendKey(key) {
    if (!state.connected) {
      openSheet();
      return;
    }
    buzz();
    try {
      await api('key', { key });
    } catch (err) {
      showToast(err.message);
    }
  }

  async function sendApp(link) {
    if (!state.connected) { openSheet(); return; }
    buzz();
    try {
      await api('app', { link });
    } catch (err) {
      showToast(err.message);
    }
  }

  // Tap sends once. Holding a key marked data-repeat keeps sending, like a real remote.
  function bindKeys() {
    document.querySelectorAll('.key').forEach((btn) => {
      const key = btn.dataset.key;
      const app = btn.dataset.app;
      const repeats = btn.hasAttribute('data-repeat');
      let timer = null;
      let fired = false;

      const fire = () => {
        fired = true;
        if (app) sendApp(app); else sendKey(key);
      };

      const stop = () => {
        clearInterval(timer);
        timer = null;
        btn.classList.remove('pressed');
      };

      btn.addEventListener('pointerdown', (e) => {
        e.preventDefault();
        btn.setPointerCapture(e.pointerId);
        btn.classList.add('pressed');
        fired = false;
        fire();
        if (repeats) {
          timer = setInterval(fire, 180);
        }
      });
      ['pointerup', 'pointercancel', 'pointerleave'].forEach((ev) => btn.addEventListener(ev, stop));
      btn.addEventListener('contextmenu', (e) => e.preventDefault());
      btn.addEventListener('click', (e) => {
        // Pointer events already handled it; keep keyboard "Enter" working.
        if (e.detail !== 0 || fired) { fired = false; return; }
        fire();
      });
    });
  }

  // Physical keyboard shortcuts when using a laptop browser.
  const keyboardMap = {
    ArrowUp: 'DPAD_UP', ArrowDown: 'DPAD_DOWN', ArrowLeft: 'DPAD_LEFT', ArrowRight: 'DPAD_RIGHT',
    Enter: 'DPAD_CENTER', Backspace: 'BACK', Escape: 'BACK', h: 'HOME', m: 'MUTE',
    '+': 'VOLUME_UP', '=': 'VOLUME_UP', '-': 'VOLUME_DOWN', ' ': 'MEDIA_PLAY_PAUSE',
    PageUp: 'CHANNEL_UP', PageDown: 'CHANNEL_DOWN',
  };
  document.addEventListener('keydown', (e) => {
    if (!sheet.hidden || e.target.tagName === 'INPUT') return;
    let key = keyboardMap[e.key];
    if (!key && /^[0-9]$/.test(e.key)) key = e.key;
    if (!key) return;
    e.preventDefault();
    sendKey(key);
  });

  // ---------- connection sheet ----------
  function openSheet() {
    sheet.hidden = false;
    backdrop.hidden = false;
    sheetOpenedForPairing = !state.connected;
    if (!hostInput.value && state.host) hostInput.value = state.host;
    if (!state.pairing) hostInput.focus();
  }
  function closeSheet() {
    sheet.hidden = true;
    backdrop.hidden = true;
  }

  $('statusBtn').addEventListener('click', openSheet);
  $('closeSheet').addEventListener('click', closeSheet);
  backdrop.addEventListener('click', closeSheet);

  $('scanBtn').addEventListener('click', async () => {
    const btn = $('scanBtn');
    btn.disabled = true;
    btn.textContent = 'Scanning…';
    deviceList.innerHTML = '';
    try {
      const { devices } = await api('discover');
      if (!devices.length) {
        deviceList.innerHTML = '<li>No TVs found. Make sure the TV is on, then type its IP address.</li>';
      }
      devices.forEach((d) => {
        const li = document.createElement('li');
        li.innerHTML = `<strong>${d.name}</strong><small>${d.host}</small>`;
        li.addEventListener('click', () => { hostInput.value = d.host; });
        deviceList.appendChild(li);
      });
    } catch (err) {
      errorText.textContent = err.message;
    } finally {
      btn.disabled = false;
      btn.textContent = 'Scan';
    }
  });

  $('connectBtn').addEventListener('click', async () => {
    const host = hostInput.value.trim();
    if (!host) { errorText.textContent = 'Enter the TV IP address first.'; return; }
    errorText.textContent = '';
    codeInput.value = '';
    const btn = $('connectBtn');
    btn.disabled = true;
    btn.textContent = 'Connecting…';
    try {
      // Long-running: the server resolves once paired/connected, or on failure.
      api('connect', { host }).catch((err) => { errorText.textContent = err.message; });
    } finally {
      setTimeout(() => { btn.disabled = false; btn.textContent = 'Connect'; }, 1500);
    }
  });

  $('pairBtn').addEventListener('click', async () => {
    const code = codeInput.value.trim();
    try {
      await api('pair', { code });
      showToast('Pairing…');
    } catch (err) {
      errorText.textContent = err.message;
    }
  });
  codeInput.addEventListener('keydown', (e) => { if (e.key === 'Enter') $('pairBtn').click(); });
  hostInput.addEventListener('keydown', (e) => { if (e.key === 'Enter') $('connectBtn').click(); });

  $('forgetBtn').addEventListener('click', async () => {
    if (!confirm('Forget this TV? You will need to pair again.')) return;
    try {
      await api('forget', {});
      hostInput.value = '';
      deviceList.innerHTML = '';
      showToast('TV forgotten');
    } catch (err) {
      errorText.textContent = err.message;
    }
  });

  // ---------- boot ----------
  bindKeys();
  listen();
  api('status').then((d) => { state = d.state; render(); if (!state.host) openSheet(); }).catch(() => {});
})();
