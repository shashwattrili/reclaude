import SwiftUI

struct SidebarView: View {
    @Environment(ConversationStore.self) var store
    @Binding var viewMode: ViewMode

    var body: some View {
        Group {
            if store.isLoading {
                ProgressView("Scanning conversations...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch viewMode {
                case .recent:
                    RecentListView()
                case .byProject:
                    ProjectGroupListView()
                case .commands:
                    CommandHistoryView()
                }
            }
        }
        .navigationTitle("Reclaude")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Picker("View", selection: $viewMode) {
                    Label("Recent", systemImage: "clock")
                        .tag(ViewMode.recent)
                    Label("By Project", systemImage: "folder")
                        .tag(ViewMode.byProject)
                    Label("Commands", systemImage: "terminal")
                        .tag(ViewMode.commands)
                }
                .pickerStyle(.segmented)
            }
        }
    }
}
