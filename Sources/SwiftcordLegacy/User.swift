//
//  File.swift
//  
//
//  Created by JWI on 15/10/2025.
//

import Foundation
import UIKit

public struct User: Equatable {
    public let id: Snowflake?
    public let username: String?
    public let displayname: String?
    public let discriminator: String?
    public let avatar: UIImage?
    public var avatarString: String?
    
    public init(_ swiftcordLegacy: SwiftcordLegacy,_ json: [String: Any]) {
        self.id = Snowflake(json["id"] as! String)
        self.username = json["username"] as? String
        self.displayname = json["global_name"] as? String
        self.discriminator = json["discriminator"] as? String
        self.avatarString = json["avatar"] as? String
        self.avatar = nil
    }

    
}
