# Deck format 2

JSON is the portable exchange format. `deck-v2.schema.json` describes new exports;
the Swift importer also accepts version 1 files. Referential checks, PDF hashes,
prerequisite cycles, and revision rules run in Swift in addition to JSON Schema.

## Content

A concept has a stable `id`, integer `revision`, optional `prerequisiteIDs`, and
`sections`. Sections have roles: `intuition`, `derivation`, `example`, `pitfall`,
`history`, or `explanation`. Historical sections require HTTPS `sourceURLs`.

Sections contain `blocks`, and derivations can also contain ordered `steps` with
their own titles and blocks. The reader reveals one step at a time.

A block is one of:

```json
{"id":"intro","kind":"text","text":"Use the distributive law."}
{"id":"identity","kind":"equation","text":"a^3-b^3=(a-b)(a^2+ab+b^2)"}
{"id":"figure","kind":"diagram","assetID":"sha256:<64 hex digits>"}
```

Equation blocks contain raw math-mode LaTeX, without delimiters. `display`
defaults to true. Text blocks also accept inline `\(...\)` and displayed
`\[...\]` equations. Legacy `explanation` and `answer` strings remain readable
fallbacks for exports, search, and old review records. `answerBlocks` can provide
a richer card answer; keep the fallback semantically equivalent.

Traditional cards use only `prompt` (front) and `answer` (back). Keep answers
short and test one skill per card. There are no hints or lesson panels in the app.
`answerBlocks` remains available for equations or a figure that forms part of the
answer. Legacy `explanationSections`, concept sections, and hints still decode
and survive backups but do not appear in the app.

An optional `archived: true` flag keeps a card in the library and retains its
schedule and review history, while excluding it from future reviews. Archiving
also removes it from a pending queue and recomputes that queue's total without
changing its completed count. Omitted flags mean active. An archived card's
replacement gets a new ID if it tests a different skill.

## TikZ figures

Compile TikZ before import. A diagram asset contains a PDF as base64-encoded
`data`, `mediaType: "application/pdf"`, a required `altText`, and optional
`darkData` containing a second PDF with dark-theme ink colours. Neither figure
should paint an opaque page background. Core Graphics renders the PDF contents
on a transparent surface. Source code stays in the authoring project and is not
included in app payloads or exports. Legacy source fields are ignored on decode.

For a single PDF, the ID is `sha256:` plus its SHA-256. For a pair, hash the bytes
`recur-pdf-pair-v1` followed by a zero byte, the light PDF's byte length as an
unsigned 64-bit big-endian integer, the light PDF bytes, and the dark PDF bytes.
Each PDF is limited to 2 MB. Changed bytes produce a different asset ID. Assets
are retained when merging so older content can still refer to them.

This avoids ZIP extraction and separate file references for small mathematical
figures. Screenshots are optional and are omitted from new starter exports.
SwiftUIMath renders mathematical LaTeX natively; it is not a full LaTeX document
engine. Packages such as TikZ belong in the authoring/compilation step. The app
keeps delimited text intact in storage and reports unsupported notation visibly.
Run the native renderer check when adding notation; KaTeX remains an extra authoring
syntax check and does not run in the app.

## Updates

Each card has a stable `id` and an `objectiveID` identifying the skill it tests.
If omitted for legacy compatibility, `objectiveID` defaults to `id`.

- Any card edit requires a higher `revision`.
- A changed question is accepted under the same ID only when explicitly marked
  `change: "wording"`, with the same objective, concept, and kind. The author is
  declaring that the tested skill has not changed.
- Clarifications use `change: "explanation"`; mathematical corrections use
  `change: "correction"`.
- Changed answers appear in the import preview. Corrections suggest restarting
  the schedule; the user can keep or reset each revised card's schedule.
- A changed learning objective requires a new card ID.
- Concept changes also require a higher revision in version 2 files.
- Imports merge, keep omitted cards, and retain all review records.

New reviews refer to a stored content snapshot containing the exact card, concept,
FSRS implementation, parameters, and learning steps. Identical snapshots are
stored once. Legacy reviews do not have retroactive snapshots; the app labels this.

## Storage and compatibility

The phone's working store is SQLite. A transaction saves the changed content,
schedule, event, content snapshot, and session together. Unchanged records are not
rewritten. The old `library.json` migrates automatically and remains intact.

JSON backups include assets, snapshots, schedules, and review events. Restoring
builds a fresh database before replacing the current one, including recovery from
a corrupt database. Content imports have a 20 MB limit; complete backups have a
128 MB limit. All compiled figures travel inside the JSON file; TeX source does not.

Use LaTeX for mathematical expressions in prompts, hints, answers, and lesson prose.
`Scripts/math_notation.py` applies explicit notation edits to the starter authoring
text; it does not guess at user-imported content.

`Scripts/make_starter.py` is the authoring source for the collection and all its
example exports. It includes `output/pdf/unit-circle.pdf` when present. Run the
math check and tests after regenerating; the app needs no authoring tools.


## Personal understanding marks

Full library backups can include an optional `understanding` object, keyed by
card ID. Values are `"needsUnderstanding"` or `"understood"`. This is personal
study state, not a card field or a memory rating; shared deck files omit it.
Missing marks leave legacy behavior unchanged, and an absent object stays absent
when encoded. Each marked ID must identify a card in the library.

SQLite stores these marks in the typed library metadata alongside the pending
session. Marking a card `needsUnderstanding` saves the mark and queue change in
one transaction. It removes the card from due lists, next-review calculations,
and pending queues without changing its schedule, content revision, completed
count, events, or historical hashes. Marking it `understood` restores review
eligibility unless archived, but does not add it to a running session. Content
imports and bundled updates preserve the user's marks.
