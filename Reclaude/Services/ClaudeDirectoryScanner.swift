import Foundation

final class ClaudeDirectoryScanner {
    let claudeDir: URL
    private let parser = JSONLParser()

    init() {
        self.claudeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
    }

    /// Scan all projects and conversations. Returns sorted projects.
    func scanProjects() -> [Project] {
        let projectsDir = claudeDir.appendingPathComponent("projects")
        let fm = FileManager.default

        guard let projectDirs = try? fm.contentsOfDirectory(
            at: projectsDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var projects: [Project] = []

        for projectDir in projectDirs {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: projectDir.path, isDirectory: &isDir),
                  isDir.boolValue else { continue }

            let dirName = projectDir.lastPathComponent
            let decodedPath = PathDecoder.decode(dirName)

            // Find all .jsonl files in this project directory (not in subdirectories)
            guard let files = try? fm.contentsOfDirectory(
                at: projectDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            let jsonlFiles = files.filter { $0.pathExtension == "jsonl" }
            guard !jsonlFiles.isEmpty else { continue }

            var conversations: [Conversation] = []

            for file in jsonlFiles {
                guard let conversation = scanConversation(file: file, projectDirName: dirName, decodedPath: decodedPath) else {
                    continue
                }
                conversations.append(conversation)
            }

            guard !conversations.isEmpty else { continue }

            // Sort conversations by most recent first
            conversations.sort { ($0.lastTimestamp ?? .distantPast) > ($1.lastTimestamp ?? .distantPast) }

            // Use cwd from first conversation as authoritative path if available
            let authoritativePath = conversations.first?.cwd ?? decodedPath

            let project = Project(
                id: dirName,
                path: authoritativePath,
                conversations: conversations
            )
            projects.append(project)
        }

        // Sort projects by most recent conversation
        projects.sort { ($0.latestTimestamp ?? .distantPast) > ($1.latestTimestamp ?? .distantPast) }

        return projects
    }

    private func scanConversation(file: URL, projectDirName: String, decodedPath: String) -> Conversation? {
        let metadata = parser.parseMetadata(at: file)

        // Use filename (without extension) as sessionId if not found in metadata
        let sessionId = metadata?.sessionId ?? file.deletingPathExtension().lastPathComponent

        return Conversation(
            id: sessionId,
            slug: metadata?.slug,
            projectPath: metadata?.cwd ?? decodedPath,
            projectDirName: projectDirName,
            cwd: metadata?.cwd,
            gitBranch: metadata?.gitBranch,
            firstTimestamp: metadata?.firstTimestamp,
            lastTimestamp: metadata?.lastTimestamp,
            fileURL: file,
            messageCount: metadata?.estimatedMessageCount ?? 0,
            firstUserMessage: metadata?.firstUserMessage
        )
    }
}
