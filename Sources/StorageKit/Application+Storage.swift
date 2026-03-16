import Vapor

extension Application {
    public struct Storage {
        let application: Application

        struct ConfigurationKey: StorageKey {
            typealias Value = StorageConfiguration
        }

        public var configuration: StorageConfiguration {
            get {
                guard let config: StorageConfiguration = self.application.storage[ConfigurationKey.self] else {
                    fatalError("StorageKit not configured. Use app.storage.configuration = ...")
                }
                return config
            }
            nonmutating set {
                self.application.storage[ConfigurationKey.self] = newValue
            }
        }

        public var client: StorageClient {
            .init(
                client: application.client,
                logger: application.logger,
                configuration: configuration
            )
        }
    }

    public var storageKit: Storage {
        .init(application: self)
    }
}

extension Request {
    public struct Storage {
        let request: Request

        public var client: StorageClient {
            let config: StorageConfiguration = request.application.storageKit.configuration
            return .init(
                client: request.client,
                logger: request.logger,
                configuration: config
            )
        }
    }

    public var storageKit: Storage {
        .init(request: self)
    }
}
