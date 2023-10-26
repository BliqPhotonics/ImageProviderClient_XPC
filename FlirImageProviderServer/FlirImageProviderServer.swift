//
//  FlirImageProviderServer.swift
//  FlirImageProviderServer
//
//  Created by Steve Begin on 2023-10-26.
//

import Cocoa
import Combine

/// This object implements the protocol which we have defined. It provides the actual behavior for the service. It is 'exported' by the service to make it available to the process hosting the service over an NSXPCConnection.
class FlirImageProviderServer: NSObject, NSXPCListenerDelegate, ImageProviderXPCServiceProtocol {
    
    var timerSource : DispatchSourceTimer?

    // The XPC Service must maintain an XPC listener to manage incoming XPC connections
    let listener : NSXPCListener

    // Maintain a reference to the XPC connection for communicating with the client application
    var connection : NSXPCConnection?
    
    override init() {
        // Initialize an XPC listener using the XPC service's label
        // Please note that the label must be advertised in the service's launchd.plist
        listener = NSXPCListener(machServiceName: XPCServiceLabels.flir.rawValue)

        super.init()

        // Set the listener's delegate to be ourself
        listener.delegate = self
        
        configureWith(self.configuration)
    }
    
    // Convenience function to resume the listener, and thus start processing incoming connections
    func startListener()
      { listener.resume() }


    // Convenience function to suspend the listener, and thus stop processing inconcoming connections
    func stopListener()
      { listener.suspend() }
    
    var clientApp : ImageProviderXPCClientProtocol
      {
        connection!
              .remoteObjectProxyWithErrorHandler { err in
                  print(err)
              } as! ImageProviderXPCClientProtocol
      }
    
    // MARK: NSXPCListenerDelegate
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Set the exported object of the new connection to be ourself
        newConnection.exportedObject = self

        // Specify the interface the exported object will conform to
        newConnection.exportedInterface = NSXPCInterface(with: ImageProviderXPCServiceProtocol.self)

        // Set the XPC interface of the connection's remote object using the client app's protocol
        newConnection.remoteObjectInterface = NSXPCInterface(with: ImageProviderXPCClientProtocol.self)

        // New connection start in a suspended state and must be resumed
        newConnection.resume()

        // Retain a reference to the new connection for use later
        connection = newConnection

        // Always accept the incoming connection
        return true
    }
    
    //MARK: - XPCDebugImageProviderServiceProtocol
    func start(
//        reply: @escaping (String?, Error?) -> Void
    ) {
        print("XPC service received start command")
        startTimer()
    }

    func stop(
//        reply: @escaping (String?, Error?) -> Void
    ) {
        print("XPC service received stop command")
        cancelTimer()
    }

    func configureWith(
        _ configuration: Configuration
    ) {
        self.configure(
            width: configuration.width,
            height: configuration.height,
            bitsPerSample: configuration.bitsPerSample,
            samplesPerPixel: configuration.samplesPerPixel) { message, error in
                if let message = message {
                    print(message)
                }
                if let error = error {
                    print(error)
                }
            
            }
    }
    
    func configure(
        width: Int,
        height: Int,
        bitsPerSample: Int,
        samplesPerPixel: Int,
        with reply: @escaping (String?, Error?) -> Void
    ) {
        let configuration = Configuration(
            width: width,
            height: height,
            bitsPerSample: bitsPerSample,
            samplesPerPixel: samplesPerPixel
        )
        
        do {
            print("Generating bitmaps")
            let bitmaps = try generate(20, bitmapsWith: configuration)
            self.bitmapStore = bitmaps
            self.configuration = configuration
            reply("Configuration applied: \(self.configuration)", nil)
        } catch {
            reply(nil, error)
        }
    }
    
    var bitmapStore = [NSBitmapImageRep]()
    
    var cancellable: Cancellable?
    func startTimer() {

        // Ensure that the timer source hasn't been created yet
        guard timerSource == nil else { return }

        // Create and retain the timer source
        timerSource = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue.main)

        // Schedule the timer source to fire every 2 seconds
        timerSource!.schedule(deadline: DispatchTime.now(), repeating: .milliseconds(30))

        // Set the event handler of the timer source to message to client app to increment it's count
        timerSource!.setEventHandler(handler: DispatchWorkItem(block: {
            guard let bitmap = self.bitmapStore.randomElement() else { return }
            
            print("publishing image")
            self.clientApp.publish(bitmap: bitmap)
        }))

        // Dispatch sources are created in a suspended state, and must be resumed before they begin processing events
        timerSource!.resume()
    }
    
    func cancelTimer()
      {
        // Ensure the timer source is non-nil
        guard timerSource != nil else { return }

        // Cancel and deallocate the timer source
        timerSource!.cancel()
        timerSource = nil
      }

    var configuration = Configuration()
    
    func generate(
        _ count: Int,
        bitmapsWith configuration: Configuration
    ) throws -> [NSBitmapImageRep] {
        try Array(0..<count).map { _ in
            try randomBitmap(with: configuration)
        }
    }
    
    // Function to generate a bitmap with a random color
    func randomBitmap(with configuration: Configuration) throws -> NSBitmapImageRep {
        let color = generateRandomColor()
        let bitmap = try createBitmap(with: configuration)
        fillBitmapWithColor(bitmap: bitmap, color: color)
        return bitmap
    }
    
    // Function to generate a random color
    func generateRandomColor() -> NSColor {
        let red = CGFloat(arc4random_uniform(256)) / 255.0
        let green = CGFloat(arc4random_uniform(256)) / 255.0
        let blue = CGFloat(arc4random_uniform(256)) / 255.0
        return NSColor(red: red, green: green, blue: blue, alpha: 1.0)
    }
    
    // Function to create a new bitmap
    func createBitmap(
        with configuration: Configuration
    ) throws -> NSBitmapImageRep {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: configuration.width,
            pixelsHigh: configuration.height,
            bitsPerSample: configuration.bitsPerSample,
            samplesPerPixel: configuration.samplesPerPixel,
            hasAlpha: configuration.samplesPerPixel == 4,
            isPlanar: false,
            colorSpaceName: configuration.samplesPerPixel == 1 ? .deviceWhite : .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        else {
            throw ServiceError.cantCreateBitmap(coonfiguration: configuration)
        }
        
        return bitmap
    }
    
    // Function to fill a bitmap with a specific color
    func fillBitmapWithColor(bitmap: NSBitmapImageRep, color: NSColor) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        color.set()
        __NSRectFill(NSRect(x: 0, y: 0, width: bitmap.size.width, height: bitmap.size.height))
        NSGraphicsContext.restoreGraphicsState()
    }
    
    //MARK: - Types
    struct Configuration: CustomStringConvertible {
        var width: Int = 100
        var height: Int = 100
        var bitsPerSample = 8
        var samplesPerPixel = 4
        
        var description: String {
            "width: \(width), height: \(height), bps: \(bitsPerSample), spp: \(samplesPerPixel)"
        }
    
    }
    
    enum ServiceError: LocalizedError {
        case cantCreateBitmap(coonfiguration: Configuration)
        
        var errorDescription: String? {
            switch self {
                case .cantCreateBitmap(let configuration):
                    return "Can't create bitmap with configuration: \(configuration)"
            }
        }
    }
}
