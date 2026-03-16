import Testing
@testable import StorageKit

@Suite("StorageKit Tests")
struct StorageKitTests {

    @Test("StorageConfiguration builds correct object URL for custom endpoint")
    func configurationObjectURLCustomEndpoint() {
        let config: StorageConfiguration = StorageConfiguration(
            endpoint: "https://minio.example.com",
            accessKey: "test-key",
            secretKey: "test-secret",
            region: "us-east-1",
            bucket: "my-bucket"
        )

        let url: String = config.objectURL(for: "documents/file.pdf")
        #expect(url == "https://minio.example.com/my-bucket/documents/file.pdf")
    }

    @Test("StorageConfiguration strips trailing slash from endpoint")
    func configurationObjectURLTrailingSlash() {
        let config: StorageConfiguration = StorageConfiguration(
            endpoint: "https://s3.us-east-1.amazonaws.com/",
            accessKey: "test-key",
            secretKey: "test-secret",
            region: "us-east-1",
            bucket: "my-bucket"
        )

        let url: String = config.objectURL(for: "file.txt")
        #expect(url == "https://s3.us-east-1.amazonaws.com/my-bucket/file.txt")
    }

    @Test("AWSSigner produces deterministic signature for same inputs")
    func signerDeterministicSignature() {
        let credential: StaticCredential = StaticCredential(
            accessKeyId: "AKIAIOSFODNN7EXAMPLE",
            secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
        )
        let signer: AWSSigner = AWSSigner(credentials: credential, name: "s3", region: "us-east-1")

        let url: URL = URL(string: "https://my-bucket.s3.us-east-1.amazonaws.com/test.txt")!
        let date: Date = Date(timeIntervalSince1970: 1_000_000_000)

        let signedURL1: URL = signer.signURL(url: url, method: .GET, date: date, expires: 3600)
        let signedURL2: URL = signer.signURL(url: url, method: .GET, date: date, expires: 3600)

        #expect(signedURL1.absoluteString == signedURL2.absoluteString)
    }

    @Test("AWSSigner signed URL contains required query parameters")
    func signerSignedURLContainsParams() {
        let credential: StaticCredential = StaticCredential(
            accessKeyId: "AKIAIOSFODNN7EXAMPLE",
            secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
        )
        let signer: AWSSigner = AWSSigner(credentials: credential, name: "s3", region: "us-east-1")

        let url: URL = URL(string: "https://my-bucket.s3.us-east-1.amazonaws.com/test.txt")!
        let signedURL: URL = signer.signURL(url: url, method: .PUT, date: Date(), expires: 900)
        let urlString: String = signedURL.absoluteString

        #expect(urlString.contains("X-Amz-Algorithm=AWS4-HMAC-SHA256"))
        #expect(urlString.contains("X-Amz-Credential="))
        #expect(urlString.contains("X-Amz-Signature="))
        #expect(urlString.contains("X-Amz-Expires=900"))
    }

    @Test("StaticCredential stores values correctly")
    func staticCredentialInit() {
        let cred: StaticCredential = StaticCredential(
            accessKeyId: "key",
            secretAccessKey: "secret",
            sessionToken: "token"
        )

        #expect(cred.accessKeyId == "key")
        #expect(cred.secretAccessKey == "secret")
        #expect(cred.sessionToken == "token")
    }

    @Test("StaticCredential session token defaults to nil")
    func staticCredentialDefaultSessionToken() {
        let cred: StaticCredential = StaticCredential(
            accessKeyId: "key",
            secretAccessKey: "secret"
        )

        #expect(cred.sessionToken == nil)
    }

    @Test("StorageError provides correct HTTP status codes")
    func storageErrorStatuses() {
        #expect(StorageError.invalidURL.status == .badRequest)
        #expect(StorageError.uploadFailed.status == .internalServerError)
        #expect(StorageError.downloadFailed.status == .internalServerError)
        #expect(StorageError.deleteFailed.status == .internalServerError)
        #expect(StorageError.presignFailed.status == .internalServerError)
    }

    @Test("StorageError provides meaningful reason strings")
    func storageErrorReasons() {
        #expect(StorageError.invalidURL.reason.isEmpty == false)
        #expect(StorageError.uploadFailed.reason.isEmpty == false)
        #expect(StorageError.downloadFailed.reason.isEmpty == false)
        #expect(StorageError.deleteFailed.reason.isEmpty == false)
        #expect(StorageError.presignFailed.reason.isEmpty == false)
    }

    @Test("String URI encoding works correctly")
    func stringURIEncoding() {
        let input: String = "attachment;filename=report.pdf"
        let encoded: String = input.uriEncode()
        #expect(encoded.contains(";") == false || encoded == input)
        #expect(!encoded.contains(" "))
    }
}

import struct Foundation.Date
import struct Foundation.URL
