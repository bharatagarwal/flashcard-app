# Recur

A native SwiftUI flashcard app for the iPhone 13 mini, with offline LaTeX, FSRS-6,
light/dark themes, and a tap-to-flip review screen. Requires iOS 17 or later.

## Review

Read the front, tap to turn the card, then choose Again, Hard, Good, or Easy.
Tap again to return to the front. Turning blocks further taps and grading until
the turn finishes. A cancellable task uses the same duration as the visual turn,
then completes the matching token; screen changes cancel it. Reduce Motion uses a fade. Saving a grade, its schedule,
the content snapshot, and the remaining queue happens in one SQLite transaction.
A failed save returns to the answer for retry.

The starter collection has **71 active cards across ten topics**. Each card asks
one focused question with a short answer. There are no topic lessons, hints, or
explanation panels. The Library lets you search questions, tap to flip either side,
edit answers, and inspect past reviews. Reviews and browsing share the same lift,
tilt, and spring turn. Browsing never changes a schedule or records a grade. Changing an answer keeps its history unless
you choose to reset the schedule.

### Swipes

The Library opens a two-dimensional topic canvas. Pan in any direction to explore
its stacks, then tap a topic to browse its cards. The list button switches to the
sectioned list; the grid button switches back. Search and the **All cards / Needs
understanding** selector keep the same results in either view. Archived cards have
the same canvas and list options.

After revealing a review answer, swipe **left for Again**, **down for Hard**,
**right for Good**, or **up for Easy**. The rating buttons show the same arrows.
Drag at least 96 points along one axis; a short or diagonal drag returns the card.
The card shows the pending rating and gives a light haptic at the threshold.
Release to save through the same transaction used by the buttons.

In the Library, adjacent cards peek in from either side. Swipe **left for next**,
**right for previous**, **up to flip the card**, or **down to close**. Navigation
follows the current search results and stops at the ends. Buttons offer the same
actions. The **Past reviews** button opens a log of study dates and recall ratings;
it does not start a review. Flipping keeps the card in place. Each new card starts on its front; browsing never records a grade.

Long answers keep vertical swipes for scrolling. Use the grip below the card for
up/down shortcuts. Reduce Motion removes travel and tilt, with a short fade for
committed actions. A separate swipe state machine blocks repeated releases and
ignores stale animation completions; the review machine still controls grading.
Browsing has one state for the card, Edit, History or closed, so sheets cannot
compete. Visit IDs and review interaction IDs invalidate delayed actions when a
card changes, a sheet opens, a flip starts or a save fails, even when returning
to the same card. Leaving a screen also invalidates an unfinished swipe action.

Fifteen former derivation or multi-part questions are archived. They remain in
Library → Archived cards, keep their schedules and history, and stay out of reviews
until restored. Open an archived card and tap **Restore to Library**, or swipe its
list row to reveal that action. Restoring keeps its schedule and past reviews;
new cards become due immediately, while studied cards keep their next review date. New replacement questions have new IDs. Unchanged skills keep their
old IDs and schedules. App updates do not rewrite historical content snapshots.
Locally edited cards at the same or a higher revision remain untouched.

## Understanding and memory

Tap **Needs understanding** during a review when the question or answer is a
black box. You can mark a card from either stable face. Recur pauses that card's
memory reviews and moves to the next card without recording a rating. Again,
Hard, Good, and Easy remain memory ratings.

Today links to cards needing understanding. In Library, choose **Needs understanding**
above the canvas to show only paused cards, grouped by topic. Each stack shows how
many paused cards it contains. Choose **All cards** to return to the full Library.
The same selector stays available when you switch to the list. These cards remain
browsable and keep their answers, schedules, and review history.
You can also mark a card through its **Card actions** menu while browsing.

Once you understand it, tap **Mark understood** on the card's banner. Its original
schedule becomes eligible again; an overdue card can appear in your next review
session. It is not inserted into a session already in progress. Archiving is
independent: an archived card stays archived even after being marked understood.
Understanding marks travel in full backups, not in shared content decks.

## Author and import cards

Edit `Scripts/make_starter.py`, then run:

```sh
python3 Scripts/make_starter.py
node Scripts/check_math.cjs
```

This creates the bundled starter and the JSON decks in `Examples`. Share a
screenshot or the fact you forgot in our chat to create more front/back cards.
Save the card file to Files, then open it in Recur or use Import.

Math uses native SwiftUI text and Core Text equations through bundled SwiftUIMath.
Parsed formulas, layouts, and transparent equation images use bounded in-memory caches.
Equation images render natively at the screen scale, then reuse that artwork during
scrolling and card turns. Artwork retains transparent padding for italic glyphs
that extend beyond their layout widths, while their text baselines stay unchanged.
No web view, JavaScript, HTML document, or network request
is involved in rendering. Text accepts `\(...\)` for inline equations and
`\[...\]` for display equations. A figure may be part of an answer when the actual question
requires it; the current starter has no figures. Optional diagram assets are
compiled vector PDFs with transparent light/dark variants and tap-to-zoom support.
No TeX engine or network service runs on the phone.

The v2 exchange format still accepts older decks and backups, including lesson
fields, figures, and snapshots. Those legacy lesson fields do not appear in the
current app. See `Schemas/README.md` and `Schemas/deck-v2.schema.json`. Retired
lesson-authoring scripts live in `Archive/lesson-authoring`; they are outside the
starter build process.

