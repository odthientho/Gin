#!/usr/bin/env python3
"""Generates Gin's flags pack: all 195 countries.

Run from the repo root:

    python3 Tools/generate_flags_pack.py

Where this data comes from
--------------------------
The country list (names and ISO 3166-1 alpha-2 codes) was taken from
worldometers.info/geography/flags-of-the-world/ on 2026-07-30 — 195 countries:
the 193 UN members plus the Holy See and the State of Palestine.

The flag *images* are deliberately not theirs. Bundling a site's image files is
a licensing problem; instead each ISO code becomes the platform's own emoji flag
(two regional-indicator characters — "vn" renders as the Vietnamese flag).
Apple's emoji artwork ships with iOS, costs nothing in the bundle, and renders
through the existing emoji art path with no new code.

A handful of names are normalized for *speech*, because every country name in
Gin is spoken aloud to a child who cannot read: "&" becomes "and", "St."
becomes "Saint", and "Czech Republic (Czechia)" becomes "Czechia". The list is
otherwise exactly as published.

Why the pack sets `poolSize`
----------------------------
Level params cap a pack's item pool (16 at Big) so a child meets a handful of
animals rather than all of them. Flags is the one pack where the whole point is
breadth, so it overrides the cap and puts all 195 in rotation.
"""

import json
from pathlib import Path

# (iso_code, name) — worldometers order, which is theirs alphabetically.
COUNTRIES = [
    ("af", "Afghanistan"), ("al", "Albania"), ("dz", "Algeria"), ("ad", "Andorra"),
    ("ao", "Angola"), ("ag", "Antigua and Barbuda"), ("ar", "Argentina"),
    ("am", "Armenia"), ("au", "Australia"), ("at", "Austria"), ("az", "Azerbaijan"),
    ("bs", "Bahamas"), ("bh", "Bahrain"), ("bd", "Bangladesh"), ("bb", "Barbados"),
    ("by", "Belarus"), ("be", "Belgium"), ("bz", "Belize"), ("bj", "Benin"),
    ("bt", "Bhutan"), ("bo", "Bolivia"), ("ba", "Bosnia and Herzegovina"),
    ("bw", "Botswana"), ("br", "Brazil"), ("bn", "Brunei"), ("bg", "Bulgaria"),
    ("bf", "Burkina Faso"), ("bi", "Burundi"), ("cv", "Cabo Verde"),
    ("kh", "Cambodia"), ("cm", "Cameroon"), ("ca", "Canada"),
    ("cf", "Central African Republic"), ("td", "Chad"), ("cl", "Chile"),
    ("cn", "China"), ("co", "Colombia"), ("km", "Comoros"), ("cg", "Congo"),
    ("cr", "Costa Rica"), ("ci", "Côte d'Ivoire"), ("hr", "Croatia"),
    ("cu", "Cuba"), ("cy", "Cyprus"), ("cz", "Czechia"), ("dk", "Denmark"),
    ("dj", "Djibouti"), ("dm", "Dominica"), ("do", "Dominican Republic"),
    ("kp", "North Korea"), ("cd", "DR Congo"), ("ec", "Ecuador"), ("eg", "Egypt"),
    ("sv", "El Salvador"), ("gq", "Equatorial Guinea"), ("er", "Eritrea"),
    ("ee", "Estonia"), ("sz", "Eswatini"), ("et", "Ethiopia"), ("fj", "Fiji"),
    ("fi", "Finland"), ("fr", "France"), ("ga", "Gabon"), ("gm", "Gambia"),
    ("ge", "Georgia"), ("de", "Germany"), ("gh", "Ghana"), ("gr", "Greece"),
    ("gd", "Grenada"), ("gt", "Guatemala"), ("gn", "Guinea"),
    ("gw", "Guinea-Bissau"), ("gy", "Guyana"), ("ht", "Haiti"), ("va", "Holy See"),
    ("hn", "Honduras"), ("hu", "Hungary"), ("is", "Iceland"), ("in", "India"),
    ("id", "Indonesia"), ("ir", "Iran"), ("iq", "Iraq"), ("ie", "Ireland"),
    ("il", "Israel"), ("it", "Italy"), ("jm", "Jamaica"), ("jp", "Japan"),
    ("jo", "Jordan"), ("kz", "Kazakhstan"), ("ke", "Kenya"), ("ki", "Kiribati"),
    ("kw", "Kuwait"), ("kg", "Kyrgyzstan"), ("la", "Laos"), ("lv", "Latvia"),
    ("lb", "Lebanon"), ("ls", "Lesotho"), ("lr", "Liberia"), ("ly", "Libya"),
    ("li", "Liechtenstein"), ("lt", "Lithuania"), ("lu", "Luxembourg"),
    ("mg", "Madagascar"), ("mw", "Malawi"), ("my", "Malaysia"), ("mv", "Maldives"),
    ("ml", "Mali"), ("mt", "Malta"), ("mh", "Marshall Islands"),
    ("mr", "Mauritania"), ("mu", "Mauritius"), ("mx", "Mexico"),
    ("fm", "Micronesia"), ("md", "Moldova"), ("mc", "Monaco"), ("mn", "Mongolia"),
    ("me", "Montenegro"), ("ma", "Morocco"), ("mz", "Mozambique"),
    ("mm", "Myanmar"), ("na", "Namibia"), ("nr", "Nauru"), ("np", "Nepal"),
    ("nl", "Netherlands"), ("nz", "New Zealand"), ("ni", "Nicaragua"),
    ("ne", "Niger"), ("ng", "Nigeria"), ("mk", "North Macedonia"),
    ("no", "Norway"), ("om", "Oman"), ("pk", "Pakistan"), ("pw", "Palau"),
    ("pa", "Panama"), ("pg", "Papua New Guinea"), ("py", "Paraguay"),
    ("pe", "Peru"), ("ph", "Philippines"), ("pl", "Poland"), ("pt", "Portugal"),
    ("qa", "Qatar"), ("ro", "Romania"), ("ru", "Russia"), ("rw", "Rwanda"),
    ("kn", "Saint Kitts and Nevis"), ("lc", "Saint Lucia"), ("ws", "Samoa"),
    ("sm", "San Marino"), ("st", "Sao Tome and Principe"), ("sa", "Saudi Arabia"),
    ("sn", "Senegal"), ("rs", "Serbia"), ("sc", "Seychelles"),
    ("sl", "Sierra Leone"), ("sg", "Singapore"), ("sk", "Slovakia"),
    ("si", "Slovenia"), ("sb", "Solomon Islands"), ("so", "Somalia"),
    ("za", "South Africa"), ("kr", "South Korea"), ("ss", "South Sudan"),
    ("es", "Spain"), ("lk", "Sri Lanka"),
    ("vc", "Saint Vincent and the Grenadines"), ("ps", "State of Palestine"),
    ("sd", "Sudan"), ("sr", "Suriname"), ("se", "Sweden"), ("ch", "Switzerland"),
    ("sy", "Syria"), ("tj", "Tajikistan"), ("tz", "Tanzania"), ("th", "Thailand"),
    ("tl", "Timor-Leste"), ("tg", "Togo"), ("to", "Tonga"),
    ("tt", "Trinidad and Tobago"), ("tn", "Tunisia"), ("tr", "Turkey"),
    ("tm", "Turkmenistan"), ("tv", "Tuvalu"), ("ae", "United Arab Emirates"),
    ("gb", "United Kingdom"), ("us", "United States"), ("ug", "Uganda"),
    ("ua", "Ukraine"), ("uy", "Uruguay"), ("uz", "Uzbekistan"), ("vu", "Vanuatu"),
    ("ve", "Venezuela"), ("vn", "Vietnam"), ("ye", "Yemen"), ("zm", "Zambia"),
    ("zw", "Zimbabwe"),
]

