# Gin

An offline iPad learning app for young children. Free, no ads, no in-app
purchases, no accounts, and no network calls of any kind.

Store listing name: **Gin: Learning for Toddlers**
Target: App Store **Kids Category**, age band *5 and under*.

## Running it

```bash
./setup.sh
```

That generates `Gin.xcodeproj` from `project.yml` with XcodeGen. The project file
is not committed — `project.yml` is the source of truth. Re-run it after pulling,
and any time you add a file.

Open the project, pick any iPad simulator, and run. **Rotate the simulator to
landscape** (⌘→) — the app is landscape-locked, so a portrait simulator renders
it sideways.

### Running on a real iPad

`setup.sh` creates `Signing.xcconfig` from the example on first run. It is
gitignored, because an Apple Development Team ID identifies the developer who
owns it. To run on hardware, put yours in it:

```
DEVELOPMENT_TEAM = YOURTEAMID
```

The Simulator needs nothing there. On a device you will also need **Developer
Mode** enabled (Settings › Privacy & Security › Developer Mode) and to trust the
certificate under Settings › General › VPN & Device Management. A free Apple ID
signs for seven days at a time.

> Speech is silent in the Simulator. The iOS Simulator ships without text-to-speech
> voice assets, so `AVSpeechSynthesizer` produces no audio there. It works on a
> real device. Recorded clips replace synthesis entirely before release.

## Architecture

The whole app is **eight reusable mechanics driven by content authored as JSON**.
Adding a category means adding a `.json` file and an art folder — not a new screen.
This is the decision that makes the project finishable.

```
Gin/
├── project.yml              XcodeGen spec — the source of truth
├── Gin/
│   ├── App/                 GinApp, RootView (home / pack / album)
│   ├── Design/              Theme (tokens), Motion, Shapes, GridFit
│   ├── Models/              Level, LevelParams, Pack, Item, RoundBuilder, NumberWord
│   ├── Services/            ContentLoader, ContentLibrary, AudioService, Haptics,
│   │                        ProgressStore, SettingsStore, UsageTracker
│   ├── Views/
│   │   ├── Components/      ItemTile, PackTile, ArtView, GeometryArtView, FlagView, …
│   │   ├── Mechanics/       One file per mechanic
│   │   └── Screens/         Home, Pack, StickerAlbum, ParentGate, ParentZone, WindDown
│   └── Resources/
│       ├── Packs/           Content, one JSON per category
│       ├── PrivacyInfo.xcprivacy
│       └── Assets.xcassets
└── GinTests/                Logic and content validation
```

### The nine mechanics

| # | Mechanic | What it is |
|---|----------|------------|
| 01 | Discover | Free tap-around. No goal, no way to finish. |
| 02 | Find It | "Where is the cow?" — and, with `promptType` flipped, "which flag is this?" |
| 03 | Match | Pairs. Face-up at Little (matching), face-down above it (memory). |
| 04 | Drop In | Drag to a silhouette. Enormous snap radius. |
| 05 | Count & Tap | Tap each object once. Teaches one-to-one correspondence. |
| 06 | Hear It | A sound plays, pick what made it. Hidden until real recordings exist. |
| 07 | Sticker Album | Open-ended. Drag earned stickers anywhere. |
| 08 | Add & Take Away | Arithmetic, objects before symbols. |
| 09 | Patterns | AB / AAB sequencing. What comes next. |

### Levels

Three levels, chosen by the **parent** behind the parental gate. The child never
sees a level picker and is never asked their age.

| Level | Ages | Choices | Pool | Adds |
|-------|------|---------|------|------|
| Little | 2–3 | 3 | 6 | Animals, Colors, Shapes, Numbers, Vehicles |
| Middle | 3–4 | 4 | 10 | **Letters, Feelings, Opposites**; Match starts hiding cards |
| Big | 4–6 | 4 | 16 | **Math, Flags, Patterns** |

Eleven packs, 12 home tiles at Big — which still fits one landscape screen at
4×3 with tiles well above the touch-target floor. `homeGridAlwaysFits` guards it.

