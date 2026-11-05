import RecallCore
import SwiftUI
import UniformTypeIdentifiers

@main
struct RecurApp: App {
    @StateObject private var model = AppModel()
    @AppStorage("appearance") private var appearance: AppAppearance = .system
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(model)
                .preferredColorScheme(appearance.colorScheme)
                .tint(Palette.accent)
        }
    }
}

enum Palette {
    static let accent = Color("AccentColor")
    static let paper = Color("Paper")
    static let surface = Color("Surface")
}

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @State private var selection = 0
    @State private var recovering = false
    var body: some View {
        Group {
            if let failure = model.startupError {
                VStack {
                    ContentUnavailableView {
                        Label(
                            "Couldn’t open your library", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text("Your saved file has been kept. \(failure)")
                    }
                    Button("Restore a backup") { recovering = true }.buttonStyle(.borderedProminent).padding()
                }
                .sheet(isPresented: $recovering) { TransferView().environmentObject(model) }
            } else {
                TabView(selection: $selection) {
                    TodayView().tabItem { Label("Today", systemImage: "rectangle.on.rectangle") }.tag(0)
                    LibraryView().tabItem { Label("Library", systemImage: "books.vertical") }.tag(1)
                    TransferView().tabItem { Label("Import", systemImage: "square.and.arrow.down") }.tag(2)
                    SettingsView().tabItem { Label("Settings", systemImage: "slider.horizontal.3") }.tag(3)
                }
            }
        }
        .onOpenURL { url in
            model.presentingReview = false
            selection = 2
            model.readImport(url)
        }
        .alert(
            "Couldn’t save",
            isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })
        ) {
            Button("OK") { model.error = nil }
        } message: {
            Text(model.error ?? "")
        }
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.caption.weight(.semibold)).tracking(1.6).foregroundStyle(.secondary)
    }
}

struct PrimaryButton: View {
    let title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 9)
        }.buttonStyle(.borderedProminent).controlSize(.large).buttonBorderShape(.roundedRectangle(radius: 16))
    }
}

struct TodayView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var now = Date()
    private var dueCount: Int { model.library?.dueCards(at: now).count ?? 0 }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack {
                        Eyebrow(text: now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        Spacer()
                        AppearanceMenu()
                    }
                    Text("Recur").font(.largeTitle.weight(.bold))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(dueCount)").font(.system(size: 84, weight: .regular, design: .serif))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text(dueCount == 1 ? "card ready to review" : "cards ready to review").font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    if let count = model.library?.needsUnderstandingCount, count > 0 {
                        NavigationLink {
                            CardListView(needsUnderstandingOnly: true)
                        } label: {
                            Label(
                                "\(count) \(count == 1 ? "card needs" : "cards need") understanding",
                                systemImage: "questionmark.circle"
                            )
                            .font(.subheadline)
                        }
                    }
                    if model.library?.session?.queue.isEmpty == false {
                        PrimaryButton(title: "Resume review") { begin() }
                    } else if dueCount > 0 {
                        PrimaryButton(title: "Start review") { begin() }
                    } else {
                        Label("You’re up to date", systemImage: "checkmark.circle").font(.headline)
                            .foregroundStyle(Palette.accent)
                        if let next = model.nextDue {
                            Text("Next review \(next.formatted(date: .abbreviated, time: .shortened)).")
                                .foregroundStyle(.secondary)
                        }
                    }
                }.padding(24)
            }.background(Palette.paper).toolbar(.hidden, for: .navigationBar)
                .fullScreenCover(isPresented: $model.presentingReview, onDismiss: { now = Date() }) {
                    ReviewView().environmentObject(model)
                }
                .onChange(of: scenePhase) { _, phase in if phase == .active { now = Date() } }
                .task {
                    while !Task.isCancelled {
                        now = Date()
                        try? await Task.sleep(for: .seconds(30))
                    }
                }
        }
    }
    func begin() {
        model.startReview()
        if model.error == nil { model.presentingReview = true }
    }
}
