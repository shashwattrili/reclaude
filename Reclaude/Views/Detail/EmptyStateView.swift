import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Select a Conversation", systemImage: "bubble.left.and.bubble.right")
        } description: {
            Text("Choose a conversation from the sidebar to view its messages.")
        }
    }
}
