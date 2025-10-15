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
    
    public var dms: [DM] = []
    
    public init(token: String) {
        self.token = token
        
        self.session = URLSessionCompat(configuration: .default)
    }
    
    
    
    
    public func getDMChannels(completion: @escaping ([[String: Any]], Error?) -> ()) {
        self.request(.getDMChannels) { data, error in
            if let data = data {
                let channels = data as! [[String: Any]]
                
                
                
                completion(channels, nil)
            }
        }
        
    }
    
    
    public func getDMs(completion: @escaping ([DM], Error?) -> ()) {
        self.getDMChannels() { channels, error in
            
            var dms: [DM] = []
            
            for channel in channels {
                if let type = channel["type"] as? Int, type == 1 {
                    let dm = DM(channel)
                    dms.append(dm)
                }
            }
            
            //MARK: need to understand, but it makes the dms in the right order!
            dms.sort(by: {
                let id1 = $0.lastMessageID?.rawValue ?? 0
                let id2 = $1.lastMessageID?.rawValue ?? 0
                return id1 > id2
            })
            
            self.dms = dms
            
            completion(self.dms, nil)
        }
        
    }
    
    public func getChannelMessages(for channel: Snowflake, completion: @escaping ([Message], Error?) -> ()) {
        self.request(.getMessages(channel)) { data, error in
            if let data = data {
                var messages: [Message] = []
                
                let messageArray = data as! [[String: Any]]
                
                for messageJson in messageArray {
                    messages.append(Message(messageJson))
                }
                
                completion(messages, nil)
            }
        }
    }
    
}




