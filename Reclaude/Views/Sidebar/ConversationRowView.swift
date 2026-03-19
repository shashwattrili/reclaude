import SwiftUI
import AppKit

struct ConversationRowView: View {
    let conversation: Conversation

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(conversation.displayName)
                    .font(.system(.body, weight: .medium))
                    .lineLimit(1)
                Spacer()
                if let date = conversation.lastTimestamp {
                    Text(DateFormatting.relative(date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let preview = conversation.firstUserMessage {
                Text(preview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 6) {
                if let branch = conversation.gitBranch, branch != "HEAD" {
                    Label(branch, systemImage: "arrow.triangle.branch")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Text(conversation.projectDisplayName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Resume in Terminal") {
                TerminalLauncher.resume(
                    sessionId: conversation.id,
                    cwd: conversation.cwd ?? conversation.projectPath
                )
            }

            Divider()

            Button("Copy Session ID") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(conversation.id, forType: .string)
            }

            Button("Reveal in Finder") {
                NSWorkspace.shared.selectFile(
                    conversation.fileURL.path,
                    inFileViewerRootedAtPath: conversation.fileURL.deletingLastPathComponent().path
                )
            }
        }
    }
}
