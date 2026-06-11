import CryptoKit
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
    private(set) var availableModels: [SpeechModelDescriptor] = SpeechModelCatalog.descriptors
    private var downloadTasks: [SpeechRecognitionEngineID: Task<Void, Never>] = [:]
    private let urlSession = URLSession.shared

    init() {
        refreshInstalledModels()
    }

    func state(for model: SpeechRecognitionEngineID) -> DownloadState {
        state(for: model.descriptor)
    }

    func state(for descriptor: SpeechModelDescriptor) -> DownloadState {
        if descriptor.isBuiltIn || descriptor.isCustom {
            return .downloaded
        }

        guard let model = SpeechRecognitionEngineID(rawValue: descriptor.id) else {
            return .notDownloaded
        }

        return states[model] ?? (isInstalled(model) ? .downloaded : .notDownloaded)
    }

    func isReady(_ modelID: String) -> Bool {
        SpeechModelCatalog.resolvedModelID(for: modelID) == modelID
    }

    func isUsable(_ modelID: String) -> Bool {
        guard let descriptor = SpeechModelCatalog.descriptor(for: modelID) else {
            return false
        }

        return isUsable(descriptor)
    }

    func isUsable(_ model: SpeechRecognitionEngineID) -> Bool {
        isUsable(model.descriptor)
    }

    func isUsable(_ descriptor: SpeechModelDescriptor) -> Bool {
        guard state(for: descriptor) == .downloaded else {
            return false
        }

        guard !descriptor.isBuiltIn else {
            return true
        }

        guard descriptor.isWhisperModel, let modelFileName = descriptor.primaryModelFileName else {
            return false
        }

        return FileManager.default.fileExists(
            atPath: SpeechModelStorage.directoryURL(forModelID: descriptor.id)
                .appendingPathComponent(modelFileName)
                .path
        )
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
                try self.verifyDownloadedModel(model)
                try await self.markInstalled(model)
                await MainActor.run {
                    self.states[model] = .downloaded
                    self.downloadTasks[model] = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.cleanupPartialDownloads(for: model)
                    self.states[model] = self.isInstalled(model) ? .downloaded : .notDownloaded
                    self.downloadTasks[model] = nil
                }
            } catch {
                await MainActor.run {
                    self.cleanupPartialDownloads(for: model)
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
        delete(model.descriptor)
    }

    func delete(_ descriptor: SpeechModelDescriptor) {
        guard !descriptor.isBuiltIn else { return }
        guard let model = SpeechRecognitionEngineID(rawValue: descriptor.id) else {
            deleteCustomModel(descriptor)
            return
        }

        cancelDownload(for: model)

        do {
            try FileManager.default.removeItem(at: directoryURL(for: model))
            states[model] = .notDownloaded
        } catch CocoaError.fileNoSuchFile {
            states[model] = .notDownloaded
        } catch {
            states[model] = .failed(error.localizedDescription)
        }

        refreshInstalledModels()
    }

    func importCustomModel(from sourceURL: URL) throws -> SpeechModelDescriptor {
        guard sourceURL.pathExtension.lowercased() == "bin" else {
            throw SpeechModelImportError.unsupportedFileType
        }

        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw SpeechModelImportError.missingFile
        }

        let sourceFileName = sourceURL.lastPathComponent
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let modelID = uniqueCustomModelID(for: baseName)
        let modelDirectoryURL = SpeechModelStorage.directoryURL(forModelID: modelID)
        let destinationURL = modelDirectoryURL.appendingPathComponent(sourceFileName)

        try FileManager.default.createDirectory(
            at: modelDirectoryURL,
            withIntermediateDirectories: true
        )
        removeFileIfNeeded(at: destinationURL)
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        let fileSize = try destinationURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
        let descriptor = SpeechModelDescriptor(
            id: modelID,
            runtime: .whisperCpp,
            architecture: .whisper,
            title: baseName.isEmpty ? "Custom Whisper Model" : baseName,
            subtitle: "Imported whisper.cpp model.",
            repositoryID: nil,
            primaryModelFileName: sourceFileName,
            checksumSHA256: try sha256HexDigest(for: destinationURL),
            estimatedByteSize: fileSize.map(Int64.init),
            supportedLanguageIdentifiers: [],
            isCustom: true,
            isRecommended: false
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(descriptor)
        try data.write(
            to: modelDirectoryURL.appendingPathComponent(SpeechModelStorage.manifestFileName),
            options: .atomic
        )

        refreshInstalledModels()
        return descriptor
    }

    func refreshInstalledModels() {
        for model in SpeechRecognitionEngineID.allCases where !model.isBuiltIn {
            states[model] = isInstalled(model) ? .downloaded : .notDownloaded
        }
        availableModels = SpeechModelCatalog.descriptors
    }

    func directoryURL(for model: SpeechRecognitionEngineID) -> URL {
        Self.directoryURL(for: model)
    }

    static func directoryURL(for model: SpeechRecognitionEngineID) -> URL {
        SpeechModelStorage.directoryURL(for: model)
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
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(model.descriptor)
        try data.write(to: manifestURL(for: model), options: .atomic)
    }

    private func downloadRepository(for model: SpeechRecognitionEngineID) async throws {
        guard let repositoryID = model.repositoryID else { return }

        let files = try await repositoryFiles(for: repositoryID)
            .filter { !$0.path.hasPrefix(".") && !$0.path.contains("/.") }

        guard !files.isEmpty else {
            throw SpeechModelDownloadError.emptyRepository
        }

        let knownTotalBytes = files.reduce(Int64(0)) { total, file in
            guard let size = file.size else { return total }
            return total + size
        }
        var completedBytes: Int64 = 0

        for (index, file) in files.enumerated() {
            try Task.checkCancellation()
            let sourceURL = try resolveURL(repositoryID: repositoryID, filePath: file.path)
            let (downloadedBytes, expectedBytes) = try await downloadFile(
                from: sourceURL,
                to: directoryURL(for: model).appendingPathComponent(file.path),
                model: model,
                filePath: file.path,
                completedBytes: completedBytes,
                totalBytes: knownTotalBytes,
                completedFileCount: index,
                totalFileCount: files.count
            )

            completedBytes += file.size ?? expectedBytes ?? downloadedBytes
            if knownTotalBytes > 0 {
                states[model] = .downloading(progress: min(1, Double(completedBytes) / Double(knownTotalBytes)))
            } else {
                states[model] = .downloading(progress: Double(index + 1) / Double(files.count))
            }
        }
    }

    private func downloadFile(
        from sourceURL: URL,
        to destinationURL: URL,
        model: SpeechRecognitionEngineID,
        filePath: String,
        completedBytes: Int64,
        totalBytes: Int64,
        completedFileCount: Int,
        totalFileCount: Int
    ) async throws -> (downloadedBytes: Int64, expectedBytes: Int64?) {
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let partialURL = partialDownloadURL(for: destinationURL)
        removeFileIfNeeded(at: partialURL)

        let (bytes, response) = try await urlSession.bytes(from: sourceURL)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw SpeechModelDownloadError.downloadFailed(filePath)
        }

        FileManager.default.createFile(atPath: partialURL.path, contents: nil)
        let fileHandle = try FileHandle(forWritingTo: partialURL)
        defer {
            try? fileHandle.close()
        }

        let expectedBytes = httpResponse.expectedContentLength > 0 ? httpResponse.expectedContentLength : nil
        var downloadedBytes: Int64 = 0
        var buffer: [UInt8] = []
        buffer.reserveCapacity(64 * 1024)

        for try await byte in bytes {
            try Task.checkCancellation()
            buffer.append(byte)
            downloadedBytes += 1

            if buffer.count >= 64 * 1024 {
                try fileHandle.write(contentsOf: Data(buffer))
                buffer.removeAll(keepingCapacity: true)
                states[model] = .downloading(
                    progress: downloadProgress(
                        downloadedFileBytes: downloadedBytes,
                        expectedFileBytes: expectedBytes,
                        completedBytes: completedBytes,
                        totalBytes: totalBytes,
                        completedFileCount: completedFileCount,
                        totalFileCount: totalFileCount
                    )
                )
            }
        }

        if !buffer.isEmpty {
            try fileHandle.write(contentsOf: Data(buffer))
        }

        removeFileIfNeeded(at: destinationURL)
        try FileManager.default.moveItem(at: partialURL, to: destinationURL)
        return (downloadedBytes, expectedBytes)
    }

    private func downloadProgress(
        downloadedFileBytes: Int64,
        expectedFileBytes: Int64?,
        completedBytes: Int64,
        totalBytes: Int64,
        completedFileCount: Int,
        totalFileCount: Int
    ) -> Double {
        if totalBytes > 0 {
            return min(1, Double(completedBytes + downloadedFileBytes) / Double(totalBytes))
        }

        guard totalFileCount > 0 else {
            return 0
        }

        let fileProgress: Double
        if let expectedFileBytes, expectedFileBytes > 0 {
            fileProgress = min(1, Double(downloadedFileBytes) / Double(expectedFileBytes))
        } else {
            fileProgress = 0
        }

        return min(1, (Double(completedFileCount) + fileProgress) / Double(totalFileCount))
    }

    private func verifyDownloadedModel(_ model: SpeechRecognitionEngineID) throws {
        guard let expectedChecksum = model.descriptor.checksumSHA256,
              let modelFileURL = SpeechModelStorage.modelFileURL(for: model) else {
            return
        }

        let actualChecksum = try sha256HexDigest(for: modelFileURL)
        guard actualChecksum.caseInsensitiveCompare(expectedChecksum) == .orderedSame else {
            throw SpeechModelDownloadError.checksumMismatch(model.title)
        }
    }

    private func sha256HexDigest(for fileURL: URL) throws -> String {
        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer {
            try? fileHandle.close()
        }

        var sha256 = SHA256()
        while true {
            let data = try fileHandle.read(upToCount: 1024 * 1024) ?? Data()
            guard !data.isEmpty else { break }
            sha256.update(data: data)
        }

        return sha256.finalize()
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func cleanupPartialDownloads(for model: SpeechRecognitionEngineID) {
        guard let enumerator = FileManager.default.enumerator(
            at: directoryURL(for: model),
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "partial" {
            removeFileIfNeeded(at: fileURL)
        }
    }

    private func partialDownloadURL(for destinationURL: URL) -> URL {
        destinationURL.appendingPathExtension("partial")
    }

    private func removeFileIfNeeded(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        try? FileManager.default.removeItem(at: url)
    }

    private func deleteCustomModel(_ descriptor: SpeechModelDescriptor) {
        do {
            try FileManager.default.removeItem(at: SpeechModelStorage.directoryURL(forModelID: descriptor.id))
        } catch CocoaError.fileNoSuchFile {
        } catch {
            NSLog("TelepromptMe could not delete custom speech model: \(error.localizedDescription)")
        }

        refreshInstalledModels()
    }

    private func uniqueCustomModelID(for name: String) -> String {
        let slug = sanitizedModelSlug(from: name)
        var candidate = "custom-\(slug)"
        var suffix = 2

        while FileManager.default.fileExists(
            atPath: SpeechModelStorage.directoryURL(forModelID: candidate).path
        ) {
            candidate = "custom-\(slug)-\(suffix)"
            suffix += 1
        }

        return candidate
    }

    private func sanitizedModelSlug(from name: String) -> String {
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let slug = name
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .components(separatedBy: allowedCharacters.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")

        return slug.isEmpty ? "whisper-model" : slug
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
        return modelInfo.siblings.map { RepositoryFile(path: $0.rfilename, size: $0.size) }
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
    var size: Int64?
}

private struct RepositoryFile: Equatable {
    var path: String
    var size: Int64?
}

private enum SpeechModelDownloadError: LocalizedError {
    case invalidRepository(String)
    case emptyRepository
    case downloadFailed(String)
    case checksumMismatch(String)

    var errorDescription: String? {
        switch self {
        case .invalidRepository(let repositoryID):
            return "Could not read model repository \(repositoryID)."
        case .emptyRepository:
            return "The selected model repository has no downloadable files."
        case .downloadFailed(let filePath):
            return "Could not download \(filePath)."
        case .checksumMismatch(let modelName):
            return "\(modelName) did not match its expected checksum."
        }
    }
}

private enum SpeechModelImportError: LocalizedError {
    case unsupportedFileType
    case missingFile

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            return "Choose a whisper.cpp model file with a .bin extension."
        case .missingFile:
            return "The selected model file could not be found."
        }
    }
}
