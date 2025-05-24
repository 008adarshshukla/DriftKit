//  DownloadTask.swift
//  DriftKit
//
//  Created by Adarsh Shukla on 5/24/25.
//

import Foundation

/// A single file download, with pause/resume and progress updates.
public actor DownloadTask {
    public enum State {
        case queued
        case downloading
        case paused
        case completed(URL)
        case failed(DriftKitError)
    }
    
    // MARK: Public API
    
    public let id = UUID()
    public private(set) var state: State = .queued
    public private(set) var progressStream: AsyncStream<ProgressUpdate>
    
    /// Start or resume downloading immediately
    public func start() {
        state = .downloading
        if let resumeData = Self.resumeStore[id] {
            downloadTask = session.downloadTask(withResumeData: resumeData)
            Self.resumeStore[id] = nil
        } else {
            downloadTask = session.downloadTask(with: url)
        }
        cumulativeBytesWritten = 0
        downloadTask?.resume()
    }
    
    public func pause() {
        guard let task = downloadTask else { return }
        task.cancel(byProducingResumeData: { data in
            if let data = data {
                Self.resumeStore[self.id] = data
            }
        })
        state = .paused
    }
    
    public func cancel() {
        downloadTask?.cancel()
        state = .failed(.canceled)
        streamCont.finish()
    }
    
    // MARK: Internal storage
    
    private let url: URL
    private let destination: URL
    private var downloadTask: URLSessionDownloadTask?
    private let streamCont: AsyncStream<ProgressUpdate>.Continuation
    private static var resumeStore: [UUID: Data] = [:]
    
    /// Tracks cumulative bytes written to ensure monotonic progress
    private var cumulativeBytesWritten: Int64 = 0
    
    private lazy var delegate = DownloadTaskDelegate(parent: self)
    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.allowsCellularAccess = true
        return URLSession(configuration: cfg, delegate: delegate, delegateQueue: nil)
    }()
    
    public init(url: URL, destination: URL) {
        self.url = url
        self.destination = destination
        var cont: AsyncStream<ProgressUpdate>.Continuation! = nil
        self.progressStream = AsyncStream<ProgressUpdate> { continuation in
            cont = continuation
        }
        self.streamCont = cont
    }
    
    /// Called by delegate bridge for each chunk of data
    fileprivate func didWrite(bytesWrittenDelta: Int64,
                              totalBytesWritten: Int64,
                              totalBytesExpected: Int64) {
        cumulativeBytesWritten += bytesWrittenDelta
        // clamp to expected to avoid exceeding
        cumulativeBytesWritten = min(cumulativeBytesWritten, totalBytesExpected)
        
        streamCont.yield(
            ProgressUpdate(
                taskID: id,
                bytesWritten: cumulativeBytesWritten,
                totalBytesExpected: totalBytesExpected
            )
        )
    }
    
    /// Called when download finishes on disk
    // MARK: - Called by delegate after moving file on disk
    fileprivate func didFinishDownloading(at destinationURL: URL) {
        // Mark completed state
        state = .completed(destinationURL)
        // Close the progress stream so the UI knows we're done
        streamCont.finish()
    }
    
    /// Called on task completion or error
    fileprivate func didComplete(with error: Error?) {
        if let ns = error as NSError?,
           ns.domain == NSURLErrorDomain,
           ns.code == NSURLErrorCancelled {
            // paused/canceled: leave stream open until explicit finish
        } else if let error = error {
            state = .failed(.networkFailure(underlying: error))
            streamCont.finish()
        } else {
            streamCont.finish()
        }
    }
    
    // MARK: - NSURLSessionDelegate Bridge
    private class DownloadTaskDelegate: NSObject, URLSessionDownloadDelegate {
        private weak var parent: DownloadTask?
        init(parent: DownloadTask) {
            self.parent = parent
        }
        
        func urlSession(_ session: URLSession,
                        downloadTask: URLSessionDownloadTask,
                        didWriteData bytesWrittenDelta: Int64,
                        totalBytesWritten: Int64,
                        totalBytesExpectedToWrite: Int64) {
            guard let p = parent else { return }
            Task { await p.didWrite(
                bytesWrittenDelta: bytesWrittenDelta,
                totalBytesWritten: totalBytesWritten,
                totalBytesExpected: totalBytesExpectedToWrite
            ) }
        }
        
        func urlSession(_ session: URLSession,
                        downloadTask: URLSessionDownloadTask,
                        didFinishDownloadingTo location: URL) {
            guard let p = parent else { return }
            // Perform file move here synchronously
            let destination = p.destination
            let dir = destination.deletingLastPathComponent()
            do {
                if !FileManager.default.fileExists(atPath: dir.path) {
                    try FileManager.default.createDirectory(
                        at: dir,
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
                }
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: location, to: destination)
                print("Moved file to \(destination.path)")
                // Notify actor
                Task { await p.didFinishDownloading(at: destination) }
            } catch {
                print("File move error in delegate: \(error.localizedDescription)")
                Task { await p.didComplete(with: error) }
            }
        }
        
        func urlSession(_ session: URLSession,
                        task: URLSessionTask,
                        didCompleteWithError error: Error?) {
            guard let p = parent else { return }
            Task { await p.didComplete(with: error) }
        }
    }
}
