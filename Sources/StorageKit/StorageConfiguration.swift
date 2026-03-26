import Vapor

public enum EndpointStyle: Sendable {
    /// Bucket name is included in the URL path: `endpoint/bucket/key`
    /// Used by AWS S3, MinIO, and other S3-compatible services.
    case pathStyle
    /// Bucket name is prepended to the endpoint hostname: `bucket.endpoint/key`
    /// Used by Cloudflare R2 and services that use virtual-hosted-style URLs.
    case virtualHosted
}

public struct StorageConfiguration: Sendable {
    public let endpoint: String
    public let accessKey: String
    public let secretKey: String
    public let region: String
    public let bucket: String
    public let endpointStyle: EndpointStyle

    public init(
        endpoint: String,
        accessKey: String,
        secretKey: String,
        region: String,
        bucket: String,
        endpointStyle: EndpointStyle = .pathStyle
    ) {
        self.endpoint = endpoint
        self.accessKey = accessKey
        self.secretKey = secretKey
        self.region = region
        self.bucket = bucket
        self.endpointStyle = endpointStyle
    }

    /// Builds the full URL for an object key based on the endpoint style.
    /// - pathStyle: `https://s3.us-east-1.amazonaws.com/my-bucket/key`
    /// - virtualHosted: `https://my-bucket.account-id.r2.cloudflarestorage.com/key`
    func objectURL(for key: String) -> String {
        let base: String = endpoint.hasSuffix("/") ? String(endpoint.dropLast()) : endpoint
        switch endpointStyle {
        case .pathStyle:
            return "\(base)/\(bucket)/\(key)"
        case .virtualHosted:
            guard let url = URL(string: base), let scheme = url.scheme, let host = url.host else {
                return "\(base)/\(key)"
            }
            if let port = url.port, port != 80, port != 443 {
                return "\(scheme)://\(bucket).\(host):\(port)/\(key)"
            }
            return "\(scheme)://\(bucket).\(host)/\(key)"
        }
    }
}
