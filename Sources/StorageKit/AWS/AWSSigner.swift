// Originally created by Adam Fowler on 2019/08/29.
// Derived from the soto-project (https://github.com/soto-project)
// Licensed under Apache License 2.0
//
// Modified: Added Sendable conformances for Swift 6 concurrency.

import Crypto
import NIO
import NIOHTTP1

import struct Foundation.CharacterSet
import struct Foundation.Data
import struct Foundation.Date
import class Foundation.DateFormatter
import struct Foundation.Locale
import struct Foundation.TimeZone
import struct Foundation.URL

/// Amazon Web Services V4 Signer
public struct AWSSigner: Sendable {
    /// Security credentials for accessing AWS services
    public let credentials: any Credential
    /// Service signing name. In general this is the same as the service name.
    public let name: String
    /// AWS region you are working in
    public let region: String

    static let hashedEmptyBody: String = SHA256.hash(data: [UInt8]()).hexDigest()

    static private let timeStampDateFormatter: DateFormatter = createTimeStampDateFormatter()

    /// Initialise the Signer class with AWS credentials.
    public init(credentials: any Credential, name: String, region: String) {
        self.credentials = credentials
        self.name = name
        self.region = region
    }

    /// Enum for holding your body data
    public enum BodyData: Sendable {
        case string(String)
        case data(Data)
        case byteBuffer(ByteBuffer)
    }

    /// Generate signed headers for a HTTP request.
    public func signHeaders(
        url: URL,
        method: HTTPMethod = .GET,
        headers: HTTPHeaders = HTTPHeaders(),
        body: BodyData? = nil,
        date: Date = Date()
    ) -> HTTPHeaders {
        let bodyHash: String = AWSSigner.hashedPayload(body)
        let dateString: String = AWSSigner.timestamp(date)
        var headers: HTTPHeaders = headers
        headers.add(name: "X-Amz-Date", value: dateString)
        headers.add(name: "host", value: Self.hostValue(from: url))
        headers.add(name: "x-amz-content-sha256", value: bodyHash)
        if let sessionToken: String = credentials.sessionToken {
            headers.add(name: "x-amz-security-token", value: sessionToken)
        }

        let signingData: SigningData = SigningData(
            url: url,
            method: method,
            headers: headers,
            body: body,
            bodyHash: bodyHash,
            date: dateString,
            signer: self
        )

        let authorization: String =
            "AWS4-HMAC-SHA256 "
            + "Credential=\(credentials.accessKeyId)/\(signingData.date)/\(region)/\(name)/aws4_request, "
            + "SignedHeaders=\(signingData.signedHeaders), "
            + "Signature=\(signature(signingData: signingData))"

        headers.add(name: "Authorization", value: authorization)

        return headers
    }

    /// Generate a signed URL for a HTTP request.
    public func signURL(
        url: URL,
        method: HTTPMethod = .GET,
        body: BodyData? = nil,
        date: Date = Date(),
        expires: Int = 86400,
        additionalQueryParams: [String: String] = [:]
    ) -> URL {
        let headers: HTTPHeaders = HTTPHeaders([("host", Self.hostValue(from: url))])
        var signingData: SigningData = SigningData(
            url: url,
            method: method,
            headers: headers,
            body: body,
            date: AWSSigner.timestamp(date),
            signer: self
        )

        var query: String = url.query ?? ""
        if query.count > 0 {
            query += "&"
        }
        query += "X-Amz-Algorithm=AWS4-HMAC-SHA256"
        query += "&X-Amz-Credential=\(credentials.accessKeyId)/\(signingData.date)/\(region)/\(name)/aws4_request"
        query += "&X-Amz-Date=\(signingData.datetime)"
        query += "&X-Amz-Expires=\(expires)"
        query += "&X-Amz-SignedHeaders=\(signingData.signedHeaders)"
        if let sessionToken: String = credentials.sessionToken {
            query += "&X-Amz-Security-Token=\(sessionToken.uriEncode())"
        }
        for (key, value) in additionalQueryParams {
            query += "&\(key.uriEncode())=\(value.uriEncode())"
        }

        query = query.split(separator: "&")
            .sorted()
            .joined(separator: "&")
            .queryEncode()

        signingData.unsignedURL = URL(
            string: url.absoluteString.split(separator: "?")[0] + "?" + query
        )!
        query += "&X-Amz-Signature=\(signature(signingData: signingData))"

        let signedURL: URL = URL(
            string: url.absoluteString.split(separator: "?")[0] + "?" + query
        )!

        return signedURL
    }

    // MARK: - Internal

    /// Structure used to store data used throughout the signing process.
    struct SigningData {
        let url: URL
        let method: HTTPMethod
        let hashedPayload: String
        let datetime: String
        let headersToSign: [String: String]
        let signedHeaders: String
        var unsignedURL: URL

        var date: String { return String(datetime.prefix(8)) }

