import RecallCore
import SwiftUI

struct LibraryView: View {
    var body: some View { NavigationStack { CardListView() } }
}

private struct CardListView: View {
    @EnvironmentObject var model: AppModel
    var archived = false
    @State private var search = ""
    @State private var showingCanvas = false
    private var groups: [(topic: Concept, cards: [Flashcard])] {
        let concepts = model.library?.deck.concepts ?? []
        let titles = Dictionary(uniqueKeysWithValues: concepts.map { ($0.id, $0.title) })
        let matches = (model.library?.deck.cards ?? []).filter {
            $0.isArchived == archived
                && (search.isEmpty
                    || ($0.prompt + " " + $0.answer + " " + (titles[$0.conceptID] ?? ""))
                        .localizedCaseInsensitiveContains(search))
        }
        let byTopic = Dictionary(grouping: matches, by: \.conceptID)
        return concepts.compactMap { topic in
            guard let cards = byTopic[topic.id], !cards.isEmpty else { return nil }
            return (topic, cards)
        }
    }
    var body: some View {
        let groups = groups
        let orderedIDs = groups.flatMap { $0.cards.map(\.id) }
        List {
            if archived, !orderedIDs.isEmpty {
                Text("Archived cards stay out of reviews. Restore a card to return it to the Library.")
                    .font(.subheadline).foregroundStyle(.secondary).listRowBackground(Color.clear)
            }
            ForEach(groups, id: \.topic.id) { group in
                Section(group.topic.title) {
                    ForEach(group.cards) { card in
                        NavigationLink {
                            CardDetailView(cardID: card.id, cardIDs: orderedIDs)
                        } label: {
                            MathText(card.prompt, pointSize: 18)
                                .allowsHitTesting(false).padding(.vertical, 10)
                        }.listRowBackground(Palette.surface)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(
                                    archived ? "Restore to Library" : "Archive",
                                    systemImage: archived ? "tray.and.arrow.up" : "archivebox"
                                ) {
                                    do {
                                        try model.setArchived(cardID: card.id, archived: !archived)
                                    } catch { model.error = error.localizedDescription }
                                }.tint(archived ? Palette.accent : .secondary)
                            }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden).background(Palette.paper)
        .navigationTitle(archived ? "Archived cards" : "Library")
        .searchable(text: $search, prompt: "Find a card")
        .overlay {
            if orderedIDs.isEmpty {
                if archived, search.isEmpty {
                    ContentUnavailableView(
                        "No archived cards", systemImage: "archivebox",
                        description: Text("Restored cards appear in Library."))
                } else {
                    ContentUnavailableView.search(text: search)
                }
            }
        }
        .fullScreenCover(isPresented: $showingCanvas) {
            LibraryCanvasView(cardIDs: orderedIDs, archived: archived)
        }
        .toolbar {
            Button {
                showingCanvas = true
            } label: {
                Label("Browse canvas", systemImage: "square.grid.3x3")
            }
            .disabled(orderedIDs.isEmpty)
            if !archived, model.library?.deck.cards.contains(where: \.isArchived) == true {
                NavigationLink {
                    CardListView(archived: true)
                } label: {
                    Label("Archived cards", systemImage: "archivebox")
                }
            }
        }
    }
}

struct CardDetailView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var browser: BrowseMachine
    @State private var answerScrolls = false
    private var selectedID: String { browser.currentID }
    private var cardIDs: [String] { browser.cardIDs }

    init(cardID: String, cardIDs: [String] = []) {
        _browser = State(initialValue: BrowseMachine(cardID: cardID, cardIDs: cardIDs))
    }

    private var index: Int { browser.index }
    private var directions: [CardSwipeDirection: String] {
        guard browser.canTurn else { return [:] }
        var values: [CardSwipeDirection: String] = [.up: "Flip card", .down: "Close"]
        if index > 0 { values[.right] = "Previous card" }
        if index + 1 < cardIDs.count { values[.left] = "Next card" }
        return values
    }

    var body: some View {
        GeometryReader { geometry in
            if let card = model.card(selectedID) {
                let visitID = browser.visitID
                ZStack {
                    if index > 0 {
                        neighbor(at: index - 1, height: max(180, geometry.size.height - 64))
                            .frame(width: geometry.size.width - 48)
                            .offset(x: -geometry.size.width + 32, y: -12)
                    }
                    if index + 1 < cardIDs.count {
                        neighbor(at: index + 1, height: max(180, geometry.size.height - 64))
                            .frame(width: geometry.size.width - 48)
                            .offset(x: geometry.size.width - 32, y: -12)
                    }
                    SwipeCanvas(
                        labels: directions, verticalSwipes: !answerScrolls,
                        departingDirections: [.left, .right, .down],
                        gripTitle: "Swipe ← next · → previous · ↑ flip · ↓ close",
                        onSwipe: { direction in
                            guard browser.accepts(visitID: visitID) else { return }
                            swipe(direction)
                        }
                    ) { interactionEnabled in
                        FlashcardView(
                            card: card, showingBack: browser.face.showingBack,
                            canTurn: browser.canTurn && interactionEnabled,
                            height: max(180, geometry.size.height - 64), turn: turnCard,
                            turnToken: browser.face.turnToken,
                            turnCompleted: { browser.finishTurn(token: $0) },
                            overflowChanged: { answerScrolls = $0 }
                        )
                    }
                    .id(card.id)
                    .transition(
                        .asymmetric(
                            insertion: reduceMotion
                                ? .opacity
                                : .move(edge: browser.lastStep > 0 ? .trailing : .leading).combined(
                                    with: .opacity),
                            removal: .identity
                        )
                    )
                    .padding(.horizontal, 24).padding(.top, 20)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
            }
        }
        .background(Palette.paper).navigationTitle("Card").navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button {
                    move(by: -1)
                } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                .disabled(!browser.canGoBack).accessibilityLabel("Previous card")
                Spacer()
                Button {
                    browser.showHistory()
                } label: {
                    VStack(spacing: 3) {
                        Text("\(index + 1) / \(cardIDs.count)").font(.subheadline.monospacedDigit())
                        Text("Past reviews").font(.caption).foregroundStyle(.secondary)
                    }.frame(minHeight: 44)
                }.buttonStyle(.plain).disabled(!browser.canTurn)
                Spacer()
                Button {
                    move(by: 1)
                } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                }
                .disabled(!browser.canGoForward).accessibilityLabel("Next card")
            }.padding(.horizontal, 20).padding(.bottom, 8)
        }
        .safeAreaInset(edge: .top) {
            if model.card(selectedID)?.isArchived == true {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Archived").font(.headline)
                        Text("Kept out of reviews").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Restore to Library") {
                        do {
                            try model.setArchived(cardID: selectedID, archived: false)
                            close()
                        } catch { model.error = error.localizedDescription }
                    }.buttonStyle(.borderedProminent).font(.subheadline).disabled(!browser.canTurn)
                }.padding(.horizontal, 20).padding(.vertical, 10)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    if model.card(selectedID)?.isArchived == false {
                        Button("Edit") { browser.edit() }.disabled(!browser.canTurn)
                    }
                    Button {
                        close()
                    } label: {
                        Image(systemName: "xmark")
                    }.accessibilityLabel("Close card")
                }
            }
        }
        .sheet(item: Binding(get: { browser.sheet }, set: { if $0 == nil { browser.dismissSheet() } })) {
            sheet in
            switch sheet {
            case .edit(let cardID):
                if let card = model.card(cardID) { EditCardView(card: card) }
            case .history(let cardID):
                CardHistoryView(cardID: cardID).presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func neighbor(at index: Int, height: CGFloat) -> some View {
        VStack {
            if let card = model.card(cardIDs[index]) {
                MathText(card.prompt, pointSize: 22).padding(26)
            }
        }
        .frame(maxWidth: .infinity).frame(height: height)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(.primary.opacity(0.08)) }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .scaleEffect(0.96)
        .allowsHitTesting(false).accessibilityHidden(true)
    }

    private func move(by delta: Int) {
        let next = index + delta
        guard cardIDs.indices.contains(next) else { return }
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.35, bounce: 0.1)) {
            answerScrolls = false
            browser.move(by: delta)
        }
    }
    private func turnCard() {
        guard browser.canTurn else { return }
        let token = UUID()
        withAnimation(FlashcardMotion.animation(reduceMotion: reduceMotion)) {
            do { try browser.beginTurn(token: token) } catch { return }
        }
    }

    private func close() {
        browser.close()
        dismiss()
    }

    private func swipe(_ direction: CardSwipeDirection) {
        switch direction {
        case .left: move(by: 1)
        case .right: move(by: -1)
        case .up: turnCard()
        case .down: close()
        }
    }
}

