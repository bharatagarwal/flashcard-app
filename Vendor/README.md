# Bundled dependencies

swift-fsrs: https://github.com/open-spaced-repetition/swift-fsrs
Snapshot: 4fbaf20184d62f82a9f44f343337c61a2c5483e9 (MIT; license in swift-fsrs/LICENSE).
The app explicitly selects FSRS-6 defaults (21 weights), 90% requested retention,
and empty learning/relearning step lists. Sources are unchanged.

KaTeX 0.19.1: https://github.com/KaTeX/KaTeX (MIT).
Runtime, CSS, fonts, auto-render and license are in App/Resources/Math.
These files are used only by the authoring syntax check and are excluded from the
iOS app. The app does not use WebKit or JavaScript for mathematics.


SwiftUIMath: https://github.com/gonzalezreal/swiftui-math
Snapshot: cf7c70153b4b3f23e2340c7487d883f4abec1775 (MIT; license in swiftui-math/LICENSE).
Fonts retain their licences inside mathFonts.bundle. The runtime uses native
SwiftUI Canvas/Core Text, with no external runtime dependency. Our manifest omits
upstream's test target and its snapshot-testing dependency. Runtime sources retain
upstream style. Local patches:

- AtomList tracks the previous math atom across spacing/style nodes when deciding
  whether a sign is unary. This fixes the derivative-cycle formula after `\quad`.
- AtomFactory adds the `\varnothing` and `\nmid` symbols used in existing cards.
- DisplayProvider limits its NSCache stores to 512 parsed formulas and 1,024 layouts.
  NSCache can evict these entries under memory pressure.

RecallMath uses upstream's Textual SPI for synchronous metrics and baseline
alignment. Keep this pinned; check metric compatibility before upgrading. The
native renderer check covers the affected formulas, both themes, and phone widths.
