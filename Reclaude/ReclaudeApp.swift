import SwiftUI

enum ViewMode: String, CaseIterable {
    case recent = "Recent"
    case byProject = "By Project"
    case commands = "Commands"
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
                    Task { await store.reload() }
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

                Button("Commands") {
                    viewMode = .commands
                }
                .keyboardShortcut("3", modifiers: .command)

                Divider()

                Button("Resume in Terminal") {
                    if let conv = store.selectedConversation {
                        let term = TerminalApp.resolvedDefault(
                            preference: UserDefaults.standard.string(forKey: "defaultTerminal")
                        )
                        TerminalLauncher.resume(
                            sessionId: conv.id,
                            cwd: conv.cwd ?? conv.projectPath,
                            in: term
                        )
                    }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(store.selectedConversation == nil)
            }
        }

        Settings {
            SettingsView()
        }
    }
}
