import SwiftUI

struct ToolCallView: View {
    let tool: ToolUseBlock
    let result: ToolResultBlock?
    @State private var expanded = false

    private var isError: Bool { result?.isError == true }
    private var change: (path: String, old: String, new: String)? { tool.fileChange }
    private var resultText: String { result?.textValue ?? "" }
    private var canExpand: Bool { change != nil || !resultText.isEmpty || (tool.bashCommand != nil) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if expanded { details.padding(.top, 6) }
        }
        .padding(8)
        .background((isError ? Color.red : ClaudeTheme.toolPill).opacity(0.12))
        .clipShape(.rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke((isError ? Color.red : ClaudeTheme.peach).opacity(0.25), lineWidth: 1))
    }

    private var header: some View {
        Button {
            if canExpand { withAnimation(.snappy(duration: 0.15)) { expanded.toggle() } }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(isError ? .red : ClaudeTheme.peach)
                    .frame(width: 16)
                Text(tool.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isError ? .red : ClaudeTheme.peach)
                if !tool.inputSummary.isEmpty {
                    Text(tool.inputSummary)
                        .font(.system(.caption, design: usesMono ? .monospaced : .default))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 4)
                if let badge = changeBadge {
                    Text(badge).font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                }
                if canExpand {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var details: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let bash = tool.bashCommand {
                labeledBlock("Command", text: bash, mono: true)
            }
            if let change {
                DiffView(old: change.old, new: change.new)
            }
            if !resultText.isEmpty {
                labeledBlock(isError ? "Error" : "Output", text: String(resultText.prefix(8000)), mono: true)
            }
        }
    }

    private func labeledBlock(_ label: String, text: String, mono: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
                Spacer()
                CopyButton(text: text)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Text(text)
                    .font(.system(.caption, design: mono ? .monospaced : .default))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 260)
            .padding(8)
            .background(ClaudeTheme.codeBlock.opacity(0.15))
            .clipShape(.rect(cornerRadius: 6))
        }
    }

    private var changeBadge: String? {
        guard let change else { return nil }
        if tool.name == "Write" { return "new file" }
        let d = DiffEngine.diff(old: change.old, new: change.new)
        let adds = d.filter { $0.kind == .add }.count
        let dels = d.filter { $0.kind == .remove }.count
        return "+\(adds) −\(dels)"
    }

    private var usesMono: Bool {
        ["Bash", "Read", "Edit", "Write", "Glob", "Grep", "NotebookEdit"].contains(tool.name)
    }

    private var icon: String {
        switch tool.name {
        case "Bash": return "terminal"
        case "Read": return "doc.text"
        case "Edit", "Write", "NotebookEdit": return "pencil"
        case "Glob", "Grep": return "magnifyingglass"
        case "WebFetch", "WebSearch": return "globe"
        case "Task", "Agent": return "person.2"
        case "TodoWrite", "TaskCreate", "TaskUpdate": return "checklist"
        default: return "wrench.and.screwdriver"
        }
    }
}

struct CopyButton: View {
    let text: String
    @State private var copied = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            withAnimation { copied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.caption2)
                .foregroundStyle(copied ? .green : .secondary)
        }
        .buttonStyle(.plain)
        .help("Copy")
    }
}
