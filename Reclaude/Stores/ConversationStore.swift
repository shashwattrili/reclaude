import Foundation
import SwiftUI

@Observable
final class ConversationStore {
    var projects: [Project] = []
    var selectedConversationId: String?
    var loadedMessages: [ConversationMessage] = []
    var searchText: String = ""
    var isLoading: Bool = false
    var isLoadingMessages: Bool = false
    var isIndexing: Bool = false

    private let scanner = ClaudeDirectoryScanner()
    private let parser = JSONLParser()
    private var fileWatcher: FileWatcher?
    private var contentIndex: [String: String] = [:]
    private var indexedModDates: [String: Date] = [:]

    // MARK: - Computed Properties

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

    var filteredProjects: [Project] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return projects }
        let terms = trimmed.lowercased()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        guard !terms.isEmpty else { return projects }

        return projects.compactMap { project in
            let matchingConversations = project.conversations.filter { conv in
                matchesSearch(conv, terms: terms)
            }
            guard !matchingConversations.isEmpty else { return nil }
            return Project(
                id: project.id,
                path: project.path,
                conversations: matchingConversations
            )
        }
    }

    var filteredRecent: [Conversation] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return recentConversations }
        let terms = trimmed.lowercased()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        guard !terms.isEmpty else { return recentConversations }
        return recentConversations.filter { matchesSearch($0, terms: terms) }
    }

    // MARK: - Actions

    func loadAll() async {
        isLoading = true
        let scanner = self.scanner
        let scannedProjects = await Task.detached(priority: .userInitiated) {
            scanner.scanProjects()
        }.value
        projects = scannedProjects
        isLoading = false
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

    /// Build a background search index of all conversation text content.
    func buildSearchIndex() async {
        isIndexing = true
        let conversations = allConversations
        let parser = self.parser
        let existingModDates = indexedModDates

        let newIndex = await Task.detached(priority: .background) {
            var index: [String: String] = [:]
            for conv in conversations {
                // Skip if already indexed and not modified
                if let existingDate = existingModDates[conv.id],
                   let convDate = conv.lastTimestamp,
                   existingDate > convDate {
                    continue
                }
                index[conv.id] = parser.extractSearchableText(at: conv.fileURL)
            }
            return index
        }.value

        // Merge new entries into existing index
        for (id, text) in newIndex {
            contentIndex[id] = text
            if let conv = allConversations.first(where: { $0.id == id }) {
                indexedModDates[id] = conv.lastTimestamp ?? Date()
            }
        }
        isIndexing = false
    }

    func startWatching() {
        let projectsPath = scanner.claudeDir
            .appendingPathComponent("projects").path
        fileWatcher = FileWatcher(path: projectsPath) { [weak self] in
            Task { @MainActor in
                await self?.loadAll()
                await self?.buildSearchIndex()
            }
        }
        fileWatcher?.start()
    }

    func stopWatching() {
        fileWatcher?.stop()
        fileWatcher = nil
    }

    // MARK: - Private

    /// Build a single searchable string for a conversation (metadata + indexed content).
    private func searchableText(for conversation: Conversation) -> String {
        var parts: [String] = [
            conversation.id,
            conversation.projectPath,
            conversation.projectDisplayName,
        ]
        if let slug = conversation.slug { parts.append(slug) }
        if let branch = conversation.gitBranch { parts.append(branch) }
        if let preview = conversation.firstUserMessage { parts.append(preview) }
        if let indexed = contentIndex[conversation.id] { parts.append(indexed) }
        return parts.joined(separator: " ").lowercased()
    }

    /// All search terms must appear somewhere in the conversation's searchable text.
    private func matchesSearch(_ conversation: Conversation, terms: [String]) -> Bool {
        let text = searchableText(for: conversation)
        return terms.allSatisfy { text.contains($0) }
    }
}