private struct CardHistoryView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let cardID: String

    var body: some View {
        NavigationStack {
            List {
                Text("When you studied this card and how you rated your recall.")
                    .font(.subheadline).foregroundStyle(.secondary)
                if let card = model.card(cardID) {
                    if card.isArchived {
                        Text("Archived · kept out of reviews").foregroundStyle(.secondary)
                    } else if let schedule = model.library?.schedules[card.id] {
                        LabeledContent(
                            "Next review", value: schedule.due.formatted(date: .abbreviated, time: .shortened)
                        )
                    }
                    let events = Array(
                        (model.library?.events.filter { $0.cardID == card.id } ?? []).reversed().prefix(20))
                    if events.isEmpty {
                        Text("You haven’t reviewed this card yet.").foregroundStyle(.secondary)
                    }
                    ForEach(events) { event in
                        DisclosureGroup {
                            if let key = event.contentID, let content = model.library?.contentVersions?[key] {
                                VStack(alignment: .leading, spacing: 12) {
                                    MathText(content.card.prompt)
                                    Divider()
                                    MathText(content.card.answer)
                                }.padding(.vertical, 12)
                            } else {
                                Text("Question and answer unavailable for this older review.")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        } label: {
                            Text(
                                "\(event.log.review.formatted(date: .abbreviated, time: .shortened)) · \(event.log.rating.stringValue.capitalized)"
                            )
                            .font(.subheadline)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden).background(Palette.paper)
            .navigationTitle("Past reviews").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct EditCardView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let card: Flashcard
    @State private var answer: String
    @State private var error: String?
    @State private var reset = false
    init(card: Flashcard) {
        self.card = card
        _answer = State(initialValue: card.answer)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Front") { MathText(card.prompt) }
                Section("Back") { TextEditor(text: $answer).frame(minHeight: 180) }
                Section { Toggle("Reset this card’s schedule", isOn: $reset) }
                Section {
                    Text(
                        "Use \\( … \\) for inline maths and \\[ … \\] for displayed maths. Editing the answer keeps your review history."
                    ).font(.footnote)
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }.navigationTitle("Edit card").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            do {
                                try model.editAnswer(cardID: card.id, answer: answer, reset: reset)
                                dismiss()
                            } catch { self.error = error.localizedDescription }
                        }
                    }
                }
        }
    }
}
