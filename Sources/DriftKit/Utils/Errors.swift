//
//  Errors.swift
//  DriftKit
//
//  Created by Adarsh Shukla on 5/24/25.
//

public enum DriftKitError: Error {
    // Networking
    case invalidURL
    case networkFailure(underlying: Error)
    case httpError(statusCode: Int)
    
    // Storage
    case fileWriteFailed(underlying: Error)
    case fileMoveFailed(underlying: Error)
    case insufficientDiskSpace
    
    // Task
    case canceled
    case paused
    
    // Retry
    case retryLimitReached
    
    // Generic
    case unknown
}

// MARK: Equatable
extension DriftKitError: Equatable {
    public static func == (lhs: DriftKitError, rhs: DriftKitError) -> Bool {
        switch (lhs, rhs) {
            
            // Simple cases
        case (.invalidURL, .invalidURL),
            (.insufficientDiskSpace, .insufficientDiskSpace),
            (.canceled, .canceled),
            (.paused, .paused),
            (.retryLimitReached, .retryLimitReached),
            (.unknown, .unknown):
            return true
            
            // HTTP error with integer payload
        case let (.httpError(code1), .httpError(code2)):
            return code1 == code2
            
            // networkFailure: compare only the localizedDescription
        case let (.networkFailure(err1), .networkFailure(err2)):
            return err1.localizedDescription == err2.localizedDescription
            
            // fileWriteFailed: same strategy
        case let (.fileWriteFailed(err1), .fileWriteFailed(err2)):
            return err1.localizedDescription == err2.localizedDescription
            
        case let (.fileMoveFailed(err1), .fileMoveFailed(err2)):
            return err1.localizedDescription == err2.localizedDescription
            
            // Anything else is unequal
        default:
            return false
        }
    }
}

// MARK: Localized Description
extension DriftKitError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL provided."
        case .networkFailure(let err):
            return "Network failure: \(err.localizedDescription)"
        case .httpError(let code):
            return "Server responded with status code \(code)."
        case .fileWriteFailed(let err):
            return "Failed to write file: \(err.localizedDescription)"
        case .fileMoveFailed(let err):
            return "Failed to move file: \(err.localizedDescription)"
        case .insufficientDiskSpace:
            return "Not enough disk space."
        case .canceled:
            return "Download was canceled."
        case .paused:
            return "Download was paused."
        case .retryLimitReached:
            return "Retry limit exceeded."
        case .unknown:
            return "An unknown error occurred."
        }
    }
}
