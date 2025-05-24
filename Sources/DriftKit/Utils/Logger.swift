//
//  Logger.swift
//  DriftKit
//
//  Created by Adarsh Shukla on 5/24/25.
//

import OSLog

public protocol DKLogger {
    func log(_ level: DKLogLevel, message: String)
}

public enum DKLogLevel {
    case debug, info, warning, error
}

public struct DefaultLogger: DKLogger {
    public init() {}
    public func log(_ level: DKLogLevel, message: String) {
        os_log("[DriftKit][%{public}@] %{public}@", String(describing: level), message)
    }
}
