import Vapor

public enum StorageError: Error, AbortError {
    case invalidURL
    case uploadFailed
    case downloadFailed
    case deleteFailed
    case presignFailed

    public var status: HTTPResponseStatus {
        switch self {
        case .invalidURL:
            return .badRequest
        case .uploadFailed, .downloadFailed, .deleteFailed, .presignFailed:
            return .internalServerError
        }
    }

    public var reason: String {
        switch self {
        case .invalidURL:
            return "Invalid storage URL"
        case .uploadFailed:
            return "Failed to upload file to storage"
        case .downloadFailed:
            return "Failed to download file from storage"
        case .deleteFailed:
            return "Failed to delete file from storage"
        case .presignFailed:
            return "Failed to generate presigned URL"
        }
    }
}
