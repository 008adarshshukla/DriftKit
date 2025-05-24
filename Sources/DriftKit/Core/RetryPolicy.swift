//
//  RetryPolicy.swift
//  DriftKit
//
//  Created by Adarsh Shukla on 5/24/25.
//

import Foundation

public struct RetryPolicy {
    public let maxRetries: Int
    public let backoffBase: TimeInterval
    
    public init(maxRetries: Int = 3, backoffBase: TimeInterval = 1) {
        self.maxRetries = maxRetries
        self.backoffBase = backoffBase
    }
    
    public func backoffDelay(for attempt: Int) -> TimeInterval {
        backoffBase * pow(2.0, Double(attempt - 1))
    }
}
