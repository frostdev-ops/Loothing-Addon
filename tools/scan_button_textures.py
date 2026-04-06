#!/usr/bin/env python3
"""Scan a WoW Interface/AddOns tree for button-like textures.

This is a development utility, not an in-game runtime feature. WoW addons
cannot freely enumerate the filesystem at runtime, so a generated manifest is
the practical way to offer a browsable texture catalog in-game.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


TEXTURE_RE = re.compile(
    r"(UI-(Panel|DialogBox)-Button|Glue-Panel-Button|BlueGoldButton|"
    r"SquareButtonTextures|128RedButton|128GoldRedButton|"
    r"ButtonHilight-(Square|Round)|UI-Button-Borders2?)",
    re.IGNORECASE,
)
EXTENSIONS = {".blp", ".tga", ".png"}


def scan(root: Path) -> list[dict[str, str]]:
    results: list[dict[str, str]] = []
    for path in root.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in EXTENSIONS:
            continue
        if not TEXTURE_RE.search(path.name):
            continue
        relative = path.relative_to(root)
        parts = relative.parts
        addon = parts[0] if parts else ""
        results.append(
            {
                "addon": addon,
                "name": path.stem,
                "path": str(path),
                "relative_path": str(relative).replace("/", "\\"),
            }
        )
    results.sort(key=lambda row: (row["addon"].lower(), row["name"].lower(), row["relative_path"].lower()))
    return results


def render_lua(entries: list[dict[str, str]]) -> str:
    body = ["return {"]
    for entry in entries:
        body.append(
            '    { addon = "%s", name = "%s", relativePath = "%s" },'
            % (
                entry["addon"].replace("\\", "\\\\").replace('"', '\\"'),
                entry["name"].replace("\\", "\\\\").replace('"', '\\"'),
                entry["relative_path"].replace("\\", "\\\\").replace('"', '\\"'),
            )
        )
    body.append("}")
    return "\n".join(body)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("addons_dir", type=Path, help="Path to Interface/AddOns")
    parser.add_argument("--format", choices=("json", "lua"), default="json")
    args = parser.parse_args()

    entries = scan(args.addons_dir)
    if args.format == "lua":
        print(render_lua(entries))
    else:
        print(json.dumps(entries, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