Unsupported imported LaTeX shows a readable rendering error rather than an empty
card. The native renderer supports math notation, not full LaTeX documents.

## Your data

SQLite stores the working library in Application Support. JSON remains the
portable import, export, and backup format. Imports retain omitted cards and
review records; explicit `archived: true` removes a card from future reviews.
The pending queue drops archived cards while retaining the completed count.
Archives retain old PDF assets for their historical references.

Export a full backup before moving phones. Restoring replaces the current library
after a preview and keeps a local recovery copy first. The old `library.json`
migrates without deleting the original. There is no iCloud sync.

Scheduling uses vendored Swift FSRS-6 with 21 default weights and a 90% recall
target. Learning and relearning step lists are empty: FSRS calculates the next
interval for Again, Hard, Good and Easy. Again means failed recall; Hard means a
correct answer with effort, Good means normal recall, and Easy means effortless
recall. Use Again when you forgot, rather than Hard.

The current Swift implementation rounds model intervals to whole days, with a
one-day minimum. This is a library rule, not a claim that a day is optimal for
every card. Short-term memory calculations remain enabled. Existing due dates,
learning progress and historical snapshots stay intact; the new settings apply
when a card is next rated. Old snapshots retain the settings used at the time.
Personal parameter fitting is not included.

## Build and check

Use Xcode 27.2 for the checked compiler and formatter versions.
Open `MathRecall.xcodeproj`, select the MathRecall scheme and your phone, and set
your Apple developer team. The display name is Recur; the internal target, bundle
ID `com.bharat.mathrecall`, and storage folder retain their names to keep data.
Xcode needs its iOS SDK. Local iOS UI checks use one Apple-silicon Simulator
runtime and the **Recur iPhone 13 mini** device. It has its own test library;
it does not sync with the phone. Keep extra runtimes uninstalled and shut down
the simulated device after testing to release memory.

To build for the simulator:

```sh
xcodebuild -project MathRecall.xcodeproj -scheme MathRecall \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath /tmp/recur-simulator-build CODE_SIGNING_ALLOWED=NO build
```

Select **Recur iPhone 13 mini** in Xcode to run it, or use its ID from
`xcrun simctl list devices available` with `simctl boot`, `install`, and `launch`.
The app is at `/tmp/recur-simulator-build/Build/Products/Debug-iphonesimulator/MathRecall.app`.
Simulator checks cover iOS layout and workflows; use the phone for final touch
and performance checks. The runtime is installed, but this local Xcode copy is
missing `Simulator.app`, so interactive simulator checks still need that app
restored from the matching Xcode distribution.

```sh
Scripts/check.sh
```

The app, core library, and tests use Swift 6 language mode. Concurrency checks are
complete; compiler warnings fail the app build and test run. `ExistentialAny`
requires explicit `any` for protocol values. Swift's type inference still applies
where the compiler can prove the type. Imported card files and math-rendering
messages use typed Codable payloads rather than untyped dictionaries.

`Scripts/lint.sh` runs strict swift-format over our app, core, tests, package
manifest, and active Swift scripts. SwiftLint 0.65.1 checks production app/core
code for forced casts, forced unwraps, forced tries, duplicate conditions,
unused bindings, and other correctness issues. It also rejects unchecked
concurrency escape hatches in our production code. Optional booleans in legacy
wire models remain intentional: an absent field must retain its original JSON
representation so archived review hashes do not change.

There are no lint baselines or blanket suppressions. Vendored libraries and
retired authoring code keep their upstream/historical style. The lint step runs
on every Xcode build and fails if its pinned tool is missing. `Scripts/check.sh`
runs lint, warning-free core tests, equation checks, the native renderer check,
and an unsigned iOS build. GitHub Actions runs the same command with a pinned
SwiftLint download and verified checksum on pushes and pull requests.
CI uses GitHub's [Xcode 27 runner](https://github.com/actions/runner-images/issues/14404)
and selects its [Xcode 27.2 installation](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md).
The linter checksum comes from the [official SwiftLint 0.65.1 assets](https://github.com/realm/SwiftLint/releases/expanded_assets/0.65.1).

`project.yml` defines the Xcode project. Run `xcodegen generate` after changing
its file layout. The tests cover legal review/flip transitions, failed saves,
FSRS schedules, archive migration, legacy imports, snapshots, and database
transactions. The native renderer check validates all starter formulas, renders at a 291-point
width in both themes and two sizes, and prints timing measurements. It does not replace a visual test on the phone.

## Icon and dependencies

`Design/RecurIcon-source.png` contains the generated overlapping-flashcards icon.
`Scripts/make_icon.swift` exports the opaque 1024-pixel app asset and a 120-pixel
preview. `Design/IconPrompt.md` records the exact prompt and built-in generation
tool used. The old spiral artwork remains in `Design/Archive`.

- Swift FSRS (MIT), bundled snapshot documented in `Vendor/README.md`.
- SwiftUIMath (MIT), pinned native renderer and fonts documented in `Vendor/README.md`.
- KaTeX (MIT), retained only for authoring validation; excluded from the app.
- SwiftUI, SQLite, Core Graphics, and CryptoKit from Apple's SDKs.
