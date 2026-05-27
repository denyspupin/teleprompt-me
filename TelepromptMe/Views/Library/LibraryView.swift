import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \ScriptCollection.name) private var collections: [ScriptCollection]
    @Query(sort: \ScriptDocument.updatedAt, order: .reverse) private var documents: [ScriptDocument]

    var body: some View {
        NavigationSplitView {
            List(selection: .constant(appState.selectedCollectionID)) {
                Section("Library") {
                    Label("All Scripts", systemImage: "doc.text")
                    Label("Favorites", systemImage: "star")
                    Label("Tags", systemImage: "tag")
                }

                Section("Collections") {
                    ForEach(collections) { collection in
                        Label(collection.name, systemImage: "folder")
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 240)
        } detail: {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TelepromptMe")
                            .font(.largeTitle)
                            .fontWeight(.semibold)
                        Text("A focused library for scripts that can be promoted on top of any macOS workflow.")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Show Overlay") {
                        appState.presentOverlayIfNeeded()
                    }
                    .buttonStyle(.borderedProminent)
                }

                if documents.isEmpty {
                    ContentUnavailableView(
                        "No Scripts Yet",
                        systemImage: "text.document",
                        description: Text("The next phase will add import, creation, and organization workflows on top of this foundation.")
                    )
                } else {
                    List(documents) { document in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(document.title)
                                .font(.headline)
                            Text(document.plainText)
                                .lineLimit(3)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Spacer()
            }
            .padding(24)
        }
    }
}
