# Recur: project guide

## Purpose and scope

Recur is a native SwiftUI flashcard app for an iPhone 13 mini. It requires iOS 17
or later. It works offline, renders LaTeX, supports light and dark themes, and
uses FSRS-6 to schedule reviews.

The product is **traditional front/back flashcards**: one focused question, one
short answer. The user rejected the former lesson and explanation panels. Do not
bring back repeated explanations, hints, derivation essays, or visible TikZ source.
Split a broad topic into several cards. Use a figure when it helps answer the
actual question. Card authoring happens through our chat and deck files; there is
no in-app screenshot-to-card service.

The display name is **Recur**. Keep the internal project and target name
`MathRecall`, bundle ID `com.bharat.mathrecall`, and Application Support folder
`MathRecall` stable. Changing these can strand the user's data.

## Project map

| Path | Role |
| --- | --- |
| `App/` | SwiftUI screens, app model, card motion, gestures, and native rendering |
| `App/AppModel.swift` | Main-actor app state, persistence calls, imports, and review actions |
| `Sources/RecallCore/` | Models, state machines, FSRS integration, imports, updates, and SQLite storage |
| `Sources/CSQLite/` | SQLite system-library bridge |
| `Tests/RecallCoreTests/` | Swift Testing tests for core rules and persistence |
| `Tests/Fixtures/` | Old decks retained to test compatibility |
| `Scripts/make_starter.py` | Source for the starter deck and example card files |
| `App/Resources/starter.json`, `Examples/` | Generated card files |
| `Sources/RecallMath/` | Native mixed text/math layout, delimiter parsing, and VoiceOver math |
| `Tests/RecallMathTests/` | Delimiter, speech, equation-boundary, and native notation regressions |
| `Tools/RendererCheck/` | Native drawing checks, timing output, and a visual sample sheet |
| `App/Resources/Math/` | KaTeX for authoring validation only; excluded from the app |
| `Schemas/` | JSON exchange format and its documentation |
| `Vendor/swift-fsrs/`, `Vendor/swiftui-math/` | Pinned scheduler and native math renderer; see `Vendor/README.md` |
| `Design/` | Icon source, prompt, preview, and old artwork |
| `Archive/lesson-authoring/` | Retired lesson tools; not part of the starter build |
| `project.yml` | XcodeGen source for `MathRecall.xcodeproj` |

Read `README.md` for setup and `Schemas/README.md` before changing card formats.

## Architecture and performance

Keep domain rules in `RecallCore`, math presentation in `RecallMath`, and screens
in `App`. `AppModel` coordinates persistence on the main actor. Change a candidate
library, commit it to SQLite, then publish it; a failed save must not publish
unsaved data. Views send actions through these boundaries.

Prefer native SwiftUI and Core Text for frequent surfaces such as Library rows
and card faces. Reuse rendered work across browsing and animation. Keep caches
bounded and disposable; they must never become the source of card content or
review state. Filter and group the Library once per view evaluation, rather than
repeating searches for every topic and navigation link.

When addressing latency, trace the work first. Measure initial rendering and
cached rendering separately. State which device and workload were measured;
Mac timings do not establish latency on the phone.

## Writing and interface conventions

Follow Orwell's six rules:

1. Never use a metaphor, simile, or other figure of speech which you are used to
   seeing in print.
2. Never use a long word where a short one will do.
3. If it is possible to cut a word out, always cut it out.
4. Never use the passive where you can use the active.
5. Never use a foreign phrase, a scientific word, or a jargon word if you can
   think of an everyday English equivalent.
6. Break any of these rules sooner than say anything outright barbarous.

Use clear action labels. Avoid vague words such as “Apply” and terms that suggest
the wrong action. **Past reviews** means a log of study dates and recall ratings;
it does not start a study session. **Restore to Library** makes an archived card
active again and keeps its schedule and past reviews.

Keep the interface spare. The card is the main surface. Use the shared `Palette`
and support both themes. Keep tap-to-flip, buttons, VoiceOver actions, and Reduce
Motion alongside gestures. Long answers must still scroll; their vertical swipe
shortcuts live on the grip below the card.

## State and interaction rules

Use explicit state machines for workflows. Views should render state and send
events; disabled controls alone must not enforce a rule. Plain view state is fine
for search text, layout measurements, theme choice, and similar independent values.

- `ReviewMachine` owns the current card, question/answer face, turns, saving, and
  completion. Only a stable answer can be graded. A failed save returns to that
  answer. Advance the queue only after the database commit succeeds.
- `BrowseMachine` owns selection, the current face machine, and one presentation
  state: browsing, a sheet, or closed. Edit and Past reviews cannot compete. A new
  card starts on its front. Browsing never grades or changes a schedule.
