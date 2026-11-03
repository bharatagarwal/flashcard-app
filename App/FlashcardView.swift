import RecallCore
import SwiftUI

/// The same card surface and turn motion serve reviews and browsing.
struct FlashcardView: View {
    let card: Flashcard
    let showingBack: Bool
    let canTurn: Bool
    let height: CGFloat
    let turn: () -> Void
    let turnToken: UUID?
    let turnCompleted: (UUID) -> Void
    var overflowChanged: (Bool) -> Void = { _ in }
    @State private var overflowingFaces: [Bool: Bool] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            face(back: false) {
                MathText(card.prompt, pointSize: 24).allowsHitTesting(false)
            }
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "arrow.turn.up.right")
                    .font(.subheadline).foregroundStyle(.secondary).padding(20)
                    .accessibilityHidden(true)
            }
            .modifier(CardTurn(angle: showingBack ? 180 : 0, reduceMotion: reduceMotion))
            .allowsHitTesting(!showingBack)
            .accessibilityHidden(showingBack)

            face(back: true) {
                if let blocks = card.answerBlocks, !blocks.isEmpty {
                    CardBlocksView(blocks: blocks, allowsTextInteraction: false)
                } else {
                    MathText(card.answer, pointSize: 21).allowsHitTesting(false)
                }
            }
            .modifier(CardTurn(angle: showingBack ? 0 : -180, reduceMotion: reduceMotion))
            .allowsHitTesting(showingBack)
            .accessibilityHidden(!showingBack)
        }
        .task(id: turnToken) {
            guard let turnToken else { return }
            // Use the same bounded clock as the visual turn. Cancellation or an old token cannot unlock a new card.
            do {
                try await Task.sleep(for: .seconds(FlashcardMotion.duration(reduceMotion: reduceMotion)))
            } catch { return }
            guard !Task.isCancelled else { return }
            turnCompleted(turnToken)
        }
        .onPreferenceChange(CardOverflowKey.self) { values in
            overflowingFaces = values
            overflowChanged(values[showingBack] == true)
        }
        .onChange(of: showingBack) { _, back in overflowChanged(overflowingFaces[back] == true) }
        .contentShape(RoundedRectangle(cornerRadius: 24))
        .onTapGesture(perform: turnIfAllowed)
        .accessibilityElement(children: .contain)
        .accessibilityHint(showingBack ? "Double-tap to show the question" : "Double-tap to show the answer")
        .accessibilityAction { turnIfAllowed() }
        .accessibilityAction(named: showingBack ? "Show question" : "Show answer", turnIfAllowed)
        .allowsHitTesting(canTurn)
    }

    private func turnIfAllowed() {
        guard canTurn else { return }
        turn()
    }

    private func face<Content: View>(back: Bool, @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .padding(26)
                .frame(maxWidth: .infinity, minHeight: height, alignment: .center)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: CardOverflowKey.self, value: [back: geometry.size.height > height + 2])
                    }
                }
        }
        .scrollDisabled(overflowingFaces[back] != true)
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 5)
    }
}

/// Hide each face as it turns away, so text never appears mirrored.
nonisolated private struct CardTurn: AnimatableModifier {
    var angle: Double
    let reduceMotion: Bool
    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }
    func body(content: Content) -> some View {
        let lift = reduceMotion ? 0 : max(0, sin(min(180, abs(angle)) * .pi / 180))
        content
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(lift * 0.12), .clear, .black.opacity(lift * 0.16)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(lift * 0.16), radius: 12 + lift * 16, x: 0, y: 5 + lift * 14)
            .opacity(reduceMotion ? max(0, 1 - abs(angle) / 180) : (abs(angle) < 90 ? 1 : 0))
            .rotation3DEffect(.degrees(reduceMotion ? 0 : angle), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
            .rotationEffect(.degrees(lift * -2.5))
            .scaleEffect(1 + lift * 0.035)
            .offset(y: lift * -10)
    }
}

/// Keep completion timing identical wherever a card can turn.
enum FlashcardMotion {
    static func duration(reduceMotion: Bool) -> Double { reduceMotion ? 0.15 : 0.65 }
    static func animation(reduceMotion: Bool) -> Animation {
        let duration = duration(reduceMotion: reduceMotion)
        return reduceMotion ? .easeInOut(duration: duration) : .spring(duration: duration, bounce: 0.16)
    }
}

private struct CardOverflowKey: PreferenceKey {
    static let defaultValue: [Bool: Bool] = [:]
    static func reduce(value: inout [Bool: Bool], nextValue: () -> [Bool: Bool]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
