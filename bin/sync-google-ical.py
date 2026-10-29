#!/usr/bin/env python3
# ponytail: syncs Google Calendar iCal feeds (from ~/.config/macos-tahoe.env or Dynamic Island config) into Akonadi std.ics
import json
import os
import subprocess
import urllib.request

urls = []
env_file = os.path.expanduser("~/.config/macos-tahoe.env")
if os.path.exists(env_file):
    with open(env_file, errors="ignore") as f:
        for line in f:
            line = line.strip()
            if line.startswith("GOOGLE_ICAL_URL="):
                val = line.split("=", 1)[1].strip().strip('"').strip("'")
                if val:
                    urls.append(val)

rc = os.path.expanduser("~/.config/plasma-org.kde.plasma.desktop-appletsrc")
if os.path.exists(rc):
    with open(rc, errors="ignore") as f:
        for line in f:
            if line.startswith("calendarSources="):
                try:
                    data = json.loads(line.split("=", 1)[1].strip())
                    for item in data:
                        u = item.get("url")
                        if u and u not in urls:
                            urls.append(u)
                except Exception:
                    pass

if not urls:
    raise SystemExit(0)

out_dir = os.path.expanduser("~/.local/share/apps/korganizer")
os.makedirs(out_dir, exist_ok=True)
out_path = os.path.join(out_dir, "std.ics")

for u in urls:
    try:
        req = urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=15) as resp:
            body = resp.read()
        if b"BEGIN:VCALENDAR" in body:
            with open(out_path, "wb") as out:
                out.write(body)
    except Exception as e:
        print("Failed to fetch", u, e)

subprocess.run(
    ["qdbus6", "org.freedesktop.Akonadi.Resource.akonadi_ical_resource_0", "/", "org.freedesktop.Akonadi.Resource.synchronize"],
    stderr=subprocess.DEVNULL,
    stdout=subprocess.DEVNULL,
)
