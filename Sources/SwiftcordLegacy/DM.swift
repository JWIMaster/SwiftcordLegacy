//
//  File.swift
//  
//
//  Created by JWI on 15/10/2025.
//

import Foundation

public struct DM {
    public let id: Snowflake?
    public let recipient: User?
    public let lastMessageID: Snowflake?
    
    
    init(_ swiftcordLegacy: SwiftcordLegacy, _ json: [String: Any]) {
        let recipients = json["recipients"] as! [[String: Any]]
        self.recipient = User(recipients[0])
        self.id = Snowflake(json["id"] as! String)
        self.lastMessageID = Snowflake(json["last_message_id"] as! String)

    }
}
