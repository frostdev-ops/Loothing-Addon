#!/usr/bin/env python3
"""Decode Loothing settings and loot export strings.

Settings exports are Base64-encoded raw-DEFLATE payloads containing the
custom Loolib serializer format. Loot exports are Base64-encoded zlib
payloads with the ``LOOTHING:1:`` prefix containing JSON.

These formats are encoded/compressed for transport. They are not encrypted.
"""

from __future__ import annotations

import argparse
import base64
import json
import math
import sys
import zlib
from typing import Any


LOOT_PREFIX = "LOOTHING:1:"
MARKER = "^"
ESCAPE = "\x01"
UNESCAPE = {
    "\x01": "\x01",
    "\x02": "\x02",
    "\x03": "\x03",
    "\x04": "\x04",
    "\x05": "^",
}


class DecodeError(ValueError):
    """Raised when an export string cannot be decoded."""


class LoolibSerializerParser:
    def __init__(self, text: str) -> None:
        self.text = text
        self.pos = 0

    def parse(self) -> list[Any]:
        if len(self.text) < 2:
            raise DecodeError("Serialized payload is too short")
        if not self.text.startswith("^1"):
            raise DecodeError("Unsupported serializer header")

        self.pos = 2
        values = []
        while self.pos < len(self.text):
            values.append(self._parse_value())
        return values

    def _parse_value(self) -> Any:
        marker = self._read_char()
        if marker != MARKER:
            raise DecodeError("Expected serializer marker")

        tag = self._read_char()
        if tag == "S":
            return self._read_until_marker()
        if tag == "N":
            return int(self._read_until_marker())
        if tag == "F":
            value = float(self._read_until_marker())
            if self._read_char() != MARKER or self._read_char() != "f":
                raise DecodeError("Invalid float terminator")
            return value
        if tag == "T":
            return self._parse_table()
        if tag == "B":
            return True
        if tag == "b":
            return False
        if tag == "Z":
            return None
        if tag == "I":
            return math.inf
        if tag == "i":
            return -math.inf
        raise DecodeError(f"Unknown serializer tag: {tag!r}")

    def _parse_table(self) -> dict[Any, Any]:
        table: dict[Any, Any] = {}
        while True:
            if self._peek_char() != MARKER:
                raise DecodeError("Expected marker while parsing table")
            if self._peek_char(1) == "t":
                self.pos += 2
                return table
            key = self._parse_value()
            value = self._parse_value()
            table[key] = value

    def _read_until_marker(self) -> str:
        out: list[str] = []
        while self.pos < len(self.text):
            ch = self.text[self.pos]
            if ch == MARKER:
                break
            if ch == ESCAPE:
                self.pos += 1
                if self.pos >= len(self.text):
                    raise DecodeError("Incomplete escape sequence")
                escaped = self.text[self.pos]
                out.append(UNESCAPE.get(escaped, escaped))
                self.pos += 1
                continue
            out.append(ch)
            self.pos += 1
        return "".join(out)

    def _peek_char(self, offset: int = 0) -> str | None:
        idx = self.pos + offset
        if idx >= len(self.text):
            return None
        return self.text[idx]

    def _read_char(self) -> str:
        if self.pos >= len(self.text):
            raise DecodeError("Unexpected end of serialized payload")
        ch = self.text[self.pos]
        self.pos += 1
        return ch


def table_to_jsonable(value: Any) -> Any:
    if isinstance(value, dict):
        if _is_dense_array(value):
            return [table_to_jsonable(value[index]) for index in range(1, len(value) + 1)]

        result: dict[str, Any] = {}
        for key, inner in value.items():
            result[_key_to_string(key)] = table_to_jsonable(inner)
        return result

    if isinstance(value, list):
        return [table_to_jsonable(item) for item in value]

    return value


def _is_dense_array(value: dict[Any, Any]) -> bool:
    if not value:
        return False
    if not all(isinstance(key, int) and key > 0 for key in value):
        return False
    size = len(value)
    return set(value.keys()) == set(range(1, size + 1))


def _key_to_string(key: Any) -> str:
    if isinstance(key, str):
        return key
    if key is None:
        return "null"
    if key is True:
        return "true"
    if key is False:
        return "false"
    return str(key)


def decode_settings(export_string: str) -> Any:
    cleaned = "".join(export_string.split())
    if not cleaned:
        raise DecodeError("Empty settings export string")

    try:
        compressed = base64.b64decode(cleaned, validate=True)
    except Exception as exc:  # noqa: BLE001
        raise DecodeError(f"Invalid Base64 settings export: {exc}") from exc

    try:
        serialized = zlib.decompress(compressed, -zlib.MAX_WBITS).decode("latin1")
    except Exception as exc:  # noqa: BLE001
        raise DecodeError(f"Could not inflate settings export: {exc}") from exc

    values = LoolibSerializerParser(serialized).parse()
    if len(values) != 1:
        raise DecodeError(f"Expected one top-level settings payload, found {len(values)} values")

    return table_to_jsonable(values[0])


def decode_loot(export_string: str) -> Any:
    text = export_string.strip()
    if not text.startswith(LOOT_PREFIX):
        raise DecodeError("Loot export must start with LOOTHING:1:")

    encoded = text[len(LOOT_PREFIX):]
    try:
        compressed = base64.b64decode(encoded, validate=True)
    except Exception as exc:  # noqa: BLE001
        raise DecodeError(f"Invalid Base64 loot export: {exc}") from exc

    try:
        payload = zlib.decompress(compressed).decode("utf-8")
    except Exception as exc:  # noqa: BLE001
        raise DecodeError(f"Could not inflate loot export: {exc}") from exc

    try:
        return json.loads(payload)
    except json.JSONDecodeError as exc:
        raise DecodeError(f"Decoded loot payload is not valid JSON: {exc}") from exc


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Decode Loothing settings or compact loot export strings. "
            "These exports are encoded/compressed, not encrypted."
        )
    )
    parser.add_argument(
        "export_string",
        nargs="?",
        help="Export string to decode. If omitted, stdin is used.",
    )
    parser.add_argument(
        "--type",
        choices=("auto", "settings", "loot"),
        default="auto",
        dest="export_type",
        help="Force export type instead of auto-detecting from the string.",
    )
    return parser.parse_args()


def read_input(args: argparse.Namespace) -> str:
    if args.export_string:
        return args.export_string
    return sys.stdin.read()


def detect_type(export_string: str) -> str:
    return "loot" if export_string.strip().startswith(LOOT_PREFIX) else "settings"


def main() -> int:
    args = parse_args()
    raw = read_input(args)
    if not raw.strip():
        print("No export string provided.", file=sys.stderr)
        return 1

    export_type = args.export_type
    if export_type == "auto":
        export_type = detect_type(raw)

    try:
        payload = decode_loot(raw) if export_type == "loot" else decode_settings(raw)
    except DecodeError as exc:
        print(str(exc), file=sys.stderr)
        return 2

    print(json.dumps(payload, indent=2, sort_keys=True, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
