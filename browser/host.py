#!/usr/bin/env python3
# Native messaging host for the DMS Album Cover extension. Takes
# {title, artist, album, art} and writes it to
# $XDG_CACHE_HOME/dms-album-cover/now-playing.json for the widget. It does
# nothing else: no network, no commands.
import json, os, struct, sys, time

OUT_DIR = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "dms-album-cover")
OUT = os.path.join(OUT_DIR, "now-playing.json")


def read_message():
    raw_length = sys.stdin.buffer.read(4)
    if len(raw_length) < 4:
        return None
    (length,) = struct.unpack("=I", raw_length)
    if length > 64 * 1024:
        return None
    return json.loads(sys.stdin.buffer.read(length))


def send_message(obj):
    data = json.dumps(obj).encode()
    sys.stdout.buffer.write(struct.pack("=I", len(data)) + data)
    sys.stdout.buffer.flush()


message = read_message()
if isinstance(message, dict) and str(message.get("art", "")).startswith(("http://", "https://")):
    os.makedirs(OUT_DIR, exist_ok=True)
    record = {key: str(message.get(key, ""))[:2000] for key in ("title", "artist", "album", "art")}
    record["ts"] = int(time.time())
    tmp = OUT + ".tmp"
    with open(tmp, "w") as f:
        json.dump(record, f, ensure_ascii=False)
    os.replace(tmp, OUT)
    send_message({"ok": True})
else:
    send_message({"ok": False})
