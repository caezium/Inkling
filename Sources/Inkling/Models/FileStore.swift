import Foundation
import Combine

@MainActor
final class FileStore: ObservableObject {
    static let shared = FileStore()

    @Published private(set) var files: [TrackedFile] = []

    private let key = "Inkling.trackedFiles.v1"
    private let defaults: UserDefaults
    private let saveDebounce = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        saveDebounce
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] in self?.save() }
            .store(in: &cancellables)
    }

    func add(_ file: TrackedFile) {
        files.append(file)
        scheduleSave()
    }

    func update(_ file: TrackedFile) {
        guard let i = files.firstIndex(where: { $0.id == file.id }) else { return }
        files[i] = file
        scheduleSave()
    }

    func remove(id: UUID) {
        files.removeAll { $0.id == id }
        scheduleSave()
    }

    func move(from source: IndexSet, to destination: Int) {
        files.move(fromOffsets: source, toOffset: destination)
        scheduleSave()
    }

    func file(id: UUID) -> TrackedFile? { files.first { $0.id == id } }

    func file(matching hotkey: Hotkey) -> TrackedFile? {
        files.first { $0.hotkey == hotkey }
    }

    private func scheduleSave() { saveDebounce.send() }

    private func load() {
        guard let data = defaults.data(forKey: key) else { return }
        if let decoded = try? JSONDecoder().decode([TrackedFile].self, from: data) {
            files = decoded
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(files) else { return }
        defaults.set(data, forKey: key)
    }
}
