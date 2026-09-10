'use strict';

/*
 * The androidtv-remote library assumes every TCP chunk holds exactly one
 * protocol frame. Real TVs sometimes send two frames back to back (for
 * example a ping plus a volume update), and when that happens the library's
 * buffer never lines up again and the connection silently stops working.
 *
 * This patch wraps the library's connection start so that:
 *   1. the buffer is cleared on every (re)connect, and
 *   2. incoming data is split into individual frames before being handed to
 *      the library's own handler.
 */

const { RemoteManager } = require('androidtv-remote/dist/remote/RemoteManager.js');

function frameLength(buf) {
  // Length prefix is a protobuf varint; frames here are small so it is one
  // byte, but read it properly so bigger frames don't wedge the parser.
  let len = 0;
  let shift = 0;
  let i = 0;
  while (i < buf.length) {
    const b = buf[i++];
    len |= (b & 0x7f) << shift;
    if ((b & 0x80) === 0) return { len, headerBytes: i };
    shift += 7;
    if (shift > 28) break;
  }
  return null; // header incomplete
}

function install() {
  if (RemoteManager.prototype.__framingPatched) return;
  RemoteManager.prototype.__framingPatched = true;

  const originalStart = RemoteManager.prototype.start;
  RemoteManager.prototype.start = function patchedStart(...args) {
    this.chunks = Buffer.from([]);
    const result = originalStart.apply(this, args);

    // The library attaches its 'data' handler synchronously inside start(),
    // so by now this.client exists and we can swap the handler out.
    const client = this.client;
    if (client && typeof client.listeners === 'function') {
      const originalHandlers = client.listeners('data');
      client.removeAllListeners('data');
      let pending = Buffer.alloc(0);
      client.on('data', (data) => {
        pending = Buffer.concat([pending, Buffer.from(data)]);
        for (;;) {
          const head = frameLength(pending);
          if (!head) return;
          const total = head.headerBytes + head.len;
          if (pending.length < total) return;
          const frame = pending.subarray(0, total);
          pending = pending.subarray(total);
          this.chunks = Buffer.from([]);
          for (const h of originalHandlers) {
            try {
              h.call(client, frame);
            } catch (err) {
              console.error('Failed to handle a frame from the TV:', err.message);
              this.chunks = Buffer.from([]);
            }
          }
        }
      });
    }
    return result;
  };
}

module.exports = { install };
