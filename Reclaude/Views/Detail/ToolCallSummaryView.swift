import SwiftUI

struct ToolCallSummaryView: View {
    let name: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.caption2)
            Text(name)
                .font(.caption)
        }
        .foregroundStyle(ClaudeTheme.peach)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(ClaudeTheme.toolPill.opacity(0.25))
        .clipShape(.capsule)
    }
}
