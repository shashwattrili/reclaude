import SwiftUI

/// Global, searchable history of every Bash command run across all sessions.
struct CommandHistoryView: View {
    @Environment(ConversationStore.self) private var store

    var body: some View {
        @Bindable var store = store
        let commands = store.filteredCommands

        List(selection: $store.selectedConversationId) {
            ForEach(commands) { entry in
                CommandRow(entry: entry)
                    .tag(entry.conversationId)
                    .listRowInsets(.init(top: 4, leading: 8, bottom: 4, trailing: 8))
            }
        }
        .listStyle(.inset)
        .overlay {
            if commands.isEmpty {
                if store.searchText.isEmpty {
                    ContentUnavailableView("No Commands", systemImage: "terminal",
                        description: Text("Bash commands from your sessions will appear here."))
                } else {
                    ContentUnavailableView.search(text: store.searchText)
                }
            }
        }
    }
}

private struct CommandRow: View {
    let entry: ConversationStore.CommandEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "terminal")
                    .font(.caption2)
                    .foregroundStyle(ClaudeTheme.peach)
                    .padding(.top, 2)
                Text(entry.command)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(3)
                    .textSelection(.enabled)
                Spacer(minLength: 4)
                CopyButton(text: entry.command)
            }
            HStack(spacing: 6) {
                Text(entry.project)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if let d = entry.date {
                    Text("·").foregroundStyle(.tertiary)
                    Text(DateFormatting.relative(d))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Copy Command") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.command, forType: .string)
            }
        }
    }
}
