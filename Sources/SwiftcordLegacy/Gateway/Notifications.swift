//
//  File.swift
//  
//
//  Created by JWI on 22/10/2025.
//

import Foundation

public extension NSNotification.Name {
    static let messageCreate = NSNotification.Name("MESSAGE_CREATE")
    static let messageDelete = NSNotification.Name("MESSAGE_DELETE")
    static let messageUpdate = NSNotification.Name("MESSAGE_UPDATE")
    static let ready = NSNotification.Name("READY")
}

public extension Notification.Name {
    static let gatewayDidReconnect = Notification.Name("gatewayDidReconnect")
}
