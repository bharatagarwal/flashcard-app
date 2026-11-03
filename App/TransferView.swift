import RecallCore
import SwiftUI
import UniformTypeIdentifiers

struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct TransferView: View {
    @EnvironmentObject var model: AppModel
    @State private var choosingFile = false
    @State private var exporting = false
    @State private var document: JSONDocument?
    @State private var exportName = "Recur-backup"
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    Text("Import cards").font(.title2.weight(.semibold))
                    Text(
                        "Share a screenshot in the chat where you create cards. Save the card file, then open it here."
                    ).foregroundStyle(.secondary)
                    PrimaryButton(title: "Choose a card file") { choosingFile = true }
                    importStatus
                    Divider()
                    Eyebrow(text: "Export")
                    Text(
                        "A backup includes cards and review history. Export cards to edit or share them without your review history."
                    )
                    .foregroundStyle(.secondary)
                    Button {
                        export(backup: true)
                    } label: {
                        Label("Export full backup", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered).controlSize(.large)
                    Button("Export cards") { export(backup: false) }.buttonStyle(.bordered).controlSize(
                        .large)
                    Text(
                        "Importing cards keeps your review history. Restoring a backup replaces your library and review history."
                    )
                    .font(.footnote).foregroundStyle(.secondary)
                }.padding(24)
            }.background(Palette.paper).navigationTitle("Import")
                .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.json]) { result in
                    switch result {
                    case .success(let url): model.readImport(url)
                    case .failure(let error): model.importState = .failed(error.localizedDescription)
                    }
                }
                .fileExporter(
                    isPresented: $exporting, document: document, contentType: .json,
                    defaultFilename: exportName
                ) { result in
                    if case .failure(let error) = result { model.error = error.localizedDescription }
                }
        }
    }
    @ViewBuilder var importStatus: some View {
        switch model.importState {
        case .idle: EmptyView()
        case .reading: ProgressView("Reading file…")
        case .saving: ProgressView("Saving…")
        case .preview(let plan):
            VStack(alignment: .leading, spacing: 16) {
                Eyebrow(text: "Ready to import")
                Text(plan.deck.title).font(.headline)
                Text("\(plan.added) new · \(plan.updated) updated · \(plan.unchanged) unchanged")
                if !plan.updates.isEmpty {
                    Text("Check the changes before importing.").font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(plan.updates) { update in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Previous answer").font(.caption)
                            MathText(update.before.answer)
                            if update.after.isArchived {
                                Text("This card will be archived.").foregroundStyle(.secondary)
                            }
                            Text("Updated answer").font(.caption)
                            if let blocks = update.after.answerBlocks, !blocks.isEmpty {
                                CardBlocksView(blocks: blocks, assets: plan.deck.assets)
                            } else {
                                MathText(update.after.answer)
                            }
                            if update.before.prompt != update.after.prompt {
                                Text("Question before").font(.caption)
                                MathText(update.before.prompt)
                                Text("Question after").font(.caption)
                                MathText(update.after.prompt)
                            }
                            Toggle(
                                "Start this card’s schedule again",
                                isOn: Binding(
                                    get: { model.importResetIDs.contains(update.id) },
                                    set: {
                                        if $0 {
                                            model.importResetIDs.insert(update.id)
                                        } else {
                                            model.importResetIDs.remove(update.id)
                                        }
                                    }
                                ))
                        }.padding(.top, 12)
                    } label: {
                        MathText(update.after.prompt, pointSize: 17).allowsHitTesting(false)
                    }
                }
                Text("Review records are always kept. Only selected cards restart their schedule.").font(
                    .footnote
                ).foregroundStyle(.secondary)
                PrimaryButton(title: "Import cards") { model.applyImport() }
                Button("Cancel") { model.importState = .idle }
            }
        case .restore(let library):
            VStack(alignment: .leading, spacing: 16) {
                Label("Restore backup?", systemImage: "arrow.counterclockwise").font(.headline)
                Text(
                    "Replace your library with \(library.deck.cards.count) cards and \(library.events.count) review records from this backup. Export your current backup first if you want to keep it."
                )
                Button("Replace library with this backup", role: .destructive) { model.applyImport() }
                    .buttonStyle(.bordered)
                Button("Cancel") { model.importState = .idle }
            }
        case .complete(let message):
            Label(message, systemImage: "checkmark.circle").foregroundStyle(Palette.accent)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 10) {
                Label("Couldn’t import", systemImage: "exclamationmark.circle").font(.headline)
                Text(message).font(.subheadline)
                Text("Your library has not changed.").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
    func export(backup: Bool) {
        guard let library = model.library else { return }
        do {
            let data = backup ? try Codec.encode(library) : try Codec.encode(library.deck)
            document = JSONDocument(data: data)
            exportName = backup ? "Recur-backup" : "Recur-deck"
            exporting = true
        } catch { model.error = error.localizedDescription }
    }
}

struct SettingsView: View {
    @AppStorage("appearance") private var appearance: AppAppearance = .system
    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appearance) {
                        ForEach(AppAppearance.allCases) { mode in Text(mode.title).tag(mode) }
                    }
                }
                Section("Review") {
                    Text("Review dates adjust to how well you remember each card, aiming for 90% recall.")
                    Text(
                        "Again: you forgot. Hard: you recalled with effort. Good: you recalled correctly. Easy: you recalled with ease. If you needed the answer, choose Again."
                    ).font(.footnote)
                }
                Section("Your data") {
                    Text(
                        "Cards and review history stay on this phone and work offline. Export a full backup from Import before moving to a new phone."
                    )
                    Text("Create new cards in your chat, then import the card file here.").font(.footnote)
                }
                Section("Open source") {
                    if let url = URL(string: "https://github.com/open-spaced-repetition/swift-fsrs") {
                        Link("Swift FSRS · MIT", destination: url)
                    }
                    if let url = URL(string: "https://github.com/KaTeX/KaTeX") {
                        Link("KaTeX · MIT", destination: url)
                    }
                    NavigationLink("Licences") {
                        ScrollView { Text(licences).font(.footnote).padding() }.navigationTitle("Licences")
                    }
                }
            }.navigationTitle("Settings")
        }
    }
    var licences: String {
        guard let url = Bundle.main.url(forResource: "ThirdPartyLicenses", withExtension: "txt"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else { return "See the bundled FSRS and KaTeX licences in the source project." }
        return text
    }
}
