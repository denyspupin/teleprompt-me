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
    @State private var hoveredAction: LibraryDocumentAction?
    @State private var selectedSettingsSection: SettingsSection = .general
    @State private var editingCollectionID: String?
    @State private var draftCollectionName = ""
    @FocusState private var focusedEditor: ScriptEditorFocus?
    @FocusState private var focusedCollectionID: String?

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
                  Button(action: appState.toggleOverlay) {
                    Label(overlayButtonTitle, systemImage: appState.isOverlayVisible ? "eye.slash.fill" : "eye.fill").labelStyle(.titleAndIcon)
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
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sidebarSection(title: "Library") {
                        sidebarButton(
                            title: "All Scripts",
                            systemImage: "doc.text",
                            item: .allScripts
                        )
                        sidebarButton(
                            title: "Favorites",
                            systemImage: "star",
                            item: .favorites
                        )
                    }

                    sidebarSection(
                        title: "Collections",
                        actionSystemImage: "plus",
                        actionHelp: "New Collection",
                        action: createCollection
                    ) {
                        if collections.isEmpty {
                            Text("No collections yet")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                        } else {
                            ForEach(collections) { collection in
                                collectionRow(for: collection)
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.never)

            Button {
                appState.selectedSidebarItem = .settings
            } label: {
                SidebarHoverRow(
                    title: "Settings",
                    systemImage: "gearshape",
                    isSelected: currentSection == .settings
                )
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func sidebarSection<Content: View>(
        title: String,
        actionSystemImage: String? = nil,
        actionHelp: String? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                if let actionSystemImage, let action {
                    Button(action: action) {
                        Image(systemName: actionSystemImage)
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 22, height: 22)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(actionHelp ?? "")
                }
            }
            .padding(.horizontal, 12)

            VStack(spacing: 6) {
                content()
            }
        }
    }

    private func sidebarButton(
        title: String,
        systemImage: String,
        item: AppState.SidebarItem
    ) -> some View {
        Button {
            appState.selectedSidebarItem = item
        } label: {
            SidebarHoverRow(
                title: title,
                systemImage: systemImage,
                isSelected: currentSection == item
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func collectionRow(for collection: ScriptCollection) -> some View {
        if editingCollectionID == collection.id {
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)

                TextField("Collection name", text: $draftCollectionName)
                    .textFieldStyle(.plain)
                    .focused($focusedCollectionID, equals: collection.id)
                    .onSubmit {
                        saveCollectionName(collection)
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.16))
            }
            .onAppear {
                draftCollectionName = collection.name
                focusedCollectionID = collection.id
            }
            .onChange(of: focusedCollectionID) { _, focusedID in
                if focusedID != collection.id {
                    saveCollectionName(collection)
                }
            }
        } else {
            Button {
                appState.selectedSidebarItem = .collection(collection.id)
            } label: {
                SidebarHoverRow(
                    title: collection.name,
                    systemImage: "folder",
                    isSelected: currentSection == .collection(collection.id)
                )
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded {
                        beginEditing(collection)
                    }
            )
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
            @State var isCreateNewDocHovered: Bool = false
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(sectionTitle)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(sectionSubtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                Spacer()
              
              Button(action: createDocumentAndOpen) {
                ZStack {
                  Circle().opacity(0)
                  Label("New Script", systemImage: "square.and.pencil")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 16))
                }
              }
              .frame(width: 40, height: 40, alignment: .center)
              .buttonSizing(.fitted)
              .buttonBorderShape(.circle)
              .onHover { isHovered in
                isCreateNewDocHovered = isHovered
              }
              .glassEffect()
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
                            LibraryDocumentCard(
                                document: document,
                                hoveredAction: hoveredAction,
                                onHoverActionChange: { hoveredAction = $0 },
                                onToggleFavorite: { toggleFavorite(for: document) },
                                onActivate: { activate(document: document) },
                                onEdit: { open(document: document) },
                                onDelete: { delete(document: document) }
                            )
                        }
                    }
                }
            }
        }
    }

    private func editorContent(for document: ScriptDocument) -> some View {
        ScriptEditorView(
            document: document,
            draftTitle: $draftTitle,
            draftText: $draftText,
            focusedEditor: $focusedEditor,
            onBack: { appState.selectedDocumentID = nil },
            onDelete: { delete(document: document) },
            onPresentWritingTools: presentWritingTools
        )
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsView(selectedSection: $selectedSettingsSection)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            Spacer()
        }
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

    private func createCollection() {
        let newCollection = ScriptCollection(name: "Untitled Collection")
        modelContext.insert(newCollection)
        appState.selectedSidebarItem = .collection(newCollection.id)
        beginEditing(newCollection)
        try? modelContext.save()
    }

    private func beginEditing(_ collection: ScriptCollection) {
        editingCollectionID = collection.id
        draftCollectionName = collection.name

        DispatchQueue.main.async {
            focusedCollectionID = collection.id
        }
    }

    private func saveCollectionName(_ collection: ScriptCollection) {
        guard editingCollectionID == collection.id else { return }

        let trimmedName = draftCollectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        collection.name = trimmedName.isEmpty ? "Untitled Collection" : trimmedName
        editingCollectionID = nil
        focusedCollectionID = nil
        draftCollectionName = ""
        try? modelContext.save()
    }

    private func createDocumentAndOpen() {
        let selectedCollection: ScriptCollection?

        if case .collection(let collectionID) = currentSection {
            selectedCollection = collections.first(where: { $0.id == collectionID })
        } else {
            selectedCollection = nil
        }

        let newDocument = ScriptDocument(title: "Untitled Script", plainText: "", collection: selectedCollection)
        modelContext.insert(newDocument)
        if let selectedCollection {
            appState.selectedSidebarItem = .collection(selectedCollection.id)
        } else {
            appState.selectedSidebarItem = .allScripts
        }
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

    private func presentWritingTools() {
        guard #available(macOS 15.2, *) else { return }

        focusedEditor = .body

        DispatchQueue.main.async {
            NSApp.sendAction(#selector(NSResponder.showWritingTools(_:)), to: nil, from: nil)
        }
    }
}
