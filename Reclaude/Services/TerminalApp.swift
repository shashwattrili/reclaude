import AppKit

/// A terminal emulator Reclaude can launch a Claude Code session into.
enum TerminalApp: String, CaseIterable, Identifiable, Sendable {
    case terminal
    case iterm
    case ghostty
    case wezterm
    case kitty
    case alacritty

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .terminal:  return "Terminal"
        case .iterm:     return "iTerm2"
        case .ghostty:   return "Ghostty"
        case .wezterm:   return "WezTerm"
        case .kitty:     return "kitty"
        case .alacritty: return "Alacritty"
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .terminal:  return "com.apple.Terminal"
        case .iterm:     return "com.googlecode.iterm2"
        case .ghostty:   return "com.mitchellh.ghostty"
        case .wezterm:   return "com.github.wez.wezterm"
        case .kitty:     return "net.kovidgoyal.kitty"
        case .alacritty: return "org.alacritty"
        }
    }

    /// Resolved app URL if installed, else nil.
    var appURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    var isInstalled: Bool { appURL != nil }

    /// All terminals currently installed, Terminal.app always first.
    static var installed: [TerminalApp] {
        allCases.filter(\.isInstalled)
    }

    /// The default to use when the user hasn't chosen one: their preference if
    /// installed, otherwise the first installed terminal, otherwise Terminal.app.
    static func resolvedDefault(preference: String?) -> TerminalApp {
        if let preference, let pref = TerminalApp(rawValue: preference), pref.isInstalled {
            return pref
        }
        return installed.first ?? .terminal
    }
}
