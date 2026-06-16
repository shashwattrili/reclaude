import SwiftUI

struct ConversationDetailView: View {
    @Environment(ConversationStore.self) var store
    @AppStorage("readingMode") private var readingMode = false
    let conversation: Conversation

    private var messages: [ConversationMessage] { store.loadedMessages }

    /// tool_use id -> its result (results live in following user messages).
    private var resultMap: [String: ToolResultBlock] {
        var map: [String: ToolResultBlock] = [:]
        for msg in messages {
            for r in msg.toolResults { map[r.toolUseId] = r }
        }
        return map
    }

    /// file path -> first message id that edits it (for jump-to-file).
    private var fileAnchors: [String: String] {
        var map: [String: String] = [:]
        for msg in messages {
            for tool in msg.toolUseBlocks {
                if let c = tool.fileChange, map[c.path] == nil { map[c.path] = msg.id }
            }
        }
        return map
    }

    var body: some View {
        Group {
            if store.isLoadingMessages {
                ProgressView("Loading messages…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if messages.isEmpty {
                ContentUnavailableView(
                    "No Messages",
                    systemImage: "bubble.left",
                    description: Text("This conversation appears to be empty.")
                )
            } else {
                conversationScroll
            }
        }
        .navigationTitle(conversation.displayName)
        .navigationSubtitle(conversation.projectPath)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ResumeButton(
                    sessionId: conversation.id,
                    cwd: conversation.cwd ?? conversation.projectPath,
                    prominent: true
                )
            }
            ToolbarItem(placement: .automatic) {
                Toggle(isOn: $readingMode) {
                    Label("Reading Mode", systemImage: readingMode ? "text.alignleft" : "wrench.and.screwdriver")
                }
                .toggleStyle(.button)
                .help("Reading mode — hide tool calls and thinking")
            }
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button("Copy as Markdown") { copyAsMarkdown() }
                    Button("Copy Session ID") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(conversation.id, forType: .string)
                    }
                    Button("Reveal JSONL in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([conversation.fileURL])
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .task(id: conversation.id) {
            await store.loadMessages(for: conversation)
        }
    }

    private var conversationScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    SessionSummaryView(
                        insights: ConversationInsights(messages: messages),
                        conversation: conversation,
                        onJumpToFile: { path in
                            if let id = fileAnchors[path] {
                                withAnimation { proxy.scrollTo(id, anchor: .top) }
                            }
                        }
                    )
                    .padding(.bottom, 4)

                    ForEach(messages) { message in
                        MessageBubbleView(message: message, results: resultMap, readingMode: readingMode)
                            .id(message.id)
                    }
                }
                .padding()
            }
        }
    }

    private func copyAsMarkdown() {
        var out = "# \(conversation.displayName)\n\n"
        for msg in messages {
            let text = msg.displayText
            guard !text.isEmpty else { continue }
            out += msg.isUser ? "## User\n\n\(text)\n\n" : "## Claude\n\n\(text)\n\n"
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(out, forType: .string)
    }
}
