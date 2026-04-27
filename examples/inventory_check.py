#!/usr/bin/env python3
"""Verify every row in docs/screens.md has a matching PNG in snapshots/, and vice versa.

Run from project root after `swift run SnapshotTool`. Exits non-zero on mismatch.
Robust to table separator rows (---) and extra columns.
"""
import pathlib
import sys


def main() -> int:
    inv: list[str] = []
    for line in pathlib.Path("docs/screens.md").read_text().splitlines():
        if not line.strip().startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if not cells or not cells[0] or set(cells[0]) <= set("- "):
            continue
        if cells[0].lower() == "name":
            continue
        inv.append(cells[0])

    shots = sorted(p.stem for p in pathlib.Path("snapshots").glob("*.png"))
    missing = sorted(set(inv) - set(shots))
    extra = sorted(set(shots) - set(inv))

    if missing:
        print("missing PNG:", *missing, sep="\n  ")
        return 1
    if extra:
        print("extra PNG (no inventory row):", *extra, sep="\n  ")
        return 1

    print(f"OK — {len(inv)} inventory rows match {len(shots)} PNGs")
    return 0


if __name__ == "__main__":
    sys.exit(main())
