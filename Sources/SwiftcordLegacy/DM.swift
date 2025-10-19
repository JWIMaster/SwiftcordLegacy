//
//  File.swift
//  
//
//  Created by JWI on 15/10/2025.
//

import Foundation

public struct DM: TextChannel {
    public internal(set) weak var swiftcordLegacy: SwiftcordLegacy?
    
    public let id: Snowflake?
    public let recipient: User?
    public let lastMessageID: Snowflake?
    public let type = ChannelType.dm
    
    
    init(_ swiftcordLegacy: SwiftcordLegacy, _ json: [String: Any]) {
        let recipients = json["recipients"] as! [[String: Any]]
        self.recipient = User(swiftcordLegacy, recipients[0])
        self.id = Snowflake(json["id"] as! String)
        self.lastMessageID = Snowflake(json["last_message_id"] as! String)
    }
}
