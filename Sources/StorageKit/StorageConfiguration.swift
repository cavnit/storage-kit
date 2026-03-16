import Vapor

public struct StorageConfiguration: Sendable {
    public let endpoint: String
    public let accessKey: String
    public let secretKey: String
    public let region: String
    public let bucket: String

    public init(endpoint: String, accessKey: String, secretKey: String, region: String, bucket: String) {
        self.endpoint = endpoint
        self.accessKey = accessKey
        self.secretKey = secretKey
        self.region = region
        self.bucket = bucket
    }

    /// Builds the base URL for an object key.
    /// For AWS S3: "https://bucket.s3.region.amazonaws.com/key"
    /// For MinIO or custom endpoints: "endpoint/bucket/key"
    func objectURL(for key: String) -> String {
        let base: String = endpoint.hasSuffix("/") ? String(endpoint.dropLast()) : endpoint
        return "\(base)/\(bucket)/\(key)"
    }
}
