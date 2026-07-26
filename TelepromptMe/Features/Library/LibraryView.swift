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
    @State private var editingCollectionID: String?
    @State private var draftCollectionName = ""
    @State private var pendingDocumentDeletionID: String?
    @State private var pendingCollectionDeletionID: String?
    @State private var saveErrorMessage: String?
    @FocusState private var focusedEditor: ScriptEditorFocus?
    @FocusState private var focusedCollectionID: String?

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
        } detail: {
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea()

                detailContent
                    .padding(28)
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: createDocumentAndOpen) {
                        Label("New Script", systemImage: "square.and.pencil")
                    }
                    .help("New Script")

                    Button(action: appState.toggleOverlay) {
                        Label(
                            overlayButtonTitle,
                            systemImage: appState.isOverlayVisible ? "eye.slash.fill" : "eye.fill"
                        )
                    }
                    .help(overlayButtonTitle)
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
        .focusedSceneValue(\.newScriptAction, createDocumentAndOpen)
        .confirmationDialog(
            "Delete this script?",
            isPresented: Binding(
                get: { pendingDocumentDeletionID != nil },
                set: { if !$0 { pendingDocumentDeletionID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Script", role: .destructive) {
                confirmDocumentDeletion()
            }
            Button("Cancel", role: .cancel) {
                pendingDocumentDeletionID = nil
            }
        } message: {
            Text("This permanently removes the script from your library.")
        }
        .confirmationDialog(
            "Delete this collection?",
            isPresented: Binding(
                get: { pendingCollectionDeletionID != nil },
                set: { if !$0 { pendingCollectionDeletionID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Collection", role: .destructive) {
                confirmCollectionDeletion()
            }
            Button("Cancel", role: .cancel) {
                pendingCollectionDeletionID = nil
            }
        } message: {
            Text("Scripts in this collection will remain in All Scripts.")
        }
        .alert(
            "Changes Could Not Be Saved",
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "Please try again.")
        }
        .alert(
            "Local Library Is Unavailable",
            isPresented: Binding(
                get: { appState.persistenceWarningMessage != nil },
                set: { if !$0 { appState.persistenceWarningMessage = nil } }
            )
        ) {
            Button("Continue Temporarily", role: .cancel) {}
        } message: {
            Text(
                "TelepromptMe opened a temporary library because its saved library could not be loaded. "
                + "Changes in this session will not be preserved. "
                + (appState.persistenceWarningMessage ?? "")
            )
        }
    }

    private var sidebar: some View {
        List(selection: sidebarSelection) {
            Section("Library") {
                Label("All Scripts", systemImage: "doc.text")
                    .tag(AppState.SidebarItem.allScripts)

                Label("Favorites", systemImage: "star")
                    .tag(AppState.SidebarItem.favorites)
            }

            Section {
                ForEach(collections) { collection in
                    collectionRow(for: collection)
                }

                if collections.isEmpty {
                    Text("No collections")
                        .foregroundStyle(.tertiary)
                }
            } header: {
                HStack {
                    Text("Collections")
                    Spacer()
                    Button(action: createCollection) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                    .help("New Collection")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("TelepromptMe")
    }

    @ViewBuilder
    private func collectionRow(for collection: ScriptCollection) -> some View {
        if editingCollectionID == collection.id {
            TextField("Collection name", text: $draftCollectionName)
                .textFieldStyle(.plain)
                .focused($focusedCollectionID, equals: collection.id)
                .onSubmit {
                    saveCollectionName(collection)
                }
                .onExitCommand {
                    cancelCollectionRename()
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
            CollectionSidebarRow(
                title: collection.name,
                onRename: { beginEditing(collection) },
                onDelete: { pendingCollectionDeletionID = collection.id }
            )
            .tag(AppState.SidebarItem.collection(collection.id))
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded {
                        beginEditing(collection)
                    }
            )
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if let document = selectedDocument {
            editorContent(for: document)
        } else {
            libraryContent
        }
    }

    private var libraryContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(sectionTitle)
                        .font(.largeTitle.weight(.bold))
                    Text(sectionSubtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(documentCountLabel)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }

            if filteredDocuments.isEmpty {
                ContentUnavailableView {
                    Label("No Scripts Here", systemImage: "doc.text")
                } description: {
                    Text(emptyStateText)
                } actions: {
                    Button("New Script", systemImage: "square.and.pencil", action: createDocumentAndOpen)
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredDocuments, id: \.id) { document in
                            LibraryDocumentCard(
                                document: document,
                                isActive: appState.activeScriptID == document.id,
                                onToggleFavorite: { toggleFavorite(for: document) },
                                onActivate: { activate(document: document) },
                                onEdit: { open(document: document) },
                                onDelete: { pendingDocumentDeletionID = document.id }
                            )
                        }
                    }
                    .padding(.bottom, 12)
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
            onDelete: { pendingDocumentDeletionID = document.id },
            onPresent: { activate(document: document) },
            onPresentWritingTools: presentWritingTools
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
        case .collection(let collectionID):
            return documents.filter { $0.collection?.id == collectionID }
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
        }
    }

    private var documentCountLabel: String {
        let count = filteredDocuments.count
        return count == 1 ? "1 script" : "\(count) scripts"
    }

    private var sidebarSelection: Binding<AppState.SidebarItem?> {
        Binding(
            get: { appState.selectedSidebarItem },
            set: { appState.selectedSidebarItem = $0 ?? .allScripts }
        )
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

        if case .collection(let collectionID) = appState.selectedSidebarItem,
           !collections.contains(where: { $0.id == collectionID }) {
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
        persistChanges()
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
        persistChanges()
    }

    private func cancelCollectionRename() {
        editingCollectionID = nil
        focusedCollectionID = nil
        draftCollectionName = ""
    }

    private func delete(collection: ScriptCollection) {
        let deletedID = collection.id

        if editingCollectionID == deletedID {
            editingCollectionID = nil
            focusedCollectionID = nil
            draftCollectionName = ""
        }

        if case .collection(deletedID) = appState.selectedSidebarItem {
            appState.selectedSidebarItem = .allScripts
        }

        do {
            try ScriptLibraryStore(context: modelContext)
                .deleteCollectionPreservingScripts(collection)
        } catch {
            modelContext.rollback()
            saveErrorMessage = error.localizedDescription
        }
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
        persistChanges()
    }

    private func save(document: ScriptDocument) {
        let trimmedTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        document.title = trimmedTitle.isEmpty ? "Untitled Script" : trimmedTitle
        document.plainText = draftText
        document.updatedAt = .now
        persistChanges()
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

        persistChanges()
    }

    private func delete(document: ScriptDocument) {
        let deletedID = document.id
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

        do {
            try ScriptLibraryStore(context: modelContext).delete(document)
        } catch {
            modelContext.rollback()
            saveErrorMessage = error.localizedDescription
        }
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
        persistChanges()
    }

    private func confirmDocumentDeletion() {
        defer { pendingDocumentDeletionID = nil }
        guard let id = pendingDocumentDeletionID,
              let document = documents.first(where: { $0.id == id }) else {
            return
        }
        delete(document: document)
    }

    private func confirmCollectionDeletion() {
        defer { pendingCollectionDeletionID = nil }
        guard let id = pendingCollectionDeletionID,
              let collection = collections.first(where: { $0.id == id }) else {
            return
        }
        delete(collection: collection)
    }

    private func persistChanges() {
        do {
            try ScriptLibraryStore(context: modelContext).save()
        } catch {
            modelContext.rollback()
            syncDraftFromSelection()
            saveErrorMessage = error.localizedDescription
        }
    }

    private func presentWritingTools() {
        guard #available(macOS 15.2, *) else { return }

        focusedEditor = .body

        DispatchQueue.main.async {
            NSApp.sendAction(#selector(NSResponder.showWritingTools(_:)), to: nil, from: nil)
        }
    }
}

private struct CollectionSidebarRow: View {
    let title: String
    let onRename: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Label(title, systemImage: "folder")
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                Button(action: onRename) {
                    Label("Rename", systemImage: "pencil")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .opacity(isHovered ? 1 : 0)
            .help("Collection Actions")
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}
