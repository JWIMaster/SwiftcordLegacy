//
//  File.swift
//  
//
//  Created by JWI on 15/10/2025.
//

import Foundation

public protocol DiscordMessage {
    var id: Snowflake? { get }
    var author: User? { get }
    var content: String? { get set }
    var attachments: [Attachment] { get }
    var channelID: Snowflake? { get }
    var timestamp: Date? { get }
    var edited: Bool { get }
    var embeds: [Embed]? { get }
    var mentions: [User] { get set }
}

public struct Message: DiscordMessage {
    public let id: Snowflake?
    public let author: User?
    public var content: String?
    public let attachments: [Attachment]
    public let channelID: Snowflake?
    public let timestamp: Date?
    public let edited: Bool
    public let replyMessage: ReplyMessage?
    public let embeds: [Embed]?
    public var mentions = [User]()
    
    public init(_ slClient: SLClient, _ json: [String: Any]) {
        self.id = Snowflake(json["id"])
        
        if let authorJson = json["author"] as? [String: Any] {
            self.author = User(slClient, authorJson)
        } else {
            self.author = nil
        }
        

        self.channelID = Snowflake(json["channel_id"])
        self.content = json["content"] as? String
        self.timestamp = (json["timestamp"] as? String)?.date
        
        self.edited = !(json["edited_timestamp"] is NSNull)

        if let replyJson = json["referenced_message"] as? [String: Any] {
            self.replyMessage = ReplyMessage(slClient, replyJson)
        } else {
            self.replyMessage = nil
        }
        
        if let attachmentsJson = json["attachments"] as? [[String: Any]] {
            self.attachments = attachmentsJson.map { Attachment($0) }
        } else {
            self.attachments = []
        }
        
        if let embedsJson = json["embeds"] as? [[String: Any]] {
            self.embeds = embedsJson.map( { Embed(slClient, $0) } )
        } else {
            self.embeds = nil
        }
        
        if let mentions = json["mentions"] as? [[String: Any]] {
            for mention in mentions {
                self.mentions.append(User(slClient, mention))
            }
        }
    }
}

public struct ReplyMessage: DiscordMessage {
    public let id: Snowflake?
    public let author: User?
    public var content: String?
    public let attachments: [Attachment]
    public let channelID: Snowflake?
    public let timestamp: Date?
    public let edited: Bool
    public let embeds: [Embed]?
    public var mentions = [User]()
    
    public init(_ slClient: SLClient, _ json: [String: Any]) {
        self.id = Snowflake(json["id"])
        
        if let authorJson = json["author"] as? [String: Any] {
            self.author = User(slClient, authorJson)
        } else {
            self.author = nil
        }
        

        self.channelID = Snowflake(json["channel_id"])
        self.content = json["content"] as? String
        self.timestamp = (json["timestamp"] as? String)?.date
        
        self.edited = !(json["edited_timestamp"] is NSNull)
        
        if let attachmentsJson = json["attachments"] as? [[String: Any]] {
            self.attachments = attachmentsJson.map { Attachment($0) }
        } else {
            self.attachments = []
        }
        
        if let embedsJson = json["embeds"] as? [[String: Any]] {
            self.embeds = embedsJson.map( { Embed(slClient, $0) } )
        } else {
            self.embeds = nil
        }
        
        if let mentions = json["mentions"] as? [[String: Any]] {
            for mention in mentions {
                self.mentions.append(User(slClient, mention))
            }
        }
    }
}

