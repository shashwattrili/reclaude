import SwiftUI

struct ConversationDetailView: View {
    @Environment(ConversationStore.self) var store
    let conversation: Conversation

    var body: some View {
        Group {
            if store.isLoadingMessages {
                ProgressView("Loading messages...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.loadedMessages.isEmpty {
                ContentUnavailableView(
                    "No Messages",
                    systemImage: "bubble.left",
                    description: Text("This conversation appears to be empty.")
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(store.loadedMessages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle(conversation.displayName)
        .navigationSubtitle(conversation.projectPath)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    TerminalLauncher.resume(
                        sessionId: conversation.id,
                        cwd: conversation.cwd ?? conversation.projectPath
                    )
                } label: {
                    Label("Resume in Terminal", systemImage: "terminal")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .task(id: conversation.id) {
            await store.loadMessages(for: conversation)
        }
    }
}
