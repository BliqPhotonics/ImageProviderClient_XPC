//
//  ContentView.swift
//  ImageProviderClient_XPC
//
//  Created by Steve Begin on 2023-10-25.
//

import SwiftUI

struct ContentView: View {

    @EnvironmentObject var imageProviderManager: ImageProviderManager

    var body: some View {
        VStack {
            
            HStack {
                ForEach(imageProviderManager.imageProviders.map(\.key), id: \.self) { key in
                    ImageProviderView(imageProvider: imageProviderManager.imageProviders[key]!)
                    
                }
            }
            
            Spacer()
            ForEach(ImageProviderManager.XPCService.allCases, id: \.rawValue) { service in
                Button(service.label) {
                    imageProviderManager.connectToImageProvider(service)
                }
            }
        }
    }

}

struct ContentView_Previews: PreviewProvider {
    static let imageProviderManager: ImageProviderManager = {
        let imageProviderManager = ImageProviderManager()

        return imageProviderManager
    }()

    static var previews: some View {
        ContentView()
            .environmentObject(imageProviderManager)

    }
}
