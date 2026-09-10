#!/bin/bash
# Double-click this file on a Mac to start the Impex web remote.
cd "$(dirname "$0")"
if ! command -v node >/dev/null 2>&1; then
  echo "Node.js is not installed. Get it from https://nodejs.org (LTS), then double-click this file again."
  read -r -p "Press Enter to close."
  exit 1
fi
[ -d node_modules ] || npm install
echo
echo "Starting... open the address below on your iPhone (same Wi-Fi as the TV)."
echo
npm start
