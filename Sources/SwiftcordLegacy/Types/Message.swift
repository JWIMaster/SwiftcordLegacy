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
    
    
    public init(_ slClient: SLClient, _ json: [String: Any]) {
        self.id = Snowflake(json["id"])
        
        if let authorJson = json["author"] as? [String: Any] {
            self.author = User(slClient, authorJson)
        } else {
            self.author = nil
        }
        
        self.content = json["content"] as? String
        self.date = json["date"] as? Date
    }
}
