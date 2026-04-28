import AppKit

enum ObsidianService {
    static let cliPath = "/Applications/Obsidian.app/Contents/MacOS/obsidian-cli"
    static let appPath = "/Applications/Obsidian.app"

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: appPath)
    }

    static var hasCLI: Bool {
        FileManager.default.isExecutableFile(atPath: cliPath)
    }

    /// Walks up from `fileURL`'s directory until it finds a `.obsidian` folder, marking the vault root.
    static func detectVault(for fileURL: URL) -> URL? {
        var dir = fileURL.deletingLastPathComponent()
        let fm = FileManager.default
        var safety = 0
        while dir.path != "/" && safety < 64 {
            if fm.fileExists(atPath: dir.appendingPathComponent(".obsidian").path) {
                return dir
            }
            dir = dir.deletingLastPathComponent()
            safety += 1
        }
        return nil
    }

    static func vaultName(for vaultURL: URL) -> String {
        vaultURL.lastPathComponent
    }

    static func relativePath(of fileURL: URL, in vaultURL: URL) -> String {
        let v = vaultURL.path.hasSuffix("/") ? vaultURL.path : vaultURL.path + "/"
        if fileURL.path.hasPrefix(v) {
            return String(fileURL.path.dropFirst(v.count))
        }
        return fileURL.lastPathComponent
    }

    @discardableResult
    static func runCLI(args: [String]) throws -> String {
        guard hasCLI else { throw ObsidianError.cliMissing }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: cliPath)
        p.arguments = args
        let outPipe = Pipe()
        let errPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = errPipe
        try p.run()
        p.waitUntilExit()
        let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if p.terminationStatus != 0 {
            let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw ObsidianError.cliFailed(status: p.terminationStatus, stderr: err.isEmpty ? out : err)
        }
        return out
    }

    static func write(text: String, file: TrackedFile, position: TrackedFile.Position) throws {
        guard let vault = detectVault(for: file.resolvedURL) else { throw ObsidianError.notInVault }
        let cmd = position == .append ? "append" : "prepend"
        try runCLI(args: [
            "vault=\(vaultName(for: vault))",
            cmd,
            "path=\(relativePath(of: file.resolvedURL, in: vault))",
            "content=\(text)"
        ])
    }

    static var isObsidianRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: "md.obsidian").isEmpty
    }

    @MainActor
    static func open(file: TrackedFile, prefs: Preferences) {
        let url = file.resolvedURL

        // Path 1: file is in a vault, user prefers Obsidian, Obsidian is running -> CLI (preserves vault context, opens as a tab)
        if prefs.preferObsidianForOpen, hasCLI, isObsidianRunning,
           let vault = detectVault(for: url) {
            do {
                try runCLI(args: [
                    "vault=\(vaultName(for: vault))",
                    "open",
                    "path=\(relativePath(of: url, in: vault))"
                ])
                if let obsidian = NSRunningApplication
                    .runningApplications(withBundleIdentifier: "md.obsidian").first {
                    obsidian.activate()
                }
                return
            } catch {
                NSLog("Inkling: obsidian-cli open failed (\(error)); falling back to launch flow.")
            }
        }

        // Path 2: file is in a vault, user prefers Obsidian, but Obsidian isn't running -> launch Obsidian with this file
        if prefs.preferObsidianForOpen, isInstalled, detectVault(for: url) != nil {
            let cfg = NSWorkspace.OpenConfiguration()
            cfg.activates = true
            NSWorkspace.shared.open(
                [url],
                withApplicationAt: URL(fileURLWithPath: appPath),
                configuration: cfg
            ) { _, error in
                if let error {
                    NSLog("Inkling: failed to launch Obsidian (\(error)); using default app instead")
                    DispatchQueue.main.async { _ = NSWorkspace.shared.open(url) }
                }
            }
            return
        }

        // Path 3: not a vault file or user opts out -> default app for the file type
        if !NSWorkspace.shared.open(url) {
            NSLog("Inkling: NSWorkspace failed to open \(url.path)")
        }
    }

    enum ObsidianError: Error, LocalizedError {
        case cliMissing
        case notInVault
        case cliFailed(status: Int32, stderr: String)

        var errorDescription: String? {
            switch self {
            case .cliMissing: return "Obsidian CLI not found at \(cliPath)."
            case .notInVault: return "File is not inside an Obsidian vault."
            case .cliFailed(let s, let e): return "obsidian-cli exited \(s): \(e)"
            }
        }
    }
}