A level does not swap content out. It filters packs by `Pack.minLevel` and hands
each mechanic a `LevelParams`. Difficulty is data, never a `switch` over age.

### Adding a category

1. Write `Gin/Resources/Packs/<id>.json`.
2. Add `<id>` to `ContentLoader.packIdentifiers`.
3. Give it a `color` no other pack uses — there is a test for this.
4. Run `./setup.sh`.

No Swift changes.

## Rules that are not negotiable

These come from the research behind the plan, and code is expected to route
through `Theme` rather than restate them:

- **120pt minimum touch target, 32pt minimum gap.** Nielsen Norman's 2cm floor
  for young children, converted for iPad.
- **No scrolling.** A two-year-old does not know content exists below the fold.
  Everything fits one screen; that is why levels cap the item pool.
- **No failure states.** No score, no timer, no lives. A wrong tap wobbles and
  re-prompts. Nothing is ever marked wrong or removed.
- **Audio first.** Every word is spoken. Text on screen is for the adult and is
  never required to operate anything.
- **Feedback under 100ms, on touch-down.** `onTapGesture` waits for the finger to
  lift; that delay reads as broken. Use `.toddlerTap`.
- **Navigation acts on touch-up** — `.toddlerTap(firesOnTouchDown: false)`. The
  visual pop still fires on touch-down, but deferring the *action* lets a press be
  aborted by sliding off, the way every iOS control works. A preference, not a
  bug fix.
- **Colour identifies a category, and it does not scale past ~8.** The original
  rule was one unique hue each. Eleven categories broke it — there are not eleven
  hues a three-year-old can tell apart, and forcing them puts teal next to sky.
  So colour is now a **family** cue: at most two packs per hue, from related
  domains, with unmistakably different icons. The icon carries identity. Tests
  enforce the two-per-hue ceiling and icon uniqueness.
- **Zero third-party dependencies.** Required by App Store guideline 1.3 — Kids
  Category apps may not send data to third parties. No analytics, ever.

## Status

**Phases 1–5 complete, and Phase 6 done except the parts that need money or a
microphone.** All nine mechanics, eleven content packs, three levels, sticker
album with persistence, parental gate, parent zone, daily limit with wind-down,
privacy manifest, and the app icon. 53 tests passing.

The icon is generated rather than drawn — see `Gin/Resources/Assets.xcassets`.
The generator lives outside the repo; re-render it with a 1024×1024 CoreGraphics
script if you want to change it, and remember `swift file.swift` cannot JIT
CoreGraphics — compile with `swiftc` first.

## Before the App Store

- [ ] Buy one illustration pack, one artist, one license. Record it in
      `LICENSES.md`. Replace every `"kind": "emoji"` with `"kind": "asset"`.
      **Emoji are placeholders and cannot ship.**
- [ ] Artwork for `flag_canada` and `flag_brazil`. Until then `FlagView` draws
      their colour bands as an approximation. The other 18 flags are geometry.
- [ ] Record ~30 mascot lines yourself; commission the vocabulary nouns, the 26
      letter names and ~20 country names from a native-English voice actor. Drop
      them in `Gin/Resources/Audio/<voiceClip>.m4a` and they replace synthesis
      with no code change. **Letters need letter *names*, not phonic sounds** —
      or both, if you want phonics later.
- [ ] Record the animal and vehicle sound effects. **Hear It stays hidden until
      they exist** — the mechanic is meaningless when every "sound" is a
      synthesized word.
- [x] App icon — a white star on a warm gradient, 1024×1024, opaque, square
      corners for iOS to mask.
- [ ] Host a privacy policy; put the URL in App Store Connect.
- [ ] Reserve the listing name, since bare "gin" collides with gin rummy and
      cocktail apps in search.

## Tests

```bash
xcodebuild -project Gin.xcodeproj -scheme Gin \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4)' test
```

They cover the logic that is invisible when it breaks: that a Find It question
always contains its own answer, that arithmetic never goes negative or asks to
subtract more than there is, that a two-year-old cannot reach Math or Flags, that
no two packs share a colour, and that progress survives a relaunch.
