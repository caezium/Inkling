import AppKit

enum AttachmentService {
    /// Saves an arbitrary pasteboard image and returns a markdown link relative to the note.
    static func savePastedImage(_ image: NSImage, for file: TrackedFile) -> String? {
        let target = saveLocation(for: file, suggestedExtension: "png")
        do {
            try FileManager.default.createDirectory(at: target.directory, withIntermediateDirectories: true)
        } catch {
            NSLog("Inkling: couldn't create attachments dir: \(error)")
            return nil
        }

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        let url = target.directory.appendingPathComponent(target.filename)
        do {
            try png.write(to: url)
        } catch {
            NSLog("Inkling: couldn't write attachment: \(error)")
            return nil
        }

        return "![](\(relativeLinkPath(for: url, note: file.resolvedURL)))"
    }

    /// Copies a dropped file into the attachment folder. Images become `![](path)`,
    /// any other file becomes `[name](path)`.
    static func saveDroppedFile(at sourceURL: URL, for file: TrackedFile) -> String? {
        let ext = sourceURL.pathExtension.isEmpty ? "bin" : sourceURL.pathExtension
        let target = saveLocation(for: file, suggestedExtension: ext, baseName: sourceURL.deletingPathExtension().lastPathComponent)
        do {
            try FileManager.default.createDirectory(at: target.directory, withIntermediateDirectories: true)
        } catch {
            NSLog("Inkling: couldn't create attachments dir: \(error)")
            return nil
        }
        let dest = target.directory.appendingPathComponent(target.filename)
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: sourceURL, to: dest)
        } catch {
            NSLog("Inkling: couldn't copy dropped file: \(error)")
            return nil
        }

        let path = relativeLinkPath(for: dest, note: file.resolvedURL)
        if isImage(ext: ext) {
            return "![](\(path))"
        }
        let label = sourceURL.deletingPathExtension().lastPathComponent
        return "[\(label)](\(path))"
    }

    // MARK: - Helpers

    private struct SaveTarget {
        let directory: URL
        let filename: String
    }

    private static func saveLocation(for file: TrackedFile, suggestedExtension ext: String, baseName: String? = nil) -> SaveTarget {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = fmt.string(from: Date())
        let nameRoot = baseName.map { sanitize($0) + "-" + stamp } ?? "inkling-\(stamp)"
        let filename = "\(nameRoot).\(ext)"
        let directory: URL
        if let vault = ObsidianService.detectVault(for: file.resolvedURL) {
            directory = vault.appendingPathComponent("attachments")
        } else {
            directory = file.resolvedURL.deletingLastPathComponent().appendingPathComponent("attachments")
        }
        return SaveTarget(directory: directory, filename: filename)
    }

    private static func sanitize(_ s: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        return String(s.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
    }

    private static func relativeLinkPath(for asset: URL, note: URL) -> String {
        if let vault = ObsidianService.detectVault(for: note) {
            return ObsidianService.relativePath(of: asset, in: vault)
        }
        let noteDir = note.deletingLastPathComponent().path
        let p = asset.path
        if p.hasPrefix(noteDir + "/") {
            return String(p.dropFirst(noteDir.count + 1))
        }
        return p
    }

    private static func isImage(ext: String) -> Bool {
        ["png", "jpg", "jpeg", "gif", "heic", "webp", "tiff", "bmp"].contains(ext.lowercased())
    }
}
