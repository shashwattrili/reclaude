import Foundation

/// Stateless, `Sendable` JSONL parser. Safe to capture in detached tasks.
struct JSONLParser: Sendable {

    private func makeDecoder() -> JSONDecoder { JSONDecoder() }

    /// Parse all displayable messages from a conversation file (used by the detail view).
    func parseAll(at url: URL) throws -> [ConversationMessage] {
        let data = try Data(contentsOf: url)
        guard let content = String(data: data, encoding: .utf8) else { return [] }
        let decoder = makeDecoder()

        var messages: [ConversationMessage] = []
        content.enumerateLines { line, _ in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let lineData = trimmed.data(using: .utf8) else { return }
            guard let msg = try? decoder.decode(ConversationMessage.self, from: lineData) else { return }
            guard msg.isDisplayable else { return }
            // Skip auto-generated user messages that are only tool results.
            if msg.isUser && !msg.isRealUserMessage { return }
            messages.append(msg)
        }
        return messages
    }

    /// Single full-file pass: extract metadata, real title, preview, and full
    /// searchable text in one read. Returns nil if the file can't be read.
    ///
    /// `searchText` contains only real conversational text — user inputs and
    /// assistant text outputs. Tool calls, tool results, and thinking are excluded.
    func parse(at url: URL, maxSearchChars: Int = 1_000_000) -> ParsedConversation? {
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else { return nil }
        let decoder = makeDecoder()

        var sessionId: String?
        var slug: String?
        var aiTitle: String?
        var customTitle: String?
        var cwd: String?
        var gitBranch: String?
        var firstTimestamp: Date?
        var firstUserMessage: String?
        var messageCount = 0
        var commands: [String] = []
        var filesTouched: [String] = []
        var filesSeen = Set<String>()
        var search = ""
        search.reserveCapacity(min(data.count, maxSearchChars))

        content.enumerateLines { line, stop in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let lineData = trimmed.data(using: .utf8) else { return }
            guard let msg = try? decoder.decode(ConversationMessage.self, from: lineData) else { return }

            // Metadata can live on any line type.
            if sessionId == nil { sessionId = msg.sessionId }
            if slug == nil { slug = msg.slug }
            if cwd == nil { cwd = msg.cwd }
            if gitBranch == nil { gitBranch = msg.gitBranch }
            if aiTitle == nil, let t = msg.aiTitle, !t.isEmpty { aiTitle = t }
            if customTitle == nil, let t = msg.customTitle, !t.isEmpty { customTitle = t }
            if firstTimestamp == nil, let date = msg.parsedDate { firstTimestamp = date }

            // Collect commands + touched files from assistant tool calls.
            if msg.isAssistant {
                for tool in msg.toolUseBlocks {
                    if let cmd = tool.bashCommand, !cmd.isEmpty, commands.count < 500 {
                        commands.append(cmd)
                    }
                    if let change = tool.fileChange, filesSeen.insert(change.path).inserted {
                        filesTouched.append(change.path)
                    }
                }
            }

            guard msg.isDisplayable else { return }

            // Real user message (text, not tool-result-only) -> preview + search.
            if msg.isUser && !msg.isRealUserMessage { return }

            let text = msg.displayText
            guard !text.isEmpty else { return }

            if firstUserMessage == nil && msg.isRealUserMessage {
                firstUserMessage = String(text.prefix(200))
            }
            messageCount += 1

            if search.count < maxSearchChars {
                search += text
                search += "\n"
                if search.count >= maxSearchChars { stop = true }
            }
        }

        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let modDate = attrs?[.modificationDate] as? Date

        return ParsedConversation(
            sessionId: sessionId,
            slug: slug,
            title: customTitle ?? aiTitle,
            cwd: cwd,
            gitBranch: gitBranch,
            firstTimestamp: firstTimestamp,
            lastTimestamp: modDate,
            firstUserMessage: firstUserMessage,
            messageCount: messageCount,
            searchText: search,
            commands: commands,
            filesTouched: filesTouched
        )
    }
}

struct ParsedConversation: Sendable {
    let sessionId: String?
    let slug: String?
    let title: String?
    let cwd: String?
    let gitBranch: String?
    let firstTimestamp: Date?
    let lastTimestamp: Date?
    let firstUserMessage: String?
    let messageCount: Int
    let searchText: String
    let commands: [String]
    let filesTouched: [String]
}
