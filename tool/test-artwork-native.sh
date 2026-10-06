#!/usr/bin/env bash
# GTK ownership/preview checks; requires a working display or xvfb-run.
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - <<'PY'
from pathlib import Path
import struct,zlib

def png(path,w,h):
 def chunk(name,data):return struct.pack('>I',len(data))+name+data+struct.pack('>I',zlib.crc32(name+data)&0xffffffff)
 raw=(b'\0'+b'\x80\xa0\xc0'*w)*h
 Path(path).write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b''))
png('/tmp/takt-preview-fixture.png',1600,800)
Path('/tmp/takt-picker-fixtures').mkdir(exist_ok=True)
png('/tmp/takt-picker-fixtures/image.png',1600,800)
PY
clang++ -std=c++17 "$project_dir/test/native/artwork_preview_test.cpp" $(pkg-config --cflags --libs gtk+-3.0) -o /tmp/takt-artwork-preview-test
clang++ -std=c++17 "$project_dir/test/native/artwork_picker_test.cpp" $(pkg-config --cflags --libs gtk+-3.0) -o /tmp/takt-artwork-picker-test
/tmp/takt-artwork-preview-test
/tmp/takt-artwork-picker-test
