# deltasleep — Implementation plan

Sleep-debt tracker for iOS: a 14-night rolling debt figure, surfaced primarily as a
Home Screen widget, backed by Apple Health sleep data.

**Source of truth for design:** [`docs/design/mockup-liquid-glass-v02.html`](design/mockup-liquid-glass-v02.html)
(direction 02, "Du verre teinté, pas un feu tricolore").

**Stack:** Swift / SwiftUI, WidgetKit, HealthKit. Native iOS only.

**Status:** planning only. No implementation has started.

**Tracking:** every phase below has an issue — [#1](https://github.com/mikedotJS/deltasleep/issues/1) S1,
[#2](https://github.com/mikedotJS/deltasleep/issues/2) S2,
[#3](https://github.com/mikedotJS/deltasleep/issues/3) P0,
[#4](https://github.com/mikedotJS/deltasleep/issues/4) P1,
[#5](https://github.com/mikedotJS/deltasleep/issues/5) P2,
[#6](https://github.com/mikedotJS/deltasleep/issues/6) P3,
[#7](https://github.com/mikedotJS/deltasleep/issues/7) P4,
[#8](https://github.com/mikedotJS/deltasleep/issues/8) P5,
[#9](https://github.com/mikedotJS/deltasleep/issues/9) P6,
[#10](https://github.com/mikedotJS/deltasleep/issues/10) P7,
[#11](https://github.com/mikedotJS/deltasleep/issues/11) P8,
[#12](https://github.com/mikedotJS/deltasleep/issues/12) P9,
[#13](https://github.com/mikedotJS/deltasleep/issues/13) P10.

---

## 1. What the mockup already decides

These are not open questions — they are pinned by the handoff and should be treated as
requirements.

| Decision | Value |
|---|---|
| Debt window | Rolling 14 nights |
| Colour semantics | Colour encodes the **derivative**, not the level. Green = debt fell vs yesterday, red = debt rose, amber = no delta computable (tonight unmeasured), neutral = no trustworthy reading at all |
| Gauge scale | Mockup renders linear 0 → 20 h (verified: 10 h 26 → 52 %, 13 h 04 → 65 %, 17 h 40 → 88 %). **Superseded** — see §1.1, gauge transfer function |
| Gauge floor | Zero debt still shows a ~1.5 % stub, not an empty track |
| Ghost marker | White tick = *yesterday's* debt on the gauge scale. The fill colour says which side of that tick you landed on |
| Recency weighting | Last night carries **15 %** of the total weight (stated in the mockup copy — and, it turns out, [RISE Science's](https://www.risescience.com/blog/how-much-sleep-debt-do-i-have) own published constant. See §1.1) |
| 14-night strip | Raw encoding, not derivative: bar above axis = slept **more** than need, below = **less**. Last night gets a white dot. Missing nights = thin grey line on the axis |
| Widget families | Small (176², one column) and medium (376×176, split: figure left / strip right) |
| Main screen stats | Tonight, configured need, 14-night average, count of nights without data |
| Deltas on main screen | Two: "since yesterday" and "since Monday" |
| States to support | 7 (see §5, Phase 6) |
| Language | French is the source language |

## 1.1 The debt engine — confirmed against RISE Science's published model

The mockup's numbers imply a weighted formula, not a plain sum: main screen shows need
8 h 00, 14-night average 7 h 15, 1 night without data, debt **13 h 04**, last night
6 h 12. A plain sum of deficits gives `13 nights × 45 min = 9 h 45` — not 13 h 04.

deltasleep's "dette de sommeil" is, deliberately or not, the same metric as
[RISE Science's](https://www.risescience.com/blog/how-much-sleep-debt-do-i-have) sleep
debt — same 14-night window, same "15 % on last night" framing quoted almost verbatim
in both the mockup's `note` copy and RISE's own explainer
([help centre](https://help.risescience.com/hc/en-us/articles/6047219133079-What-is-Sleep-Dept-And-how-to-track-it-with-RISE)).
RISE's copy also confirms the sum framing is wrong: "rather than simply adding up total
hours missed," recent nights are weighted more heavily. Treat RISE's public description
as the spec, tightened by fitting it to the mockup's numbers, and confirm/adjust in
Phase 1 against real data (see the backtest note under the gauge transfer function
below).

**Weights.** Geometric decay with ratio `r ≈ 0.873` puts last night at exactly 15.0 %
of total weight over 14 nights (half-life ≈ 5.1 nights):

```
w_i = r^i / Σ(r^k), k = 0..13        # i = 0 is last night
```

**Scaling.** RISE's own guidance — aim for "≤ 5 h" of debt, since zero is "often
unachievable" — only makes sense if debt is a *magnitude*, not a bounded mean: a bare
weighted-mean deficit tops out at `need` (~8 h), which would make "aim for ≤ 5 h" mean
"sleep at least 3 h a night." Scaling the weighted mean back up by the window length
fixes that, and reproduces the mockup's numbers:

```
debt = 14 × Σ( w_i × nightDeficit_i )
```

Sanity check: weighted mean deficit must be `13 h 04 / 14 = 56 min`. Last night
(deficit 1 h 48) contributes `0.150 × 108 = 16.2 min`; the remaining 85 % of weight
then needs to average 46.8 min — right next to the mockup's stated 45 min overall
average, and `10 h 26 / 14 = 44.7 min/night` matches the green card's 45 min chip
exactly. **`r = 0.873` and `×14` are internally consistent with every number the
mockup shows.**

**Per-night deficit and surplus credit (resolves D2).** RISE frames debt as something
you "pay back" by sleeping in or napping — language that implies surplus nights count.
But *uncapped* credit models sleep as a bank account (physiologically wrong — sleep is
homeostatic, not bankable) and, combined with last night's 2.12× leverage on the
headline (`14 × 0.150`), would let one long night move the figure by hours. Resolution:
surplus reduces `nightDeficit_i` below zero, **capped at −1 h** (i.e. at most 1 h of
credit per night), and the final debt is floored at zero. This lets catch-up sleep
count — RISE's own advice — without letting a single night swing the headline by more
than `14 × 0.150 × 1 h ≈ 2 h 07`. Validate the 1 h cap against the Phase 1 backtest
below; if surplus nights are rare in real data the cap is inert and a hard clamp (no
credit at all) is an equally safe fallback.

**Weight renormalisation over present nights (extends D1).** Weights `w_i` must be
renormalised over nights that actually have data, not silently treated as zero-deficit
when computed against a fixed 14-slot window — otherwise turning off the Watch for a
night *lowers* the debt, since a gap would act as a perfect night. This is what makes
the `×14` scaling gap-invariant, which a plain sum is not.

**Gap nights (extends D3/D8).** When last night specifically is a gap, carry
yesterday's debt forward unchanged rather than recomputing over a shifted window — the
mockup's own amber card shows fill and ghost at the identical 52 %, which is only true
if the calculation didn't advance.

**Trend, not raw delta (extends D1).** Define `Trend` as *last night's sleep vs. the
weighted-average sleep implied by the current weights* (equivalently: debt falls
whenever last night beat the weighted average), not as `debt_today − debt_yesterday`.
The two usually agree, but a raw window-difference can flip colour on a bad night
merely because a worse night 14 days ago rolled *out* of the window — an artifact the
design cannot afford, since colour is the entire signal. As a byproduct this gives a
free, more actionable number than the debt itself: tonight's break-even target. Cross-
checks against the mockup: green card debt 10 h 26 → weighted mean deficit 44.7 min →
break-even 7 h 15, which is exactly the "moyenne sur 14 nuits" already printed on the
main screen; the phone card's 6 h 12 vs. a computed 7 h 04 break-even likewise explains
its rising-red state.

**Freeze trend on a sleep-need change (extends P7).** Changing "besoin réglé" from
8 h 00 to 7 h 30 moves the headline by `14 × 30 min = 7 h` on a settings tap alone.
Trend must come from sleep, not configuration: on a need change, recompute debt but
mark that day's trend `unknown` until the next real night lands.

## 1.2 Gauge transfer function (supersedes the mockup's linear 0–20 h reading)

RISE's own target band (aim for ≤ 5 h, zero often unachievable) tells us where users
actually live: `5 h` of debt is `21 min/night` average deficit, `10 h 26` (the mockup's
own "nominal" card) is `45 min/night`. A linear 0–20 h scale spends its top half on
territory rarely reached and compresses the entire meaningful range — including the
mockup's own reference values — into its bottom third.

Two-segment mapping: **0 → 8 h across the first 60 % of the track, 8 → 24 h across the
remaining 40 %**, both segments linear. This keeps `10 h 26 → 65 %`, matching the
mockup's own drawn position closely enough that the visual design doesn't need to be
re-plotted, while giving real resolution to the 0–8 h band where the 5 h target and
most improvement actually happen. Mark the `5 h` target on the track alongside the
ghost tick — it's a more useful reference than yesterday's value alone, and it's the
number RISE tells users to aim for.

The stored `debt` value is **never** capped — only its gauge mapping saturates above
24 h. Capping the stored value would flatten the derivative the whole design depends
on: two different bad days both pegged at "24 h" would read as no change.

The 8 h breakpoint is a starting point, not a commitment — validate and, if needed,
retune it against Phase 1's fixture/backtest work (see the debt-formula backtest note
above): plot the real debt distribution from Health data and put the breakpoint near
the 75th–80th percentile rather than by inspection.

---

## 2. Open decisions (resolve before or during the phase noted)

| # | Decision | Proposed default | Needed by |
|---|---|---|---|
| D1 | Debt formula | **Resolved, pending backtest — see §1.1.** Geometric weights `r = 0.873`, weights renormalised over present nights, `×14` scaling, gap nights carry yesterday's debt forward, trend defined as last-night-vs-weighted-average (not raw window delta), trend frozen on a sleep-need change | Phase 1 |
| D2 | Are surplus nights allowed to pay down debt? | **Resolved — see §1.1.** Yes, capped: surplus reduces a night's deficit below zero, capped at −1 h/night; total debt floored at 0. Balances RISE's own "pay it back" framing against the ~2 h swing an uncapped night would cause | Phase 1 |
| D3 | Sleep-day boundary | Noon → noon: a sleep session is attributed to the day it *ended* | Phase 2 |
| D4 | Minimum deployment target | **Resolved — iOS 26.** Ships against the real Liquid Glass APIs the design leans on rather than a hand-rolled fallback everywhere; narrows reach, accepted deliberately | Phase 0 |
| D5 | Typography | Mockup uses Inter Tight / Inter. Ship the licensed fonts, or map to SF Pro Rounded / SF Pro with tightened tracking | Phase 4 |
| D6 | Staleness threshold for the "cached" state | 6 h since `computedAt`, or "no new night since the expected wake window" | Phase 3 |
| D7 | "Since Monday" reference | Debt as of 00:00 local on the most recent Monday; hide the chip if the week has <2 measured nights | Phase 1 |
| D8 | Insufficient-history rule | Refuse to show a figure below 14 measured nights, as the mockup does. Confirm the gap-vs-missing interaction (does 13 nights + 1 gap count as sufficient?) | Phase 1 |
| D9 | Localisation scope | FR + EN at launch | Phase 9 |
| D10 | Gauge transfer function | **Resolved, pending backtest — see §1.2.** Two-segment: 0–8 h across the first 60 % of the track, 8–24 h across the remaining 40 %; 5 h target marked on the track; stored debt never capped, only the gauge mapping saturates | Phase 1 (formula), Phase 5 (component) |

---

## 3. Module layout

Local Swift packages so the domain and the design system are testable without a
simulator and reusable by both targets.

```
DeltaSleep.xcodeproj
├─ DeltaSleep            (app target)
├─ DeltaSleepWidget      (widget extension)
└─ Packages/
   ├─ SleepDebtCore      pure Swift: models + debt engine       (no HealthKit, no UI)
   ├─ HealthSleepSource  HealthKit → [Night], behind a protocol
   ├─ SnapshotStore      App Group cache + refresh orchestration
   └─ GlassKit           design tokens + glass surfaces + components
```

Both targets share an App Group. The widget never touches HealthKit: the app computes
and caches a snapshot, the widget renders it. This is what makes the "cached data"
state a first-class state rather than a bug.

### Dependency graph

```
P0 foundation
├── P1 SleepDebtCore ─────────┬─────────────┐
├── P2 HealthSleepSource ─────┤             │
│                             ↓             │
│                        P3 SnapshotStore   │
├── P4 GlassKit ──────────────┬─────────────┤
│                             ↓             ↓
│                        P5 Components ────┐
│                             ↓            ↓
│                    ┌── P6 Widget    P7 Main screen
├── P8 Onboarding ───┘        │            │
│                             └──── P9 Hardening ──── P10 Release
└── S1 / S2 spikes (early, de-risking)
```

---

## 4. Parallelisation

After **P0** lands, three tracks run independently with no shared files:

- **Data track:** P1 → P2 → P3
- **Design track:** S1 → P4 → P5
- **Plumbing track:** P8's HealthKit-authorisation UX research, CI, release config

P6 and P7 are the first real convergence point and can then be built in parallel by
two people. P9 is partly cross-cutting: every UI phase owns its own VoiceOver labels
and Dynamic Type behaviour, and P9 is the sweep that verifies the whole surface.

---

## 5. Phases

### S1 — Spike: how much of this glass survives inside a widget?

**Why first:** the entire visual direction rests on backdrop-blurred glass over the
wallpaper. A widget's content is rendered into a snapshot by the extension, not
composited live against the Home Screen, so a widget almost certainly cannot sample
and blur the wallpaper the way the HTML mockup does with `backdrop-filter`. iOS 26
draws the widget's *container* with system glass, but that is not the same as the
tinted bloom passing *through* the material. If this spike comes back negative, the
widget needs a different — still beautiful — recipe, and that changes P4's API before
anyone writes it.

**Deliverables**

- Throwaway widget rendering: (a) native `glassEffect`-style material, (b) hand-rolled
  gradient + grain + specular stack, (c) both over light and dark wallpapers.
- Screenshots on device, side by side with the mockup.
- Written verdict: what the widget can and cannot do, and the fallback recipe.
- Same check for the grain overlay (`mix-blend-mode: soft-light` has no direct SwiftUI
  equivalent — `.blendMode(.softLight)` on an image overlay is the candidate) and for
  gradient-filled text (`.foregroundStyle(LinearGradient)` on the big numerals).

**Done when:** P4's glass API can be designed against a known answer instead of a hope.
**Timebox:** 1–2 days. Do not fix anything; just learn.

---

### S2 — Spike: HealthKit background delivery reliability for sleep

**Why:** the product's promise is "the number is right when you glance at the widget
after waking". That depends on `HKObserverQuery` + `enableBackgroundDelivery` waking the
app after a sleep session is written, and on the widget refresh budget (roughly 40–70
timeline reloads per day). If delivery is slow or lossy, the staleness UX in P3/P6 has
to carry more weight.

**Deliverables**

- Minimal app that registers an observer on `sleepAnalysis`, logs every wake with a
  timestamp, and calls `WidgetCenter.reloadAllTimelines()`.
- A week of real logs: latency from "Watch syncs the night" to "app woken".
- Verdict on whether the widget can also query HealthKit directly as a backstop.

**Done when:** D6's staleness threshold is chosen from data rather than guessed.
**Timebox:** 1 day of setup, then passive observation while other phases proceed.

---

### P0 — Foundation

**Goal:** an empty but correctly configured project that builds green in CI.

**Scope**

- Xcode project, app target + widget extension target, shared App Group.
- Bundle identifiers, provisioning, HealthKit capability, `NSHealthShareUsageDescription`.
- The four local Swift packages from §3, empty but wired up with test targets.
- `.gitignore`, SwiftFormat + SwiftLint config, `.editorconfig`.
- GitHub Actions: build both targets, run all package tests, run the linter.
- Deployment target: **iOS 26** (**D4**, resolved) — set it in the project config from
  the first commit; no fallback path to build for older iOS.

**Out of scope:** anything visible.

**Done when:** `xcodebuild test` passes on CI for a fresh clone; the widget appears in
the simulator's widget gallery as a blank placeholder.

**Depends on:** nothing. **Blocks:** everything.

---

### P1 — Domain model and debt engine

**Goal:** the whole computation, as pure Swift, fully unit tested, with no HealthKit
and no SwiftUI anywhere near it.

**Scope**

- `Night` (date, time asleep, source, `isGap`), `SleepNeed`, `DebtSnapshot`
  (debt, yesterday's debt, delta since yesterday, delta since Monday, 14-night average,
  gap count, measured-night count, `computedAt`).
- `Trend { falling, rising, flat, unknown }` — computed as last-night-vs-weighted-average,
  not as a raw delta of two window totals (see §1.1) — the thing that drives colour.
- `WidgetState` enum covering all 7 states, computed from a snapshot, so every surface
  derives its state the same way instead of each view re-deriving it.
- The weighted-debt engine per **D1**: geometric weights (`r = 0.873`), renormalised
  over present nights, `×14` scaling, per-night surplus credit capped at −1 h floored
  at 0 total (**D2**), gap nights carry the prior debt forward unchanged, trend frozen
  on a sleep-need change, insufficient-history rule (**D8**), Monday reference (**D7**).
- **Backtest against real Health data** (own device history, or synthetic if unavailable
  early): confirm/retune `r`, the 1 h surplus-credit cap, and — feeding P5 — the
  gauge's 8 h breakpoint (**D10**) against the actual debt distribution, since all
  three are fit to a handful of mockup numbers plus RISE's public description rather
  than derived from first principles.
- Gauge mapping: debt → 0…1 via the two-segment transfer function (**D10**), with the
  1.5 % floor and the 5 h target mark.
- Strip mapping: per-night surplus/deficit → normalised bar height, gap style.
- Fixture set reproducing every mockup screenshot exactly, asserted to the minute.

**Out of scope:** where nights come from; how anything looks.

**Done when:** each of the mockup's seven states and both home-screen widgets can be
reproduced from a fixture, the main-screen numbers (13 h 04 / 6 h 12 / 8 h 00 /
7 h 15 / 1 gap) are consistent under the chosen formula, and the backtest has either
confirmed `r = 0.873` / the 1 h credit cap / the 8 h gauge breakpoint or produced
retuned values with the data behind them. Test coverage on the engine ≥ 90 %.

**Depends on:** P0. **Parallel with:** P2, P4, S1.

**Risk:** if D1 or D10 are later overruled by the backtest, everything downstream keeps
working — this is exactly why the engine is isolated.

---

### P2 — HealthKit ingestion

**Goal:** `[Night]` out of Apple Health, correct in the messy cases.

**Scope**

- `SleepDataSource` protocol + `HealthKitSleepSource` + `FakeSleepSource` for tests.
- Authorisation: request read access to `HKCategoryTypeIdentifier.sleepAnalysis`;
  use `getRequestStatusForAuthorization` to decide whether to prompt.
  **Note the platform constraint:** HealthKit deliberately does not reveal whether
  *read* access was denied, so "authorised but no data" and "denied" are
  indistinguishable from the API. The disambiguation is heuristic and it drives the
  difference between the mockup's "authorisation missing" and "insufficient history"
  states — spell the heuristic out in code and in tests.
- Session → night attribution per **D3** (noon → noon).
- Aggregate `asleepCore` / `asleepDeep` / `asleepREM` / `asleepUnspecified`; exclude
  `inBed` and `awake`.
- Deduplicate overlapping samples across sources (Watch + a third-party app both
  writing the same night must not double-count). Prefer one source per night by
  priority, or merge by interval union — decide and test.
- Distinguish "night with 0 min of sleep recorded" from "night with no samples at all"
  (the gap case).

**Out of scope:** caching, background delivery, UI.

**Done when:** a fixture suite of raw `HKCategorySample` sets — including
multi-source overlap, a nap-only day, a session crossing noon, and a total gap —
converts to the expected `[Night]`.

**Depends on:** P0 (and P1's `Night` type). **Parallel with:** P4, P5.

---

### P3 — Snapshot cache and refresh

**Goal:** the widget always has something to render, and knows how old it is.

**Scope**

- Versioned, `Codable` `DebtSnapshot` persisted in the App Group container; a schema
  version field and a migration path, because a snapshot written by an old build must
  not crash a new widget.
- `HKObserverQuery` + `enableBackgroundDelivery` in the app; on wake: fetch → compute →
  write snapshot → `WidgetCenter.reloadAllTimelines()`.
- Foreground refresh on app launch and on scene activation.
- Staleness evaluation per **D6**, feeding `WidgetState.cached`.
- Refresh budget discipline: coalesce reloads, never reload when the snapshot is
  unchanged.

**Out of scope:** rendering.

**Done when:** killing the app and changing Health data still updates the widget within
the latency S2 measured; a snapshot written by build N is readable by build N+1;
forcing a stale clock flips the widget to the neutral cached state.

**Depends on:** P1, P2, S2. **Parallel with:** P4, P5.

---

### P4 — GlassKit: tokens and surfaces

**Goal:** one API that renders the mockup's material in the app *and* an
honest-looking equivalent in the widget, with the difference hidden from callers.

**Scope**

- Tokens: the four semantic tints (`red`, `green`, `amber`, `neutral`) as tint-1/tint-2
  pairs, fill gradients + glow per tint, figure gradient end-colours, text opacity
  ladder, corner radii (34 pt widget / 44 pt phone card), spacing scale.
- `GlassSurface`: base gradient, the two-radial semantic bloom, the rotated specular
  sweep, the grain overlay, the six inset/outset shadows from the mockup.
- Two backends behind one modifier, chosen by render environment, per S1's verdict.
- Resolve **D5** (fonts); register them if licensed.
- A SwiftUI preview catalogue showing every tint × every surface × light/dark
  wallpaper, so drift is visible.

**Out of scope:** anything that knows what sleep debt is. GlassKit must not import
SleepDebtCore.

**Done when:** the preview catalogue is placed next to the mockup at the same scale and
the differences are deliberate and written down.

**Depends on:** P0, S1. **Parallel with:** P1, P2, P3.

**Risk:** this is the phase most likely to eat time. The mockup leans on CSS features
(`backdrop-filter`, `mix-blend-mode: soft-light`, `background-clip: text`) whose
SwiftUI equivalents are close but not identical. Budget for approximation and decide
early what "close enough" means.

---

### P5 — Shared components

**Goal:** the vocabulary both surfaces are assembled from.

**Scope**

- `DebtFigure` — gradient-clipped numerals, `13` + small `h` + `04`, two sizes
  (47 pt widget / 64 pt phone), tabular alignment so the number does not jitter.
- `LiquidGauge` — track, gradient fill with glow and inner highlight, ghost tick,
  minimum-visible-fill floor, a marked 5 h target, two heights. Value mapping uses the
  two-segment transfer function from **D10**, not a linear scale — the component takes
  raw debt and does its own 0–8 h / 8–24 h mapping so callers never see raw percentages.
- `DeltaChip` — arrow glyph + duration in a pill; carries direction non-chromatically
  (this is what keeps the green/red semantics accessible).
- `NightStrip` — 14 slots, centre axis, above/below bars, last-night dot, gap style,
  `14 nuits` / `cette nuit` legend.
- `StateMessage` — the tight-typeface message + small subtitle used by the
  authorisation and insufficient-history states.
- Every component driven by a view model derived from P1 types. Snapshot tests at both
  widget sizes and the phone width.

**Out of scope:** screen assembly, timeline logic.

**Done when:** all seven mockup state cards render from fixtures, at the mockup's
dimensions, and snapshot tests are green.

**Depends on:** P1 (types), P4. **Parallel with:** P2, P3.

---

### P6 — Widget extension

**Goal:** shippable small and medium widgets.

**Scope**

- Timeline provider reading the App Group snapshot; `TimelineEntry` carrying a
  `WidgetState`.
- Refresh policy: next expected wake window and the staleness boundary, within budget.
- All seven states rendered at both sizes:
  1. **Nominal, falling** — green glass, ghost tick right of the fill.
  2. **Zero** — green, gauge at the floor stub, no celebration.
  3. **High, rising** — deep red, bloom filling the glass; the system's intensity ceiling.
  4. **Cached** — colour withdraws entirely to neutral, fill desaturated, measurement
     time shown.
  5. **Authorisation missing** — no colour, a message and a deep link into the app.
  6. **Insufficient history** — "6 nuits sur 14", empty gauge rather than a wrong one.
  7. **Night missing** — amber; neither rising nor falling because tonight left the
     calculation.
- `placeholder(in:)` / redacted rendering, deep links via `widgetURL`.
- Accessibility labels for the gauge and the strip (a bar chart is invisible to
  VoiceOver unless described).

**Done when:** each state can be forced on a real device via the debug harness and
matches the mockup; the widget survives a cold boot with no cached snapshot.

**Depends on:** P3, P5. **Parallel with:** P7.

---

### P7 — Main screen

**Goal:** the phone card from the mockup, as the app's home.

**Scope**

- Header row, 64 pt figure, taller gauge with ghost, the two delta chips
  ("since yesterday", "since Monday"), the 14-night strip, and the four stat rows
  (tonight / configured need / 14-night average / nights without data).
- Pull-to-refresh, loading and error states, and the same seven states as the widget.
- Sleep-need setting (default 8 h 00) with persistence, and recomputation when it
  changes.
- Deep-link entry points from the widget.

**Out of scope:** first-run flow (P8).

**Done when:** the screen matches the mockup at the reference width and reacts
correctly to a need change, a fresh sync, and every state.

**Depends on:** P3, P5. **Parallel with:** P6.

---

### P8 — Onboarding and authorisation

**Goal:** get from install to a trustworthy first number without lying to the user.

**Scope**

- First-run: what the app does, why it needs Health, then the HealthKit read prompt.
- Denial path — and it is the awkward one, because P2 established that denial is not
  directly observable. Explain, offer a deep link to Settings → Health → Data Access,
  re-check on foreground.
- Set sleep need.
- The "not enough history yet" path: the app must be honest that it needs 14 nights,
  while still feeling alive on day one.
- Entry from the widget's authorisation state.

**Done when:** fresh-install, denied, granted-but-empty, and partial-history runs all
land somewhere sensible.

**Depends on:** P2, P4. **Parallel with:** P6, P7 (touches different screens).

---

### P9 — Accessibility, localisation, and adaptive hardening

**Goal:** the design direction holds up outside its ideal conditions.

**Scope**

- `Reduce Transparency` and `Increase Contrast`: glass must degrade to a solid,
  legible surface with contrast ratios that pass.
- `Reduce Motion`: no animated bloom or shimmer.
- Dynamic Type through to the accessibility sizes on the phone screen; the constrained,
  documented behaviour in widgets.
- VoiceOver: the debt figure, the gauge (value + yesterday's reference + direction),
  the strip as a summarised series, every chip.
- Colour independence: red/green encode the derivative, so verify the arrow glyph and
  wording carry that meaning with colour removed — including for deuteranopia.
- FR + EN strings (**D9**), with a duration formatter that handles `13 h 04`, `39 min`,
  `1 h 24` in both locales.
- Dark/light wallpapers, and the widget's tinted and accented Home Screen modes.

**Done when:** an audit pass with each accessibility setting on produces no unreadable
or unspoken content.

**Depends on:** P5, P6, P7.

---

### P10 — QA harness and release

**Goal:** ship it and be able to debug it.

**Scope**

- Debug state switcher that forces any of the seven states in both app and widget
  (this pays for itself from P6 onward — consider pulling it forward).
- Screenshot fixtures wired into CI to catch visual regressions.
- Widget render-time and memory budget check; extension crash guardrails.
- HealthKit privacy manifest and App Store privacy disclosures (Health data is
  sensitive; nothing leaves the device — say so).
- App Store metadata, screenshots derived from the mockup, TestFlight round.

**Depends on:** everything.

---

## 6. Cross-cutting risks

| Risk | Phase | Mitigation |
|---|---|---|
| A widget cannot reproduce true backdrop-blurred glass | S1, P4 | Spike before designing the API; accept a widget-specific recipe |
| Debt formula, surplus-credit cap, and gauge breakpoint are fit to mockup numbers + RISE's public description, not derived or independently confirmed | P1 | Backtest against real Health data in Phase 1 before P5/P6 consume the values; the engine is isolated so retuning is cheap |
| HealthKit read denial is not observable | P2, P8 | Explicit heuristic, tested; honest copy rather than a false "no data" |
| Background delivery latency makes the widget stale at wake-up | S2, P3 | Measure first; the "cached" state is the designed fallback |
| Widget refresh budget exhausted | P3, P6 | Coalesce, skip no-op reloads, one scheduled refresh near the wake window |
| Glass + grain + gradient text costs too much render time in an extension | P4, P6 | Budget check in P10, pre-rendered noise texture rather than live generation |
| Green at 13 h of debt reads as a bug to users | P7, P9 | Deliberate per the mockup; the copy must teach it. Worth user-testing |

---

## 7. Suggested order

1. **P0** (blocking), with **S1** and **S2** kicked off immediately after.
2. Then in parallel: **P1 → P2 → P3** and **P4 → P5**.
3. Then in parallel: **P6**, **P7**, **P8**.
4. Then **P9**, then **P10**.

Every phase above is independently reviewable and mergeable: P1–P5 land as package code
with tests and no UI entry point, P6–P8 land as separate screens/targets, P9–P10 are
sweeps. Nothing needs a phase after it to be considered complete.
