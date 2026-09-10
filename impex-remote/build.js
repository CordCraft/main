'use strict';
// Bundles the server and every dependency into dist/remote.js so it can run
// on machines where `npm install` is unreliable (for example iSH on iOS):
//   node dist/remote.js
const path = require('path');
const fs = require('fs');
const esbuild = require('esbuild');

const out = path.join(__dirname, 'dist');
fs.mkdirSync(out, { recursive: true });

esbuild.buildSync({
  entryPoints: [path.join(__dirname, 'server.js')],
  bundle: true,
  platform: 'node',
  target: 'node14',
  outfile: path.join(out, 'remote.js'),
  // The remote library reads its .proto schemas from disk next to the code,
  // so we copy them next to the bundle and point __dirname there.
  define: { 'process.env.IMPEX_BUNDLED': '"1"' },
  logLevel: 'warning',
});

const protoDir = path.join(__dirname, 'node_modules', 'androidtv-remote', 'dist');
for (const f of ['remote/remotemessage.proto', 'pairing/pairingmessage.proto']) {
  fs.copyFileSync(path.join(protoDir, f), path.join(out, path.basename(f)));
}
console.log('Built dist/remote.js');
