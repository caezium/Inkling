import Foundation

@MainActor
final class WriteHistory: ObservableObject {
    static let shared = WriteHistory()

    @Published private(set) var entries: [FileWriter.Receipt] = []
    private let limit = 25

    func record(_ receipt: FileWriter.Receipt) {
        entries.append(receipt)
        if entries.count > limit { entries.removeFirst(entries.count - limit) }
    }

    @discardableResult
    func popLast() -> FileWriter.Receipt? {
        entries.popLast()
    }

    var lastDescription: String? {
        guard let last = entries.last else { return nil }
        let preview = last.writtenLine.split(separator: "\n").first.map(String.init) ?? last.writtenLine
        let trimmed = preview.trimmingCharacters(in: .whitespaces)
        return "Undo: \"\(trimmed.prefix(40))…\" in \(last.fileAlias)"
    }
}
