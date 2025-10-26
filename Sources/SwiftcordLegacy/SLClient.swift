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
    
    public func getDMChannels(completion: @escaping ([[String: Any]], Error?) -> ()) {
        self.request(.getDMChannels) { data, error in
            if let data = data {
                let channelArray = data as? [[String: Any]]
                guard let channelArray = channelArray else { return }
                completion(channelArray, nil)
            }
        }
        
    }
    
    public func getDMs(completion: @escaping ([Snowflake: DMChannel], Error?) -> ()) {
        self.getDMChannels() { channelArray, error in
            for channel in channelArray {
                let type = channel["type"] as? Int
                switch type {
                case 1:
                    let dm = DM(self, channel)
                    
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
    
    public func sendMessage(_ content: String, to channel: Snowflake, completion: @escaping (Message, Error?) -> ()) {
        self.request(.sendMessage(channel), body: ["content": content]) { data, error in
            completion(Message(self, data as! [String: Any]), nil)
        }
    }
    
}




