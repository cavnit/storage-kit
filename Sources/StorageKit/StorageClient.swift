import Vapor

public struct StorageClient: Sendable {
    let client: any Client
    let logger: Logger
    let configuration: StorageConfiguration

    /// Upload data to S3 with a PUT request.
    public func upload(key: String, data: ByteBuffer, contentType: String) async throws {
        guard let url = URL(string: configuration.objectURL(for: key)) else {
            throw StorageError.invalidURL
        }

        let signer: AWSSigner = makeSigner()
        let signedURL: URL = signer.signURL(
            url: url,
            method: .PUT,
            expires: 300
        )

        let response: ClientResponse = try await client.put(URI(string: signedURL.absoluteString)) { req in
            req.headers.contentType = HTTPMediaType.fileExtension(contentType) ?? .binary
            req.body = data
        }

        guard response.status == .ok || response.status == .created else {
            throw StorageError.uploadFailed
        }
    }

    /// Download a file from S3, returning the raw bytes.
    public func download(key: String) async throws -> ByteBuffer {
        guard let url = URL(string: configuration.objectURL(for: key)) else {
            throw StorageError.invalidURL
        }

        let signer: AWSSigner = makeSigner()
        let signedURL: URL = signer.signURL(
            url: url,
            method: .GET,
            expires: 300
        )

        let response: ClientResponse = try await client.get(URI(string: signedURL.absoluteString))

        guard let body: ByteBuffer = response.body else {
            throw StorageError.downloadFailed
        }

        return body
    }

    /// Delete a file from S3.
    public func delete(key: String) async throws {
        guard let url = URL(string: configuration.objectURL(for: key)) else {
            throw StorageError.invalidURL
        }

        let signer: AWSSigner = makeSigner()
        let signedURL: URL = signer.signURL(
            url: url,
            method: .DELETE,
            expires: 300
        )

        do {
            _ = try await client.delete(URI(string: signedURL.absoluteString))
        } catch {
            throw StorageError.deleteFailed
        }
    }

    /// Generate a presigned PUT URL for frontend direct upload.
    public func presignedUploadURL(key: String, contentType: String, expires: Int = 900) throws -> String {
        guard let url = URL(string: configuration.objectURL(for: key)) else {
            throw StorageError.invalidURL
        }

        let signer: AWSSigner = makeSigner()
        let signedURL: URL = signer.signURL(
            url: url,
            method: .PUT,
            expires: expires
        )

        return signedURL.absoluteString
    }

    /// Generate a presigned GET URL with content-disposition for download.
    public func presignedDownloadURL(key: String, filename: String, expires: Int = 900) throws -> String {
        let disposition: String = "attachment;filename=\(filename)"
        let encodedDisposition: String = disposition.uriEncode()
        let urlString: String = "\(configuration.objectURL(for: key))?response-content-disposition=\(encodedDisposition)"

        guard let url = URL(string: urlString) else {
            throw StorageError.invalidURL
        }

        let signer: AWSSigner = makeSigner()
        let signedURL: URL = signer.signURL(
            url: url,
            method: .GET,
            expires: expires
        )

        return signedURL.absoluteString
    }

    // MARK: - Private

    private func makeSigner() -> AWSSigner {
        let credentials: StaticCredential = StaticCredential(
            accessKeyId: configuration.accessKey,
            secretAccessKey: configuration.secretKey
        )
        return AWSSigner(credentials: credentials, name: "s3", region: configuration.region)
    }
}
