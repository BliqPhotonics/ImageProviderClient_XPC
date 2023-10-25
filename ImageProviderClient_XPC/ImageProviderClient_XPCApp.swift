//
//  ImageProviderClient_XPCApp.swift
//  ImageProviderClient_XPC
//
//  Created by Steve Begin on 2023-10-25.
//

import SwiftUI

@main
struct ImageProviderClient_XPCApp: App {
    var connectionManager = ImageProviderManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectionManager)
        }
    }
}
