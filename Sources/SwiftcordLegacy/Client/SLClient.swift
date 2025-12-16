//
//  File.swift
//  
//
//  Created by JWI on 15/10/2025.
//

import Foundation
import FoundationCompatKit

import Foundation

/// Swiftcord Legacy client class
public final class SLClient {
    public let token: String
    public let session: URLSessionCompat
    public let sessionConfig: URLSessionConfigurationCompat = {
        let config = URLSessionConfigurationCompat()
        config.httpAdditionalHeaders = additionalHeaders
        return config
    }()
    public var gateway: Gateway?
    public var clientUser: ClientUser?
    
    public var dms = [Snowflake: DMChannel]()
    public var guilds = [Snowflake: Guild]()
    

    
    public var presences = [Snowflake: PresenceType]()
    
    public let logger = LegacyLogger(fileName: "rest logs")
    
    public var clientUserSettings: UserSettings?
    
    public var relationships: [Snowflake: (Relationship, String?)] = [:]
    
    public var friends = [User]()
    
    public lazy var sortedDMs: [DMChannel] = dms.values.sorted { dm1, dm2 in
        let id1 = dm1.lastMessageID?.rawValue ?? 0
        let id2 = dm2.lastMessageID?.rawValue ?? 0
        return id1 > id2
    }
    
    public var onReady: (() -> Void)?

    
    public init(token: String) {
        self.token = token
        
        self.session = URLSessionCompat(configuration: self.sessionConfig)
        
        self.getClientUser() { user, error in
            
        }
        
        
    }
    
    public func connect() {
        if let gateway = gateway {
            gateway.stop()

        }
        self.gateway = Gateway(self, token: self.token)
        self.gateway?.start()
        
    }
    
    public func disconnect() {
        if let gateway = gateway {
            gateway.stop()
        }
        
        self.gateway = nil
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
            guard let userData = jsonData["user"] as? [String: Any] else { return }
            print(jsonData)
            let user = User(self, userData)
            guard let profileData = jsonData["user_profile"] as? [String: Any] else { return }
            let userProfile = UserProfile(self, profileData)
            
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
            self.relationships = relationships
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
    
    public func create(reaction: Reaction, in channel: Snowflake, on message: Snowflake , completion: @escaping ((Error?) -> ())) {
        guard let emoji = reaction.emoji else { return }
        var emojiString: String
        if let emojiID = emoji.id?.description, let emojiName = emoji.name {
            emojiString = "\(emojiName):\(emojiID)"
        } else if let emojiName = emoji.name {
            emojiString = emojiName.urlPathPercentEncoded()
        } else {
            emojiString = ""
        }
        self.request(.createReaction(channel: channel, message: message, emoji: emojiString)) { _, _ in
            completion(nil)
        }
    }
    
    public func delete(ownReaction: Reaction, in channel: Snowflake, on message: Snowflake , completion: @escaping ((Error?) -> ())) {
        guard let emoji = ownReaction.emoji else { return }
        var emojiString: String
        if let emojiID = emoji.id?.description, let emojiName = emoji.name {
            emojiString = "\(emojiName):\(emojiID)"
        } else if let emojiName = emoji.name {
            emojiString = emojiName.urlPathPercentEncoded()
        } else {
            emojiString = ""
        }
        self.request(.deleteOwnReaction(channel: channel, message: message, emoji: emojiString)) { _, _ in
            completion(nil)
        }
    }
}




