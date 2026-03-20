import SwiftUI

/// Renders a string as markdown, handling block elements including tables.
struct MarkdownText: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let level, let text):
                    renderInline(text)
                        .font(level == 1 ? .title2 : level == 2 ? .title3 : .headline)
                        .fontWeight(.bold)
                case .blockquote(let text):
                    renderInline(text)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 12)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(ClaudeTheme.peach.opacity(0.5))
                                .frame(width: 3)
                        }
                case .bullet(let text):
                    HStack(alignment: .top, spacing: 6) {
                        Text("·")
                            .foregroundStyle(.secondary)
                        renderInline(text)
                    }
                    .padding(.leading, 8)
                case .numbered(let num, let text):
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(num).")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        renderInline(text)
                    }
                    .padding(.leading, 8)
                case .table(let headers, let rows):
                    TableView(headers: headers, rows: rows)
                case .paragraph(let text):
                    renderInline(text)
                }
            }
        }
    }

    // MARK: - Block Parsing

    private enum Block {
        case heading(Int, String)
        case blockquote(String)
        case bullet(String)
        case numbered(String, String)
        case table(headers: [String], rows: [[String]])
        case paragraph(String)
    }

    private var blocks: [Block] {
        let lines = content.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .init(charactersIn: "\r")) }

        var result: [Block] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]

            if line.isEmpty {
                i += 1
                continue
            }

            // Table: detect consecutive lines starting with |
            if isTableRow(line) {
                var tableLines: [String] = []
                while i < lines.count && (isTableRow(lines[i]) || isSeparatorRow(lines[i])) {
                    if !isSeparatorRow(lines[i]) {
                        tableLines.append(lines[i])
                    }
                    i += 1
                }
                if let table = parseTable(tableLines) {
                    result.append(table)
                }
                continue
            }

            // Headings
            if line.hasPrefix("### ") {
                result.append(.heading(3, String(line.dropFirst(4))))
            } else if line.hasPrefix("## ") {
                result.append(.heading(2, String(line.dropFirst(3))))
            } else if line.hasPrefix("# ") {
                result.append(.heading(1, String(line.dropFirst(2))))
            }
            // Blockquote
            else if line.hasPrefix("> ") {
                result.append(.blockquote(String(line.dropFirst(2))))
            }
            // Bullet list
            else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                result.append(.bullet(String(line.dropFirst(2))))
            }
            // Numbered list
            else if line.count > 2, line.first?.isNumber == true, line.contains(". ") {
                let parts = line.split(separator: ".", maxSplits: 1)
                if parts.count == 2, parts[0].allSatisfy(\.isNumber) {
                    result.append(.numbered(String(parts[0]), String(parts[1]).trimmingCharacters(in: .whitespaces)))
                } else {
                    result.append(.paragraph(line))
                }
            }
            // Plain paragraph
            else {
                result.append(.paragraph(line))
            }

            i += 1
        }

        return result
    }

    private func isTableRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("|") && trimmed.hasSuffix("|") && trimmed.count > 2
    }

    private func isSeparatorRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("|") else { return false }
        let inner = trimmed.dropFirst().dropLast()
        return inner.allSatisfy { $0 == "-" || $0 == "|" || $0 == ":" || $0 == " " }
    }

    private func parseTable(_ lines: [String]) -> Block? {
        guard !lines.isEmpty else { return nil }

        func parseCells(_ line: String) -> [String] {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let inner = trimmed.hasPrefix("|") ? String(trimmed.dropFirst()) : trimmed
            let cleaned = inner.hasSuffix("|") ? String(inner.dropLast()) : inner
            return cleaned.components(separatedBy: "|").map {
                $0.trimmingCharacters(in: .whitespaces)
            }
        }

        let headers = parseCells(lines[0])
        let rows = lines.dropFirst().map { parseCells($0) }

        return .table(headers: headers, rows: rows)
    }

    private func renderInline(_ text: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attributed)
        }
        return Text(text)
    }
}

// MARK: - Table View

private struct TableView: View {
    let headers: [String]
    let rows: [[String]]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                ForEach(Array(headers.enumerated()), id: \.offset) { idx, header in
                    Text(header)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                    if idx < headers.count - 1 {
                        Divider()
                    }
                }
            }
            .background(ClaudeTheme.peach.opacity(0.15))

            Divider()

            // Data rows
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { colIdx, cell in
                        Text(cell)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .textSelection(.enabled)
                        if colIdx < row.count - 1 {
                            Divider()
                        }
                    }
                }
                if rowIdx < rows.count - 1 {
                    Divider()
                }
            }
        }
        .clipShape(.rect(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(ClaudeTheme.blush.opacity(0.3), lineWidth: 1)
        )
    }
}
