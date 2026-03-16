// Originally created by Adam Fowler on 2019/08/29.
// Derived from the soto-project (https://github.com/soto-project)
// Licensed under Apache License 2.0
//
// Modified: Added Sendable conformances for Swift 6 concurrency.

import class Foundation.ProcessInfo

/// Protocol for providing credential details for accessing AWS services.
public protocol Credential: Sendable {
    var accessKeyId: String { get }
    var secretAccessKey: String { get }
    var sessionToken: String? { get }
}

/// Static credential where you supply the values directly.
public struct StaticCredential: Credential {
    public let accessKeyId: String
    public let secretAccessKey: String
    public let sessionToken: String?

    public init(accessKeyId: String, secretAccessKey: String, sessionToken: String? = nil) {
        self.accessKeyId = accessKeyId
        self.secretAccessKey = secretAccessKey
        self.sessionToken = sessionToken
    }
}

/// Credential that reads from environment variables.
public struct EnvironmentCredential: Credential {
    public let accessKeyId: String
    public let secretAccessKey: String
    public let sessionToken: String?

    public init?() {
        guard let accessKeyId: String = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"] else {
            return nil
        }
        guard let secretAccessKey: String = ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"] else {
            return nil
        }
        self.accessKeyId = accessKeyId
        self.secretAccessKey = secretAccessKey
        self.sessionToken = ProcessInfo.processInfo.environment["AWS_SESSION_TOKEN"]
    }
}
