//
//  FileHandle+Extensions.swift
//  DriftKit
//
//  Created by Adarsh Shukla on 5/24/25.
//

import Foundation

import Foundation

extension FileHandle {
    /// Creates (and if necessary, parent‐directory–creates) a file at `url`,
    /// and opens it for appending using a POSIX open + FileHandle initializer.
    convenience init(writingTo url: URL) throws {
        // 1. Ensure parent directory exists
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // 2. Create the file if it doesn't exist
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil)
        }

        // 3. Open the file for writing (O_WRONLY | O_APPEND)
        let fd = Darwin.open(url.path, O_WRONLY | O_APPEND)
        guard fd >= 0 else {
            let err = NSError(
                domain: NSPOSIXErrorDomain,
                code: Int(errno),
                userInfo: nil
            )
            throw DriftKitError.fileWriteFailed(underlying: err)
        }

        // 4. Initialize the FileHandle with the POSIX file descriptor
        self.init(fileDescriptor: fd, closeOnDealloc: true)
    }
}
