import Vapor

public struct StorageUploadRequest: Content, Sendable {
    public let filename: String
    public let contentType: String

    public init(filename: String, contentType: String) {
        self.filename = filename
        self.contentType = contentType
    }
}

public struct StoragePresignedURL: Content, Sendable {
    public let url: String
    public let key: String

    public init(url: String, key: String) {
        self.url = url
        self.key = key
    }
}
