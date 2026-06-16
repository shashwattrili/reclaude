import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultTerminal") private var defaultTerminalRaw = ""

    var body: some View {
        Form {
            Section("Resume") {
                Picker("Open sessions in", selection: $defaultTerminalRaw) {
                    Text("Automatic").tag("")
                    Divider()
                    ForEach(TerminalApp.installed) { term in
                        Text(term.displayName).tag(term.rawValue)
                    }
                }
                .pickerStyle(.menu)

                Text("“Automatic” uses the first installed terminal. You can also override per-session from the Resume button’s menu.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 180)
    }
}
