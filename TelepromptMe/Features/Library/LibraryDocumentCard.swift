import AppKit
import SwiftUI

struct LibraryDocumentCard: View {
    let document: ScriptDocument
    let isActive: Bool
    let onToggleFavorite: () -> Void
    let onActivate: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.text")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
                .frame(width: 34, height: 34)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(document.title)
                        .font(.headline)
                        .lineLimit(1)

                    if document.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                            .accessibilityLabel("Favorite")
                    }

                    if isActive {
                        Text("Active")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                    }
                }

                Text(document.plainText.isEmpty ? "Empty script" : document.plainText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)

                HStack(spacing: 6) {
                    Text(document.updatedAt.relativeLibraryDate)
                    Text("•")
                    Text("\(document.plainText.wordCount) words")
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 12)

            Button(action: onActivate) {
                Label(isActive ? "Presenting" : "Present", systemImage: isActive ? "checkmark" : "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(isActive ? .secondary : .accentColor)
            .disabled(isActive)
            .help(isActive ? "This script is active" : "Show in Teleprompter")

            Menu {
                Button(action: onEdit) {
                    Label("Edit Script", systemImage: "pencil")
                }

                Button(action: onToggleFavorite) {
                    Label(
                        document.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                        systemImage: document.isFavorite ? "star.slash" : "star"
                    )
                }

                Divider()

                Button(role: .destructive, action: onDelete) {
                    Label("Delete Script", systemImage: "trash")
                }
            } label: {
                Label("More", systemImage: "ellipsis")
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("Script Actions")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture(count: 2, perform: onEdit)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .contextMenu {
            Button("Edit Script", action: onEdit)
            Button(
                document.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                action: onToggleFavorite
            )
            Divider()
            Button("Delete Script", role: .destructive, action: onDelete)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Edit Script", onEdit)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(isHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.10) : Color(nsColor: .controlBackgroundColor))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(isHovered ? 0.8 : 0.45))
            }
            .shadow(color: .black.opacity(isHovered ? 0.08 : 0.035), radius: isHovered ? 8 : 3, y: 2)
    }
}
