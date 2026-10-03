#!/usr/bin/env python3
# Current Lua-based Hyprland integration. Verify focused class and executable before signaling Takt.
"""Close the focused window; let Takt save and fully quit instead of hiding."""
import json
import os
import signal
import subprocess

result = subprocess.run(['hyprctl', 'activewindow', '-j'], capture_output=True, text=True)
try:
    window = json.loads(result.stdout)
    pid = int(window.get('pid', 0))
    is_takt = str(window.get('class', '')).lower() == 'com.takt.player.takt'
    if is_takt and pid > 1 and os.path.basename(os.readlink(f'/proc/{pid}/exe')) == 'takt':
        os.kill(pid, signal.SIGTERM)
    else:
        subprocess.run(['hyprctl', 'dispatch', 'hl.dsp.window.close()'], check=True)
except (ValueError, OSError, subprocess.CalledProcessError):
    raise SystemExit(1)
