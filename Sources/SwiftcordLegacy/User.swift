//
//  File.swift
//  
//
//  Created by JWI on 15/10/2025.
//

import Foundation

public struct User {
    public let id: Snowflake?
    public let username: String?
    public let displayname: String?
    
    public init(_ json: [String: Any]) {
        self.id = Snowflake(json["id"] as! String)
        self.username = json["username"] as? String
        self.displayname = json["global_name"] as? String
    }
}
