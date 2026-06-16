import SwiftUI
import MarkdownUI

struct MessageBubbleView: View {
    let message: ConversationMessage
    var results: [String: ToolResultBlock] = [:]
    var readingMode: Bool = false

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
                Markdown(message.displayText)
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
                    if let model = message.message?.model {
                        Text(model)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    if let date = message.parsedDate {
                        Text("·").foregroundStyle(.tertiary)
                        Text(DateFormatting.relative(date))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 0)
                }

                if !readingMode, let thinking = message.thinkingText {
                    ThinkingView(text: thinking)
                }

                ForEach(message.contentBlocks) { block in
                    switch block {
                    case .text(let tb):
                        CodeBlockView(text: tb.text)
                    case .toolUse(let tu):
                        if !readingMode {
                            ToolCallView(tool: tu, result: results[tu.id])
                        }
                    case .thinking, .toolResult, .unknown:
                        EmptyView()
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ClaudeTheme.claudeBubble.opacity(0.15))
            .clipShape(.rect(cornerRadius: 12))

            Spacer(minLength: 60)
        }
    }
}

struct ThinkingView: View {
    let text: String
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.snappy(duration: 0.15)) { expanded.toggle() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "brain")
                        .font(.caption2)
                    Text("Thinking")
                        .font(.caption.weight(.medium))
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .foregroundStyle(.secondary)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if expanded {
                Markdown(text)
                    .textSelection(.enabled)
                    .font(.callout)
                    .padding(8)
                    .background(.quaternary.opacity(0.4))
                    .clipShape(.rect(cornerRadius: 6))
            }
        }
    }
}
