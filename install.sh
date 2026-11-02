#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TV_IP="${TV_IP:-${1:-192.168.1.3}}"
SSH_KEY="${WEBOS_SSH_KEY:-${2:-$HOME/.ssh/mytv_webos}}"
APP_ID="com.littlelauncher.app"
REMOTE_ARCHIVE="/tmp/${APP_ID}-payload.tar.gz"
REMOTE_IPK="/tmp/${APP_ID}-install.ipk"
REMOTE_APP="/media/developer/apps/usr/palm/applications/${APP_ID}"
REMOTE_LEGACY="/media/developer/apps/${APP_ID}"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

for tool in ssh scp tar ares-package python3; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Missing required command: $tool" >&2; exit 1; }
done
[[ -f "$SSH_KEY" ]] || { echo "SSH key not found: $SSH_KEY" >&2; exit 1; }
[[ -f "$ROOT_DIR/appinfo.json" && -f "$ROOT_DIR/index.html" && -f "$ROOT_DIR/app.js" ]] || {
  echo "Run this script from the Nothing Launcher project directory." >&2; exit 1;
}
[[ -f "$ROOT_DIR/tools/tv_app_catalog.py" ]] || { echo "Missing TV app catalog generator." >&2; exit 1; }

SSH=(ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)
SCP=(scp -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)
SSH_TTY=(ssh -tt -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)
VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$ROOT_DIR/appinfo.json")"
STAGE_DIR="$WORK_DIR/$APP_ID"
mkdir -p "$STAGE_DIR" "$WORK_DIR/packages"

echo "Preparing Nothing Launcher ${VERSION} for ${TV_IP}..."
echo "Checking SSH connection..."
"${SSH[@]}" "root@${TV_IP}" 'true'

echo "Reading installed TV apps and packaging a proper webOS app..."
"${SSH[@]}" "root@${TV_IP}" 'python3 -' < "$ROOT_DIR/tools/tv_app_catalog.py" > "$WORK_DIR/app-catalog.js"
[[ -s "$WORK_DIR/app-catalog.js" ]] || { echo "The TV returned an empty app catalog." >&2; exit 1; }
tar -cf - -C "$ROOT_DIR" appinfo.json index.html style.css app.js icon.png splash.png webOSTVjs-1.2.13 | tar -xf - -C "$STAGE_DIR"
cp "$WORK_DIR/app-catalog.js" "$STAGE_DIR/app-catalog.js"
"$(command -v ares-package)" -o "$WORK_DIR/packages" "$STAGE_DIR"
IPK="$(find "$WORK_DIR/packages" -maxdepth 1 -type f -name '*.ipk' -print -quit)"
[[ -n "$IPK" && -s "$IPK" ]] || { echo "webOS package creation failed." >&2; exit 1; }

"${SCP[@]}" "$IPK" "root@${TV_IP}:${REMOTE_IPK}"
echo "Removing the previous launcher and registering the IPK with webOS..."
"${SSH_TTY[@]}" "root@${TV_IP}" "luna-send-pub -n 1 -f luna://com.webos.appInstallService/dev/remove '{\"id\":\"${APP_ID}\"}' || true"
echo "Waiting for webOS to finish removing the old registration..."
sleep 12
"${SSH[@]}" "root@${TV_IP}" "rm -rf -- '${REMOTE_LEGACY}'"
"${SSH_TTY[@]}" "root@${TV_IP}" "luna-send-pub -n 1 -f luna://com.webos.appInstallService/dev/install '{\"id\":\"${APP_ID}\",\"ipkUrl\":\"${REMOTE_IPK}\",\"subscribe\":true}'"
echo "Waiting for webOS to register the installed app..."
REMOTE_VERIFY="i=0
while [ \$i -lt 30 ]; do
  if [ -f '${REMOTE_APP}/appinfo.json' ] && grep -q '\"version\": \"${VERSION}\"' '${REMOTE_APP}/appinfo.json'; then echo 'Installed version ${VERSION}'; exit 0; fi
  i=\$((i+1)); sleep 2
done
echo 'Timed out waiting for webOS IPK installation' >&2; exit 1"
"${SSH[@]}" "root@${TV_IP}" "$REMOTE_VERIFY"
"${SSH[@]}" "root@${TV_IP}" "rm -f -- '${REMOTE_IPK}'"
echo "Rebooting so webOS can refresh its app list..."
"${SSH[@]}" "root@${TV_IP}" 'nohup sh -c "sleep 2; reboot" >/dev/null 2>&1 </dev/null &' || true
echo "The TV is rebooting. After startup, open the TV app list and select Nothing Launcher."