- `CardSwipeMachine` owns idle, dragging, and committing. A deliberate drag must
  cross the 96-point threshold along one axis. Short or diagonal drags return the
  card. Releasing twice cannot trigger two actions.

| Gesture | Review, after revealing the answer | Library card browsing |
| --- | --- | --- |
| Left | Again | Next card |
| Right | Good | Previous card |
| Up | Easy | Flip card |
| Down | Hard | Close card |

The Library canvas pans across topic groups in both axes. Keep its search and
archive filters consistent with the list. Card browsing stops at the ends.

Use visit IDs, interaction IDs, and turn tokens to reject stale callbacks. A card
ID alone is insufficient: the user can leave a card and return before an old
callback runs. Closing a screen must invalidate its pending swipe action.

`FlashcardView` serves both review and browsing. A cancellable `.task(id:)` uses
the duration in `FlashcardMotion`, then completes the matching turn token. This
avoids a turn remaining locked when SwiftUI misses an animation completion.
Keep the visual duration and the turn clock in sync, including Reduce Motion.
Do not reintroduce a flip Boolean that competes with the machine's face state.
Only departing actions should send the card off-screen; flipping keeps it in place.

## Cards, schedules, and persistence

- SQLite holds the working library. JSON is the import, export, and backup format.
  Use typed `Codable` payloads, including `CardFile`; do not infer formats through
  `[String: Any]` dictionaries.
- Save grades, schedules, content snapshots, and the remaining queue in one
  transaction. Preserve immutable historical content and its digest.
- Keep old v1/v2 decks and backups readable. Old lesson fields and PDF assets may
  be needed by historical snapshots even though current screens omit lessons.
- Optional legacy fields are intentional. Changing an absent field into an
  encoded default can change an old snapshot's hash. Preserve its wire shape.
- Keep card IDs for unchanged skills. Give a new objective a new ID. Increase the
  revision for changes; prompt edits with the same objective need the appropriate
  wording marker. Do not overwrite local edits at the same or a higher revision.
- Omitted cards in an import remain in the library. Archiving removes cards from
  due lists and pending queues, while keeping schedules, completed counts,
  reviews, and snapshots. Use `Library.setArchived` for archive/restore actions.
  Restoring does not insert cards into a session already in progress.
- A full backup restore replaces the library after a preview and recovery copy.
  Preserve the original `library.json` when migrating it to SQLite.
- Use FSRS-6 with its 21 default weights and 90% retention. Learning and relearning
  step lists are empty so FSRS calculates intervals for all four ratings. Keep
  short-term memory calculations enabled. Do not add fixed minute steps or a
  custom interval sequence. The vendored implementation currently rounds model
  intervals to whole days with a one-day minimum; personal fitting is absent.
  Preserve existing due dates and historical settings when changing the scheduler;
  apply current settings when a card is next rated.

Again means failed recall; Hard means correct recall with effort; Good means
normal correct recall; Easy means effortless recall. These are model inputs,
not fixed durations. Ratings can produce the same rounded interval. Distinguish
upstream defaults, our chosen settings, and research findings when discussing
scheduling; do not present an unverified duration as a scientific recommendation.

## Math, diagrams, and generated files

Author cards in `Scripts/make_starter.py`, then regenerate:

```sh
python3 Scripts/make_starter.py
node Scripts/check_math.cjs
swift Scripts/check_renderer.swift
```

For a topic shared in chat, identify the missing skill before writing cards.
Separate a rule, its meaning, and a short application when each needs recall.
Fundamentals belong in focused questions with short backs: identifying an inner
function, interpreting a symbol, or stating why two rates multiply. Longer
teaching and derivations belong in chat. Include assumptions such as log base,
domain restrictions, and radians where they affect the answer.

Edit the authoring script, not generated JSON alone. Regenerate the bundled deck
and examples together; update documented counts and existing count checks when
the collection changes. Count active and archived cards separately. The bundled
deck's counts need not match the phone after imports, edits, and restores.

Use `\(...\)` for inline LaTeX and `\[...\]` for display math. `MathText` in
`RecallMath` lays out native prose and SwiftUIMath equations. `App/MathText.swift`
is an alias to that shared renderer; do not create separate renderers for the
Library, reviews, imports, or historical content.

The renderer aligns inline math with text baselines and reserves a line for
display math. Display equations wrap at safe top-level equalities and list
separators; indivisible wide formulas scale to fit. It keeps bounded parse/layout
caches and a 16 MB, 512-entry artwork cache. Equations draw once into transparent,
screen-scale images keyed by formula, font, size, style, and display scale.
Template tinting follows the current theme without another typeset. Keep this
separation: live math Canvas drawing inside the animated card caused missing
glyphs even when offscreen rendering checks passed.

