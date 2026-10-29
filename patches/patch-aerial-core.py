#!/usr/bin/env python3
"""
Patches libaerial_core.so (plasma6-wallpapers-aerial) to change the default
AerialCacheRust::default download_interval_secs from 86400 (24h) to 0s so all
Apple TV Aerial videos download and cycle freely without hitting Qt6 QML
qlonglong binding errors.
"""
import os
import sys

# movq $0x15180, 0x28(%rsp) -> movq $0x0, 0x28(%rsp)
SEQ_86400 = bytes.fromhex("48c744242880510100")
SEQ_ZERO  = bytes.fromhex("48c744242800000000")

TARGETS = [
    "/usr/lib/libaerial_core.so",
    "/usr/lib64/libaerial_core.so",
    "/usr/lib/x86_64-linux-gnu/libaerial_core.so",
    "/usr/lib/qt6/qml/org/kde/plasma/wallpaper/aerial/libaerial_core.so",
    "/usr/lib64/qt6/qml/org/kde/plasma/wallpaper/aerial/libaerial_core.so",
    "/usr/lib/x86_64-linux-gnu/qt6/qml/org/kde/plasma/wallpaper/aerial/libaerial_core.so",
]

for path in TARGETS:
    if not os.path.exists(path):
        continue
    with open(path, "rb") as f:
        data = f.read()
    if SEQ_86400 in data:
        data = data.replace(SEQ_86400, SEQ_ZERO, 1)
        tmp = path + ".new"
        with open(tmp, "wb") as f:
            f.write(data)
        os.chmod(tmp, 0o755)
        os.replace(tmp, path)
        print(f"[patched] {path}: download_interval_secs 86400 -> 0")
    elif SEQ_ZERO in data:
        print(f"[ok] {path}: already patched")
    else:
        print(f"[skip] {path}: byte sequence not found (different compiler/version)", file=sys.stderr)
