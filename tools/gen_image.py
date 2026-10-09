#!/usr/bin/env python3
"""Generate images with the OpenAI Images API.

The API key is read from the CLAUDE_OPENAI_API_KEY environment variable.

Examples:
    python tools/gen_image.py "a cartoon dartboard, flat style" -o assets/generated/dartboard.png
    python tools/gen_image.py "a skull icon" -o assets/generated/skull.png --background transparent --size 1024x1024
    python tools/gen_image.py "same style, a gear icon" -o out.png --ref assets/game_selector/game_selector_cricket.png

With --ref, the reference images are sent to the edits endpoint so the result
follows their style.
"""
import argparse
import base64
import json
import mimetypes
import os
import sys
import urllib.error
import urllib.request
import uuid
from pathlib import Path

API_URL = "https://api.openai.com/v1/images/generations"
EDITS_URL = "https://api.openai.com/v1/images/edits"
KEY_ENV = "CLAUDE_OPENAI_API_KEY"


def _multipart_request(url: str, key: str, fields: dict, images: list[str]) -> urllib.request.Request:
    boundary = uuid.uuid4().hex
    parts = []
    for name, value in fields.items():
        parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode())
    for path in images:
        mime = mimetypes.guess_type(path)[0] or "image/png"
        header = (f'--{boundary}\r\nContent-Disposition: form-data; name="image[]"; '
                  f'filename="{Path(path).name}"\r\nContent-Type: {mime}\r\n\r\n')
        parts.append(header.encode() + Path(path).read_bytes() + b"\r\n")
    parts.append(f"--{boundary}--\r\n".encode())
    return urllib.request.Request(
        url,
        data=b"".join(parts),
        headers={"Authorization": f"Bearer {key}", "Content-Type": f"multipart/form-data; boundary={boundary}"},
    )


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("prompt")
    p.add_argument("-o", "--output", required=True, help="Output PNG path (suffixed _1, _2... when -n > 1)")
    p.add_argument("-n", type=int, default=1, help="Number of images")
    p.add_argument("--model", default="gpt-image-1")
    p.add_argument("--size", default="1024x1024", help="1024x1024, 1536x1024, 1024x1536 or auto")
    p.add_argument("--quality", default="medium", help="low, medium, high or auto")
    p.add_argument("--background", default="auto", help="transparent, opaque or auto")
    p.add_argument("--ref", action="append", default=[], help="Reference image (repeatable)")
    args = p.parse_args()

    key = os.environ.get(KEY_ENV)
    if not key:
        print(f"Error: environment variable {KEY_ENV} is not set.", file=sys.stderr)
        return 1

    body = {
        "model": args.model,
        "prompt": args.prompt,
        "n": args.n,
        "size": args.size,
        "quality": args.quality,
        "background": args.background,
    }
    if args.ref:
        req = _multipart_request(EDITS_URL, key, body, args.ref)
    else:
        req = urllib.request.Request(
            API_URL,
            data=json.dumps(body).encode(),
            headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        )
    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            data = json.load(resp)
    except urllib.error.HTTPError as e:
        print(f"HTTP {e.code}: {e.read().decode(errors='replace')}", file=sys.stderr)
        return 1

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    for i, item in enumerate(data["data"], 1):
        path = out if args.n == 1 else out.with_name(f"{out.stem}_{i}{out.suffix}")
        path.write_bytes(base64.b64decode(item["b64_json"]))
        print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
