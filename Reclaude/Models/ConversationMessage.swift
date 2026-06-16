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
    let aiTitle: String?
    let customTitle: String?

    var id: String { uuid ?? "\(type)-\(timestamp ?? UUID().uuidString)" }

    var isUser: Bool { type == "user" }
    var isAssistant: Bool { type == "assistant" }
    var isDisplayable: Bool { isUser || isAssistant }

    var parsedDate: Date? {
        guard let timestamp else { return nil }
        return DateFormatting.parseISO(timestamp)
    }

    /// Combined thinking text from this message, if any.
    var thinkingText: String? {
        guard case .blocks(let blocks)? = message?.content else { return nil }
        let t = blocks.compactMap { block -> String? in
            if case .thinking(let tb) = block { return tb.thinking }
            return nil
        }.joined(separator: "\n")
        return t.isEmpty ? nil : t
    }

    /// tool_result blocks carried by this (user) message, keyed by tool_use id.
    var toolResults: [ToolResultBlock] {
        guard case .blocks(let blocks)? = message?.content else { return [] }
        return blocks.compactMap { if case .toolResult(let r) = $0 { return r }; return nil }
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
    let input: JSONValue?

    enum CodingKeys: String, CodingKey {
        case type, id, name, input
    }

    private func str(_ key: String) -> String? { input?[key]?.stringValue }

    /// The single most descriptive parameter, for one-line display.
    var inputSummary: String {
        switch name {
        case "Bash":                 return str("command") ?? ""
        case "Read", "Edit", "Write", "NotebookEdit":
                                     return str("file_path").map(shortPath) ?? ""
        case "Glob":                 return str("pattern") ?? ""
        case "Grep":                 return str("pattern") ?? ""
        case "Task", "Agent":        return str("description") ?? str("subagent_type") ?? ""
        case "WebFetch":             return str("url") ?? ""
        case "WebSearch":            return str("query") ?? ""
        case "TodoWrite":            return "todo list"
        case "TaskCreate", "TaskUpdate": return str("subject") ?? str("status") ?? ""
        default:
            return str("file_path").map(shortPath) ?? str("path") ?? str("query") ?? ""
        }
    }

    var bashCommand: String? { name == "Bash" ? str("command") : nil }

    /// (path, old, new) for Edit; for Write, old is "" and new is content.
    var fileChange: (path: String, old: String, new: String)? {
        switch name {
        case "Edit", "NotebookEdit":
            guard let p = str("file_path") else { return nil }
            return (p, str("old_string") ?? str("old_source") ?? "", str("new_string") ?? str("new_source") ?? "")
        case "Write":
            guard let p = str("file_path") else { return nil }
            return (p, "", str("content") ?? "")
        default: return nil
        }
    }

    private func shortPath(_ p: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return p.hasPrefix(home) ? "~" + p.dropFirst(home.count) : p
    }
}

/// A minimal JSON value so tool-call inputs can be decoded generically.
enum JSONValue: Codable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([String: JSONValue].self) { self = .object(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }

    subscript(_ key: String) -> JSONValue? {
        if case .object(let o) = self { return o[key] }
        return nil
    }

    var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .number(let n): return n == n.rounded() ? String(Int(n)) : String(n)
        case .bool(let b): return String(b)
        default: return nil
        }
    }
}

struct ToolResultBlock: Codable {
    let type: String
    let toolUseId: String
    let content: MessageContent?
    let isError: Bool?

    enum CodingKeys: String, CodingKey {
        case type
        case toolUseId = "tool_use_id"
        case content
        case isError = "is_error"
    }

    var textValue: String {
        switch content {
        case .text(let s): return s
        case .blocks(let blocks):
            return blocks.compactMap { if case .text(let t) = $0 { return t.text }; return nil }
                .joined(separator: "\n")
        case nil: return ""
        }
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
