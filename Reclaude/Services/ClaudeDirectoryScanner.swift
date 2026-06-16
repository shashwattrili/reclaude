import Foundation

/// One file's parsed result, cached by modification date so unchanged files
/// are never re-read on a rescan (cheap re-scans during active sessions).
struct CachedFile: Sendable {
    let modDate: Date
    let conversation: Conversation
    let searchText: String
}

/// Result of a full scan: the project tree plus a search index keyed by
/// conversation id, plus the refreshed per-file cache.
struct ScanOutput: Sendable {
    let projects: [Project]
    let searchIndex: [String: String]
    let cache: [String: CachedFile]
}

struct ClaudeDirectoryScanner: Sendable {
    let claudeDir: URL
    private let parser = JSONLParser()

    init() {
        self.claudeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
    }

    var projectsDir: URL { claudeDir.appendingPathComponent("projects") }

    /// Scan all projects. Reuses `cache` entries whose file mod-date is unchanged.
    func scan(cache previous: [String: CachedFile]) -> ScanOutput {
        let fm = FileManager.default

        guard let projectDirs = try? fm.contentsOfDirectory(
            at: projectsDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return ScanOutput(projects: [], searchIndex: [:], cache: [:])
        }

        var projects: [Project] = []
        var searchIndex: [String: String] = [:]
        var newCache: [String: CachedFile] = [:]

        for projectDir in projectDirs {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: projectDir.path, isDirectory: &isDir),
                  isDir.boolValue else { continue }

            let dirName = projectDir.lastPathComponent
            let decodedPath = PathDecoder.decode(dirName)

            guard let files = try? fm.contentsOfDirectory(
                at: projectDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            let jsonlFiles = files.filter { $0.pathExtension == "jsonl" }
            guard !jsonlFiles.isEmpty else { continue }

            var conversations: [Conversation] = []

            for file in jsonlFiles {
                let path = file.path
                let modDate = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast

                // Reuse cache if the file is unchanged.
                if let cached = previous[path], cached.modDate == modDate {
                    conversations.append(cached.conversation)
                    searchIndex[cached.conversation.id] = cached.searchText
                    newCache[path] = cached
                    continue
                }

                guard let parsed = parser.parse(at: file) else { continue }
                let sessionId = parsed.sessionId ?? file.deletingPathExtension().lastPathComponent

                let conversation = Conversation(
                    id: sessionId,
                    title: parsed.title,
                    slug: parsed.slug,
                    projectPath: parsed.cwd ?? decodedPath,
                    projectDirName: dirName,
                    cwd: parsed.cwd,
                    gitBranch: parsed.gitBranch,
                    firstTimestamp: parsed.firstTimestamp,
                    lastTimestamp: parsed.lastTimestamp,
                    fileURL: file,
                    messageCount: parsed.messageCount,
                    firstUserMessage: parsed.firstUserMessage,
                    commands: parsed.commands,
                    filesTouched: parsed.filesTouched
                )

                conversations.append(conversation)
                searchIndex[conversation.id] = parsed.searchText
                newCache[path] = CachedFile(modDate: modDate, conversation: conversation, searchText: parsed.searchText)
            }

            guard !conversations.isEmpty else { continue }
            conversations.sort { ($0.lastTimestamp ?? .distantPast) > ($1.lastTimestamp ?? .distantPast) }

            let authoritativePath = conversations.first?.cwd ?? decodedPath
            projects.append(Project(id: dirName, path: authoritativePath, conversations: conversations))
        }

        projects.sort { ($0.latestTimestamp ?? .distantPast) > ($1.latestTimestamp ?? .distantPast) }
        return ScanOutput(projects: projects, searchIndex: searchIndex, cache: newCache)
    }
}
