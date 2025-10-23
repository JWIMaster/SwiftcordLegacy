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

public enum OP: Int {
    case dispatch = 0
    case heartbeat = 1
    case identify = 2
    case presenceUpdate = 3
    case voiceStateUpdate = 4
    case resume = 6
    case reconnect = 7
    case requestGuildMembers = 8
    case invalidSession = 9
    case hello = 10
    case heartbeatACK = 11
}



public enum Intents: Int {
    case guilds = 1
    case guildMembers = 2
    case guildBans = 4
    case guildEmojisAndStickers = 8
    case guildIntegrations = 16
    case guildWebhooks = 32
    case guildInvites = 64
    case guildVoiceStates = 128
    case guildPresences = 256
    case guildMessages = 512
    case guildMessageReactions = 1024
    case guildMessageTyping = 2048
    case directMessages = 4096
    case directMessagesReactions = 8192
    case directMessagesTyping = 16384
    case messageContent = 32768
    case guildScheduledEvents = 65536
}

public enum HTTPMethod: String {
    case get = "GET",
         post = "POST",
         put = "PUT",
         patch = "PATCH",
         delete = "DELETE"
}

public enum Event: String {
    case messageCreate = "MESSAGE_CREATE"
    case messageDelete = "MESSAGE_DELETE"
    case messageUpdate = "MESSAGE_UPDATE"
}


