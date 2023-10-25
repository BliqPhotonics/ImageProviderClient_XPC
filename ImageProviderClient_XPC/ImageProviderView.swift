//
//  ImageProviderView.swift
//  ImageProviderClient_XPC
//
//  Created by Steve Begin on 2023-10-25.
//

import SwiftUI

struct ImageProviderView: View {
    @ObservedObject var imageProvider: ImageProvider
    
    var body: some View {
        VStack {
            Text("Service: \(imageProvider.service.rawValue)")
                .font(.title)
            
            if let message = imageProvider.connectionMessage {
                Text("Message: \(message)")
                    .font(.headline)
            }
            
            
            if imageProvider.connection == nil {
                Color.clear
                    .overlay {
                        VStack {
                            Text("No connection")
                            Button("Connect to service") {
                                imageProvider.connectToService()
                            }
                        }
                    }
            } else {
                
                Spacer()
                
                Group {
                    if let image = imageProvider.image {
                        image
                            .resizable()
                            .scaledToFit()
                    } else {
                        Color.black
                            .overlay {
                                Text("No Image")
                            }
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let message = imageProvider.message {
                        Text(message)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(10)
                            .onAppear(perform: {
                                Task {
                                    try await Task.sleep(for: .seconds(1.5))
                                    imageProvider.message = nil
                                }
                            })
                    }
                    
                    if let error = imageProvider.error {
                        VStack {
                            Text("\(error.localizedDescription)")
                                .foregroundColor(.yellow)
                            Button("Dismiss") {
                                imageProvider.error = nil
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                        
                    }
                }
                
                Spacer()
                
                HStack {
                    Button("Start", action: imageProvider.start)
                    Button("Stop", action: imageProvider.stop)
                }
                
                ImageProviderConfigurationView(
                    configuration: $imageProvider.configuration,
                    action: imageProvider.configure
                )
                
                Button("Invalidate Connection", action: imageProvider.invalidateConnection).padding()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct ImageProviderConfigurationView: View {
    @Binding var configuration: ImageProvider.Configuration
    let action: () -> Void
    
    @State private var topExpanded: Bool = true

    var body: some View {
        DisclosureGroup(
            "Configuration",
            isExpanded: $topExpanded
        ) {
            Form {
                TextField(
                    "Width",
                    value: $configuration.width,
                    format: .number
                )
                TextField(
                    "Height",
                    value: $configuration.height,
                    format: .number
                )
                TextField(
                    "Bits per sample",
                    value: $configuration.bitsPerSample,
                    format: .number
                )
                TextField(
                    "Samples per pixel",
                    value: $configuration.samplesPerPixel,
                    format: .number
                )

            }
            
            Button("Apply Configuration", action: action)
        }
        .frame(maxWidth: 200)

    }
}

#Preview {
    ImageProviderView(imageProvider: .init(service: .universal))
}
