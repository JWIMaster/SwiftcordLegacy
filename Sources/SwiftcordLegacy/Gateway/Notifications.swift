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
    static let guildMemberChunk = NSNotification.Name("GUILD_MEMBER_CHUNK")
    static let typingStart = NSNotification.Name("TYPING_START")
    static let readyProcessed = NSNotification.Name("READY_PROCESSED")
    static let messageReactionAdd = NSNotification.Name("MESSAGE_REACTION_ADD")
    static let messageReactionRemove = NSNotification.Name("MESSAGE_REACTION_REMOVE")
    static let presenceUpdate = NSNotification.Name("PRESENCE_UPDATE")
}

public extension Notification.Name {
    static let gatewayDidReconnect = Notification.Name("gatewayDidReconnect")
}
