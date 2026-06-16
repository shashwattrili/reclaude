import Foundation
import SwiftUI

@MainActor
@Observable
final class ConversationStore {
    var projects: [Project] = []
    var selectedConversationId: String?
    var loadedMessages: [ConversationMessage] = []
    var searchText: String = ""
    var isLoading: Bool = false
    var isLoadingMessages: Bool = false

    private let scanner = ClaudeDirectoryScanner()
    private let parser = JSONLParser()
    private var fileWatcher: FileWatcher?

    /// conversation id -> full searchable text (original case).
    private var contentIndex: [String: String] = [:]
    /// file path -> cached parse, reused across scans when mod-date is unchanged.
    private var parseCache: [String: CachedFile] = [:]

    // Reload coalescing: collapse bursts of FSEvents (active sessions) into a
    // single sequential rescan so shared state is only ever mutated one-at-a-time
    // on the main actor.
    private var reloadInFlight = false
    private var reloadQueued = false

    // MARK: - Derived collections

    var allConversations: [Conversation] {
        var seen = Set<String>()
        return projects.flatMap(\.conversations).filter { seen.insert($0.id).inserted }
    }

    var recentConversations: [Conversation] {
        allConversations.sorted {
            ($0.lastTimestamp ?? .distantPast) > ($1.lastTimestamp ?? .distantPast)
        }
    }

    var selectedConversation: Conversation? {
        guard let id = selectedConversationId else { return nil }
        return allConversations.first { $0.id == id }
    }

    private var queryTerms: [String] {
        searchText
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    var filteredRecent: [Conversation] {
        let terms = queryTerms
        guard !terms.isEmpty else { return recentConversations }
        return rank(recentConversations, terms: terms)
    }

    var filteredProjects: [Project] {
        let terms = queryTerms
        guard !terms.isEmpty else { return projects }
        return projects.compactMap { project in
            let matches = rank(project.conversations, terms: terms)
            guard !matches.isEmpty else { return nil }
            return Project(id: project.id, path: project.path, conversations: matches)
        }
    }

    // MARK: - Command history

    struct CommandEntry: Identifiable {
        let id = UUID()
        let command: String
        let conversationId: String
        let project: String
        let date: Date?
    }

    var allCommands: [CommandEntry] {
        recentConversations.flatMap { conv in
            conv.commands.map {
                CommandEntry(command: $0, conversationId: conv.id, project: conv.projectDisplayName, date: conv.lastTimestamp)
            }
        }
    }

    var filteredCommands: [CommandEntry] {
        let terms = queryTerms
        guard !terms.isEmpty else { return allCommands }
        return allCommands.filter { entry in
            let hay = entry.command.lowercased()
            return terms.allSatisfy { hay.contains($0) }
        }
    }

    /// Conversations that touched a given file path, most recent first.
    func conversations(touching path: String) -> [Conversation] {
        recentConversations.filter { $0.filesTouched.contains(path) }
    }

    // MARK: - Search

    /// Rank conversations: every term must match somewhere (AND), ordered by score.
    private func rank(_ conversations: [Conversation], terms: [String]) -> [Conversation] {
        conversations
            .compactMap { conv -> (Conversation, Int)? in
                let s = score(conv, terms: terms)
                return s > 0 ? (conv, s) : nil
            }
            .sorted { a, b in
                if a.1 != b.1 { return a.1 > b.1 }
                return (a.0.lastTimestamp ?? .distantPast) > (b.0.lastTimestamp ?? .distantPast)
            }
            .map(\.0)
    }

    /// 0 = no match. Higher = more relevant. Returns 0 unless *all* terms hit.
    private func score(_ conv: Conversation, terms: [String]) -> Int {
        let title = conv.displayName.lowercased()
        let slug = conv.slug?.lowercased() ?? ""
        let path = conv.projectPath.lowercased()
        let id = conv.id.lowercased()
        let content = contentIndex[conv.id]

        var total = 0
        for term in terms {
            var hit = 0
            if title.contains(term) { hit += 100 }
            if slug.contains(term) { hit += 40 }
            if id.contains(term) { hit += 40 }
            if path.contains(term) { hit += 20 }
            if let content, content.range(of: term, options: .caseInsensitive) != nil { hit += 10 }
            guard hit > 0 else { return 0 }   // AND across terms
            total += hit
        }
        return total
    }

    /// A highlighted snippet of conversation text around the first content match.
    func snippet(for conv: Conversation) -> AttributedString? {
        let terms = queryTerms
        guard !terms.isEmpty, let content = contentIndex[conv.id] else { return nil }

        guard let firstRange = terms
            .compactMap({ content.range(of: $0, options: .caseInsensitive) })
            .min(by: { $0.lowerBound < $1.lowerBound })
        else { return nil }

        // Window of ~80 chars before and after the first match.
        let lower = content.index(firstRange.lowerBound, offsetBy: -80, limitedBy: content.startIndex) ?? content.startIndex
        let upper = content.index(firstRange.upperBound, offsetBy: 120, limitedBy: content.endIndex) ?? content.endIndex
        var window = String(content[lower..<upper])
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
        if lower != content.startIndex { window = "…" + window }
        if upper != content.endIndex { window += "…" }

        var attributed = AttributedString(window)
        for term in terms {
            var search = attributed.startIndex
            while let r = attributed[search...].range(of: term, options: .caseInsensitive) {
                attributed[r].inlinePresentationIntent = .stronglyEmphasized
                attributed[r].foregroundColor = ClaudeTheme.peach
                search = r.upperBound
            }
        }
        return attributed
    }

    // MARK: - Loading

    func loadInitial() async {
        isLoading = projects.isEmpty
        await reload()
        isLoading = false
    }

    /// Coalesced rescan. Heavy file I/O runs off-actor; results are assigned here.
    func reload() async {
        if reloadInFlight { reloadQueued = true; return }
        reloadInFlight = true
        defer { reloadInFlight = false }

        repeat {
            reloadQueued = false
            let scanner = self.scanner
            let cacheIn = parseCache
            let out = await Task.detached(priority: .userInitiated) {
                scanner.scan(cache: cacheIn)
            }.value
            projects = out.projects
            contentIndex = out.searchIndex
            parseCache = out.cache
        } while reloadQueued
    }

    func loadMessages(for conversation: Conversation) async {
        isLoadingMessages = true
        let parser = self.parser
        let url = conversation.fileURL
        let parsed = await Task.detached(priority: .userInitiated) {
            try? parser.parseAll(at: url)
        }.value
        loadedMessages = parsed ?? []
        isLoadingMessages = false
    }

    // MARK: - Watching

    func startWatching() {
        let path = scanner.projectsDir.path
        fileWatcher = FileWatcher(path: path) { [weak self] in
            Task { @MainActor in await self?.reload() }
        }
        fileWatcher?.start()
    }

    func stopWatching() {
        fileWatcher?.stop()
        fileWatcher = nil
    }
}
