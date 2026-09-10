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
app.use(express.static(path.join(__dirname, 'public'), { extensions: ['html'] }));

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

// Find Android TV / Google TV sets on the network via mDNS.
app.get('/api/discover', (req, res) => {
  const bonjour = new Bonjour();
  const found = new Map();
  const browser = bonjour.find({ type: 'androidtvremote2' }, (service) => {
    const ip = (service.addresses || []).find((a) => /^\d+\.\d+\.\d+\.\d+$/.test(a)) || service.host;
    if (ip) found.set(ip, { name: service.name, host: ip, port: service.port });
  });
  setTimeout(() => {
    browser.stop();
    bonjour.destroy();
    res.json({ ok: true, devices: Array.from(found.values()) });
  }, 2500);
});

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
  for (const list of Object.values(os.networkInterfaces())) {
    for (const iface of list || []) {
      if (iface.family === 'IPv4' && !iface.internal) out.push(iface.address);
    }
  }
  return out;
}

app.listen(PORT, () => {
  console.log('Impex TV web remote is running.');
  console.log('Open one of these on your iPhone (same Wi-Fi as the TV):');
  for (const ip of localAddresses()) console.log(`  http://${ip}:${PORT}`);
  console.log(`  http://localhost:${PORT}  (on this computer)`);

  // Reconnect automatically to the last TV we paired with.
  if (tv.config.host && tv.config.cert) {
    tv.connect(tv.config.host).catch((err) => console.error('Auto-connect failed:', err.message));
  }
});
