import Foundation

struct Project: Identifiable, Equatable {
    static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id && lhs.conversations.count == rhs.conversations.count
    }

    let id: String               // the encoded directory name
    let path: String             // decoded human-readable path
    var conversations: [Conversation]

    var displayName: String {
        let components = path.split(separator: "/")
        return String(components.last ?? Substring(path))
    }

    var conversationCount: Int {
        conversations.count
    }

    var latestTimestamp: Date? {
        conversations.compactMap(\.lastTimestamp).max()
    }
}
