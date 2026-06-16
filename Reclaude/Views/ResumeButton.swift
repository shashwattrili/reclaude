import SwiftUI

/// Split-button: primary action resumes in the default terminal; the menu
/// lets you pick any installed terminal for this one resume.
struct ResumeButton: View {
    @AppStorage("defaultTerminal") private var defaultTerminalRaw = ""
    let sessionId: String
    let cwd: String
    var prominent: Bool = false

    private var defaultTerminal: TerminalApp {
        TerminalApp.resolvedDefault(preference: defaultTerminalRaw.isEmpty ? nil : defaultTerminalRaw)
    }

    var body: some View {
        Menu {
            ForEach(TerminalApp.installed) { term in
                Button {
                    TerminalLauncher.resume(sessionId: sessionId, cwd: cwd, in: term)
                } label: {
                    Label("Resume in \(term.displayName)", systemImage: "terminal")
                }
            }
        } label: {
            Label("Resume in \(defaultTerminal.displayName)", systemImage: "terminal")
        } primaryAction: {
            TerminalLauncher.resume(sessionId: sessionId, cwd: cwd, in: defaultTerminal)
        }
        .menuStyle(.button)
        .buttonStyle(prominent ? AnyPrimitiveButtonStyle(.borderedProminent) : AnyPrimitiveButtonStyle(.bordered))
        .help("Resume this session — click the arrow to choose a terminal")
    }
}

/// Type-erased button style so the same view can be prominent or not.
struct AnyPrimitiveButtonStyle: PrimitiveButtonStyle {
    private let make: (Configuration) -> AnyView
    init<S: PrimitiveButtonStyle>(_ style: S) {
        make = { config in AnyView(style.makeBody(configuration: config)) }
    }
    func makeBody(configuration: Configuration) -> some View {
        make(configuration)
    }
}
