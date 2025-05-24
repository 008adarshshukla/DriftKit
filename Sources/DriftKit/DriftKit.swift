// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

public enum DriftKit {
    /// Shared manager instance
    public static let manager = DownloadManager()
    
    
    /// Enqueue a download
    @discardableResult
    public static func download(
        _ urlString: String,
        to relativePath: String,
        priority: TaskPriority = .medium
    ) async throws -> UUID {
        guard let url = URL(string: urlString) else {
            throw DriftKitError.invalidURL
        }
        let dest = try fileURL(for: relativePath)
        return await manager.enqueue(url, destination: dest, priority: priority)
    }
    
    /// Pause a download
    public static func pause(_ id: UUID) async {
        await manager.pause(id: id)
    }
    /// Resume
    public static func resume(_ id: UUID) async throws {
        try await manager.resume(id: id)
    }
    /// Cancel
    public static func cancel(_ id: UUID) async {
        await manager.cancel(id: id)
    }
    
    /// Progress stream for a download
    public static func progress(
        for id: UUID
    ) async -> AsyncThrowingStream<ProgressUpdate, Error> {
        return await manager.progressStream(for: id)
    }
    
    private static func fileURL(for path: String) throws -> URL {
        let docs = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(path)
    }
}
