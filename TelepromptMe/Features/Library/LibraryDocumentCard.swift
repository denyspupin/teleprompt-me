import SwiftUI

enum LibraryDocumentAction: Hashable {
    case favorite(String)
    case activate(String)
    case edit(String)
    case delete(String)
}

struct LibraryDocumentCard: View {
    let document: ScriptDocument
    let hoveredAction: LibraryDocumentAction?
    let onHoverActionChange: (LibraryDocumentAction?) -> Void
    let onToggleFavorite: () -> Void
    let onActivate: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
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
                        accessibilityLabel: document.isFavorite ? "Remove from favorites" : "Add to favorites",
                        action: onToggleFavorite
                    )

                    quickActionButton(
                        id: .activate(document.id),
                        systemImage: "play.fill",
                        accessibilityLabel: "Show in teleprompter",
                        action: onActivate
                    )

                    quickActionButton(
                        id: .edit(document.id),
                        systemImage: "pencil",
                        accessibilityLabel: "Edit script",
                        action: onEdit
                    )

                    quickActionButton(
                        id: .delete(document.id),
                        systemImage: "trash",
                        accessibilityLabel: "Delete script",
                        action: onDelete
                    )
                }
            }

            HStack {
                Text(document.updatedAt.relativeLibraryDate)
                Spacer()
                Text("\(document.plainText.wordCount) words")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(contentCard)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete Script", systemImage: "trash")
            }
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

    private func quickActionButton(
        id: LibraryDocumentAction,
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
            onHoverActionChange(isHovering ? id : (hoveredAction == id ? nil : hoveredAction))
        }
        .help(accessibilityLabel)
    }
}
