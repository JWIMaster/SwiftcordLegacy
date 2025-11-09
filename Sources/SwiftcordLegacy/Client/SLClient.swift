//
//  File.swift
//  
//
//  Created by JWI on 15/10/2025.
//

import Foundation
import FoundationCompatKit

import Foundation

extension Data {
    init?(base64EncodedLegacy string: String) {
        let cleanedString = string
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        let base64Table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        var decodedBytes = [UInt8]()
        var buffer: UInt32 = 0
        var bufferLength = 0
        
        for char in cleanedString {
            if let index = base64Table.firstIndex(of: char) {
                let value = UInt32(base64Table.distance(from: base64Table.startIndex, to: index))
                buffer = (buffer << 6) | value
                bufferLength += 6
                if bufferLength >= 8 {
                    bufferLength -= 8
                    let byte = UInt8((buffer >> bufferLength) & 0xFF)
                    decodedBytes.append(byte)
                }
            } else if char == "=" {
                break
            } else {
                continue
            }
        }
        
        self.init(bytes: decodedBytes, count: decodedBytes.count)
    }
}


/// Swiftcord Legacy client class
public class SLClient {
    public let token: String
    public let session: URLSessionCompat
    public var gateway: Gateway?
    public var clientUser: ClientUser?
    
    public var dms: [Snowflake: DMChannel] = [:]
    public var guilds: [Snowflake: Guild] = [:]
    
    public let logger = LegacyLogger(fileName: "rest logs")
    
    public var clientUserSettings: UserSettings?
    
    public var relationships: [Snowflake: (Relationship, String?)] = [:]
    
    public lazy var sortedDMs: [DMChannel] = dms.values.sorted { dm1, dm2 in
        let id1 = dm1.lastMessageID?.rawValue ?? 0
        let id2 = dm2.lastMessageID?.rawValue ?? 0
        return id1 > id2
    }
    
    public var onReady: (() -> Void)?

    
    public init(token: String) {
        self.token = token
        
        self.session = URLSessionCompat(configuration: .default)
        
        self.getClientUser() { user, error in
            
        }
        
        
    }
    
    public func connect() {
        self.gateway = Gateway(self, token: self.token)
        self.gateway?.start()
        
    }
    
    
    public func handleReady(_ data: [String: Any]) {
        // User
        logger.log("trying to parse the ready payload")
        if let userData = data["user"] as? [String: Any] {
            self.clientUser = ClientUser(self, userData)
        }
        
        // User settings
        autoreleasepool {
            if let base64String = data["user_settings_proto"] as? String,
               let decodedData = Data(base64EncodedLegacy: base64String),
               let jsonObject = try? JSONSerialization.jsonObject(with: decodedData) as? [String: Any] {
                self.clientUserSettings = UserSettings(self, jsonObject)
            } else if let settingsData = data["user_settings"] as? [String: Any] {
                self.clientUserSettings = UserSettings(self, settingsData)
            }
        }
        
        
        
        // Relationships
        autoreleasepool {
            if let relationshipsArray = data["relationships"] as? [[String: Any]] {
                var rels: [Snowflake: (Relationship, String?)] = [:]
                for r in relationshipsArray {
                    if let id = r["id"] as? String, let type = r["type"] as? Int {
                        let userID = Snowflake(id)!
                        let relType = Relationship(rawValue: type) ?? .unknown
                        let nickname = r["nickname"] as? String
                        rels[userID] = (relType, nickname)
                    }
                }
                // Store locally
                self.relationships = rels
            }
        }
        
        
        // 1. Build a dictionary of users from the ready payload
        var users: [String: [String: Any]] = [:]
        autoreleasepool {
            if let usersArray = data["users"] as? [[String: Any]] {
                for userJSON in usersArray {
                    if let id = userJSON["id"] as? String {
                        users[id] = userJSON
                    }
                }
            }
        }
        

        // 2. Populate private channels (DMs and Group DMs)
        autoreleasepool {
            if let privateChannels = data["private_channels"] as? [[String: Any]] {
                for channel in privateChannels {
                    guard let type = channel["type"] as? Int else { continue }

                    switch type {
                    case 1: // DM
                        // Get the recipient JSON by matching recipient_ids
                        var channelJSON = channel
                        if let recipientIDs = channel["recipient_ids"] as? [String] {
                            let recipientsJSON = recipientIDs.compactMap { users[$0] }
                            channelJSON["recipients"] = recipientsJSON
                        }

                        if var dm = DM(self, channelJSON, relationships) {
                            // Assign first recipient as the DM recipient
                            self.dms[dm.id!] = dm
                        }

                    case 3: // Group DM
                        if let groupDM = GroupDM(self, channel) {
                            self.dms[groupDM.id!] = groupDM
                        }

                    default:
                        break
                    }
                }
            }
        }
        
        
        
        // Guilds & members
        autoreleasepool {
            if let guildsArray = data["guilds"] as? [[String: Any]] {
                for guildData in guildsArray {
                    let guild = Guild(self, guildData)
                    self.guilds[(guild?.id)!] = guild
                }
            }
        }
        
        DispatchQueue.main.async {
            self.saveCache()
            self.onReady?()

        }
    }
    
    
    
    
    
    public func getUser(withID userID: Snowflake, completion: @escaping (User, Error?) -> ()) {
        self.request(.getUser(user: userID)) { data, error in
            guard let userData = data as? [String: Any] else { return }
            let user = User(self, userData)
            completion(user, nil)
        }
    }
    
    public func getUserProfile(withID userID: Snowflake, completion: @escaping (User, UserProfile, Error?) -> ()) {
        self.request(.getUserProfile(user: userID)) { data, error in
            guard let jsonData = data as? [String: Any] else { return }
            print(jsonData)
            guard let userData = jsonData["user"] as? [String: Any] else { return }
            let user = User(self, userData)
            guard let profileData = jsonData["user_profile"] as? [String: Any] else { return }
            let userProfile = UserProfile(self, profileData)
            
            print(profileData)
            
            completion(user, userProfile, nil)
        }
    }
    
    
    public func getClientUser(completion: @escaping (ClientUser, Error?) -> ()) {
        self.request(.getClientUser) { data, error in
            if let data = data {
                let clientUser = data as? [String: Any]
                guard let clientUser = clientUser else { return }
                
                self.clientUser = ClientUser(self, clientUser)
                completion(self.clientUser ?? ClientUser(self, clientUser), nil)
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
    
    public func getClientUserSettings(completion: @escaping (UserSettings, Error?) -> ()) {
        self.request(.getUserSettings) { settings, error in
            guard let settingsJson = settings as? [String: Any] else { return }
            let userSettings = UserSettings(self, settingsJson)
            self.clientUserSettings = userSettings
            completion(userSettings, nil)
        }
    }
}




