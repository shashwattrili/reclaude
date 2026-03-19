import SwiftUI

enum ViewMode: String, CaseIterable {
    case recent = "Recent"
    case byProject = "By Project"
}

@main
struct ReclaudeApp: App {
    @State private var store = ConversationStore()
    @State private var viewMode: ViewMode = .recent

    var body: some Scene {
        WindowGroup {
            ContentView(viewMode: $viewMode)
                .environment(store)
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1000, height: 700)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Refresh Conversations") {
                    Task { await store.loadAll() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            CommandMenu("Navigate") {
                Button("Recent") {
                    viewMode = .recent
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("By Project") {
                    viewMode = .byProject
                }
                .keyboardShortcut("2", modifiers: .command)

                Divider()

                Button("Resume in Terminal") {
                    if let conv = store.selectedConversation {
                        TerminalLauncher.resume(
                            sessionId: conv.id,
                            cwd: conv.cwd ?? conv.projectPath
                        )
                    }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(store.selectedConversation == nil)
            }
        }
    }
}
