import AppKit

enum TerminalLauncher {
    /// Resume a Claude Code session in Terminal.app
    static func resume(sessionId: String, cwd: String) {
        let escapedCwd = shellEscape(cwd)
        let script = """
        tell application "Terminal"
            activate
            do script "cd \(escapedCwd) && claude --resume \(sessionId)"
        end tell
        """

        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error {
                print("AppleScript error: \(error)")
            }
        }
    }

    /// Start a new Claude Code session in a project directory
    static func newSession(cwd: String) {
        let escapedCwd = shellEscape(cwd)
        let script = """
        tell application "Terminal"
            activate
            do script "cd \(escapedCwd) && claude"
        end tell
        """

        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error {
                print("AppleScript error: \(error)")
            }
        }
    }

    private static func shellEscape(_ str: String) -> String {
        "'" + str.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
