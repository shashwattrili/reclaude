import SwiftUI

/// Derived, at-a-glance facts about a conversation.
struct ConversationInsights {
    struct FileChange: Identifiable { let id = UUID(); let path: String; let adds: Int; let dels: Int; let isNew: Bool }

    var model: String?
    var inputTokens = 0
    var outputTokens = 0
    var commandCount = 0
    var fileChanges: [FileChange] = []
    var tasksCreated: [String] = []
    var tasksCompleted = 0
    var userTurns = 0
    var duration: TimeInterval?

    var openTaskCount: Int { max(0, tasksCreated.count - tasksCompleted) }

    init(messages: [ConversationMessage]) {
        var firstDate: Date?
        var lastDate: Date?
        var byPath: [String: (adds: Int, dels: Int, isNew: Bool)] = [:]
        var order: [String] = []

        for msg in messages {
            if let d = msg.parsedDate {
                if firstDate == nil { firstDate = d }
                lastDate = d
            }
            if msg.isRealUserMessage { userTurns += 1 }
            if let u = msg.message?.usage {
                // Count genuinely new tokens; cache reads are re-counted each turn
                // and would massively inflate the total.
                inputTokens += (u.inputTokens ?? 0) + (u.cacheCreationInputTokens ?? 0)
                outputTokens += u.outputTokens ?? 0
            }
            if let m = msg.message?.model { model = m }

            for tool in msg.toolUseBlocks {
                if tool.bashCommand != nil { commandCount += 1 }
                if tool.name == "TaskCreate", let s = tool.inputSummary.isEmpty ? nil : tool.inputSummary {
                    tasksCreated.append(s)
                }
                if tool.name == "TaskUpdate", tool.input?["status"]?.stringValue == "completed" {
                    tasksCompleted += 1
                }
                if let c = tool.fileChange {
                    let d = DiffEngine.diff(old: c.old, new: c.new)
                    let adds = d.filter { $0.kind == .add }.count
                    let dels = d.filter { $0.kind == .remove }.count
                    if byPath[c.path] == nil { order.append(c.path); byPath[c.path] = (0, 0, tool.name == "Write" && c.old.isEmpty) }
                    byPath[c.path]?.adds += adds
                    byPath[c.path]?.dels += dels
                }
            }
        }
        fileChanges = order.map { p in
            let v = byPath[p]!
            return FileChange(path: p, adds: v.adds, dels: v.dels, isNew: v.isNew)
        }
        if let f = firstDate, let l = lastDate, l > f { duration = l.timeIntervalSince(f) }
    }
}

struct SessionSummaryView: View {
    let insights: ConversationInsights
    let conversation: Conversation
    var onJumpToFile: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Stat chips
            HStack(spacing: 8) {
                if let model = insights.model { chip("cpu", shortModel(model)) }
                chip("text.bubble", "\(insights.userTurns) turns")
                if insights.commandCount > 0 { chip("terminal", "\(insights.commandCount) cmds") }
                if insights.inputTokens + insights.outputTokens > 0 {
                    chip("number", tokenString)
                }
                if let d = insights.duration { chip("clock", durationString(d)) }
                if insights.openTaskCount > 0 {
                    chip("checklist", "\(insights.openTaskCount) open", tint: .orange)
                }
                Spacer()
            }

            if !insights.fileChanges.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Files changed (\(insights.fileChanges.count))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: 6) {
                        ForEach(insights.fileChanges) { fc in
                            Button { onJumpToFile?(fc.path) } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: fc.isNew ? "plus.circle" : "pencil")
                                        .font(.caption2)
                                    Text(fileName(fc.path)).font(.caption.monospaced())
                                    Text("+\(fc.adds)").font(.caption2).foregroundStyle(.green)
                                    Text("−\(fc.dels)").font(.caption2).foregroundStyle(.red)
                                }
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(.quaternary.opacity(0.5))
                                .clipShape(.capsule)
                            }
                            .buttonStyle(.plain)
                            .help(fc.path)
                        }
                    }
                }
            }

            if !insights.tasksCreated.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tasks · \(insights.tasksCompleted)/\(insights.tasksCreated.count) done")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(Array(insights.tasksCreated.prefix(6).enumerated()), id: \.offset) { _, t in
                        Label(t, systemImage: "circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(12)
        .background(ClaudeTheme.peach.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(ClaudeTheme.peach.opacity(0.2), lineWidth: 1))
    }

    private func chip(_ icon: String, _ text: String, tint: Color = .secondary) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2)
            Text(text).font(.caption)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.quaternary.opacity(0.4))
        .clipShape(.capsule)
    }

    private var tokenString: String {
        let total = insights.inputTokens + insights.outputTokens
        return total >= 1000 ? String(format: "%.0fk tok", Double(total)/1000) : "\(total) tok"
    }
    private func shortModel(_ m: String) -> String {
        m.replacingOccurrences(of: "claude-", with: "").replacingOccurrences(of: "-20", with: " ’")
    }
    private func fileName(_ p: String) -> String { (p as NSString).lastPathComponent }
    private func durationString(_ t: TimeInterval) -> String {
        let mins = Int(t / 60)
        if mins < 60 { return "\(mins)m" }
        return "\(mins/60)h \(mins%60)m"
    }
}

/// Simple wrapping HStack for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > maxW { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
        return CGSize(width: maxW == .infinity ? x : maxW, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxW = bounds.width
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > bounds.minX + maxW { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}
