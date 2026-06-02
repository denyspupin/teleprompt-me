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
    let onPresentWritingTools: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            toolbar
            titleEditor
            bodyEditor

            Text("Changes are saved automatically. Apple Intelligence Writing Tools are available from the text controls.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            focusedEditor = .body
        }
    }

    private var toolbar: some View {
        HStack {
            Button(action: onBack) {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(.borderless)

            Spacer()

            if #available(macOS 15.2, *) {
                Button("Writing Tools", action: onPresentWritingTools)
                    .buttonStyle(.bordered)
            }

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(.bordered)
        }
    }

    private var titleEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Script title", text: $draftTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 30, weight: .bold, design: .rounded))
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
    }
}
