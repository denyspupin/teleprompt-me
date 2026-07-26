import SwiftUI

enum ScriptEditorFocus: Hashable {
    case title
    case body
}

struct ScriptEditorView: View {
    let document: ScriptDocument
    @Binding var draftTitle: String
    @Binding var draftText: String
    @FocusState.Binding var focusedEditor: ScriptEditorFocus?
    let onBack: () -> Void
    let onDelete: () -> Void
    let onPresent: () -> Void
    let onPresentWritingTools: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            editorHeader
            titleEditor
            bodyEditor

            Label("Saved automatically", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            focusedEditor = .body
        }
    }

    private var editorHeader: some View {
        HStack {
            Button(action: onBack) {
                Label("All Scripts", systemImage: "chevron.left")
            }
            .buttonStyle(.borderless)

            Spacer()

            if #available(macOS 15.2, *) {
                Button("Writing Tools", action: onPresentWritingTools)
                    .buttonStyle(.bordered)
            }

            Menu {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete Script", systemImage: "trash")
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("Script Actions")

            Button(action: onPresent) {
                Label("Present Script", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var titleEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Script title", text: $draftTitle)
                .textFieldStyle(.plain)
                .font(.largeTitle.weight(.bold))
                .writingToolsBehavior(.complete)
                .focused($focusedEditor, equals: .title)

            HStack(spacing: 12) {
                Text("\(draftText.wordCount) words")
                Text("\(draftText.count) characters")
                Text("Updated \(document.updatedAt.relativeLibraryDate)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var bodyEditor: some View {
        TextEditor(text: $draftText)
            .font(.system(size: 18))
            .scrollContentBackground(.hidden)
            .writingToolsBehavior(.complete)
            .focused($focusedEditor, equals: .body)
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.55))
            }
    }
}
