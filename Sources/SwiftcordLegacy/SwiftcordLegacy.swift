//
//  File.swift
//  
//
//  Created by JWI on 15/10/2025.
//

import Foundation
import FoundationCompatKit

public class SwiftcordLegacy {
    internal let token: String
    internal let session: URLSessionCompat
    
    public var clientUser: User?
    
    public var dms: [Snowflake: DM] = [:]
    
    public init(token: String) {
        self.token = token
        
        self.session = URLSessionCompat(configuration: .default)
        
        self.getClientUser() { user, error in
            
        }
    }
    
    
    public func getClientUser(completion: @escaping (User, Error?) -> ()) {
        self.request(.getClientUser) { data, error in
            if let data = data {
                let clientUser = data as! [String: Any]
                print(clientUser)
                self.clientUser = User(self, clientUser)
                completion(self.clientUser!, nil)
            }
        }
    }
    
    public func getDMChannels(completion: @escaping ([[String: Any]], Error?) -> ()) {
        self.request(.getDMChannels) { data, error in
            if let data = data {
                let channelArray = data as! [[String: Any]]
                
                completion(channelArray, nil)
            }
        }
        
    }
    
    public func getDMs(completion: @escaping ([Snowflake: DM], Error?) -> ()) {
        self.getDMChannels() { channelArray, error in
            
            
            for channel in channelArray {
                if let type = channel["type"] as? Int, type == 1 {
                    let dm = DM(self, channel)
                    self.dms[dm.id!] = dm
                }
            }
            
            completion(self.dms, nil)
        }
        
    }
    
    
    public func getChannelMessages(for channel: Snowflake, completion: @escaping ([Message], Error?) -> ()) {
        self.request(.getMessages(channel)) { data, error in
            if let data = data {
                var messages: [Message] = []
                
                let messageArray = data as! [[String: Any]]
                
                for message in messageArray {
                    messages.append(Message(self, message))
                }
                
                //MARK: do this so that it returns the newest ones at the bottom, as that's how messages are presented
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




