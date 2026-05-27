import SwiftUI
import SwiftData
import AppKit

struct LibraryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScriptCollection.name) private var collections: [ScriptCollection]
    @Query(sort: \ScriptDocument.updatedAt, order: .reverse) private var documents: [ScriptDocument]
    @State private var draftTitle = ""
    @State private var draftText = ""
    @FocusState private var focusedEditor: EditorFocus?

    private enum EditorFocus: Hashable {
        case title
        case body
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 240)
        } detail: {
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea()

                Group {
                    if currentSection == .settings {
                        settingsContent
                    } else if let document = selectedDocument {
                        editorContent(for: document)
                    } else {
                        libraryContent
                    }
                }
                .padding(24)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(overlayButtonTitle) {
                        appState.toggleOverlay()
                    }
                }
            }
            .onAppear {
                normalizeSelection()
                syncDraftFromSelection()
            }
            .onChange(of: appState.selectedSidebarItem) { _, _ in
                appState.selectedDocumentID = nil
                normalizeSelection()
                syncDraftFromSelection()
            }
            .onChange(of: appState.selectedDocumentID) { _, _ in
                syncDraftFromSelection()
            }
            .onChange(of: draftTitle) { _, _ in
                autosaveSelectedDocument()
            }
            .onChange(of: draftText) { _, _ in
                autosaveSelectedDocument()
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: selectedSidebarBinding) {
                Section("Library") {
                    Label("All Scripts", systemImage: "doc.text")
                        .tag(AppState.SidebarItem.allScripts)
                    Label("Favorites", systemImage: "star")
                        .tag(AppState.SidebarItem.favorites)
                    Label("Tags", systemImage: "tag")
                        .tag(AppState.SidebarItem.tags)
                }

                Section("Collections") {
                    if collections.isEmpty {
                        Text("No collections yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(collections) { collection in
                            Label(collection.name, systemImage: "folder")
                                .tag(AppState.SidebarItem.collection(collection.id))
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            Button {
                appState.selectedSidebarItem = .settings
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .padding(12)
        }
    }

    private var libraryContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(sectionTitle)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(sectionSubtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("New Script") {
                    createDocumentAndOpen()
                }
                .buttonStyle(.bordered)
            }

            if filteredDocuments.isEmpty {
                ContentUnavailableView(
                    "No Scripts Here",
                    systemImage: "text.document",
                    description: Text(emptyStateText)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredDocuments) { document in
                            Button {
                                appState.selectedDocumentID = document.id
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(document.title)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)

                                            Text(document.plainText.isEmpty ? "Empty script" : document.plainText)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }

                                    HStack {
                                        Text(relativeDate(for: document.updatedAt))
                                        Spacer()
                                        Text("\(wordCount(for: document.plainText)) words")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(contentCard)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func editorContent(for document: ScriptDocument) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button {
                    appState.selectedDocumentID = nil
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.borderless)

                Spacer()

                if #available(macOS 15.2, *) {
                    Button("Writing Tools") {
                        presentWritingTools()
                    }
                    .buttonStyle(.bordered)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                TextField("Script title", text: $draftTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .writingToolsBehavior(.complete)
                    .focused($focusedEditor, equals: .title)

                HStack(spacing: 12) {
                    Text("\(wordCount(for: draftText)) words")
                    Text("\(draftText.count) characters")
                    Text("Updated \(relativeDate(for: document.updatedAt))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            TextEditor(text: $draftText)
                .font(.system(size: 18))
                .scrollContentBackground(.hidden)
                .writingToolsBehavior(.complete)
                .focused($focusedEditor, equals: .body)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                )

            Text("Changes are saved automatically. Apple Intelligence Writing Tools are available from the text controls.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            focusedEditor = .body
        }
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Settings")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("Adjust TelepromptMe preferences here.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            SettingsView()
                .frame(maxWidth: 620, alignment: .leading)

            Spacer()
        }
    }

    private var contentCard: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.03))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
            )
    }

    private var selectedSidebarBinding: Binding<AppState.SidebarItem?> {
        Binding(
            get: { appState.selectedSidebarItem },
            set: { appState.selectedSidebarItem = $0 }
        )
    }

    private var currentSection: AppState.SidebarItem {
        appState.selectedSidebarItem ?? .allScripts
    }

    private var filteredDocuments: [ScriptDocument] {
        switch currentSection {
        case .allScripts:
            return documents
        case .favorites:
            return documents.filter(\.isFavorite)
        case .tags:
            return documents.filter { !$0.tagNames.isEmpty }
        case .collection(let collectionID):
            return documents.filter { $0.collection?.id == collectionID }
        case .settings:
            return []
        }
    }

    private var selectedDocument: ScriptDocument? {
        guard let selectedID = appState.selectedDocumentID else { return nil }
        return filteredDocuments.first(where: { $0.id == selectedID }) ?? documents.first(where: { $0.id == selectedID })
    }

    private var sectionTitle: String {
        switch currentSection {
        case .allScripts:
            return "All Scripts"
        case .favorites:
            return "Favorites"
        case .tags:
            return "Tags"
        case .collection(let collectionID):
            return collections.first(where: { $0.id == collectionID })?.name ?? "Collection"
        case .settings:
            return "Settings"
        }
    }

    private var sectionSubtitle: String {
        switch currentSection {
        case .allScripts:
            return "Browse every script in your library."
        case .favorites:
            return "Quick access to the scripts you mark as favorites."
        case .tags:
            return "Scripts that already have tags assigned."
        case .collection:
            return "Scripts inside the selected collection."
        case .settings:
            return "Adjust TelepromptMe preferences."
        }
    }

    private var emptyStateText: String {
        switch currentSection {
        case .allScripts:
            return "Create your first script to get started."
        case .favorites:
            return "Favorite scripts will appear here."
        case .tags:
            return "Tagged scripts will appear here."
        case .collection:
            return "This collection does not have any scripts yet."
        case .settings:
            return ""
        }
    }

    private var overlayButtonTitle: String {
        appState.isOverlayVisible ? "Hide Overlay" : "Show Overlay"
    }

    private func normalizeSelection() {
        if appState.selectedSidebarItem == nil {
            appState.selectedSidebarItem = .allScripts
        }
    }

    private func syncDraftFromSelection() {
        guard let document = selectedDocument else {
            draftTitle = ""
            draftText = ""
            return
        }

        draftTitle = document.title
        draftText = document.plainText
    }

    private func createDocumentAndOpen() {
        let newDocument = ScriptDocument(title: "Untitled Script", plainText: "")
        modelContext.insert(newDocument)
        appState.selectedSidebarItem = .allScripts
        appState.selectedDocumentID = newDocument.id
        syncDraftFromSelection()
        try? modelContext.save()
    }

    private func save(document: ScriptDocument) {
        let trimmedTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        document.title = trimmedTitle.isEmpty ? "Untitled Script" : trimmedTitle
        document.plainText = draftText
        document.updatedAt = .now
        try? modelContext.save()
        syncDraftFromSelection()
    }

    private func autosaveSelectedDocument() {
        guard let document = selectedDocument else { return }

        let trimmedTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = trimmedTitle.isEmpty ? "Untitled Script" : trimmedTitle

        guard document.title != resolvedTitle || document.plainText != draftText else { return }

        document.title = resolvedTitle
        document.plainText = draftText
        document.updatedAt = .now
        try? modelContext.save()
    }

    private func wordCount(for text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    private func relativeDate(for date: Date) -> String {
        date.formatted(.relative(presentation: .named))
    }

    private func presentWritingTools() {
        guard #available(macOS 15.2, *) else { return }

        focusedEditor = .body

        DispatchQueue.main.async {
            NSApp.sendAction(#selector(NSResponder.showWritingTools(_:)), to: nil, from: nil)
        }
    }
}