assert len(COUNTRIES) == 195, f"expected 195 countries, have {len(COUNTRIES)}"
assert len({c for c, _ in COUNTRIES}) == 195, "duplicate ISO code"


def emoji_flag(iso: str) -> str:
    """Two regional-indicator characters; the platform renders them as the flag."""
    return "".join(chr(0x1F1E6 + ord(c) - ord("a")) for c in iso)


def slug(name: str) -> str:
    """Stable ASCII id. Must keep producing the ids stickers were earned under."""
    out = []
    for ch in name.lower().replace("'", "").replace("-", " "):
        if ch == "ô":
            out.append("o")
        elif ch.isalnum():
            out.append(ch)
        elif ch == " ":
            out.append("_")
    return "".join(out)


items = [
    {
        "id": slug(name),
        "name": name,
        "art": {"kind": "emoji", "value": emoji_flag(iso)},
        "voiceClip": slug(name),
        "tags": [iso],
    }
    for iso, name in COUNTRIES
]

assert len({i["id"] for i in items}) == 195, "duplicate item id"

pack = {
    "id": "flags",
    "title": "Flags",
    "color": "teal",
    "icon": "🚩",
    "minLevel": 3,
    # No Discover: a no-scroll grid cannot hold 195 tiles. The pack opens
    # straight into Find It, which is the actual flags experience — see a flag
    # and pick the country, or hear a country and pick the flag.
    "mechanics": ["findIt", "match"],
    # Overrides the per-level pool cap. Flags is the one pack whose point is
    # breadth, so all 195 stay in rotation.
    "poolSize": 195,
    # Enables the flag-first direction: show a flag, ask for the country.
    "visualPrompt": True,
    "items": items,
}

out = Path(__file__).resolve().parent.parent / "Gin" / "Resources" / "Packs" / "flags.json"
out.write_text(json.dumps(pack, indent=2, ensure_ascii=False) + "\n")
print(f"Wrote {out.name}: {len(items)} countries")
