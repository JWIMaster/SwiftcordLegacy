//
//  File.swift
//  
//
//  Created by JWI on 22/10/2025.
//

import Foundation

typealias EndpointInfo = (method: HTTPMethod, url: String)

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
