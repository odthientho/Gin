#!/usr/bin/env python3
"""Generates Gin's writing pack: the stroke paths a child traces.

Run from the repo root:

    python3 Tools/generate_writing_pack.py

Why this is hand-authored rather than extracted from a font
-----------------------------------------------------------
A font gives you a glyph *outline*. Tracing an outline is not writing: the
outline of "O" is two concentric circles, and the outline of "I" is a rectangle.
What handwriting practice needs is the **centerline** — the path a pen actually
travels — split into strokes, in the order a child is taught to draw them, each
starting where they are taught to start.

That is pedagogy, not typography, so it is authored by hand here and emitted as
data. Coordinates are normalized to a 0...1 box with the origin at top-left, so
the app can render them at any size.
"""

import json
import math
from pathlib import Path

# Writing guides. L/R are the side walls, T/B the cap and baseline.
L, R = 0.22, 0.78
T, B = 0.10, 0.90
MX, MY = 0.50, 0.50


def line(start, end, n=10):
    """Samples a straight segment. Enough points that coverage checking is even."""
    (x0, y0), (x1, y1) = start, end
    return [
        (x0 + (x1 - x0) * i / (n - 1), y0 + (y1 - y0) * i / (n - 1))
        for i in range(n)
    ]


def arc(cx, cy, rx, ry, deg_from, deg_to, n=22):
    """Samples an elliptical arc.

    Angles are in degrees with y pointing *down*, so increasing angle sweeps
    clockwise on screen. 0 is the right-hand point, 90 the bottom, -90 the top.
    """
    return [
        (
            cx + rx * math.cos(math.radians(deg_from + (deg_to - deg_from) * i / (n - 1))),
            cy + ry * math.sin(math.radians(deg_from + (deg_to - deg_from) * i / (n - 1))),
        )
        for i in range(n)
    ]


def joined(*segments):
    """Concatenates segments into one continuous stroke, dropping seam duplicates."""
    out = []
    for segment in segments:
        if out and math.dist(out[-1], segment[0]) < 1e-6:
            out.extend(segment[1:])
        else:
            out.extend(segment)
    return out


# ---------------------------------------------------------------------------
# Pre-writing strokes
#
# The actual prerequisites for letter formation, and the only part of this pack
# a two- or three-year-old can really do. Letters come years later.
# ---------------------------------------------------------------------------

PRE_STROKES = {
    "down":   ("Line down",   [line((MX, T), (MX, B))]),
    "across": ("Line across", [line((L, MY), (R, MY))]),
    "round":  ("Circle",      [arc(MX, MY, 0.30, 0.34, -90, 270)]),
    "cross":  ("Cross",       [line((MX, T), (MX, B)), line((L, MY), (R, MY))]),
}

# ---------------------------------------------------------------------------
# Uppercase letters
#
# Uppercase only, and deliberately: capitals are made of straight lines and
# simple arcs, all starting from the top, which is why every handwriting
# curriculum starts there rather than with lowercase.
# ---------------------------------------------------------------------------

LETTERS = {
    "A": [line((L, B), (MX, T)), line((MX, T), (R, B)), line((0.31, 0.62), (0.69, 0.62))],
    "B": [
        line((L, T), (L, B)),
        arc(L, (T + MY) / 2, 0.30, (MY - T) / 2, -90, 90),
        arc(L, (MY + B) / 2, 0.32, (B - MY) / 2, -90, 90),
    ],
    "C": [arc(MX, MY, 0.28, 0.40, -60, -300)],
    "D": [line((L, T), (L, B)), arc(L, MY, 0.34, (B - T) / 2, -90, 90)],
    "E": [
        line((L, T), (L, B)),
        line((L, T), (R, T)),
        line((L, MY), (0.70, MY)),
        line((L, B), (R, B)),
    ],
    "F": [line((L, T), (L, B)), line((L, T), (R, T)), line((L, MY), (0.68, MY))],
    "G": [arc(MX, MY, 0.28, 0.40, -60, -360), line((MX + 0.28, MY), (0.60, MY))],
    "H": [line((L, T), (L, B)), line((R, T), (R, B)), line((L, MY), (R, MY))],
    "I": [line((MX, T), (MX, B))],
    "J": [joined(line((0.62, T), (0.62, 0.66)), arc(0.46, 0.66, 0.16, 0.20, 0, 90))],
    "K": [line((L, T), (L, B)), line((R, T), (L, 0.52)), line((L, 0.52), (R, B))],
    "L": [line((L, T), (L, B)), line((L, B), (R, B))],
    "M": [
        line((L, B), (L, T)),
        line((L, T), (MX, 0.58)),
        line((MX, 0.58), (R, T)),
        line((R, T), (R, B)),
    ],
    "N": [line((L, B), (L, T)), line((L, T), (R, B)), line((R, B), (R, T))],
    "O": [arc(MX, MY, 0.28, 0.40, -90, 270)],
    "P": [line((L, T), (L, B)), arc(L, (T + MY) / 2, 0.30, (MY - T) / 2, -90, 90)],
    "Q": [arc(MX, MY, 0.28, 0.40, -90, 270), line((0.62, 0.70), (0.80, 0.92))],
    "R": [
        line((L, T), (L, B)),
        arc(L, (T + MY) / 2, 0.30, (MY - T) / 2, -90, 90),
        line((L, MY), (R, B)),
    ],
    # Hand-plotted: an S built from two arcs never looks like an S.
    "S": [[
        (0.72, 0.22), (0.63, 0.14), (0.47, 0.12), (0.34, 0.19), (0.31, 0.31),
        (0.39, 0.40), (0.53, 0.46), (0.66, 0.53), (0.72, 0.64), (0.68, 0.78),
        (0.54, 0.87), (0.37, 0.87), (0.27, 0.79),
    ]],
    "T": [line((L, T), (R, T)), line((MX, T), (MX, B))],
    "U": [joined(
        line((L, T), (L, 0.62)),
        arc(MX, 0.62, MX - L, 0.26, 180, 0),
        line((R, 0.62), (R, T)),
    )],
    "V": [line((L, T), (MX, B)), line((MX, B), (R, T))],
    "W": [
        line((L, T), (0.36, B)),
        line((0.36, B), (MX, 0.42)),
        line((MX, 0.42), (0.64, B)),
        line((0.64, B), (R, T)),
    ],
    "X": [line((L, T), (R, B)), line((R, T), (L, B))],
    "Y": [line((L, T), (MX, 0.54)), line((R, T), (MX, 0.54)), line((MX, 0.54), (MX, B))],
    "Z": [line((L, T), (R, T)), line((R, T), (L, B)), line((L, B), (R, B))],
}

