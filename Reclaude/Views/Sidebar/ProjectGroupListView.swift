import SwiftUI

struct ProjectGroupListView: View {
    @Environment(ConversationStore.self) var store
    @State private var expandedProjects: Set<String> = []
    @State private var hasInitialized = false

    var body: some View {
        @Bindable var store = store

        List(selection: $store.selectedConversationId) {
            ForEach(store.filteredProjects) { project in
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { expandedProjects.contains(project.id) },
                        set: { isExpanded in
                            if isExpanded {
                                expandedProjects.insert(project.id)
                            } else {
                                expandedProjects.remove(project.id)
                            }
                        }
                    )
                ) {
                    ForEach(project.conversations) { conversation in
                        ConversationRowView(conversation: conversation)
                            .tag(conversation.id)
                    }
                } label: {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.secondary)
                        Text(project.displayName)
                            .font(.headline)
                        Spacer()
                        Text("\(project.conversationCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary)
                            .clipShape(.capsule)
                    }
                    .help(project.path)
                    .contextMenu {
                        Button("Expand All") {
                            expandedProjects = Set(store.filteredProjects.map(\.id))
                        }
                        Button("Collapse All") {
                            expandedProjects.removeAll()
                        }
                        Divider()
                        Button("Open in Terminal") {
                            TerminalLauncher.newSession(cwd: project.path)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .onChange(of: store.filteredProjects) {
            if !hasInitialized && !store.filteredProjects.isEmpty {
                expandedProjects = Set(store.filteredProjects.map(\.id))
                hasInitialized = true
            }
        }
        .overlay {
            if store.filteredProjects.isEmpty && !store.searchText.isEmpty {
                ContentUnavailableView.search(text: store.searchText)
            } else if store.filteredProjects.isEmpty {
                ContentUnavailableView(
                    "No Projects",
                    systemImage: "folder",
                    description: Text("No Claude Code projects found.")
                )
            }
        }
    }
}
