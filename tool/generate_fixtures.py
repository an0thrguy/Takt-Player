#!/usr/bin/env python3
# Generate owned synthetic codec fixtures; edit formats to extend the decoder test matrix.
"""Create original synthetic audio for decoder checks; no downloaded music."""
from pathlib import Path
import subprocess
import sys
root=Path(sys.argv[1] if len(sys.argv)>1 else '/tmp/takt-formats')
root.mkdir(parents=True,exist_ok=True)
formats=[('mp3','libmp3lame'),('flac','flac'),('wav','pcm_s16le'),('aiff','pcm_s16be'),('aac','aac'),('m4a','aac'),('alac.m4a','alac'),('ogg','libvorbis'),('opus','libopus'),('wma','wmav2'),('wv','wavpack')]
for suffix,codec in formats:
    subprocess.run(['ffmpeg','-v','error','-f','lavfi','-i','sine=frequency=440:duration=2.5','-c:a',codec,'-y',str(root/f'check.{suffix}')],check=True)
print(f'{len(formats)} files generated in {root}')
