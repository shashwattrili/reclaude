import SwiftUI

struct MessageBubbleView: View {
    let message: ConversationMessage

    var body: some View {
        if message.isUser {
            userBubble
        } else {
            assistantBubble
        }
    }

    private var userBubble: some View {
        HStack {
            Spacer(minLength: 60)
            VStack(alignment: .trailing, spacing: 4) {
                Text(message.displayText)
                    .textSelection(.enabled)
                    .padding(12)
                    .background(ClaudeTheme.userBubble.opacity(0.3))
                    .clipShape(.rect(cornerRadius: 12))

                if let date = message.parsedDate {
                    Text(DateFormatting.relative(date))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var assistantBubble: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkle")
                        .font(.caption)
                        .foregroundStyle(ClaudeTheme.sparkle)
                    Text("Claude")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(ClaudeTheme.sparkle)
                    if let date = message.parsedDate {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(DateFormatting.relative(date))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                ForEach(message.contentBlocks) { block in
                    switch block {
                    case .text(let tb):
                        CodeBlockView(text: tb.text)
                    case .toolUse(let tu):
                        ToolCallSummaryView(name: tu.name)
                    case .thinking:
                        EmptyView()
                    case .toolResult:
                        EmptyView()
                    case .unknown:
                        EmptyView()
                    }
                }
            }
            .padding(12)
            .background(ClaudeTheme.claudeBubble.opacity(0.15))
            .clipShape(.rect(cornerRadius: 12))

            Spacer(minLength: 60)
        }
    }
}
