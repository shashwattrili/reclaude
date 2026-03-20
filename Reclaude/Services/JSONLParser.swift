import Foundation

final class JSONLParser {
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    /// Parse all displayable messages from a conversation file.
    func parseAll(at url: URL) throws -> [ConversationMessage] {
        let data = try Data(contentsOf: url)
        guard let content = String(data: data, encoding: .utf8) else { return [] }

        let lines = content.components(separatedBy: .newlines)
        var messages: [ConversationMessage] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard let lineData = trimmed.data(using: .utf8) else { continue }

            if let msg = try? decoder.decode(ConversationMessage.self, from: lineData) {
                if msg.isDisplayable {
                    // Skip user messages that are only tool results
                    if msg.isUser && !msg.isRealUserMessage {
                        continue
                    }
                    messages.append(msg)
                }
            }
        }

        return messages
    }

    /// Parse only first N lines to extract metadata quickly.
    func parseMetadata(at url: URL, maxLines: Int = 50) -> ConversationMetadata? {
        guard let fileHandle = FileHandle(forReadingAtPath: url.path) else { return nil }
        defer { fileHandle.closeFile() }

        // Read first 32KB — enough for metadata even with many initial progress lines
        let data = fileHandle.readData(ofLength: 32768)
        guard let content = String(data: data, encoding: .utf8) else { return nil }

        let lines = content.components(separatedBy: .newlines)
        var sessionId: String?
        var slug: String?
        var cwd: String?
        var gitBranch: String?
        var firstTimestamp: Date?
        var firstUserMessage: String?
        var lineCount = 0

        for line in lines.prefix(maxLines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let lineData = trimmed.data(using: .utf8) else { continue }

            guard let msg = try? decoder.decode(ConversationMessage.self, from: lineData) else { continue }
            lineCount += 1

            // Extract metadata from any message that has it
            if sessionId == nil { sessionId = msg.sessionId }
            if slug == nil { slug = msg.slug }
            if cwd == nil { cwd = msg.cwd }
            if gitBranch == nil { gitBranch = msg.gitBranch }

            if firstTimestamp == nil, let date = msg.parsedDate {
                firstTimestamp = date
            }

            // Get first real user message for preview
            if firstUserMessage == nil && msg.isRealUserMessage {
                let text = msg.displayText
                if !text.isEmpty {
                    firstUserMessage = String(text.prefix(200))
                }
            }
        }

        // Get total line count and file modification date
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let modDate = attrs?[.modificationDate] as? Date

        // Count total lines (approximate from file size)
        let fileSize = attrs?[.size] as? Int ?? 0
        let estimatedLines = max(lineCount, fileSize / 500) // rough estimate

        return ConversationMetadata(
            sessionId: sessionId,
            slug: slug,
            cwd: cwd,
            gitBranch: gitBranch,
            firstTimestamp: firstTimestamp,
            lastTimestamp: modDate,
            firstUserMessage: firstUserMessage,
            estimatedMessageCount: estimatedLines
        )
    }

    /// Extract only searchable text content from a conversation file.
    /// Returns concatenated user + assistant text, capped at maxChars.
    func extractSearchableText(at url: URL, maxChars: Int = 50_000) -> String {
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else { return "" }

        var result = ""
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let lineData = trimmed.data(using: .utf8) else { continue }
            guard let msg = try? decoder.decode(ConversationMessage.self, from: lineData) else { continue }

            if msg.isDisplayable {
                let text = msg.displayText
                if !text.isEmpty {
                    result += text
                    result += " "
                    if result.count >= maxChars { break }
                }
            }
        }

        return String(result.prefix(maxChars))
    }
}

struct ConversationMetadata {
    let sessionId: String?
    let slug: String?
    let cwd: String?
    let gitBranch: String?
    let firstTimestamp: Date?
    let lastTimestamp: Date?
    let firstUserMessage: String?
    let estimatedMessageCount: Int
}
