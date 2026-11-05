import RecallCore
import SwiftUI

struct LibraryView: View {
    var body: some View { NavigationStack { LibraryBrowserView() } }
}

enum LibraryLayout {
    case canvas, list
}

/// Search and scope stay in one place while the user switches how the same cards are shown.
struct LibraryBrowserView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let archived: Bool
    @State private var search = ""
    @State private var layout: LibraryLayout
    @State private var needsUnderstandingOnly: Bool

    init(archived: Bool = false, needsUnderstandingOnly: Bool = false, layout: LibraryLayout = .canvas) {
        self.archived = archived
        _needsUnderstandingOnly = State(initialValue: needsUnderstandingOnly)
        _layout = State(initialValue: layout)
    }
    var body: some View {
        let query = LibraryQuery(
            archived: archived, needsUnderstandingOnly: needsUnderstandingOnly, search: search)
        let groups = model.library?.groups(matching: query) ?? []
        let pausedCount =
            model.library?.groups(matching: LibraryQuery(archived: archived, needsUnderstandingOnly: true))
            .reduce(0) { $0 + $1.cards.count } ?? 0
        Group {
            switch layout {
            case .canvas:
                LibraryCanvasView(groups: groups, needsUnderstandingOnly: needsUnderstandingOnly)
                    .id(query)
            case .list:
                LibrarySectionsView(
                    groups: groups, archived: archived, needsUnderstandingOnly: needsUnderstandingOnly)
            }
        }
        .background(Palette.paper)
        .navigationTitle(archived ? "Archived cards" : "Library")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Find a card")
        .safeAreaInset(edge: .top) {
            Picker("Cards to show", selection: $needsUnderstandingOnly) {
                Text("All cards").tag(false)
                Text("Needs understanding (\(pausedCount))").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12)
            .background(Palette.paper)
        }
        .overlay {
            if groups.isEmpty {
                if !search.isEmpty {
                    ContentUnavailableView.search(text: search)
                } else if needsUnderstandingOnly {
                    ContentUnavailableView(
                        "No cards need understanding", systemImage: "questionmark.circle",
                        description: Text("Mark a card during a review to pause it here."))
                } else if archived {
                    ContentUnavailableView(
                        "No archived cards", systemImage: "archivebox",
                        description: Text("Restored cards appear in Library."))
                } else {
                    ContentUnavailableView("No cards", systemImage: "rectangle.stack")
                }
            }
        }
        .toolbar {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                    layout = layout == .canvas ? .list : .canvas
                }
            } label: {
                Label(
                    layout == .canvas ? "Show list" : "Show canvas",
                    systemImage: layout == .canvas ? "list.bullet" : "square.grid.3x3")
            }
            if !archived, model.library?.deck.cards.contains(where: \.isArchived) == true {
                NavigationLink {
                    LibraryBrowserView(
                        archived: true, needsUnderstandingOnly: needsUnderstandingOnly, layout: layout)
                } label: {
                    Label("Archived cards", systemImage: "archivebox")
                }
            }
        }
    }
}

private struct LibrarySectionsView: View {
    @EnvironmentObject var model: AppModel
    let groups: [LibraryGroup]
    let archived: Bool
    let needsUnderstandingOnly: Bool

    var body: some View {
        let orderedIDs = groups.flatMap { $0.cards.map(\.id) }
        List {
            if archived, !groups.isEmpty {
                Text("Archived cards stay out of reviews. Restore a card to return it to the Library.")
                    .font(.subheadline).foregroundStyle(.secondary).listRowBackground(Color.clear)
            }
            ForEach(groups) { group in
                Section(group.concept.title) {
                    ForEach(group.cards) { card in
                        NavigationLink {
                            CardDetailView(
                                cardID: card.id, cardIDs: orderedIDs,
                                needsUnderstandingOnly: needsUnderstandingOnly)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                MathText(card.prompt, pointSize: 18).allowsHitTesting(false)
                                if model.library?.needsUnderstanding(card.id) == true {
                                    Label("Needs understanding", systemImage: "questionmark.circle")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }.padding(.vertical, 10)
                        }
                        .listRowBackground(Palette.surface)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(
                                archived ? "Restore to Library" : "Archive",
                                systemImage: archived ? "tray.and.arrow.up" : "archivebox"
                            ) {
                                do { try model.setArchived(cardID: card.id, archived: !archived) } catch {
                                    model.error = error.localizedDescription
                                }
                            }.tint(archived ? Palette.accent : .secondary)
                        }
                    }
                }
            }
        }.scrollContentBackground(.hidden)
    }
}

struct CardDetailView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let needsUnderstandingOnly: Bool
    @State private var browser: BrowseMachine
    @State private var answerScrolls = false
    private var selectedID: String { browser.currentID }
    private var cardIDs: [String] { browser.cardIDs }

    init(cardID: String, cardIDs: [String] = [], needsUnderstandingOnly: Bool = false) {
        self.needsUnderstandingOnly = needsUnderstandingOnly
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
        let actionCardID = selectedID
        let actionVisitID = browser.visitID
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
            VStack(spacing: 0) {
                if model.library?.needsUnderstanding(selectedID) == true {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Needs understanding").font(.headline)
                            Text("Memory reviews paused").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Mark understood") {
                            changeUnderstanding(to: .understood, cardID: actionCardID, visitID: actionVisitID)
                        }
                        .buttonStyle(.bordered).disabled(!browser.canTurn)
                    }.padding(.horizontal, 20).padding(.vertical, 10)
                }
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
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    Menu {
                        if model.card(selectedID)?.isArchived == false {
                            Button("Edit answer") {
                                guard browser.currentID == actionCardID,
                                    browser.accepts(visitID: actionVisitID)
                                else { return }
                                browser.edit()
                            }
                        }
                        if model.library?.needsUnderstanding(selectedID) == true {
                            Button("Mark understood") {
                                changeUnderstanding(
                                    to: .understood, cardID: actionCardID, visitID: actionVisitID)
                            }
                        } else {
                            Button("Needs understanding") {
                                changeUnderstanding(
                                    to: .needsUnderstanding, cardID: actionCardID, visitID: actionVisitID)
                            }
                        }
                    } label: {
                        Label("Card actions", systemImage: "ellipsis")
                    }.disabled(!browser.canTurn)
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

    private func changeUnderstanding(to status: CardUnderstanding, cardID: String, visitID: UUID) {
        guard browser.currentID == cardID else { return }
        do {
            try browser.beginUnderstandingChange(visitID: visitID)
        } catch { return }
        do {
            try model.setUnderstanding(status, cardID: cardID)
            browser.finishUnderstandingChange()
            if needsUnderstandingOnly, status == .understood { close() }
        } catch {
            browser.finishUnderstandingChange()
            model.error = error.localizedDescription
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
