import RecallCore
import SwiftUI

/// A card can move freely, but its action commits only after crossing a labelled threshold.
struct SwipeCanvas<Content: View>: View {
    let labels: [CardSwipeDirection: String]
    var verticalSwipes = true
    var departingDirections = Set(CardSwipeDirection.allCases)
    let gripTitle: String
    let onSwipe: (CardSwipeDirection) -> Void
    @ViewBuilder let content: (Bool) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var machine = CardSwipeMachine()
    @GestureState private var touching = false

    private var allowed: Set<CardSwipeDirection> { Set(labels.keys) }
    private var offset: CGSize {
        switch machine.phase {
        case .idle: return .zero
        case .dragging(let x, let y):
            return CGSize(width: x * 0.7, height: y * 0.7)
        case .committing(let direction, _):
            if reduceMotion || !departingDirections.contains(direction) { return .zero }
            switch direction {
            case .left: return CGSize(width: -650, height: 20)
            case .right: return CGSize(width: 650, height: 20)
            case .up: return CGSize(width: 0, height: -900)
            case .down: return CGSize(width: 0, height: 900)
            }
        }
    }
    private var committing: Bool {
        if case .committing(let direction, _) = machine.phase {
            return departingDirections.contains(direction)
        }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            content(machine.canInteract)
                .overlay(alignment: .top) {
                    if let direction = machine.readyDirection, let title = labels[direction] {
                        Label(title, systemImage: direction.symbol)
                            .font(.headline).padding(.horizontal, 18).padding(.vertical, 10)
                            .foregroundStyle(Palette.accent)
                            .background(.regularMaterial, in: Capsule())
                            .padding(.top, 16).allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
                .rotationEffect(.degrees(reduceMotion ? 0 : Double(offset.width) / 32))
                .offset(reduceMotion && !committing ? .zero : offset)
                .opacity(committing ? 0 : 1)
                .contentShape(Rectangle())
                .simultaneousGesture(drag(fromGrip: false))
            VStack(spacing: 5) {
                Capsule().fill(.secondary.opacity(0.4)).frame(width: 32, height: 4)
                Text(gripTitle).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity).frame(height: 44)
            .contentShape(Rectangle())
            .gesture(drag(fromGrip: true))
            .accessibilityHidden(true)
        }
        .sensoryFeedback(.selection, trigger: machine.readyDirection)
        .onChange(of: touching) { _, active in
            // Gesture cancellation (including a sheet or system interruption) must release the card.
            if !active { withAnimation(.snappy) { machine.cancel() } }
        }
        .onDisappear { machine.invalidate() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { machine.cancel() }
        }
    }

    private func drag(fromGrip: Bool) -> some Gesture {
        DragGesture(minimumDistance: 16)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in
                let directions = fromGrip || verticalSwipes ? allowed : allowed.subtracting([.up, .down])
                let x = value.translation.width
                let y = value.translation.height
                // A scrolling answer keeps vertical drags for reading.
                guard fromGrip || verticalSwipes || abs(x) > abs(y) * 1.3 else { return }
                machine.update(x: x, y: y, allowed: directions)
            }
            .onEnded { value in
                let directions = fromGrip || verticalSwipes ? allowed : allowed.subtracting([.up, .down])
                machine.update(x: value.translation.width, y: value.translation.height, allowed: directions)
                let token = UUID()
                var action: CardSwipeDirection?
                withAnimation(
                    reduceMotion
                        ? .easeOut(duration: 0.12)
                        : (machine.readyDirection == nil
                            ? .spring(duration: 0.35, bounce: 0.15) : .easeIn(duration: 0.22)),
                    completionCriteria: .removed
                ) {
                    action = machine.release(token: token, allowed: directions)
                } completion: {
                    guard let action, machine.finish(token: token) else { return }
                    onSwipe(action)
                }
            }
    }
}

extension CardSwipeDirection {
    var symbol: String {
        switch self {
        case .left: "arrow.left"
        case .right: "arrow.right"
        case .up: "arrow.up"
        case .down: "arrow.down"
        }
    }

}