        init(
            url: URL,
            method: HTTPMethod = .GET,
            headers: HTTPHeaders = HTTPHeaders(),
            body: BodyData? = nil,
            bodyHash: String? = nil,
            date: String,
            signer: AWSSigner
        ) {
            if url.path == "" {
                self.url = url.appendingPathComponent("/")
            } else {
                self.url = url
            }
            self.method = method
            self.datetime = date
            self.unsignedURL = self.url

            if let hash: String = bodyHash {
                self.hashedPayload = hash
            } else if signer.name == "s3" {
                self.hashedPayload = "UNSIGNED-PAYLOAD"
            } else {
                self.hashedPayload = AWSSigner.hashedPayload(body)
            }

            let headersNotToSign: Set<String> = ["Authorization"]
            var headersToSign: [String: String] = [:]
            var signedHeadersArray: [String] = []
            for header in headers {
                if headersNotToSign.contains(header.name) {
                    continue
                }
                headersToSign[header.name] = header.value
                signedHeadersArray.append(header.name.lowercased())
            }
            self.headersToSign = headersToSign
            self.signedHeaders = signedHeadersArray.sorted().joined(separator: ";")
        }
    }

    /// Stage 3: Calculate signature.
    func signature(signingData: SigningData) -> String {
        let kDate = HMAC<SHA256>.authenticationCode(
            for: Data(signingData.date.utf8),
            using: SymmetricKey(data: Array("AWS4\(credentials.secretAccessKey)".utf8))
        )
        let kRegion = HMAC<SHA256>.authenticationCode(
            for: Data(region.utf8),
            using: SymmetricKey(data: kDate)
        )
        let kService = HMAC<SHA256>.authenticationCode(
            for: Data(name.utf8),
            using: SymmetricKey(data: kRegion)
        )
        let kSigning = HMAC<SHA256>.authenticationCode(
            for: Data("aws4_request".utf8),
            using: SymmetricKey(data: kService)
        )
        let kSignature = HMAC<SHA256>.authenticationCode(
            for: stringToSign(signingData: signingData),
            using: SymmetricKey(data: kSigning)
        )
        return kSignature.hexDigest()
    }

    /// Stage 2: Create the string to sign.
    func stringToSign(signingData: SigningData) -> Data {
        let stringToSign: String =
            "AWS4-HMAC-SHA256\n"
            + "\(signingData.datetime)\n"
            + "\(signingData.date)/\(region)/\(name)/aws4_request\n"
            + SHA256.hash(data: canonicalRequest(signingData: signingData)).hexDigest()
        return Data(stringToSign.utf8)
    }

    /// Stage 1: Create the canonical request.
    func canonicalRequest(signingData: SigningData) -> Data {
        let canonicalHeaders: String = signingData.headersToSign.map {
            return "\($0.key.lowercased()):\($0.value.trimmingCharacters(in: CharacterSet.whitespaces))"
        }
        .sorted()
        .joined(separator: "\n")

        let canonicalRequest: String =
            "\(signingData.method.rawValue)\n"
            + "\(signingData.unsignedURL.path.uriEncodeWithSlash())\n"
            + "\(signingData.unsignedURL.query ?? "")\n"
            + "\(canonicalHeaders)\n\n"
            + "\(signingData.signedHeaders)\n"
            + signingData.hashedPayload
        return Data(canonicalRequest.utf8)
    }

    /// Create a SHA256 hash of the request body.
    static func hashedPayload(_ payload: BodyData?) -> String {
        guard let payload: BodyData = payload else { return hashedEmptyBody }
        let hash: String?
        switch payload {
        case .string(let string):
            hash = SHA256.hash(data: Data(string.utf8)).hexDigest()
        case .data(let data):
            hash = SHA256.hash(data: data).hexDigest()
        case .byteBuffer(let byteBuffer):
            let byteBufferView = byteBuffer.readableBytesView
            hash = byteBufferView.withContiguousStorageIfAvailable { bytes in
                return SHA256.hash(data: bytes).hexDigest()
            }
        }
        if let hash: String = hash {
            return hash
        } else {
            return hashedEmptyBody
        }
    }

    /// Return a hex-encoded string buffer from an array of bytes.
    static func hexEncoded(_ buffer: [UInt8]) -> String {
        return buffer.map { String(format: "%02x", $0) }.joined(separator: "")
    }

    /// Return the host value for signing, including the port for non-standard ports.
    static func hostValue(from url: URL) -> String {
        if let port = url.port, port != 80, port != 443 {
            return "\(url.host ?? ""):\(port)"
        }
        return url.host ?? ""
    }

    /// Create timestamp DateFormatter.
    static private func createTimeStampDateFormatter() -> DateFormatter {
        let formatter: DateFormatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }

    /// Return a timestamp formatted for signing requests.
    static func timestamp(_ date: Date) -> String {
        return timeStampDateFormatter.string(from: date)
    }
}

// MARK: - String Extensions

extension String {
    func queryEncode() -> String {
        return addingPercentEncoding(withAllowedCharacters: String.queryAllowedCharacters) ?? self
    }

    func uriEncode() -> String {
        return addingPercentEncoding(withAllowedCharacters: String.uriAllowedCharacters) ?? self
    }

    func uriEncodeWithSlash() -> String {
        return addingPercentEncoding(withAllowedCharacters: String.uriAllowedWithSlashCharacters) ?? self
    }

    static let uriAllowedWithSlashCharacters: CharacterSet = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~/"
    )
    static let uriAllowedCharacters: CharacterSet = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )
    static let queryAllowedCharacters: CharacterSet = CharacterSet(charactersIn: "/;+").inverted
}

// MARK: - Hex Digest

extension Sequence where Element == UInt8 {
    /// Return a hex-encoded string buffer from a sequence of bytes.
    public func hexDigest() -> String {
        return self.map { String(format: "%02x", $0) }.joined(separator: "")
    }
}
