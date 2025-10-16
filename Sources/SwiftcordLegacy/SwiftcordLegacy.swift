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
    
    public var dms: [Snowflake: DM] = [:]
    
    public init(token: String) {
        self.token = token
        
        self.session = URLSessionCompat(configuration: .default)
    }
    
    
    
    
    public func getDMChannels(completion: @escaping ([[String: Any]], Error?) -> ()) {
        self.request(.getDMChannels) { data, error in
            if let data = data {
                let channelArray = data as! [[String: Any]]
                
                completion(channelArray, nil)
            }
        }
        
    }
    
    
    public func getDMs(completion: @escaping ([DM], Error?) -> ()) {
        self.getDMChannels() { channelArray, error in
            
            //MARK: so it's sorted when viewing
            var sortedDMs: [DM] = []
            
            for channel in channelArray {
                if let type = channel["type"] as? Int, type == 1 {
                    let dm = DM(self, channel)
                    self.dms[dm.id!] = dm
                }
            }
            
            for (_,dm) in self.dms {
                sortedDMs.append(dm)
            }
            
            //MARK: need to understand, but it makes the dms in the right order!
            sortedDMs.sort(by: {
                let id1 = $0.lastMessageID?.rawValue ?? 0
                let id2 = $1.lastMessageID?.rawValue ?? 0
                return id1 > id2
            })
            
            
            completion(sortedDMs, nil)
        }
        
    }
    
    public func getChannelMessages(for channel: Snowflake, completion: @escaping ([Message], Error?) -> ()) {
        self.request(.getMessages(channel)) { data, error in
            if let data = data {
                var messages: [Message] = []
                
                let messageArray = data as! [[String: Any]]
                
                for messageJson in messageArray {
                    messages.append(Message(self, messageJson))
                }
                
                completion(messages, nil)
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




