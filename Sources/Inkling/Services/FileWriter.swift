import AppKit

enum FileWriter {
    enum WriteError: Error, LocalizedError {
        case readFailed(URL, Error)
        case writeFailed(URL, Error)
        var errorDescription: String? {
            switch self {
            case .readFailed(let u, let e): return "Couldn't read \(u.lastPathComponent): \(e.localizedDescription)"
            case .writeFailed(let u, let e): return "Couldn't write \(u.lastPathComponent): \(e.localizedDescription)"
            }
        }
    }

    /// Result of a write — used by undo to reverse it.
    struct Receipt {
        let fileURL: URL
        let beforeContents: String
        let afterContents: String
        let writtenLine: String
        let timestamp: Date
        let fileAlias: String
    }

    @discardableResult
    static func write(
        text rawText: String,
        to file: TrackedFile,
        position: TrackedFile.Position,
        timestampFormat: String,
        preferObsidianWrite: Bool
    ) throws -> Receipt {
        let formatted = TemplateEngine.render(
            template: file.template,
            text: rawText,
            file: file,
            timestampFormat: timestampFormat
        )

        // Obsidian CLI write doesn't support section-targeted insertion, so
        // fall back to direct write whenever a section is configured.
        if file.targetSection == nil,
           preferObsidianWrite,
           ObsidianService.hasCLI,
           ObsidianService.detectVault(for: file.resolvedURL) != nil,
           ObsidianService.isObsidianRunning {
            let before = (try? String(contentsOf: file.resolvedURL, encoding: .utf8)) ?? ""
            do {
                try ObsidianService.write(text: formatted, file: file, position: position)
                let after = (try? String(contentsOf: file.resolvedURL, encoding: .utf8)) ?? ""
                return Receipt(
                    fileURL: file.resolvedURL,
                    beforeContents: before,
                    afterContents: after,
                    writtenLine: formatted,
                    timestamp: Date(),
                    fileAlias: file.displayName
                )
            } catch {
                NSLog("Inkling: obsidian-cli write failed (\(error)); falling back to direct write.")
            }
        }
        return try writeDirectly(
            text: formatted,
            to: file.resolvedURL,
            position: position,
            section: file.targetSection,
            fileAlias: file.displayName
        )
    }

    /// Restore a prior file state (used for undo).
    static func restore(_ receipt: Receipt) throws {
        do {
            try receipt.beforeContents.write(to: receipt.fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw WriteError.writeFailed(receipt.fileURL, error)
        }
    }

    private static func writeDirectly(
        text: String,
        to url: URL,
        position: TrackedFile.Position,
        section: String?,
        fileAlias: String
    ) throws -> Receipt {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            throw WriteError.writeFailed(url, error)
        }

        if !fm.fileExists(atPath: url.path) {
            do { try "".write(to: url, atomically: true, encoding: .utf8) }
            catch { throw WriteError.writeFailed(url, error) }
        }

        let existing: String
        do { existing = try String(contentsOf: url, encoding: .utf8) }
        catch { throw WriteError.readFailed(url, error) }

        var line = text
        if !line.hasSuffix("\n") { line += "\n" }

        let combined: String
        if let section, let inserted = insertInSection(into: existing, line: line, section: section) {
            combined = inserted
        } else {
            switch position {
            case .append:
                if existing.isEmpty {
                    combined = line
                } else if existing.hasSuffix("\n") {
                    combined = existing + line
                } else {
                    combined = existing + "\n" + line
                }
            case .prepend:
                combined = line + existing
            }
        }

        do { try combined.write(to: url, atomically: true, encoding: .utf8) }
        catch { throw WriteError.writeFailed(url, error) }

        return Receipt(
            fileURL: url,
            beforeContents: existing,
            afterContents: combined,
            writtenLine: line,
            timestamp: Date(),
            fileAlias: fileAlias
        )
    }

    /// Inserts `line` at the end of the named section. Returns nil if section not found.
    private static func insertInSection(into contents: String, line: String, section: String) -> String? {
        let target = section.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).lowercased()
        guard !target.isEmpty else { return nil }

        var lines = contents.components(separatedBy: "\n")
        var headingIndex: Int?
        var headingLevel: Int = 0
        var inFenced = false
        for (i, raw) in lines.enumerated() {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") { inFenced.toggle(); continue }
            if inFenced { continue }
            guard trimmed.hasPrefix("#") else { continue }
            var level = 0
            var idx = trimmed.startIndex
            while idx < trimmed.endIndex, trimmed[idx] == "#", level < 6 {
                level += 1
                idx = trimmed.index(after: idx)
            }
            guard level > 0, idx < trimmed.endIndex, trimmed[idx] == " " else { continue }
            let title = String(trimmed[idx...]).trimmingCharacters(in: .whitespaces).lowercased()
            if title == target {
                headingIndex = i
                headingLevel = level
                break
            }
        }
        guard let start = headingIndex else { return nil }

        var sectionEnd = lines.count
        inFenced = false
        for j in (start + 1)..<lines.count {
            let trimmed = lines[j].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") { inFenced.toggle(); continue }
            if inFenced { continue }
            if trimmed.hasPrefix("#") {
                var level = 0
                var idx = trimmed.startIndex
                while idx < trimmed.endIndex, trimmed[idx] == "#", level < 6 {
                    level += 1
                    idx = trimmed.index(after: idx)
                }
                if level > 0, idx < trimmed.endIndex, trimmed[idx] == " ", level <= headingLevel {
                    sectionEnd = j
                    break
                }
            }
        }
        var insertAt = sectionEnd
        while insertAt > start + 1, lines[insertAt - 1].trimmingCharacters(in: .whitespaces).isEmpty {
            insertAt -= 1
        }
        let lineToInsert = line.hasSuffix("\n") ? String(line.dropLast()) : line
        lines.insert(lineToInsert, at: insertAt)
        return lines.joined(separator: "\n")
    }
}
