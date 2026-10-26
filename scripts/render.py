#!/usr/bin/env python3
"""Render a template with {{placeholders}}.

    render.py <template> [KEY=VALUE ...]              → stdout
    render.py <template> --out <path> [KEY=VALUE ...] → file
    render.py <template> --stdin [KEY=VALUE ...]      → values from JSON on stdin

With --stdin, values also come from a JSON object on stdin, so a topology record
can be piped in whole. Explicit KEY=VALUE wins over stdin. Reading stdin is
opt-in because an inherited-but-idle pipe — command substitution, a tool
harness — would otherwise block the render forever.

Unresolved placeholders are an error, not an empty string: a prompt that
silently loses its bead ID is worse than one that refuses to render.
"""
import json
import re
import sys
from pathlib import Path

PLACEHOLDER = re.compile(r"\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}")


def main() -> int:
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)

    template = Path(args.pop(0))
    if not template.is_file():
        sys.exit(f"render.py: no such template: {template}")

    out = None
    values = {}
    read_stdin = False

    while args:
        arg = args.pop(0)
        if arg == "--out":
            if not args:
                sys.exit("render.py: --out needs a path")
            out = Path(args.pop(0))
        elif arg == "--stdin":
            read_stdin = True
        elif "=" in arg:
            key, _, value = arg.partition("=")
            values[key] = value
        else:
            sys.exit(f"render.py: unexpected argument: {arg}")

    if read_stdin:
        raw = sys.stdin.read().strip()
        if raw:
            try:
                piped = json.loads(raw)
            except json.JSONDecodeError as exc:
                sys.exit(f"render.py: stdin is not JSON: {exc}")
            if not isinstance(piped, dict):
                sys.exit("render.py: stdin JSON must be an object")
            # Explicit KEY=VALUE wins.
            for k, v in piped.items():
                if not isinstance(v, (dict, list)):
                    values.setdefault(k, v)

    missing = []

    def substitute(match: re.Match) -> str:
        key = match.group(1)
        if key not in values:
            missing.append(key)
            return match.group(0)
        return str(values[key])

    text = PLACEHOLDER.sub(substitute, template.read_text())

    if missing:
        sys.exit(f"render.py: unresolved placeholders: {', '.join(sorted(set(missing)))}")

    if out:
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(text)
        print(out)
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
