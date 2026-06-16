import SwiftUI

struct ContentView: View {
    @Environment(ConversationStore.self) var store
    @Binding var viewMode: ViewMode

    var body: some View {
        @Bindable var store = store

        NavigationSplitView {
            SidebarView(viewMode: $viewMode)
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 450)
        } detail: {
            if let conversation = store.selectedConversation {
                ConversationDetailView(conversation: conversation)
            } else {
                EmptyStateView()
            }
        }
        .searchable(text: $store.searchText, placement: .sidebar, prompt: "Search conversations")
        .task {
            await store.loadInitial()
            store.startWatching()
        }
    }
}
