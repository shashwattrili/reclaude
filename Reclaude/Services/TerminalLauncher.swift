import AppKit

enum TerminalLauncher {

    /// Resume a Claude Code session.
    static func resume(sessionId: String, cwd: String, in terminal: TerminalApp) {
        run(command: "claude --resume \(sessionId)", cwd: cwd, in: terminal)
    }

    /// Start a new Claude Code session in a directory.
    static func newSession(cwd: String, in terminal: TerminalApp) {
        run(command: "claude", cwd: cwd, in: terminal)
    }

    // MARK: - Core

    private static func run(command: String, cwd: String, in terminal: TerminalApp) {
        let inner = "cd \(shellEscape(cwd)) && \(command)"

        switch terminal {
        case .terminal:
            runAppleScript("""
            tell application "Terminal"
                activate
                do script "\(appleEscape(inner))"
            end tell
            """)

        case .iterm:
            runAppleScript("""
            tell application "iTerm"
                activate
                set newWindow to (create window with default profile)
                tell current session of newWindow
                    write text "\(appleEscape(inner))"
                end tell
            end tell
            """)

        case .ghostty, .alacritty:
            open(terminal, args: ["-e", "/bin/zsh", "-lc", inner])

        case .kitty:
            open(terminal, args: ["/bin/zsh", "-lc", inner])

        case .wezterm:
            open(terminal, args: ["start", "--", "/bin/zsh", "-lc", inner])
        }
    }

    /// Launch a new instance of `terminal` via `open`, passing CLI args.
    private static func open(_ terminal: TerminalApp, args: [String]) {
        guard let appURL = terminal.appURL else {
            // Fall back to the system default if somehow uninstalled.
            runAppleScript("""
            tell application "Terminal"
                activate
                do script "\(appleEscape(args.last ?? ""))"
            end tell
            """)
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", appURL.path, "--args"] + args
        do {
            try process.run()
        } catch {
            print("Terminal launch error: \(error)")
        }
    }

    private static func runAppleScript(_ source: String) {
        guard let script = NSAppleScript(source: source) else { return }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error { print("AppleScript error: \(error)") }
    }

    /// Quote for a POSIX shell.
    private static func shellEscape(_ str: String) -> String {
        "'" + str.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Escape for embedding inside an AppleScript double-quoted string.
    private static func appleEscape(_ str: String) -> String {
        str.replacingOccurrences(of: "\\", with: "\\\\")
           .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
