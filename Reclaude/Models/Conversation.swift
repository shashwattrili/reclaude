import Foundation

struct Conversation: Identifiable, Hashable {
    let id: String                 // sessionId (UUID string)
    let slug: String?              // human-readable name
    let projectPath: String        // decoded path: "/Users/.../repos/rwa"
    let projectDirName: String     // raw dir name
    let cwd: String?
    let gitBranch: String?
    let firstTimestamp: Date?
    let lastTimestamp: Date?
    let fileURL: URL
    let messageCount: Int
    let firstUserMessage: String?  // preview text for sidebar

    var displayName: String {
        slug ?? String(id.prefix(8))
    }

    var projectDisplayName: String {
        // Last meaningful component of the project path
        let components = projectPath.split(separator: "/")
        return String(components.last ?? Substring(projectPath))
    }

    var relativeTimeString: String {
        guard let date = lastTimestamp else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
