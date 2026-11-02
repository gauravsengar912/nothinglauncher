# Nothing TV Launcher

A lightweight, remote-first LG webOS app with four full-screen views:

- **Home:** 2026 F1 weekend schedule, driver and constructor standings, Greater Noida temperature and AQI.
- **Apps:** TV app catalog, search, manual app entries, and configurable 3×3, 4×3, or 4×4 grids.
- **Inputs:** TV source shortcuts.
- **Settings:** Accent color, F1 text size, focus strength, temperature units, clock format, app grid, and supported LG controls.

The interface uses plain HTML, CSS, and JavaScript. D-pad navigation uses Left/Right/Up/Down and OK. Back closes an open dialog or returns to Home. Focus is stationary and uses the selected accent color.

## Install on a developer-mode TV

Run `./install.sh` from this directory. Defaults are TV `192.168.1.3` and SSH key `~/.ssh/mytv_webos`. Override them with `./install.sh TV_IP SSH_KEY`, or set `TV_IP` and `WEBOS_SSH_KEY`.

The script reads installed app manifests over SSH, generates the TV app catalog, packages an IPK, replaces the existing **Nothing TV app registration**, verifies the installed version, and reboots the TV.

## Home button takeover

[LG Luma](https://github.com/ecklf/lg-luma) provides a root takeover for supported rooted TVs. Its webOS 25/26 method mounts a native Home app manifest and executable at the system Home app path and reapplies that mount during cold boot. This project is a web app (`type: web`) and does not include Luma's native executable or root helper, so Luma's `home.sh` cannot be applied directly to this package. Keep the Luma takeover disabled for Nothing TV unless a compatible native Home integration is built and the exact TV model is verified. Luma's confirmed-model list includes some, but not all, webOS 25 TVs.

For now, install Nothing TV with the script and launch it from the TV app list. The installer does not modify LG Home or reboot into Nothing TV by default.

## Developer checks

Run `node --check app.js`, `bash -n install.sh`, and `python3 -m json.tool appinfo.json` to check JavaScript syntax, installer syntax, and manifest JSON. Live F1/weather feeds and LG Luna services require network access or a TV.