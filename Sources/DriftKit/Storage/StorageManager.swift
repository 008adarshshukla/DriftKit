//
//  StorageManager.swift
//  DriftKit
//
//  Created by Adarsh Shukla on 5/24/25.
//

import Foundation

/// Where to store fragments or final files
public enum Directory {
    /// App‐only Documents (backed up, persistent)
    case documents
    
    /// Exposed Documents folder (requires UIFileSharingEnabled = YES)
    case documentsExposed
    
    /// Caches (not backed up, survives launches)
    case caches
    
    /// tmp (system may purge at any time)
    case temporary
    
    fileprivate var url: URL {
        switch self {
        case .documents, .documentsExposed:
            return FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
        case .caches:
            return FileManager.default
                .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        case .temporary:
            return FileManager.default.temporaryDirectory
        }
    }
}


/// Manages on-disk storage for DriftKit’s downloads
public final class StorageManager {
    private let baseURL: URL
    
    /// - Parameter base: the directory to use for all temp fragments
    public init(base: Directory = .caches) {
        self.baseURL = base.url
    }
    
    /// Returns a unique “.part” file URL for storing a download in progress
    public func temporaryFileURL(for id: UUID) -> URL {
        return baseURL
            .appendingPathComponent(id.uuidString)
            .appendingPathExtension("part")
    }
    
    /// Atomically moves the completed file into its final destination
    public func finalize(tempURL: URL, destination: URL) throws {
        let destDir = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: destDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
        // Remove existing file if present
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        // Now move
        do {
            try FileManager.default.moveItem(at: tempURL, to: destination)
        }
        catch {
            // Fallback to replace (atomic overwrite)
            try FileManager.default.replaceItemAt(
                destination,
                withItemAt: tempURL,
                backupItemName: nil,
                options: []
            )
        }
    }
    
    /// Deletes a temporary fragment (used on cancel)
    public func cleanup(tempURL: URL) throws {
        do {
            try FileManager.default.removeItem(at: tempURL)
        } catch {
            // If the file is already gone, that’s fine
            if (error as NSError).code != NSFileNoSuchFileError {
                throw DriftKitError.fileMoveFailed(underlying: error)
            }
        }
    }
    
    /// Deletes all “.part” files older than now–ttl seconds
    public func pruneStaleFragments(ttl: TimeInterval) throws {
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: []
        )
        let expirationDate = Date().addingTimeInterval(-ttl)
        for url in fileURLs where url.pathExtension == "part" {
            let attrs = try url.resourceValues(
                forKeys: [.contentModificationDateKey]
            )
            if let modDate = attrs.contentModificationDate,
               modDate < expirationDate
            {
                try FileManager.default.removeItem(at: url)
            }
        }
    }
}
