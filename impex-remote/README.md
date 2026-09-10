# Impex TV web remote

A remote control for Impex Android TV / Google TV sets that runs in any web
browser, including Safari on an iPhone. It uses the same Wi-Fi remote
protocol the official Google TV app uses, so nothing needs to be installed on
the TV.

The page is laid out like the physical Impex remote: power, mute, number pad,
volume and channel rockers, input, Assistant, profile, settings, D-pad, back,
home, live TV, Netflix / YouTube / Prime Video shortcuts, the four colour keys,
exit, record, play/pause, stop, subtitles, audio track and teletext.

## What you need

- A computer (Mac, Windows, Linux) or a Raspberry Pi on the **same Wi-Fi as the TV**.
  It runs a tiny server that talks to the TV. Your phone talks to that server.
- [Node.js](https://nodejs.org) 14 or newer on that computer (18+ recommended).
- The TV switched on, at least the first time, so it can show the pairing code.

## No-install option (iPhone with iSH, Raspberry Pi, anything where npm is flaky)

`dist/remote.js` is a prebuilt single file with every dependency inside. It
needs only Node 14 or newer, no `npm install`:

```bash
node dist/remote.js
```

Rebuild it after changing the code with `npm run build`.

## Setup (about two minutes)

On a Mac, double-click `start.command`. On Windows, double-click `start.bat`.
Or from a terminal:

```bash
cd impex-remote
npm install
npm start
```

The terminal prints something like:

```
Impex TV web remote is running.
Open one of these on your iPhone (same Wi-Fi as the TV):
  http://192.168.1.23:8123
```

1. Open that address in Safari on your iPhone (or any browser on the computer).
2. Tap **Scan** to find the TV, or type the TV's IP address. On the TV it is
   under Settings, Network & Internet, then your Wi-Fi network.
3. Tap **Connect**. The TV shows a 6 character code on screen.
4. Type the code into the page and tap **Pair**.

That is it. The pairing is saved in `data/config.json`, so next time you run
`npm start` it reconnects on its own.

### Make it feel like an app on the iPhone

In Safari tap the Share button, then **Add to Home Screen**. It opens full
screen with no browser chrome, just like a real remote.

### Keyboard shortcuts on a laptop

Arrow keys move, Enter is OK, Backspace or Esc is back, `h` is home, `m` is
mute, `+` and `-` change volume, space is play/pause, Page Up/Down change
channel, and the number keys work as expected.

## Notes and limits

- **Power on from standby** works only if the TV keeps Wi-Fi alive while off.
  On most Google TV sets this is the default. If the TV does not wake, turn it
  on from the button on the set once, and the page reconnects automatically.
- **The mic button** opens Google Assistant on the TV, but this page cannot
  stream your voice to it. Use the D-pad and on-screen keyboard instead.
- **USB** on the physical remote opens the media player. There is no public
  key for that, so the USB button here opens the input picker instead. If you
  learn the app's package link, change `data-app` on that button in
  `public/index.html`.
- **EXIT** sends Android's Escape key. If your set ignores it, change the
  `data-key` on that button to `HOME`.
- Volume, current app and power state update live on the page when the TV
  reports them.
- The server listens on port 8123. Change it with `PORT=9000 npm start`.
- Keep it on your home network only. There is no login on the page, so do not
  expose the port to the internet.

## How it works

`server.js` is an Express app that serves the page and exposes a small JSON
API (`/api/connect`, `/api/pair`, `/api/key`, `/api/app`, `/api/status`,
`/api/events` for live updates, `/api/discover` for finding TVs via mDNS).
`lib/tv.js` wraps the [`androidtv-remote`](https://www.npmjs.com/package/androidtv-remote)
library, which implements the Android TV Remote v2 protocol (TLS on ports
6467 for pairing and 6466 for control). `lib/framing-patch.js` fixes a
robustness issue in that library where two protocol frames arriving in one
TCP packet would wedge the connection.

Any Android `KEYCODE_*` name can be sent through `/api/key`, so adding a new
button is a one-line change in `public/index.html`.

## Running it all the time

On a Raspberry Pi or an always-on computer you can keep it running with pm2:

```bash
npm install -g pm2
pm2 start server.js --name impex-remote
pm2 save && pm2 startup
```
