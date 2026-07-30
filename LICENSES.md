# Third-party assets

Everything used in Gin that someone else made, and the terms it is used under.

**Keep this current.** In two years nobody will remember where a file came from,
and "we think it was fine" is not an answer if it is ever asked.

## Code

None. Gin has no third-party dependencies — no packages, no SDKs, no vendored
source. This is a hard rule, not a coincidence: App Store guideline 1.3 forbids
a Kids Category app from sending data off-device, and having nothing installed
that could is the only guarantee that survives a careless future commit.

## Fonts

SF Pro Rounded — Apple system font, used via `Font.system(design: .rounded)`.
Covered by the Xcode / Apple Developer Program license for use in an app running
on Apple platforms.

## Icons

SF Symbols — Apple, same terms. Used for all UI chrome (home, back, speaker,
arrows).

## Illustrations

> **Not yet purchased.** Every item currently rendering as `"kind": "emoji"` in
> `Gin/Resources/Packs/*.json` is a development placeholder. Emoji are not
> licensed for redistribution as app content and **must not ship**.

When the pack is bought, record it here:

| Asset set | Source | Artist | License | Purchased | Covers app use? | No "secondary element" clause? |
| --------- | ------ | ------ | ------- | --------- | --------------- | ------------------------------ |
| _(pending)_ | | | | | | |

Requirements for whatever is bought, in priority order:

1. **One pack, one artist.** Style consistency across ~70 illustrations is the
   whole point; assembling free icons from five sources looks exactly as cheap as
   it is.
2. **The license must permit use in software, with no reproduction cap.**
3. **No "secondary element" restriction.** Subscription sites such as Flaticon
   permit app use but require their art to be a *secondary* element of the
   design. In a flashcard app the illustration **is** the content, which puts
   that use outside the license. Prefer a one-time marketplace purchase whose
   terms cover software outright.

## Flag artwork

`flag_canada` and `flag_brazil` are declared with `assetName` in
`flags.json` but have no asset yet — a maple leaf and a banner with a celestial
globe are not reasonably hand-codable. `FlagView` falls back to drawing their
colour bands, which is an approximation, not the real flag. Buy or commission
these two before release.

The other 18 flags are geometry defined in `flags.json` and involve no
third-party asset at all.

## Audio

> **Not yet recorded.** All speech is currently `AVSpeechSynthesizer` at runtime,
> which ships nothing and licenses nothing.

| Track | Source | Terms |
| ----- | ------ | ----- |
| ~30 mascot lines | To be recorded by the app's author | Owned outright |
| ~120 vocabulary nouns | To be commissioned | Needs full buyout, all media, perpetual |
| ~20 country names | To be commissioned | Same |
| Animal / vehicle sound effects | To be sourced | Must permit embedding in software |

When commissioning voice work, get a **full buyout in writing**. A per-territory
or time-limited voice license on an App Store app is a problem that surfaces
years later, at the worst possible moment.
