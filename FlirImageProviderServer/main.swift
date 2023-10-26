//
//  main.swift
//  FlirImageProviderServer
//
//  Created by Steve Begin on 2023-10-26.
//

import Foundation

let xpcService = FlirImageProviderServer()
xpcService.startListener()

// Run the XPC service on the main queue
dispatchMain()
