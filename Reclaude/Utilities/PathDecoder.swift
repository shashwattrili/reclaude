import Foundation

enum PathDecoder {
    /// Decode a Claude Code project directory name to a filesystem path.
    /// e.g., "-Users-shashwataggarwal-Work-repos-rwa" → "/Users/shashwataggarwal/Work/repos/rwa"
    ///
    /// Note: This simple replacement can break on directory names with real dashes.
    /// We use `cwd` from the JSONL messages as the authoritative path when available.
    static func decode(_ encoded: String) -> String {
        guard encoded.hasPrefix("-") else { return encoded }
        return "/" + encoded.dropFirst().replacingOccurrences(of: "-", with: "/")
    }

    /// Get just the last path component for display.
    static func displayName(_ encoded: String) -> String {
        let decoded = decode(encoded)
        return URL(fileURLWithPath: decoded).lastPathComponent
    }
}
