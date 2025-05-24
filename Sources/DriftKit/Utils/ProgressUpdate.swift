//
//  ProgressUpdate.swift
//  DriftKit
//
//  Created by Adarsh Shukla on 5/24/25.
//

import Foundation

public struct ProgressUpdate: Sendable {
    public let taskID: UUID
    public let bytesWritten: Int64
    public let totalBytesExpected: Int64?
    
    public var fractionCompleted: Double? {
        guard let total = totalBytesExpected, total > 0 else { return nil }
        return Double(bytesWritten) / Double(total)
    }
}
