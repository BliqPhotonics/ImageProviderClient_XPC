//
//  ImageProviderManager.swift
//  DebugImageProviderXPC
//
//  Created by Steve Begin on 2023-09-28.
//

import Cocoa
import SwiftUI

class ImageProviderManager: NSObject, ObservableObject {

    static func establishConnectionTo(
        service: XPCService
    ) -> NSXPCConnection {
        // Create an XPC connection to the XPC service
        let connection = NSXPCConnection(serviceName: service.label)

        // Set the XPC interface of the connection's remote object using the XPC service's published protocol
        connection.remoteObjectInterface = NSXPCInterface(
            with: XPCDebugImageProviderServiceProtocol.self
        )

        // Configure the XPC connection's interruption handler
        connection.interruptionHandler = {

            // If the interruption handler has been called, the XPC connection remains valid, and the
            // the XPC service will automatically be re-launched with future calls to the connection object
            NSLog("connection to XPC service has been interrupted")
        }

        // Configure the XPC connection's invalidation handler
//        _connection.invalidationHandler = {
//
//            // If the invalidation handler has been called, the XPC connection is no longer valid and must be recreated
//            NSLog("connection to XPC service has been invalidated")
//            //self._connection = nil
//            self.imageProviders[label]?.connection = nil
//        }

        // New connections must be resumed before use
        connection.resume()

        NSLog("successfully connected to XPC service: \(service.label))")
        
        return connection
    }
    
    @Published var imageProviders: [String: ImageProvider] = [:]
    public func connectToImageProvider(_ service: XPCService) {
        guard imageProviders[service.label] == nil else {
            NSLog("already connected to \(service.label)")
            return
        }
        let imageProvider = ImageProvider(service: service)
        imageProviders[service.label] = imageProvider
    }

    enum XPCService: String, CaseIterable {
        case universal
        case arm64
        case x86
        
        var label: String {
            "com.bliq.DebugImageProviderXPCService-\(self.rawValue)"
        }
    }

}

@objc protocol XPCDebugImageProviderServiceProtocol {
    func start()
    func stop()
    func configure(
        width: Int,
        height: Int,
        bitsPerSample: Int,
        samplesPerPixel: Int,
        with reply: @escaping (String?, Error?) -> Void
    )
}

@objc protocol ClientProtocol {
    func publish(bitmap: NSBitmapImageRep)
}
