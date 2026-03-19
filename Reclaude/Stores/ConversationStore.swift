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

    private let scanner = ClaudeDirectoryScanner()
    private let parser = JSONLParser()
    private var fileWatcher: FileWatcher?

    // MARK: - Computed Properties

    var allConversations: [Conversation] {
        projects.flatMap(\.conversations)
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
        guard !searchText.isEmpty else { return projects }
        let query = searchText.lowercased()

        return projects.compactMap { project in
            let matchingConversations = project.conversations.filter { conv in
                matchesSearch(conv, query: query)
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
        guard !searchText.isEmpty else { return recentConversations }
        let query = searchText.lowercased()
        return recentConversations.filter { matchesSearch($0, query: query) }
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

    func startWatching() {
        let projectsPath = scanner.claudeDir
            .appendingPathComponent("projects").path
        fileWatcher = FileWatcher(path: projectsPath) { [weak self] in
            Task { @MainActor in
                await self?.loadAll()
            }
        }
        fileWatcher?.start()
    }

    func stopWatching() {
        fileWatcher?.stop()
        fileWatcher = nil
    }

    // MARK: - Private

    private func matchesSearch(_ conversation: Conversation, query: String) -> Bool {
        if let slug = conversation.slug, slug.lowercased().contains(query) {
            return true
        }
        if conversation.projectPath.lowercased().contains(query) {
            return true
        }
        if conversation.projectDisplayName.lowercased().contains(query) {
            return true
        }
        if let preview = conversation.firstUserMessage, preview.lowercased().contains(query) {
            return true
        }
        return false
    }
}
