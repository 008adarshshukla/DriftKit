//  NetworkSession.swift
//  DriftKit
//
//  Created by Adarsh Shukla on 5/24/25.
//

import Foundation

/// Abstract over the system’s download‐task engine.
/// You could inject/mock this in tests if you like.
public protocol NetworkSession {
    /// Kick off a download, returning a `DownloadTask` you can start/pause/resume
    func makeDownloadTask(
        url: URL,
        destination: URL
    ) -> DownloadTask
}

extension URLSession: NetworkSession {
    public func makeDownloadTask(
        url: URL,
        destination: URL
    ) -> DownloadTask {
        return DownloadTask(url: url, destination: destination)
    }
}

