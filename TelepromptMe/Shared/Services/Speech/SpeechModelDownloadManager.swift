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

    private(set) var states: [String: DownloadState] = [:]
    private(set) var availableModels: [SpeechModelDescriptor] = SpeechModelCatalog.descriptors
    private var downloadableModels: [SpeechModelDescriptor] = SpeechModelCatalog.downloadableDescriptors
    private var downloadTasks: [String: Task<Void, Never>] = [:]
    private let urlSession = URLSession.shared

    init(refreshesHuggingFaceModels: Bool = true) {
        refreshInstalledModels()
        if refreshesHuggingFaceModels {
            Task { [weak self] in
                await self?.refreshHuggingFaceModels()
            }
        }
    }

    func state(for model: SpeechRecognitionEngineID) -> DownloadState {
        state(for: model.descriptor)
    }

    func state(for descriptor: SpeechModelDescriptor) -> DownloadState {
        if descriptor.isBuiltIn || descriptor.isCustom {
            return .downloaded
        }

        return states[descriptor.id] ?? (isInstalled(descriptor) ? .downloaded : .notDownloaded)
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
        download(model.descriptor)
    }

    func download(_ descriptor: SpeechModelDescriptor) {
        guard !descriptor.isBuiltIn else { return }
        guard downloadTasks[descriptor.id] == nil else { return }

        states[descriptor.id] = .downloading(progress: 0)

        let task = Task { [weak self] in
            guard let self else { return }

            do {
                try await self.prepareModelDirectory(for: descriptor)
                try await self.downloadRepository(for: descriptor)
                try self.verifyDownloadedModel(descriptor)
                try await self.markInstalled(descriptor)
                await MainActor.run {
                    self.states[descriptor.id] = .downloaded
                    self.downloadTasks[descriptor.id] = nil
                    self.refreshInstalledModels()
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.cleanupPartialDownloads(for: descriptor)
                    self.states[descriptor.id] = self.isInstalled(descriptor) ? .downloaded : .notDownloaded
                    self.downloadTasks[descriptor.id] = nil
                }
            } catch {
                await MainActor.run {
                    self.cleanupPartialDownloads(for: descriptor)
                    self.states[descriptor.id] = .failed(error.localizedDescription)
                    self.downloadTasks[descriptor.id] = nil
                }
            }
        }

        downloadTasks[descriptor.id] = task
    }

    func cancelDownload(for model: SpeechRecognitionEngineID) {
        cancelDownload(for: model.descriptor)
    }

    func cancelDownload(for descriptor: SpeechModelDescriptor) {
        downloadTasks[descriptor.id]?.cancel()
    }

    func delete(_ model: SpeechRecognitionEngineID) {
        delete(model.descriptor)
    }

    func delete(_ descriptor: SpeechModelDescriptor) {
        guard !descriptor.isBuiltIn else { return }
        guard SpeechRecognitionEngineID(rawValue: descriptor.id) != nil || descriptor.repositoryID != nil else {
            deleteCustomModel(descriptor)
            return
        }

        cancelDownload(for: descriptor)

        do {
            try FileManager.default.removeItem(at: SpeechModelStorage.directoryURL(forModelID: descriptor.id))
            states[descriptor.id] = .notDownloaded
        } catch CocoaError.fileNoSuchFile {
            states[descriptor.id] = .notDownloaded
        } catch {
            states[descriptor.id] = .failed(error.localizedDescription)
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
            checksumSHA256: try Self.sha256HexDigest(for: destinationURL),
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
        rebuildAvailableModels()
        for descriptor in availableModels where !descriptor.isBuiltIn && !descriptor.isCustom {
            if downloadTasks[descriptor.id] == nil {
                states[descriptor.id] = isInstalled(descriptor) ? .downloaded : .notDownloaded
            }
        }
    }

    func refreshHuggingFaceModels() async {
        do {
            let modelFiles = try await repositoryFiles(for: SpeechModelCatalog.whisperCppRepositoryID)
                .map(\.path)
                .filter(SpeechModelCatalog.isWhisperCppModelFile)
                .sorted()
            let descriptors = try await descriptorsWithResolvedSizes(for: modelFiles)

            guard !descriptors.isEmpty else {
                return
            }

            downloadableModels = descriptors
            refreshInstalledModels()
        } catch {
            NSLog("TelepromptMe could not refresh Hugging Face speech models: \(error.localizedDescription)")
        }
    }

    private func descriptorsWithResolvedSizes(for fileNames: [String]) async throws -> [SpeechModelDescriptor] {
        var descriptors: [SpeechModelDescriptor] = []
        descriptors.reserveCapacity(fileNames.count)

        for fileName in fileNames {
            try Task.checkCancellation()
            var descriptor = SpeechModelCatalog.whisperCppDescriptor(for: fileName)
            descriptor.estimatedByteSize = try await modelFileSize(
                repositoryID: SpeechModelCatalog.whisperCppRepositoryID,
                filePath: fileName
            ) ?? descriptor.estimatedByteSize
            descriptors.append(descriptor)
        }

        return descriptors
    }

    private func modelFileSize(repositoryID: String, filePath: String) async throws -> Int64? {
        let url = try Self.resolveURL(repositoryID: repositoryID, filePath: filePath)
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        let (_, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<400).contains(httpResponse.statusCode) else {
            return nil
        }

        return Self.byteSize(from: httpResponse)
    }

    private func rebuildAvailableModels() {
        availableModels = SpeechModelCatalog.builtInDescriptors +
            downloadableModels +
            SpeechModelCatalog.customDescriptors()
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
        isInstalled(model.descriptor)
    }

    private func manifestURL(for descriptor: SpeechModelDescriptor) -> URL {
        SpeechModelStorage.directoryURL(forModelID: descriptor.id)
            .appendingPathComponent(SpeechModelStorage.manifestFileName)
    }

    private func isInstalled(_ descriptor: SpeechModelDescriptor) -> Bool {
        FileManager.default.fileExists(atPath: manifestURL(for: descriptor).path)
    }

    private func prepareModelDirectory(for descriptor: SpeechModelDescriptor) async throws {
        try FileManager.default.createDirectory(
            at: SpeechModelStorage.directoryURL(forModelID: descriptor.id),
            withIntermediateDirectories: true
        )
    }

    private func markInstalled(_ descriptor: SpeechModelDescriptor) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(descriptor)
        try data.write(to: manifestURL(for: descriptor), options: .atomic)
    }

    private func downloadRepository(for descriptor: SpeechModelDescriptor) async throws {
        guard let repositoryID = descriptor.repositoryID else { return }
        guard let primaryModelFileName = descriptor.primaryModelFileName else {
            throw SpeechModelDownloadError.missingPrimaryModelFile(descriptor.title)
        }

        let files = try await repositoryFiles(for: repositoryID)
        guard let modelFile = files.first(where: { $0.path == primaryModelFileName }) else {
            throw SpeechModelDownloadError.modelFileNotFound(primaryModelFileName, repositoryID)
        }

        let sourceURL = try Self.resolveURL(repositoryID: repositoryID, filePath: modelFile.path)
        let totalBytes = modelFile.size ?? descriptor.estimatedByteSize ?? 0

        try Task.checkCancellation()
        let (_, expectedBytes) = try await downloadFile(
            from: sourceURL,
            to: SpeechModelStorage.directoryURL(forModelID: descriptor.id).appendingPathComponent(modelFile.path),
            modelID: descriptor.id,
            filePath: modelFile.path,
            completedBytes: 0,
            totalBytes: totalBytes,
            completedFileCount: 0,
            totalFileCount: 1
        )

        if totalBytes > 0 || expectedBytes != nil {
            states[descriptor.id] = .downloading(progress: 1)
        }
    }

    private func downloadFile(
        from sourceURL: URL,
        to destinationURL: URL,
        modelID: String,
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

        let expectedBytes = Self.byteSize(from: httpResponse)
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
                states[modelID] = .downloading(
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

    private func verifyDownloadedModel(_ descriptor: SpeechModelDescriptor) throws {
        guard let expectedChecksum = descriptor.checksumSHA256,
              let modelFileURL = SpeechModelStorage.modelFileURL(for: descriptor) else {
            return
        }

        try Self.verifyChecksum(
            for: modelFileURL,
            expectedChecksum: expectedChecksum,
            modelName: descriptor.title
        )
    }

    static func verifyChecksum(
        for fileURL: URL,
        expectedChecksum: String,
        modelName: String
    ) throws {
        let actualChecksum = try sha256HexDigest(for: fileURL)
        guard actualChecksum.caseInsensitiveCompare(expectedChecksum) == .orderedSame else {
            throw SpeechModelDownloadError.checksumMismatch(modelName)
        }
    }

    static func sha256HexDigest(for fileURL: URL) throws -> String {
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

    private func cleanupPartialDownloads(for descriptor: SpeechModelDescriptor) {
        guard let enumerator = FileManager.default.enumerator(
            at: SpeechModelStorage.directoryURL(forModelID: descriptor.id),
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

    func repositoryFiles(for repositoryID: String) async throws -> [RepositoryFile] {
        guard let url = Self.repositoryAPIURL(for: repositoryID) else {
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

    static func repositoryAPIURL(for repositoryID: String) -> URL? {
        URL(string: "https://huggingface.co/api/models/\(encodedRepositoryID(repositoryID))")
    }

    static func resolveURL(repositoryID: String, filePath: String) throws -> URL {
        guard let url = URL(string: "https://huggingface.co/\(encodedRepositoryID(repositoryID))/resolve/main/\(encodedFilePath(filePath))") else {
            throw SpeechModelDownloadError.downloadFailed(filePath)
        }

        return url
    }

    static func byteSize(from response: HTTPURLResponse) -> Int64? {
        if let linkedSize = headerValue("X-Linked-Size", in: response),
           let linkedByteSize = Int64(linkedSize) {
            return linkedByteSize
        }

        if let contentLength = headerValue("Content-Length", in: response),
           let contentByteSize = Int64(contentLength) {
            return contentByteSize
        }

        return response.expectedContentLength > 0 ? response.expectedContentLength : nil
    }

    private static func headerValue(_ name: String, in response: HTTPURLResponse) -> String? {
        response.allHeaderFields.first { key, _ in
            guard let key = key as? String else { return false }
            return key.caseInsensitiveCompare(name) == .orderedSame
        }?.value as? String
    }

    private static func encodedRepositoryID(_ repositoryID: String) -> String {
        let encodedRepositoryID = repositoryID
            .split(separator: "/")
            .map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")

        return encodedRepositoryID
    }

    private static func encodedFilePath(_ filePath: String) -> String {
        filePath
            .split(separator: "/")
            .map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")
    }
}

private struct HuggingFaceModelInfo: Decodable {
    var siblings: [HuggingFaceSibling]
}

private struct HuggingFaceSibling: Decodable {
    var rfilename: String
    var size: Int64?
}

struct RepositoryFile: Equatable {
    var path: String
    var size: Int64?
}

private enum SpeechModelDownloadError: LocalizedError {
    case invalidRepository(String)
    case missingPrimaryModelFile(String)
    case modelFileNotFound(String, String)
    case downloadFailed(String)
    case checksumMismatch(String)

    var errorDescription: String? {
        switch self {
        case .invalidRepository(let repositoryID):
            return "Could not read model repository \(repositoryID)."
        case .missingPrimaryModelFile(let modelName):
            return "\(modelName) does not declare a Hugging Face model file to download."
        case .modelFileNotFound(let fileName, let repositoryID):
            return "Could not find \(fileName) in Hugging Face repository \(repositoryID)."
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
