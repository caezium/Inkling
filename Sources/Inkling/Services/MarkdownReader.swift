import Foundation

enum MarkdownReader {
    struct Heading: Hashable, Identifiable {
        let id = UUID()
        let level: Int
        let title: String
        let lineIndex: Int

        var indentedLabel: String {
            String(repeating: "  ", count: max(0, level - 1)) + title
        }
    }

    /// Returns ATX-style headings (`# foo`, `## bar`) found in the file.
    static func headings(at url: URL) -> [Heading] {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return parseHeadings(contents)
    }

    static func parseHeadings(_ contents: String) -> [Heading] {
        let lines = contents.components(separatedBy: "\n")
        var out: [Heading] = []
        var inFenced = false
        for (i, raw) in lines.enumerated() {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                inFenced.toggle()
                continue
            }
            if inFenced { continue }
            guard trimmed.hasPrefix("#") else { continue }
            var level = 0
            var idx = trimmed.startIndex
            while idx < trimmed.endIndex, trimmed[idx] == "#", level < 6 {
                level += 1
                idx = trimmed.index(after: idx)
            }
            // Must have a space after the #s (otherwise it's like a #tag, not a heading).
            guard level > 0, idx < trimmed.endIndex, trimmed[idx] == " " else { continue }
            let title = String(trimmed[idx...]).trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty else { continue }
            out.append(Heading(level: level, title: title, lineIndex: i))
        }
        return out
    }

    /// Returns the last `n` non-empty lines of the file, oldest-first.
    static func recentLines(at url: URL, count: Int = 3) -> [String] {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let lines = contents
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return Array(lines.suffix(count))
    }
}
