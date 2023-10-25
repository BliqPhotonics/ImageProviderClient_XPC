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

        // New connections must be resumed before use
        connection.resume()

        NSLog("successfully connected to XPC service: \(service.label)")
        
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
