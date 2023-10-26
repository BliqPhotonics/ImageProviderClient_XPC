//
//  XPCProtocols.swift
//  ImageProviderClient_XPC
//
//  Created by Steve Begin on 2023-10-26.
//

import Cocoa

@objc protocol ImageProviderXPCServiceProtocol {
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

@objc protocol ImageProviderXPCClientProtocol {
    func publish(bitmap: NSBitmapImageRep)
}

enum XPCServiceLabels: String {
    case flir = "com.bliq.FlirImageProviderServer"
}
