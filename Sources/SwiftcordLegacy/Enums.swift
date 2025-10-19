//
//  File.swift
//  
//
//  Created by JWI on 15/10/2025.
//

import Foundation

public enum Endpoint {
    case getDMChannels
    case getMessages(Snowflake)
    case getGuilds
    case getClientUser
    case sendMessage(Snowflake)
}

typealias EndpointInfo = (method: HTTPMethod, url: String)

enum HTTPMethod: String {
    case get = "GET",
         post = "POST",
         put = "PUT",
         patch = "PATCH",
         delete = "DELETE"
}

extension Endpoint {
    var httpInfo: EndpointInfo {
        switch self {
        case .getDMChannels:
            return(.get, "/users/@me/channels")
        case let .getMessages(channelID):
            return(.get, "/channels/\(channelID)/messages")
        case .getGuilds:
            return (.get, "/users/@me/guilds")
        case .getClientUser:
            return (.get, "/users/@me")
        case let .sendMessage(channel):
            return (.post, "/channels/\(channel)/messages")
        }
    }
}
