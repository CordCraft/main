'use strict';

/*
 * Thin wrapper around the Android TV Remote v2 protocol (the same protocol the
 * Google TV app uses). Keeps one live connection to the TV, remembers the
 * pairing certificate on disk so you only pair once, and exposes a tiny API
 * that the HTTP server calls.
 */

const fs = require('fs');
const path = require('path');
const EventEmitter = require('events');
const { AndroidRemote, RemoteKeyCode, RemoteDirection } = require('androidtv-remote');
require('./framing-patch').install();

const DATA_DIR = path.join(__dirname, '..', 'data');
const CONFIG_FILE = path.join(DATA_DIR, 'config.json');

function loadConfig() {
  try {
    return JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
  } catch (err) {
    return {};
  }
}

function saveConfig(config) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
  fs.writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2));
}

class TvController extends EventEmitter {
  constructor() {
    super();
    this.config = loadConfig();
    this.remote = null;
    this.state = {
      host: this.config.host || null,
      paired: Boolean(this.config.cert && this.config.cert.key),
      connecting: false,
      connected: false,
      pairing: false,
      powered: null,
      volume: null,
      currentApp: null,
      lastError: null,
    };
  }

  snapshot() {
    return { ...this.state };
  }

  setState(patch) {
    Object.assign(this.state, patch);
    this.emit('state', this.snapshot());
  }

  /*
   * Connect to a TV. If we have no certificate for it yet, the library opens
   * the pairing port and the TV shows a 6 character code on screen. The UI
   * then calls sendPairingCode() with it.
   */
  async connect(host) {
    if (!host) throw new Error('A TV IP address is required');
    host = host.trim();

    await this.disconnect();

    const sameTv = this.config.host === host;
    const cert = sameTv && this.config.cert ? this.config.cert : {};

    this.config.host = host;
    if (!sameTv) delete this.config.cert;
    saveConfig(this.config);

    this.setState({
      host,
      paired: Boolean(cert.key),
      connecting: true,
      connected: false,
      pairing: false,
      lastError: null,
    });

    const remote = new AndroidRemote(host, {
      pairing_port: 6467,
      remote_port: 6466,
      service_name: 'Impex Web Remote',
      cert,
    });
    this.remote = remote;
    this.startHealthCheck();

    remote.on('secret', () => this.setState({ pairing: true }));
    remote.on('powered', (powered) => this.setState({ powered }));
    remote.on('volume', (volume) => this.setState({ volume }));
    remote.on('current_app', (currentApp) => this.setState({ currentApp }));
    remote.on('ready', () => {
      // Persist the certificate the first time pairing succeeds.
      const c = remote.getCertificate();
      if (c && c.key && !this.config.cert) {
        this.config.cert = c;
        saveConfig(this.config);
      }
      this.setState({ paired: true, pairing: false, connecting: false, connected: true, lastError: null });
    });
    remote.on('unpaired', () => {
      delete this.config.cert;
      saveConfig(this.config);
      this.setState({ paired: false, connected: false, connecting: false, lastError: 'The TV rejected our pairing. Please pair again.' });
    });
    remote.on('error', (err) => {
      const message = err && err.error ? JSON.stringify(err.error) : String(err);
      this.setState({ lastError: message });
    });

    try {
      const started = await remote.start();
      if (!started) {
        this.setState({ connecting: false, pairing: false, lastError: this.state.lastError || 'Could not connect. Is the TV on and on the same Wi-Fi?' });
      }
    } catch (err) {
      this.setState({ connecting: false, pairing: false, lastError: String(err && err.message ? err.message : err) });
    }
    return this.snapshot();
  }

  sendPairingCode(code) {
    if (!this.remote || !this.state.pairing) throw new Error('The TV is not asking for a pairing code right now');
    const clean = String(code || '').trim().toUpperCase();
    if (!/^[0-9A-F]{6}$/.test(clean)) throw new Error('The code is the 6 characters shown on the TV screen');
    const ok = this.remote.sendCode(clean);
    if (!ok) {
      this.setState({ lastError: 'That code did not match. Try connecting again to get a new one.' });
    }
    return ok;
  }

  // The library reconnects on its own when the TV drops off; we just need to
  // know whether the socket is currently usable.
  socketAlive() {
    const rm = this.remote && this.remote.remoteManager;
    const client = rm && rm.client;
    return Boolean(client && !client.destroyed && client.writable);
  }

  requireConnection() {
    if (!this.remote || !this.state.connected) {
      throw new Error('Not connected to the TV yet');
    }
    if (!this.socketAlive()) {
      this.setState({ connected: false });
      throw new Error('Lost the TV connection, reconnecting. Is the TV on?');
    }
  }

  startHealthCheck() {
    clearInterval(this.healthTimer);
    this.healthTimer = setInterval(() => {
      if (this.state.connected && !this.socketAlive()) this.setState({ connected: false });
    }, 3000);
    if (this.healthTimer.unref) this.healthTimer.unref();
  }

  sendKey(name, direction = 'SHORT') {
    this.requireConnection();
    const keyName = name.startsWith('KEYCODE_') ? name : `KEYCODE_${name}`;
    const key = RemoteKeyCode[keyName];
    if (key === undefined) throw new Error(`Unknown key: ${name}`);
    const dir = RemoteDirection[direction];
    if (dir === undefined) throw new Error(`Unknown direction: ${direction}`);
    this.remote.sendKey(key, dir);
  }

  sendAppLink(link) {
    this.requireConnection();
    if (!link || typeof link !== 'string') throw new Error('An app link is required');
    this.remote.sendAppLink(link);
  }

  async disconnect() {
    if (this.remote) {
      try {
        this.remote.removeAllListeners();
        if (this.remote.remoteManager && this.remote.remoteManager.client) {
          // Stop the library's automatic reconnect loop before destroying.
          this.remote.remoteManager.client.removeAllListeners('close');
          this.remote.remoteManager.client.destroy();
        }
        if (this.remote.pairingManager && this.remote.pairingManager.client) {
          this.remote.pairingManager.client.destroy();
        }
      } catch (err) {
        // ignore, we are tearing down anyway
      }
      this.remote = null;
    }
    this.setState({ connected: false, connecting: false, pairing: false });
  }

  async forget() {
    await this.disconnect();
    this.config = {};
    saveConfig(this.config);
    this.setState({ host: null, paired: false, powered: null, volume: null, currentApp: null, lastError: null });
  }
}

module.exports = { TvController, RemoteKeyCode, RemoteDirection };