# ---------------------------------------------------------------------------
# Digits
# ---------------------------------------------------------------------------

DIGITS = {
    "0": [arc(MX, MY, 0.24, 0.40, -90, 270)],
    # No flag and no base serif. Both are extra strokes a beginner does not need.
    "1": [line((MX, T), (MX, B))],
    "2": [[
        (0.30, 0.26), (0.35, 0.16), (0.49, 0.11), (0.63, 0.16), (0.70, 0.28),
        (0.64, 0.42), (0.49, 0.56), (0.32, 0.72), (0.27, 0.88), (0.74, 0.88),
    ]],
    "3": [[
        (0.31, 0.18), (0.42, 0.11), (0.58, 0.13), (0.67, 0.24), (0.60, 0.36),
        (0.46, 0.42), (0.61, 0.48), (0.70, 0.61), (0.66, 0.77), (0.52, 0.88),
        (0.36, 0.86), (0.28, 0.78),
    ]],
    "4": [line((0.62, T), (0.26, 0.60)), line((0.26, 0.60), (0.76, 0.60)),
          line((0.62, T), (0.62, B))],
    "5": [
        joined(line((0.34, T), (0.34, 0.44)), [
            (0.34, 0.44), (0.48, 0.40), (0.62, 0.45), (0.70, 0.58),
            (0.65, 0.76), (0.50, 0.88), (0.34, 0.85),
        ]),
        line((0.34, T), (0.70, T)),
    ],
    "6": [[
        (0.66, 0.16), (0.52, 0.11), (0.38, 0.20), (0.30, 0.38), (0.28, 0.58),
        (0.33, 0.77), (0.45, 0.88), (0.59, 0.86), (0.68, 0.75), (0.67, 0.61),
        (0.57, 0.51), (0.42, 0.50), (0.32, 0.58),
    ]],
    "7": [line((0.28, T), (0.74, T)), line((0.74, T), (0.42, B))],
    # Two stacked loops rather than one crossing path: far easier to trace, and
    # it is how an 8 is taught.
    "8": [arc(MX, 0.30, 0.19, 0.19, -90, 270), arc(MX, 0.69, 0.21, 0.21, -90, 270)],
    "9": [arc(MX, 0.34, 0.22, 0.23, -90, 270), line((MX + 0.22, 0.34), (MX + 0.22, B))],
}


def item(item_id, name, strokes, tags):
    return {
        "id": item_id,
        "name": name,
        "art": {"kind": "geometry", "value": f"letter:{name}"},
        "voiceClip": item_id,
        "tags": tags,
        "trace": {
            "strokes": [
                {"points": [{"x": round(x, 4), "y": round(y, 4)} for (x, y) in stroke]}
                for stroke in strokes
            ]
        },
    }


items = []

for key, (name, strokes) in PRE_STROKES.items():
    items.append({
        **item(f"pre_{key}", name, strokes, ["prewriting"]),
        # A pre-stroke has no glyph, so its tile shows the mark it teaches
        # rather than a placeholder box.
        "art": {"kind": "geometry", "value": {
            "down": "letter:|", "across": "letter:—",
            "round": "circle", "cross": "letter:+",
        }[key]},
    })

for glyph, strokes in LETTERS.items():
    items.append(item(f"write_{glyph.lower()}", glyph, strokes, ["letter"]))

for digit, strokes in DIGITS.items():
    items.append(item(f"write_{digit}", digit, strokes, ["digit"]))

pack = {
    "id": "writing",
    "title": "Writing",
    "color": "ink",
    "icon": "✏️",
    "minLevel": 1,
    "mechanics": ["trace"],
    "items": items,
}

out = Path(__file__).resolve().parent.parent / "Gin" / "Resources" / "Packs" / "writing.json"
out.write_text(json.dumps(pack, indent=2, ensure_ascii=False) + "\n")

strokes_total = sum(len(i["trace"]["strokes"]) for i in items)
points_total = sum(len(s["points"]) for i in items for s in i["trace"]["strokes"])
print(f"Wrote {out.relative_to(out.parents[3])}")
print(f"  {len(items)} glyphs, {strokes_total} strokes, {points_total} points")
