import Foundation
import Observation

@MainActor
@Observable
final class SpeechModelDownloadManager {
    enum DownloadState: Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case downloaded
        case failed(String)
    }

    private(set) var states: [SpeechRecognitionEngineID: DownloadState] = [:]
    private var downloadTasks: [SpeechRecognitionEngineID: Task<Void, Never>] = [:]
    private let urlSession = URLSession.shared

    init() {
        refreshInstalledModels()
    }

    func state(for model: SpeechRecognitionEngineID) -> DownloadState {
        if model.isBuiltIn {
            return .downloaded
        }

        return states[model] ?? (isInstalled(model) ? .downloaded : .notDownloaded)
    }

    func isReady(_ modelID: String) -> Bool {
        guard let model = SpeechRecognitionEngineID(rawValue: modelID) else {
            return false
        }

        return state(for: model) == .downloaded
    }

    func download(_ model: SpeechRecognitionEngineID) {
        guard !model.isBuiltIn else { return }
        guard downloadTasks[model] == nil else { return }

        states[model] = .downloading(progress: 0)

        let task = Task { [weak self] in
            guard let self else { return }

            do {
                try await self.prepareModelDirectory(for: model)
                try await self.downloadRepository(for: model)
                try await self.markInstalled(model)
                await MainActor.run {
                    self.states[model] = .downloaded
                    self.downloadTasks[model] = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.states[model] = self.isInstalled(model) ? .downloaded : .notDownloaded
                    self.downloadTasks[model] = nil
                }
            } catch {
                await MainActor.run {
                    self.states[model] = .failed(error.localizedDescription)
                    self.downloadTasks[model] = nil
                }
            }
        }

        downloadTasks[model] = task
    }

    func cancelDownload(for model: SpeechRecognitionEngineID) {
        downloadTasks[model]?.cancel()
    }

    func delete(_ model: SpeechRecognitionEngineID) {
        guard !model.isBuiltIn else { return }
        cancelDownload(for: model)

        do {
            try FileManager.default.removeItem(at: directoryURL(for: model))
            states[model] = .notDownloaded
        } catch CocoaError.fileNoSuchFile {
            states[model] = .notDownloaded
        } catch {
            states[model] = .failed(error.localizedDescription)
        }
    }

    func refreshInstalledModels() {
        for model in SpeechRecognitionEngineID.allCases where !model.isBuiltIn {
            states[model] = isInstalled(model) ? .downloaded : .notDownloaded
        }
    }

    func directoryURL(for model: SpeechRecognitionEngineID) -> URL {
        applicationSupportURL
            .appendingPathComponent("SpeechModels", isDirectory: true)
            .appendingPathComponent(model.rawValue, isDirectory: true)
    }

    private var applicationSupportURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TelepromptMe", isDirectory: true)
    }

    private func manifestURL(for model: SpeechRecognitionEngineID) -> URL {
        directoryURL(for: model).appendingPathComponent(model.manifestFileName)
    }

    private func isInstalled(_ model: SpeechRecognitionEngineID) -> Bool {
        FileManager.default.fileExists(atPath: manifestURL(for: model).path)
    }

    private func prepareModelDirectory(for model: SpeechRecognitionEngineID) async throws {
        try FileManager.default.createDirectory(
            at: directoryURL(for: model),
            withIntermediateDirectories: true
        )
    }

    private func markInstalled(_ model: SpeechRecognitionEngineID) async throws {
        let metadata = """
        model=\(model.rawValue)
        repository=\(model.repositoryID ?? "built-in")
        installedAt=\(Date().ISO8601Format())
        """

        try metadata.write(to: manifestURL(for: model), atomically: true, encoding: .utf8)
    }

    private func downloadRepository(for model: SpeechRecognitionEngineID) async throws {
        guard let repositoryID = model.repositoryID else { return }

        let files = try await repositoryFiles(for: repositoryID)
            .filter { !$0.path.hasPrefix(".") && !$0.path.contains("/.") }

        guard !files.isEmpty else {
            throw SpeechModelDownloadError.emptyRepository
        }

        for (index, file) in files.enumerated() {
            try Task.checkCancellation()
            let sourceURL = try resolveURL(repositoryID: repositoryID, filePath: file.path)
            let (temporaryURL, response) = try await urlSession.download(from: sourceURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw SpeechModelDownloadError.downloadFailed(file.path)
            }

            let destinationURL = directoryURL(for: model).appendingPathComponent(file.path)
            try FileManager.default.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
            states[model] = .downloading(progress: Double(index + 1) / Double(files.count))
        }
    }

    private func repositoryFiles(for repositoryID: String) async throws -> [RepositoryFile] {
        let encodedRepositoryID = repositoryID
            .split(separator: "/")
            .map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")

        guard let url = URL(string: "https://huggingface.co/api/models/\(encodedRepositoryID)") else {
            throw SpeechModelDownloadError.invalidRepository(repositoryID)
        }

        let (data, response) = try await urlSession.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw SpeechModelDownloadError.invalidRepository(repositoryID)
        }

        let modelInfo = try JSONDecoder().decode(HuggingFaceModelInfo.self, from: data)
        return modelInfo.siblings.map { RepositoryFile(path: $0.rfilename) }
    }

    private func resolveURL(repositoryID: String, filePath: String) throws -> URL {
        let encodedRepositoryID = repositoryID
            .split(separator: "/")
            .map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")
        let encodedFilePath = filePath
            .split(separator: "/")
            .map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")

        guard let url = URL(string: "https://huggingface.co/\(encodedRepositoryID)/resolve/main/\(encodedFilePath)") else {
            throw SpeechModelDownloadError.downloadFailed(filePath)
        }

        return url
    }
}

private struct HuggingFaceModelInfo: Decodable {
    var siblings: [HuggingFaceSibling]
}

private struct HuggingFaceSibling: Decodable {
    var rfilename: String
}

private struct RepositoryFile: Equatable {
    var path: String
}

private enum SpeechModelDownloadError: LocalizedError {
    case invalidRepository(String)
    case emptyRepository
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidRepository(let repositoryID):
            return "Could not read model repository \(repositoryID)."
        case .emptyRepository:
            return "The selected model repository has no downloadable files."
        case .downloadFailed(let filePath):
            return "Could not download \(filePath)."
        }
    }
}
