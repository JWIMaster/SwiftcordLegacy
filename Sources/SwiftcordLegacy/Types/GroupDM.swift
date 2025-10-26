//
//  File.swift
//
//
//  Created by JWI on 15/10/2025.
//

import Foundation

public struct GroupDM: DMChannel {
    public internal(set) weak var slClient: SLClient?
    
    public let id: Snowflake?
    public var recipients: [User]?
    public let lastMessageID: Snowflake?
    public let type = ChannelType.groupDM
    public let name: String?
    
    
    init?(_ slClient: SLClient, _ json: [String: Any]) {
        self.slClient = slClient
        if let recipients = json["recipients"] as? [[String: Any]] {
            var users: [User] = []
            
            for recipient in recipients {
                users.append(User(slClient, recipient))
            }
            self.recipients = users
        } else {
            self.recipients = nil
        }

        
        self.id = Snowflake(json["id"] as? String)
        
        self.name = json["name"] as? String
        
        self.lastMessageID = Snowflake(json["last_message_id"] as? String)
    }
}
