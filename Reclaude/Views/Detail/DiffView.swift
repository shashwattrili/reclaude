import SwiftUI

/// Minimal LCS-based line diff so file edits render like a real diff.
enum DiffEngine {
    enum Kind { case same, add, remove }
    struct Line: Identifiable { let id = UUID(); let kind: Kind; let text: String }

    static func diff(old: String, new: String) -> [Line] {
        let a = old.isEmpty ? [] : old.components(separatedBy: "\n")
        let b = new.components(separatedBy: "\n")
        if a.isEmpty { return b.map { Line(kind: .add, text: $0) } }

        // LCS table (capped to keep huge files cheap).
        let n = a.count, m = b.count
        guard n * m <= 2_000_000 else {
            return a.map { Line(kind: .remove, text: $0) } + b.map { Line(kind: .add, text: $0) }
        }
        var dp = [[Int]](repeating: [Int](repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                dp[i][j] = a[i] == b[j] ? dp[i+1][j+1] + 1 : max(dp[i+1][j], dp[i][j+1])
            }
        }
        var result: [Line] = []
        var i = 0, j = 0
        while i < n && j < m {
            if a[i] == b[j] { result.append(Line(kind: .same, text: a[i])); i += 1; j += 1 }
            else if dp[i+1][j] >= dp[i][j+1] { result.append(Line(kind: .remove, text: a[i])); i += 1 }
            else { result.append(Line(kind: .add, text: b[j])); j += 1 }
        }
        while i < n { result.append(Line(kind: .remove, text: a[i])); i += 1 }
        while j < m { result.append(Line(kind: .add, text: b[j])); j += 1 }
        return result
    }
}

struct DiffView: View {
    let old: String
    let new: String
    var contextLimit: Int = 400

    private var lines: [DiffEngine.Line] { DiffEngine.diff(old: old, new: new) }

    var body: some View {
        let all = lines
        let shown = Array(all.prefix(contextLimit))
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(shown) { line in
                    HStack(alignment: .top, spacing: 8) {
                        Text(gutter(line.kind))
                            .frame(width: 12, alignment: .center)
                            .foregroundStyle(.secondary)
                        Text(line.text.isEmpty ? " " : line.text)
                            .textSelection(.enabled)
                    }
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 1)
                    .background(background(line.kind))
                }
                if all.count > contextLimit {
                    Text("… \(all.count - contextLimit) more lines")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(6)
                }
            }
        }
        .clipShape(.rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary, lineWidth: 1))
    }

    private func gutter(_ k: DiffEngine.Kind) -> String {
        switch k { case .add: return "+"; case .remove: return "−"; case .same: return " " }
    }
    private func background(_ k: DiffEngine.Kind) -> Color {
        switch k {
        case .add: return .green.opacity(0.14)
        case .remove: return .red.opacity(0.12)
        case .same: return .clear
        }
    }
}
