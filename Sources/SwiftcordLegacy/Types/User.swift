//
//  File.swift
//  
//
//  Created by JWI on 15/10/2025.
//

import Foundation
import UIKit


public class User: Equatable, CustomStringConvertible {
    public static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id
    }
    
    public let id: Snowflake?
    public let username: String?
    public let displayname: String?
    public let discriminator: String?
    public var avatar: UIImage?
    public let avatarString: String?
    public let nickname: String?
    public let relationship: Relationship?
    public var bio: String?
    public var mfaEnabled: Bool
    
    public init(_ slClient: SLClient, _ json: [String: Any], nickname: String? = nil, relationship: Relationship = .unknown) {
        self.id = Snowflake(json["id"] as? String)
        self.username = json["username"] as? String
        self.displayname = json["global_name"] as? String
        self.discriminator = json["discriminator"] as? String
        self.avatarString = json["avatar"] as? String
        self.mfaEnabled = json["mfa_enabled"] as? Bool ?? false
        self.bio = json["bio"] as? String
        self.avatar = nil
        self.nickname = nickname
        self.relationship = relationship
    }
    
    public var description: String {
        return """
            User(
                id: \(id?.description ?? "nil"),
                username: \(username ?? "nil"),
                displayname: \(displayname ?? "nil"),
                discriminator: \(discriminator ?? "nil"),
                nickname: \(nickname ?? "nil"),
                mfaEnabled: \(mfaEnabled)
            )
            """
    }
}

public struct UserProfile {
    public var pronouns: String?
    public var themeColors: [UIColor]
    
    public init(_ slClient: SLClient, _ json: [String: Any]) {
        self.pronouns = json["pronouns"] as? String
        if let colorInts = json["theme_colors"] as? [Int] {
            self.themeColors = colorInts.map { UIColor(discordColor: $0) }  
        } else {
            self.themeColors = []
        }

    }
}

public class ClientUser: User {
    public var email: String?
    public var phone: String?
    
    
    public init(_ slClient: SLClient, _ json: [String: Any]) {
        self.phone = json["phone"] as? String
        self.email = json["email"] as? String
        super.init(slClient, json)
    }
}

public class PlaceholderUser: User {
    
    public init(_ slClient: SLClient) {
        let json: [String: Any] = ["id": 0, "username": "unknown"]
        super.init(slClient, json)
    }
}


public class GuildMember: CustomStringConvertible {
    public var user: User
    public var guildNickname: String?
    public var roles: [Role]?
    public var guild: Guild?
    
    public var topRole: Role? {
        return roles?.max(by: { $0.position < $1.position })
    }
    
    public var topRoleColor: Role? {
        return roles?
            .filter { role in
                let color = role.color
                return !(UIColor(red: 0, green: 0, blue: 0, alpha: 1) == color)
            }
            .max(by: { $0.position < $1.position })
    }

    
    public init(_ slClient: SLClient, _ json: [String: Any], _ guild: Guild) {
        if let userData = json["user"] as? [String: Any] {
            self.user = User(slClient, userData)
        } else {
            self.user = PlaceholderUser(slClient)
        }
        
        self.guildNickname = json["nick"] as? String
        self.roles = []
        self.guild = guild
        if let roleStrings = json["roles"] as? [String] {
            for roleIDString in roleStrings {
                if let roleID = Snowflake(roleIDString),
                   let guild = self.guild,
                   let role = guild.roles?[roleID] {
                    if self.roles == nil {
                        self.roles = []
                    }
                    self.roles?.append(role)
                }
            }
            self.roles = self.roles?.sorted(by: { $0.position > $1.position })
        }

    }
    
    public var description: String {
        return """
            GuildMember(
                user: \(user)
                guildNickname: \(guildNickname)
            )
        """
    }
}
