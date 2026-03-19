import SwiftUI

struct RecentListView: View {
    @Environment(ConversationStore.self) var store

    var body: some View {
        @Bindable var store = store

        List(store.filteredRecent, selection: $store.selectedConversationId) { conversation in
            ConversationRowView(conversation: conversation)
                .tag(conversation.id)
        }
        .listStyle(.sidebar)
        .overlay {
            if store.filteredRecent.isEmpty && !store.searchText.isEmpty {
                ContentUnavailableView.search(text: store.searchText)
            } else if store.filteredRecent.isEmpty {
                ContentUnavailableView(
                    "No Conversations",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Start a Claude Code session in your terminal to see conversations here.")
                )
            }
        }
    }
}
