# StorageKit

A Swift package providing a type-safe abstraction layer for S3-compatible cloud storage services. Built for [Vapor](https://vapor.codes).

## Features

- Upload, download, and delete files
- Generate presigned URLs for direct frontend uploads/downloads (AWS Signature V4)
- Works with AWS S3, MinIO, or any S3-compatible endpoint
- Integrates with Vapor's application and request lifecycle
- Full Swift 6 concurrency support (`Sendable`)

## Requirements

- Swift 6.1+
- macOS 15.0+

## Installation

Add StorageKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/cavnit/storage-kit.git", from: "1.0.0"),
],
targets: [
    .target(
        name: "App",
        dependencies: [
            .product(name: "StorageKit", package: "storage-kit"),
        ]
    ),
]
```

## Usage

### Configuration

```swift
app.storageKit.configuration = StorageConfiguration(
    endpoint: "https://s3.us-east-1.amazonaws.com",
    accessKey: "your-access-key",
    secretKey: "your-secret-key",
    region: "us-east-1",
    bucket: "my-bucket"
)
```

### Upload

```swift
try await req.storageKit.client.upload(
    key: "documents/file.pdf",
    data: fileBuffer,
    contentType: "application/pdf"
)
```

### Download

```swift
let data = try await req.storageKit.client.download(key: "documents/file.pdf")
```

### Delete

```swift
try await req.storageKit.client.delete(key: "documents/file.pdf")
```

### Presigned URLs

Generate a presigned upload URL for direct browser uploads:

```swift
let url = try req.storageKit.client.presignedUploadURL(
    key: "documents/new-file.pdf",
    contentType: "application/pdf",
    expires: 900 // 15 minutes
)
```

Generate a presigned download URL:

```swift
let url = try req.storageKit.client.presignedDownloadURL(
    key: "documents/file.pdf",
    filename: "my-file.pdf",
    expires: 900
)
```

## License

Apache License 2.0
