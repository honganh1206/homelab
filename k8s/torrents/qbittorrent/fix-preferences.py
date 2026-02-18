import json
import os
import sys

JSON_PATH = "/config/qBittorrent/config/preferences.json"

if os.path.isfile(JSON_PATH):
    with open(JSON_PATH, "r") as f:
        prefs = json.load(f)
    prefs["web_ui_address"] = "*"
    prefs["web_ui_port"] = 8080
    with open(JSON_PATH, "w") as f:
        json.dump(prefs, f, indent=4)
    print("[fix-preferences] Updated preferences.json: web_ui_address=*")
else:
    os.makedirs(os.path.dirname(JSON_PATH), exist_ok=True)
    with open(JSON_PATH, "w") as f:
        json.dump({"web_ui_address": "*", "web_ui_port": 8080}, f, indent=4)
    print("[fix-preferences] Created preferences.json with web_ui_address=*")
