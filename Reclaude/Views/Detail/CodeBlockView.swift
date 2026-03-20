import SwiftUI
import MarkdownUI

/// Renders text with styled code blocks and MarkdownUI for prose.
struct CodeBlockView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let content):
                    Markdown(content)
                        .textSelection(.enabled)
                case .code(let language, let content):
                    VStack(alignment: .leading, spacing: 0) {
                        if !language.isEmpty {
                            Text(language)
                                .font(.caption2)
                                .foregroundStyle(ClaudeTheme.peach)
                                .padding(.horizontal, 10)
                                .padding(.top, 8)
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(content)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(10)
                        }
                    }
                    .background(ClaudeTheme.codeBlock.opacity(0.15))
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(ClaudeTheme.codeBlock.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
    }

    private enum TextSegment {
        case text(String)
        case code(language: String, content: String)
    }

    private var segments: [TextSegment] {
        var result: [TextSegment] = []
        let pattern = "```(\\w*)\\n([\\s\\S]*?)```"

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [.text(text)]
        }

        let nsText = text as NSString
        var lastEnd = 0
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        for match in matches {
            let beforeRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
            let before = nsText.substring(with: beforeRange).trimmingCharacters(in: .whitespacesAndNewlines)
            if !before.isEmpty {
                result.append(.text(before))
            }

            let langRange = match.range(at: 1)
            let language = nsText.substring(with: langRange)

            let codeRange = match.range(at: 2)
            let code = nsText.substring(with: codeRange)

            result.append(.code(language: language, content: code))
            lastEnd = match.range.location + match.range.length
        }

        if lastEnd < nsText.length {
            let remaining = nsText.substring(from: lastEnd).trimmingCharacters(in: .whitespacesAndNewlines)
            if !remaining.isEmpty {
                result.append(.text(remaining))
            }
        }

        if result.isEmpty {
            result.append(.text(text))
        }

        return result
    }
}
