'use strict';

/*
 * Impex TV web remote.
 *
 * Run this on any computer (or Raspberry Pi) that sits on the same Wi-Fi as
 * the TV, then open http://<that-computer>:8123 on your iPhone or in any
 * browser. The page talks to this server, and this server talks to the TV
 * using the Android TV Remote protocol (the one built into Google TV).
 */

const path = require('path');
const os = require('os');
const express = require('express');
const { Bonjour } = require('bonjour-service');
const { TvController } = require('./lib/tv');

const PORT = Number(process.env.PORT) || 8123;

const app = express();
const tv = new TvController();

app.use(express.json());
// Works both from source (server.js next to public/) and from the single-file
// bundle in dist/ (one level down).
const fs = require('fs');
const PUBLIC_DIR = [path.join(__dirname, 'public'), path.join(__dirname, '..', 'public')].find((d) => fs.existsSync(d));
app.use(express.static(PUBLIC_DIR, { extensions: ['html'] }));

// Small helper so route handlers can throw and still return clean JSON.
const wrap = (fn) => (req, res) => {
  Promise.resolve()
    .then(() => fn(req, res))
    .catch((err) => res.status(400).json({ ok: false, error: err.message || String(err) }));
};

app.get('/api/status', (req, res) => {
  res.json({ ok: true, state: tv.snapshot() });
});

// Server-sent events so the page updates live when volume, power or app change.
app.get('/api/events', (req, res) => {
  res.set({
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    Connection: 'keep-alive',
  });
  res.flushHeaders();
  const send = (state) => res.write(`data: ${JSON.stringify(state)}\n\n`);
  send(tv.snapshot());
  tv.on('state', send);
  const keepAlive = setInterval(() => res.write(': ping\n\n'), 20000);
  req.on('close', () => {
    clearInterval(keepAlive);
    tv.off('state', send);
  });
});

// Find Android TV / Google TV sets on the network. mDNS first; if that finds
// nothing (or ?subnet=192.168.1 is given) probe every address in the /24 range
// for the remote port, which works even where multicast is blocked.
const net = require('net');

function probe(host, port, timeoutMs) {
  return new Promise((resolve) => {
    const sock = net.connect({ host, port });
    const done = (ok) => { sock.destroy(); resolve(ok); };
    sock.setTimeout(timeoutMs, () => done(false));
    sock.once('connect', () => done(true));
    sock.once('error', () => done(false));
  });
}

async function scanSubnet(base) {
  const hits = [];
  const hosts = [];
  for (let i = 1; i < 255; i++) hosts.push(`${base}.${i}`);
  const workers = Array.from({ length: 64 }, async () => {
    while (hosts.length) {
      const host = hosts.shift();
      if (await probe(host, 6466, 700)) hits.push({ name: 'Android TV', host, port: 6466 });
    }
  });
  await Promise.all(workers);
  return hits.sort((a, b) => Number(a.host.split('.')[3]) - Number(b.host.split('.')[3]));
}

function discoverMdns() {
  return new Promise((resolve) => {
    let bonjour;
    let browser;
    const found = new Map();
    let finished = false;
    const finish = () => {
      if (finished) return;
      finished = true;
      try { if (browser) browser.stop(); } catch (err) { /* ignore */ }
      try { if (bonjour) bonjour.destroy(); } catch (err) { /* ignore */ }
      resolve(Array.from(found.values()));
    };
    try {
      // Multicast may be unavailable (iSH on iOS); fall through to the port scan.
      bonjour = new Bonjour({}, (err) => { console.warn('mDNS unavailable:', err && err.message); finish(); });
      browser = bonjour.find({ type: 'androidtvremote2' }, (service) => {
        const ip = (service.addresses || []).find((a) => /^\d+\.\d+\.\d+\.\d+$/.test(a)) || service.host;
        if (ip) found.set(ip, { name: service.name, host: ip, port: service.port });
      });
    } catch (err) {
      console.warn('mDNS unavailable:', err.message);
      return finish();
    }
    setTimeout(finish, 2500);
  });
}

app.get('/api/discover', wrap(async (req, res) => {
  let devices = [];
  const explicit = String(req.query.subnet || '').trim().replace(/\.$/, '');
  if (explicit) {
    if (!/^\d+\.\d+\.\d+$/.test(explicit)) throw new Error('Subnet should look like 192.168.1');
    devices = await scanSubnet(explicit);
  } else {
    devices = await discoverMdns();
    if (!devices.length) {
      const bases = new Set(localAddresses().map((ip) => ip.split('.').slice(0, 3).join('.')));
      for (const base of bases) devices.push(...await scanSubnet(base));
    }
  }
  res.json({ ok: true, devices });
}));

app.post('/api/connect', wrap(async (req, res) => {
  const state = await tv.connect(req.body.host);
  res.json({ ok: true, state });
}));

app.post('/api/pair', wrap((req, res) => {
  const ok = tv.sendPairingCode(req.body.code);
  res.json({ ok, state: tv.snapshot() });
}));

app.post('/api/key', wrap((req, res) => {
  tv.sendKey(String(req.body.key || ''), req.body.direction || 'SHORT');
  res.json({ ok: true });
}));

app.post('/api/app', wrap((req, res) => {
  tv.sendAppLink(req.body.link);
  res.json({ ok: true });
}));

app.post('/api/disconnect', wrap(async (req, res) => {
  await tv.disconnect();
  res.json({ ok: true, state: tv.snapshot() });
}));

app.post('/api/forget', wrap(async (req, res) => {
  await tv.forget();
  res.json({ ok: true, state: tv.snapshot() });
}));

function localAddresses() {
  const out = [];
  let interfaces = {};
  try {
    interfaces = os.networkInterfaces();
  } catch (err) {
    // Some environments (iSH on iOS) cannot list interfaces. Not fatal.
    return out;
  }
  for (const list of Object.values(interfaces)) {
    for (const iface of list || []) {
      if (iface.family === 'IPv4' && !iface.internal) out.push(iface.address);
    }
  }
  return out;
}

// Keep the server alive if a library hits an unsupported system call.
process.on('uncaughtException', (err) => {
  console.error('Unexpected error (server keeps running):', err && err.message ? err.message : err);
});

const server = app.listen(PORT, () => {
  console.log('Impex TV web remote is running.');
  console.log('Open one of these on your iPhone (same Wi-Fi as the TV):');
  for (const ip of localAddresses()) console.log(`  http://${ip}:${PORT}`);
  console.log(`  http://localhost:${PORT}  (on this computer)`);

  // Reconnect automatically to the last TV we paired with.
  if (tv.config.host && tv.config.cert) {
    tv.connect(tv.config.host).catch((err) => console.error('Auto-connect failed:', err.message));
  }
});

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`Port ${PORT} is already in use. Is the remote already running? Stop it, or start with PORT=8124.`);
  } else {
    console.error('Could not start the server:', err.message);
  }
  process.exit(1);
});
