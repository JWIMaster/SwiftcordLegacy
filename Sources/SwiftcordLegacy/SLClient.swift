//
//  File.swift
//  
//
//  Created by JWI on 15/10/2025.
//

import Foundation
import FoundationCompatKit

/// Swiftcord Legacy client class
public class SLClient {
    public let token: String
    public let session: URLSessionCompat
    public var gateway: Gateway?
    public var intents: Int?
    public var clientUser: User?
    
    public var dms: [Snowflake: DMChannel] = [:]
    
    public let logger = LegacyLogger(fileName: "rest logs")
    
    
    public init(token: String) {
        self.token = token
        
        self.session = URLSessionCompat(configuration: .default)
        
        self.getClientUser() { user, error in
            
        }
    }
    
    public func connect() {
        self.gateway = Gateway(self, token: self.token, intents: intents!)
        self.gateway?.start()
    }
    
    public func setIntents(intents: Intents...) {
        self.intents = 0
        for intent in intents {
            self.intents! += intent.rawValue
        }
    }
    
    public func getClientUser(completion: @escaping (User, Error?) -> ()) {
        self.request(.getClientUser) { data, error in
            if let data = data {
                let clientUser = data as? [String: Any]
                
                guard let clientUser = clientUser else { return }
                
                self.clientUser = User(self, clientUser)
                completion(self.clientUser ?? User(self, clientUser), nil)
            }
        }
    }
    
    ///Function to get the current users relationships, returns a dictionary that has a UserID lookup and a tuple containing the relationship status and nickname (if applicable)
    public func getRelationships(completion: @escaping ([Snowflake: (Relationship, String?)], Error?) -> ()) {
        self.request(.getRelationships) { data, error in
            guard let relationshipsArray = data as? [[String: Any]] else { return }
            
            //Relationships are a dictionary composed of a userID to lookup, a relationship type, and a nickname if the nickname exists
            var relationships: [Snowflake: (Relationship, String?)] = [:]
            
            for relationship in relationshipsArray {
                if let id = relationship["id"] as? String, let typeInt = relationship["type"] as? Int {
                    let type = Relationship(rawValue: typeInt) ?? .unknown
                    let userID = Snowflake(id)!
                    let nickname = relationship["nickname"] as? String
                    relationships[userID] = (type, nickname)
                }
            }
            
            completion(relationships, nil)
        }
    }
    
    
    ///Function to get the DM Channels, returns an error and an array of channel dictionaries
    public func getDMChannels(completion: @escaping ([[String: Any]], Error?) -> ()) {
        self.request(.getDMChannels) { data, error in
            if let data = data {
                let channelArray = data as? [[String: Any]]
                guard let channelArray = channelArray else { return }
                completion(channelArray, nil)
            }
        }
        
    }
    
    ///Function to get the DM Channels in the format of protocol DMChannel, which is either a GroupDM or a DM struct. Returns a dictionary with ChannelID Snowflake keys and DMChannels.
    public func getDMs(completion: @escaping ([Snowflake: DMChannel], Error?) -> ()) {
        self.getRelationships { relationships, error in
            
            self.getDMChannels() { channelArray, error in
                for channel in channelArray {
                    let type = channel["type"] as? Int
                    switch type {
                    case 1:
                        let dm = DM(self, channel, relationships)
                        
                        guard let dm = dm else { return }
                        
                        self.dms[dm.id!] = dm
                    case 2:
                        break
                    case 3:
                        let groupDM = GroupDM(self, channel)
                        guard let groupDM = groupDM else {
                            return
                        }
                        self.dms[groupDM.id!] = groupDM
                    case 4:
                        break
                    default:
                        break
                    }
                }
                completion(self.dms, nil)
            }
            
        }
    }
    
    ///Function to send a message string to a specified channel
    public func send(message: Message, in channel: TextChannel, completion: @escaping (Error?) -> ()) {
        guard let content = message.content, let channelID = channel.id else { return }
        self.request(.sendMessage(channelID), body: ["content": content]) { data, error in
            completion(nil)
        }
    }
    
    public func reply(to originalMessage: Message, with replyMessage: Message, in channel: TextChannel, completion: @escaping (Error?) -> ()) {
        guard let originalMessageID = originalMessage.id,
              let replyMessageContent = replyMessage.content,
              let channelID = channel.id
        else { return }
        
        let messageToSend: [String : Any] = [
            "content": replyMessageContent,
            "message_reference": [
                "message_id": String(originalMessageID.rawValue)
            ]
        ]
        
        self.request(.sendMessage(channelID), body: messageToSend) { data, error in
            completion(nil)
        }
    }
    
    
    
    
    public func delete(message: Message, in channel: TextChannel, completion: @escaping (Error?) -> ()) {
        guard let messageID = message.id, let channelID = channel.id else { return }
        self.request(.deleteMessage(channel: channelID, message: messageID)) { data, error in
            completion(nil)
        }
    }
    
    public func edit(message: Message, to newMessage: Message, in channel: TextChannel, completion: @escaping (Error?) -> ()) {
        guard let messageID = message.id, let channelID = channel.id, let messageContent = newMessage.content else { return }
        self.request(.editMessage(channel: channelID, message: messageID), body: ["content": messageContent]) { data, error in
            completion(nil)
        }
    }
    
    
    ///Function to get the messages in a given channel. Returns an array of Message structs.
    public func getChannelMessages(for channel: Snowflake, completion: @escaping ([Message], Error?) -> ()) {
        self.request(.getMessages(channel)) { data, error in
            if let data = data {
                var messages: [Message] = []
                
                let messageArray = data as? [[String: Any]]
                
                guard let messageArray = messageArray else { return }
                
                for message in messageArray {
                    messages.append(Message(self, message))
                }
                completion(messages.reversed(), nil)
            }
        }
    }
    
    public func getGuilds(completion: @escaping ([Guild], Error?) -> ()) {
        self.request(.getGuilds) { data, error in
            let guildArray = data as! [[String: Any]]
            var guilds: [Guild] = []
            
            for guild in guildArray {
                guilds.append(Guild(guild)!)
            }
            
            completion(guilds, nil)
        }
    }

    
    
    
}




