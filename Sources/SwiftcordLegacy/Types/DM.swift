//
//  File.swift
//  
//
//  Created by JWI on 15/10/2025.
//

import Foundation



public struct DM: DMChannel {
    public internal(set) weak var slClient: SLClient?
    
    public let id: Snowflake?
    public let recipient: User?
    public let lastMessageID: Snowflake?
    public let type = ChannelType.dm
    
    
    init?(_ slClient: SLClient, _ json: [String: Any]) {
        self.slClient = slClient
        let recipients = json["recipients"] as? [[String: Any]]
        
        if let recipients = recipients {
            self.recipient = User(slClient, recipients[0])
        } else {
            self.recipient = nil
        }
        
        self.id = Snowflake(json["id"] as? String)
        
        self.lastMessageID = Snowflake(json["last_message_id"] as? String)
    }
}
