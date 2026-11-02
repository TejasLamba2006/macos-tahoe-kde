#!/usr/bin/env bash
# ponytail: zero-evaluateScript multi-screen sync — only calls evaluateScript if a connected monitor lacks a panel in plasma-org.kde.plasma.desktop-appletsrc, preventing KDE Plasma 6 KConfigGroup::readEntry SIGSEGV when a monitor is unplugged

SCREENS=$(grep -l '^connected$' /sys/class/drm/card*-*/status 2>/dev/null | wc -l)
[ "$SCREENS" -lt 1 ] && exit 0

RC="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
if [ -f "$RC" ]; then
    # Heal any stale empty-desktop URL directly in config without evaluateScript
    if grep -q "file:///tmp/empty-desktop" "$RC" 2>/dev/null; then
        sed -i 's|url=file:///tmp/empty-desktop|url=desktop:/|g' "$RC"
    fi

    # Check if every connected screen (0..SCREENS-1) already has both a top (location=3) and bottom (location=4) panel
    if python3 -I -c "
import os, re, sys
rc = os.path.expanduser('$RC')
text = open(rc, errors='ignore').read()
tops, bots = set(), set()
for block in re.split(r'\n(?=\[Containments\]\[\d+\]\n)', text):
    if 'formfactor=2' in block:
        m_scr = re.search(r'^lastScreen=(\d+)', block, re.M)
        m_loc = re.search(r'^location=(\d+)', block, re.M)
        if m_scr and m_loc:
            s, loc = int(m_scr.group(1)), int(m_loc.group(1))
            if loc == 3: tops.add(s)
            elif loc == 4: bots.add(s)
screens = int('$SCREENS')
for s in range(screens):
    if s not in tops or s not in bots:
        sys.exit(1)
sys.exit(0)
"; then
        echo "All $SCREENS connected screen(s) already have top & bottom panels configured on disk — skipping evaluateScript."
        exit 0
    fi
fi
