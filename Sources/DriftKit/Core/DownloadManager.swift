//
//  DownloadManager.swift
//  DriftKit
//
//  Created by Adarsh Shukla on 5/24/25.
//

import Foundation

public actor DownloadManager {
    // MARK: Configuration
    public struct Config {
        public var maxConcurrentTasks: Int
        public var retryPolicy: RetryPolicy
        public var allowsCellularAccess: Bool
        public var sessionConfiguration: URLSessionConfiguration
        public var tempDirectory: Directory
        public var fragmentTTL: TimeInterval
        
        public init(
            maxConcurrentTasks: Int = 3,
            retryPolicy: RetryPolicy = .init(maxRetries: 3, backoffBase: 1),
            allowsCellularAccess: Bool = true,
            sessionConfiguration: URLSessionConfiguration = .default,
            tempDirectory: Directory = .documentsExposed,
            fragmentTTL: TimeInterval = 7 * 24 * 60 * 60
        ) {
            self.maxConcurrentTasks = maxConcurrentTasks
            self.retryPolicy = retryPolicy
            self.allowsCellularAccess = allowsCellularAccess
            let config = sessionConfiguration
            config.allowsCellularAccess = allowsCellularAccess
            self.sessionConfiguration = config
            self.tempDirectory = tempDirectory
            self.fragmentTTL = fragmentTTL
        }
    }
    
    // MARK: Properties
    private let config: Config
    private let storage: StorageManager
    private let logger: DKLogger
    
    private var queue: [DownloadTask] = []
    private var activeCount: Int = 0
    
    // MARK: Init
    public init(
        config: Config = .init(),
        storage: StorageManager = .init(),
        logger: DKLogger = DefaultLogger()
    ) {
        self.config = config
        self.storage = storage
        self.logger = logger
    }
    
    // MARK: Public API
    @discardableResult
    public func enqueue(
        _ url: URL,
        destination: URL,
        priority: TaskPriority = .medium
    ) -> UUID {
        logger.log(.info, message: "Downloading url:\n\(url)\nto destination:\n\(destination)")
        let task = DownloadTask(
            url: url,
            destination: destination
        )
        queue.append(task)
        Task { await scheduleNext() }
        return task.id
    }
    
    public func pause(id: UUID) async {
        if let task = task(for: id) {
            await task.pause()
        }
    }
    
    public func resume(id: UUID) async throws {
        if let task = task(for: id) {
            try await task.start()
        }
    }
    
    public func cancel(id: UUID) async {
        if let index = queue.firstIndex(where: { $0.id == id }) {
            let task = queue.remove(at: index)
            await task.cancel()
        }
    }
    
    public func progressStream(
        for id: UUID
    ) -> AsyncThrowingStream<ProgressUpdate, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let task = await task(for: id) else {
                    continuation.finish(throwing: DriftKitError.invalidURL)
                    return
                }
                for await update in await task.progressStream {
                    continuation.yield(update)
                }
                continuation.finish()
            }
        }
    }
    
    // MARK: Scheduler
    private func scheduleNext() async {
        do {
            try storage.pruneStaleFragments(ttl: config.fragmentTTL)
        } catch {
            logger.log(.warning, message: "Prune error: \(error.localizedDescription)")
        }
        
        while activeCount < config.maxConcurrentTasks,
              let next = await firstQueued() {
            activeCount += 1
            Task {
                do {
                    Task {
                        try await next.start()
                        await self.taskDidFinish(task: next)
                    }
                } catch {
                    logger.log(.error, message: "Task \(next.id) failed: \(error)")
                }
            }
        }
    }
    
    private func taskDidFinish(task: DownloadTask) async {
        activeCount -= 1
        await scheduleNext()
    }
    
    // MARK: Helpers
    
    /// Actor‐isolated lookup by ID to allow synchronous predicates elsewhere
    private func task(for id: UUID) -> DownloadTask? {
        queue.first { $0.id == id }
    }
    
    /// Finds the first queued task
    private func firstQueued() async -> DownloadTask? {
        for task in queue {
            if case .queued = await task.state {
                return task
            }
        }
        return nil
    }
}