VoiceOver reads the whole text with spoken fractions, powers, and common symbols.
Do not reintroduce web views, JavaScript, HTML interpretation, or network rendering.
Keep card JSON and historical hashes unchanged when changing rendering.
Run the native renderer check for new notation; unsupported imported math must
show a readable error, never an empty card.

SwiftUIMath and its fonts are pinned locally. `RecallMath` uses its Textual SPI
for metrics; check compatibility before upgrading. Record upstream revisions,
local patches, and licences in `Vendor/README.md`. KaTeX remains an authoring
syntax check only: passing it does not prove that the native renderer supports
the notation. Keep vendor fonts in app bundles and temporary native test apps.

If needed, compile TikZ outside the phone app into vector PDFs. Preserve
transparency, supply suitable light/dark variants, and keep tap-to-zoom support.
Do not show source code as study content. Screenshots need not ship with cards.

`Design/RecurIcon-source.png` is the current icon artwork.
`Scripts/make_icon.swift` exports the opaque 1024-pixel app icon and small preview;
`Design/IconPrompt.md` records how the artwork was made. Old artwork lives in
`Design/Archive`.

## Swift and checks

Use Xcode 27.2 for the checked compiler and formatter versions. Our app, core, and
tests use Swift 6, complete concurrency checking, and `ExistentialAny`. Compiler
warnings fail builds and tests. Keep actor isolation and types explicit where
needed; retain type inference where it is clear.

Do not use forced casts, forced unwraps, forced tries, unchecked concurrency
escape hatches, lint baselines, or blanket suppressions in production code.
SwiftLint is pinned in `.swiftlint-version` (currently 0.65.1). Use `.swift-format`
for layout and `.swiftlint.yml` for correctness rules. Leave vendor code and
retired tools in their own style.

```sh
# Format files you changed; use their paths in place of these examples.
xcrun swift format format --in-place App/LibraryView.swift Sources/RecallCore/BrowseMachine.swift

Scripts/lint.sh             # Strict formatting and production-code lint
Scripts/test.sh             # Core and math tests, with warnings as errors
node Scripts/check_math.cjs # LaTeX validation
swift Scripts/check_renderer.swift # Native SwiftUI checks at phone width, both themes
Scripts/check.sh            # All of the above, then an unsigned generic iOS build
```

The lint step also runs on every Xcode build. Run checks suited to the change;
documentation-only edits do not need an app build. Add regression tests for
meaningful bugs and workflow changes, especially stale events, cancellation,
failed saves, archive/restore, and compatibility. Unit tests and renderer checks
do not prove that touch interaction works: check the actual sequence in a native
view or on the phone when changing gestures or animation timing.

For math changes, inspect the rendered sample sheet as well as check results.
Check complete equations, baselines, wrapping, both themes, and larger text.
For renderer or animation changes, also reveal a real card and move between
cards in a native view: a successful parse or snapshot can miss live clipping.
Keep temporary test apps separate from the user's data and close them afterward.

GitHub Actions runs `Scripts/check.sh`; local success is not evidence that the
remote workflow ran. Report what was actually checked and any remaining limits.

## Build and phone updates

Run `xcodegen generate` after changing `project.yml` or the app's file layout.
Change build settings in `project.yml`, not just the generated Xcode project.
Use the `MathRecall` scheme. Build products should live outside the source tree,
such as `/tmp/math-recall-ios-build`.

The user wants a small Xcode footprint. Use the installed iOS SDK and physical
phone; do not download simulator runtimes unless asked. Read the current signing
team and device ID from the local setup rather than hardcoding personal IDs here.

Build a signed generic iOS app with automatic signing, then install the resulting
`MathRecall.app` with `xcrun devicectl device install app`. Increase the build
number in `project.yml` for a new phone update. **Never uninstall the app to update
it**, reset its container, or change its bundle/storage identity to solve a build
issue. Keep the user's data. A successful build is not a successful install;
verify the install result. A locked phone can block launch even after installation.

Card files do not sync automatically with this chat. A phone update installs a
new bundled deck; the app merges it on launch using the existing revision rules.
An exported JSON deck can instead be imported through Recur. Report separately
whether cards were authored, checked, built, installed, and launched. Do not call
a local file change a phone update, or claim a touch check from a build result.

Keep documentation in sync when changing gesture mappings, labels, card formats,
state rules, or check commands. Preserve unrelated user edits.

## Git workflow

Make atomic commits and push completed work to the configured remote, following
the user's standing request. Inspect the working tree first and stage only files
for the task. Keep generated files with their authoring changes and documentation
with the behavior it describes. Preserve unrelated edits and do not rewrite
published history. For documentation-only changes, review the diff and whitespace;
do not rebuild or reinstall the app. Report the commit and what was checked.
