#!/usr/bin/env python3
"""Collect the resolved dependencies' copyright notices into the release bundle."""
import json
import pathlib
import sys
import urllib.parse

project = pathlib.Path(__file__).resolve().parent.parent
config = project / '.dart_tool/package_config.json'
destination = pathlib.Path(sys.argv[1])
destination.mkdir(parents=True, exist_ok=True)
for package in json.loads(config.read_text())['packages']:
    uri = urllib.parse.urljoin(config.as_uri(), package['rootUri'])
    root = pathlib.Path(urllib.parse.unquote(urllib.parse.urlparse(uri).path))
    for filename in ['LICENSE', 'LICENSE.md', 'LICENSE.txt', 'COPYING', 'NOTICE']:
        notice = root / filename
        if notice.is_file():
            (destination / f"{package['name']}-{filename}").write_bytes(notice.read_bytes())
# Flutter's native engine includes additional notices inside its SDK artifacts.
flutter = next(p for p in json.loads(config.read_text())['packages'] if p['name'] == 'flutter')
root = pathlib.Path(urllib.parse.unquote(urllib.parse.urlparse(
    urllib.parse.urljoin(config.as_uri(), flutter['rootUri'])).path))
sdk = root.parent.parent
sdk_notice = sdk / 'LICENSE'
if sdk_notice.is_file():
    (destination / 'Flutter-SDK.txt').write_bytes(sdk_notice.read_bytes())
# The pinned SDK publishes the Linux engine notices under an artifact-specific name.
engine_candidates = [
    sdk / 'bin/cache/artifacts/engine/linux-x64-release/LICENSE.flutter_gtk.md',
    sdk / 'bin/cache/artifacts/engine/linux-x64/LICENSE.flutter_gtk.md',
    sdk / 'bin/cache/artifacts/engine/linux-x64/LICENSE',
]
engine_notice = next((p for p in engine_candidates if p.is_file()), None)
if engine_notice is None:
    raise FileNotFoundError('Flutter Linux engine license notice is missing')
(destination / 'Flutter-engine.txt').write_bytes(engine_notice.read_bytes())
