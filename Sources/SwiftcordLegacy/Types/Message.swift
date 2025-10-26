//
//  File.swift
//  
//
//  Created by JWI on 15/10/2025.
//

import Foundation


public struct Message {
    
    public let id: Snowflake?
    public let author: User?
    public var content: String?
    public let date: Date?
    public let attachments: [Attachment]
    public let channelID: Snowflake?
    
    
    public init(_ slClient: SLClient, _ json: [String: Any]) {
        self.id = Snowflake(json["id"])
        
        if let authorJson = json["author"] as? [String: Any] {
            self.author = User(slClient, authorJson)
        } else {
            self.author = nil
        }
        
        self.channelID = Snowflake(json["channel_id"])
        self.content = json["content"] as? String
        self.date = json["date"] as? Date
        
        if let attachmentsJson = json["attachments"] as? [[String: Any]] {
            self.attachments = attachmentsJson.map { Attachment($0) }
        } else {
            self.attachments = []
        }
    }
}
