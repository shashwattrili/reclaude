import Foundation

/// Represents a single line from a .jsonl conversation file.
struct ConversationMessage: Identifiable, Codable {
    let uuid: String?
    let parentUuid: String?
    let type: String
    let timestamp: String?
    let sessionId: String?
    let slug: String?
    let cwd: String?
    let gitBranch: String?
    let version: String?
    let userType: String?
    let isSidechain: Bool?
    let message: APIMessage?
    let promptId: String?
    let permissionMode: String?

    var id: String { uuid ?? "\(type)-\(timestamp ?? UUID().uuidString)" }

    var isUser: Bool { type == "user" }
    var isAssistant: Bool { type == "assistant" }
    var isDisplayable: Bool { isUser || isAssistant }

    var parsedDate: Date? {
        guard let timestamp else { return nil }
        return DateFormatting.parseISO(timestamp)
    }

    /// Extract plain text from this message for display.
    var displayText: String {
        guard let message else { return "" }
        switch message.content {
        case .text(let str):
            return str
        case .blocks(let blocks):
            return blocks.compactMap { block in
                switch block {
                case .text(let tb): return tb.text
                default: return nil
                }
            }.joined(separator: "\n")
        }
    }

    /// Check if this is a real user message (not just tool results).
    var isRealUserMessage: Bool {
        guard isUser, let message else { return false }
        switch message.content {
        case .text: return true
        case .blocks(let blocks):
            return blocks.contains { block in
                if case .text = block { return true }
                return false
            }
        }
    }

    /// Get tool use blocks from assistant messages.
    var toolUseBlocks: [ToolUseBlock] {
        guard let message else { return [] }
        if case .blocks(let blocks) = message.content {
            return blocks.compactMap { block in
                if case .toolUse(let tu) = block { return tu }
                return nil
            }
        }
        return []
    }

    /// Get content blocks for rendering.
    var contentBlocks: [ContentBlock] {
        guard let message else { return [] }
        switch message.content {
        case .text(let str):
            return [.text(TextBlock(type: "text", text: str))]
        case .blocks(let blocks):
            return blocks
        }
    }
}

struct APIMessage: Codable {
    let role: String?
    let content: MessageContent
    let model: String?
    let id: String?
    let usage: TokenUsage?

    enum CodingKeys: String, CodingKey {
        case role, content, model, id, usage
    }
}

/// Content can be a plain string OR an array of content blocks.
enum MessageContent: Codable {
    case text(String)
    case blocks([ContentBlock])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .text(str)
        } else if let blocks = try? container.decode([ContentBlock].self) {
            self = .blocks(blocks)
        } else {
            self = .text("")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let str):
            try container.encode(str)
        case .blocks(let blocks):
            try container.encode(blocks)
        }
    }
}

enum ContentBlock: Codable, Identifiable {
    case text(TextBlock)
    case thinking(ThinkingBlock)
    case toolUse(ToolUseBlock)
    case toolResult(ToolResultBlock)
    case unknown

    var id: String {
        switch self {
        case .text(let b): return "text-\(b.text.hashValue)"
        case .thinking(let b): return "thinking-\(b.thinking.hashValue)"
        case .toolUse(let b): return "tool-\(b.id)"
        case .toolResult(let b): return "result-\(b.toolUseId)"
        case .unknown: return "unknown"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            self = .text(try TextBlock(from: decoder))
        case "thinking":
            self = .thinking(try ThinkingBlock(from: decoder))
        case "tool_use":
            self = .toolUse(try ToolUseBlock(from: decoder))
        case "tool_result":
            self = .toolResult(try ToolResultBlock(from: decoder))
        default:
            self = .unknown
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let b): try b.encode(to: encoder)
        case .thinking(let b): try b.encode(to: encoder)
        case .toolUse(let b): try b.encode(to: encoder)
        case .toolResult(let b): try b.encode(to: encoder)
        case .unknown: break
        }
    }
}

struct TextBlock: Codable {
    let type: String
    let text: String
}

struct ThinkingBlock: Codable {
    let type: String
    let thinking: String
}

struct ToolUseBlock: Codable {
    let type: String
    let id: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case type, id, name
    }
}

struct ToolResultBlock: Codable {
    let type: String
    let toolUseId: String
    let content: MessageContent?

    enum CodingKeys: String, CodingKey {
        case type
        case toolUseId = "tool_use_id"
        case content
    }
}

struct TokenUsage: Codable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }
}
