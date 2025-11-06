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
    public var clientUser: ClientUser?
    
    public var dms: [Snowflake: DMChannel] = [:]
    public var guilds: [Snowflake: Guild] = [:]
    
    public let logger = LegacyLogger(fileName: "rest logs")
    
    
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
}




