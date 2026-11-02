"""Run on an LG webOS TV to emit its installed user-app catalog as JavaScript."""
import glob
import json
import os
import base64

SELF = "com.littlelauncher.app"
ROOTS = (
    "/media/cryptofs/apps/usr/palm/applications",
    "/media/developer/apps/usr/palm/applications",
)
apps = {}
for root in ROOTS:
    for manifest in glob.glob(os.path.join(root, "*", "appinfo.json")):
        try:
            with open(manifest, encoding="utf-8") as source:
                data = json.load(source)
            app_id = data.get("id")
            title = data.get("title")
            app_type = data.get("type", "")
            if app_id and title and app_id != SELF and data.get("visible", True) is not False and app_type in ("web", "native"):
                root = os.path.dirname(manifest)
                icon_path = os.path.abspath(os.path.join(root, data.get("icon", "")))
                icon = ""
                if icon_path.startswith(os.path.abspath(root) + os.sep):
                    try:
                        with open(icon_path, "rb") as image:
                            raw = image.read(256 * 1024 + 1)
                        if len(raw) <= 256 * 1024:
                            mime = "image/png" if raw.startswith(b"\x89PNG") else "image/jpeg" if raw.startswith(b"\xff\xd8") else "image/webp" if raw.startswith(b"RIFF") and raw[8:12] == b"WEBP" else ""
                            if mime:
                                icon = "data:" + mime + ";base64," + base64.b64encode(raw).decode("ascii")
                    except OSError:
                        pass
                apps[app_id] = {"id": app_id, "title": title, "icon": icon, "appType": app_type, "custom": False}
        except (OSError, ValueError, TypeError):
            continue

print("window.TV_APP_CATALOG = " + json.dumps(sorted(apps.values(), key=lambda app: app["title"].casefold()), ensure_ascii=True) + ";")
