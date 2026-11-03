import RecallCore
import SwiftUI

struct ReviewView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var answerScrolls = false
    var currentID: String? { model.review.currentID }
    var body: some View {
        NavigationStack {
            Group {
                if model.review.phase == .finished {
                    finished
                } else if let id = currentID, let card = model.card(id) {
                    reviewCard(card)
                } else {
                    ProgressView()
                }
            }
            .background(Palette.paper)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .principal) {
                    Text("\(model.library?.session?.completed ?? 0) / \(model.library?.session?.total ?? 0)")
                        .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
    }
    func reviewCard(_ card: Flashcard) -> some View {
        let interactionID = model.review.interactionID
        return GeometryReader { geometry in
            SwipeCanvas(
                labels: model.review.canGrade
                    ? [.left: "Again", .down: "Hard", .right: "Good", .up: "Easy"] : [:],
                verticalSwipes: !answerScrolls,
                gripTitle: model.review.canGrade ? "Swipe to rate" : "Tap the card to flip",
                onSwipe: { direction in
                    guard model.review.acceptsGrade(cardID: card.id, interactionID: interactionID) else {
                        return
                    }
                    model.rate(direction.grade, cardID: card.id)
                }
            ) { interactionEnabled in
                FlashcardView(
                    card: card, showingBack: model.review.showingBack,
                    canTurn: model.review.canTurn && interactionEnabled,
                    height: max(180, geometry.size.height - 84), turn: turnCard,
                    turnToken: model.review.turnToken, turnCompleted: { model.finishTurn(token: $0) },
                    overflowChanged: { answerScrolls = $0 }
                )
            }
            .id(card.id)
            .padding(.horizontal, 20).padding(.top, 20)
        }
        .safeAreaInset(edge: .bottom) {
            // Reserve the rating area so turning the card never changes its size.
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                gradeButton(.left, "Again", "Forgot")
                gradeButton(.down, "Hard", "Recalled with effort")
                gradeButton(.right, "Good", "Recalled correctly")
                gradeButton(.up, "Easy", "Recalled with ease")
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .opacity(model.review.canGrade || isSaving ? 1 : 0)
            .allowsHitTesting(model.review.canGrade)
            .accessibilityHidden(!model.review.canGrade)
        }
    }
    var isSaving: Bool {
        if case .saving = model.review.phase { return true }
        return false
    }
    func turnCard() {
        guard model.review.canTurn else { return }
        let token = UUID()
        withAnimation(FlashcardMotion.animation(reduceMotion: reduceMotion)) {
            model.turnCard(token: token)
        }
    }

    func gradeButton(_ direction: CardSwipeDirection, _ title: String, _ detail: String) -> some View {
        let grade = direction.grade
        return Button {
            guard let id = currentID else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) { model.rate(grade, cardID: id) }
        } label: {
            HStack {
                Label(title, systemImage: direction.symbol).font(.headline)
                Spacer(minLength: 4)
                if let id = currentID {
                    Text(model.interval(grade, cardID: id)).font(.caption.monospacedDigit())
                }
            }.padding(14).frame(maxWidth: .infinity)
                .background(
                    grade == .good ? Palette.accent : Palette.surface, in: RoundedRectangle(cornerRadius: 13)
                )
                .foregroundStyle(grade == .good ? Color.white : Color.primary)
        }.buttonStyle(.plain)
            .disabled(!model.review.canGrade)
            .accessibilityLabel(
                "\(title). \(detail). Next review in \(currentID.map { model.interval(grade, cardID: $0) } ?? "")"
            )
    }
    var finished: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle").font(.system(size: 60, weight: .ultraLight))
                .foregroundStyle(Palette.accent)
            Text("Session complete").font(.largeTitle.weight(.semibold))
            Text("\(model.library?.session?.completed ?? 0) reviews saved.")
                .foregroundStyle(.secondary)
            Spacer()
            PrimaryButton(title: "Back to Today") { dismiss() }
        }.padding(24)
    }
}
