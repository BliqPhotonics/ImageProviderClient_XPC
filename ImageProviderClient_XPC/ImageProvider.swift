//
//  ImageProvider.swift
//  ImageProviderClient_XPC
//
//  Created by Steve Begin on 2023-10-25.
//

import Foundation
import SwiftUI

protocol XPCConnected {
    var connection: NSXPCConnection? { get set }
}

class ImageProvider: ObservableObject, ClientProtocol, XPCConnected {

    init(
        service: ImageProviderManager.XPCService
    ) {
        self.service = service
        connectToService()
    }
    
    func connectToService() {
        connection = ImageProviderManager.establishConnectionTo(service: service)
        connection?.exportedObject = self
        connection?.exportedInterface = NSXPCInterface(with: ClientProtocol.self)
        connection?.invalidationHandler = {
            
            Task { [service = self.service] in
                await MainActor.run {
                    self.connectionMessage = "Connection to XPC service \(service.rawValue) has been invalidated"
                    self.connection = nil
                }
            }
        }
        
        connection?.interruptionHandler = {
            Task { [service = self.service] in
                await MainActor.run {
                    self.connectionMessage = "Connection to XPC service \(service.rawValue) has been interrupted"

                    self.connection = nil
                }
            }
        }
        
        self.connectionMessage = "Successfully connected to XPC service: \(service.label)"
        
        xpcService = connection?
            .remoteObjectProxyWithErrorHandler { error in
                NSLog("\(error)")
                self.error = error
            } as? XPCDebugImageProviderServiceProtocol
    }
    let service: ImageProviderManager.XPCService
    @Published var connection: NSXPCConnection?
    var xpcService: XPCDebugImageProviderServiceProtocol?

    @Published var configuration = ImageProvider.Configuration()
    @Published var image: Image?
    @Published var connectionMessage: String? {
        didSet { NSLog(connectionMessage ?? "") }
    }
    @Published var message: String?
    @Published var error: Swift.Error?
    
    func start() {
        xpcService?.start()
    }
    
    func stop() {
        xpcService?.stop()
    }
    
    func configure() {
        xpcService?.configure(
            width: configuration.width,
            height: configuration.height,
            bitsPerSample: configuration.bitsPerSample,
            samplesPerPixel: configuration.samplesPerPixel
        ) { message, error in
            Task { [message, error, configuration = self.configuration] in
                await MainActor.run { [message, error, configuration] in
                    if let message = message {
                        self.message = message
                        self.error = nil
                    }
                    if let error = error {
                        print(error)
                        self.message = nil
                        self.error = Error.invalidConfiguration(configuration, error)
                    }
                }
            }
            
        }
    }

    func invalidateConnection() {
        // Invalidate the connection
        connection?.invalidate()
        connection = nil
    }

    // MARK: ClientProtocol
    func publish(bitmap: NSBitmapImageRep) {
        let image = convertToImage(bitmap: bitmap)
        Task { [image] in
            await set(image: image)
        }
    }

    @MainActor
    func set(image: Image) {
        self.image = image
    }

    func convertToImage(bitmap: NSBitmapImageRep) -> Image {
        let nsImage = NSImage(size: bitmap.size)
        nsImage.addRepresentation(bitmap)

        let image = Image(nsImage: nsImage)
        return image
    }
}

extension ImageProvider {    
    struct Configuration: CustomStringConvertible {
        var width: Int = 100
        var height: Int = 100
        var bitsPerSample = 8
        var samplesPerPixel = 4
        
        var description: String {
            "w\(width) X h\(height), bps: \(bitsPerSample), spp: \(samplesPerPixel)"
        }
    }

    enum Error: LocalizedError {
        case invalidConfiguration(Configuration, Swift.Error)
        
        var errorDescription: String? {
            switch self {
            case let .invalidConfiguration(configuration, error):
                return "Invalid configuration: \(configuration) - Error: \(error)"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .invalidConfiguration:
                return "Please check the configuration parameters"
            }
        }
    }
}
