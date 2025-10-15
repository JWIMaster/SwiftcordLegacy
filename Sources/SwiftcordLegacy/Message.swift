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
    public let content: String?
    public let date: Date?
    
    
    public init(_ json: [String: Any]) {
        self.id = Snowflake(json["id"] as! String)
        self.author = User(json["author"] as! [String: Any])
        self.content = json["content"] as? String
        self.date = json["date"] as? Date
    }
}
