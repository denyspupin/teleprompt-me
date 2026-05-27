import SwiftUI
import SwiftData
import AppKit

struct LibraryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]
    @Query(sort: \ScriptCollection.name) private var collections: [ScriptCollection]
    @Query(sort: \ScriptDocument.updatedAt, order: .reverse) private var documents: [ScriptDocument]
    @State private var draftTitle = ""
    @State private var draftText = ""
    @State private var hoveredAction: HoveredAction?
    @State private var selectedSettingsSection: SettingsSection = .general
    @FocusState private var focusedEditor: EditorFocus?

    private enum EditorFocus: Hashable {
        case title
        case body
    }

    private enum HoveredAction: Hashable {
        case favorite(String)
        case activate(String)
        case edit(String)
        case delete(String)
    }

    var body: some View {
        NavigationSplitView {
            Group {
                if isSettingsSelected {
                    settingsSidebar
                } else {
                    sidebar
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 240)
        } detail: {
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea()

                detailContent
                .padding(isSettingsSelected ? 0 : 24)
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
                syncPlaybackSpeedFromSettings()
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

    private var settingsSidebar: some View {
        SettingsSidebarView(selectedSection: $selectedSettingsSection) {
            appState.selectedSidebarItem = .allScripts
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if isSettingsSelected {
            settingsContent
        } else if let document = selectedDocument {
            editorContent(for: document)
        } else {
            libraryContent
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

                Button {
                    createDocumentAndOpen()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.06))

                        Circle()
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)

                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.primary.opacity(0.88))
                    }
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("New Script")
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
                        ForEach(filteredDocuments, id: \.id) { document in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(document.title)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)

                                        Text(document.plainText.isEmpty ? "Empty script" : document.plainText)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                    }

                                    Spacer()

                                    HStack(spacing: 8) {
                                        quickActionButton(
                                            id: .favorite(document.id),
                                            systemImage: document.isFavorite ? "star.fill" : "star",
                                            accessibilityLabel: document.isFavorite ? "Remove from favorites" : "Add to favorites"
                                        ) {
                                            toggleFavorite(for: document)
                                        }

                                        quickActionButton(
                                            id: .activate(document.id),
                                            systemImage: "play.fill",
                                            accessibilityLabel: "Show in teleprompter"
                                        ) {
                                            activate(document: document)
                                        }

                                        quickActionButton(
                                            id: .edit(document.id),
                                            systemImage: "pencil",
                                            accessibilityLabel: "Edit script"
                                        ) {
                                            open(document: document)
                                        }

                                        quickActionButton(
                                            id: .delete(document.id),
                                            systemImage: "trash",
                                            accessibilityLabel: "Delete script"
                                        ) {
                                            delete(document: document)
                                        }
                                    }
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
                            .contextMenu {
                                Button(role: .destructive) {
                                    delete(document: document)
                                } label: {
                                    Label("Delete Script", systemImage: "trash")
                                }
                            }
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

                Button(role: .destructive) {
                    delete(document: document)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)
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
            SettingsView(selectedSection: $selectedSettingsSection)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

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

    private var isSettingsSelected: Bool {
        if case .settings = currentSection {
            return true
        }
        return false
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

    private var currentSettings: AppSettings? {
        settings.first
    }

    private func normalizeSelection() {
        if appState.selectedSidebarItem == nil {
            appState.selectedSidebarItem = .allScripts
        }
    }

    private func syncPlaybackSpeedFromSettings() {
        if let currentSettings {
            appState.playbackController.applySpeed(currentSettings.playbackSpeedWordsPerMinute)
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
        appState.activateScript(id: newDocument.id, title: newDocument.title, text: newDocument.plainText)
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

        if appState.activeScriptID == document.id {
            appState.activateScript(id: document.id, title: resolvedTitle, text: draftText)
        }

        try? modelContext.save()
    }

    private func delete(document: ScriptDocument) {
        let deletedID = document.id
        modelContext.delete(document)

        if appState.selectedDocumentID == deletedID {
            appState.selectedDocumentID = nil
            draftTitle = ""
            draftText = ""
        }

        if appState.activeScriptID == deletedID {
            appState.activeScriptID = nil
            appState.activeScriptTitle = "No Active Script"
            appState.activeScriptText = "Choose a script from the library to show it in the teleprompter overlay."
        }

        try? modelContext.save()
    }

    private func open(document: ScriptDocument) {
        appState.selectedDocumentID = document.id
    }

    private func activate(document: ScriptDocument) {
        appState.activateScript(id: document.id, title: document.title, text: document.plainText)
        appState.presentOverlayIfNeeded()
    }

    private func toggleFavorite(for document: ScriptDocument) {
        document.isFavorite.toggle()
        try? modelContext.save()
    }

    private func quickActionButton(
        id: HoveredAction,
        systemImage: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        let isHovered = hoveredAction == id

        return Button(action: action) {
            ZStack {
                Circle()
                    .fill(isHovered ? Color.accentColor.opacity(0.32) : Color.white.opacity(0.06))

                Circle()
                    .strokeBorder(isHovered ? Color.accentColor.opacity(0.75) : Color.white.opacity(0.08), lineWidth: 1)

                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isHovered ? Color.white : Color.primary.opacity(0.88))
            }
            .frame(width: 30, height: 30)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.06 : 1)
        .shadow(color: isHovered ? Color.accentColor.opacity(0.28) : .clear, radius: 8, y: 2)
        .animation(.easeOut(duration: 0.14), value: isHovered)
        .onHover { isHovering in
            hoveredAction = isHovering ? id : (hoveredAction == id ? nil : hoveredAction)
        }
        .help(accessibilityLabel)
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
