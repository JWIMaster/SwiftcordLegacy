//
//  File.swift
//  
//
//  Created by JWI on 2/11/2025.
//

import Foundation

extension SLClient {
    ///Function to send a message string to a specified channel
    public func send(message: Message, in channel: TextChannel, completion: @escaping (Error?) -> ()) {
        guard let content = message.content, let channelID = channel.id else { return }
        self.request(.sendMessage(channelID), body: ["content": content]) { data, error in
            completion(nil)
        }
    }
    
    public func reply(to originalMessage: Message, with replyMessage: Message, in channel: TextChannel, completion: @escaping (Error?) -> ()) {
        guard let originalMessageID = originalMessage.id,
              let replyMessageContent = replyMessage.content,
              let channelID = channel.id
        else { return }
        
        let messageToSend: [String : Any] = [
            "content": replyMessageContent,
            "message_reference": [
                "message_id": String(originalMessageID.rawValue)
            ]
        ]
        
        self.request(.sendMessage(channelID), body: messageToSend) { data, error in
            completion(nil)
        }
    }
    
    
    
    
    public func delete(message: Message, in channel: TextChannel, completion: @escaping (Error?) -> ()) {
        guard let messageID = message.id, let channelID = channel.id else { return }
        self.request(.deleteMessage(channel: channelID, message: messageID)) { data, error in
            completion(nil)
        }
    }
    
    public func edit(message: Message, to newMessage: Message, in channel: TextChannel, completion: @escaping (Error?) -> ()) {
        guard let messageID = message.id, let channelID = channel.id, let messageContent = newMessage.content else { return }
        self.request(.editMessage(channel: channelID, message: messageID), body: ["content": messageContent]) { data, error in
            completion(nil)
        }
    }
    
    
    ///Function to get the messages in a given channel. Returns an array of Message structs.
    public func getChannelMessages(for channel: Snowflake, completion: @escaping ([Message], Error?) -> ()) {
        self.request(.getMessages(channel)) { data, error in
            if let data = data {
                var messages: [Message] = []
                
                let messageArray = data as? [[String: Any]]
                
                guard let messageArray = messageArray else { return }
                
                for message in messageArray {
                    messages.append(Message(self, message))
                }
                completion(messages.reversed(), nil)
            }
        }
    }
    
    ///Get a channel via a Snowflake ID
    public func getChannel(_ channelID: Snowflake, completion: @escaping (Channel?, Error?) -> ()) {
        // First, check all guilds for this channel in cache
        for (_, guild) in self.guilds {
            if let cachedChannel = guild.channels[channelID] {
                completion(cachedChannel, nil)
                return
            }
        }

        // Otherwise, fetch it from the API
        self.request(.getChannel(channel: channelID)) { data, error in
            if let error = error {
                completion(nil, error)
                return
            }

            guard let channelData = data as? [String: Any] else {
                completion(nil, nil)
                return
            }

            let type = channelData["type"] as? Int
            switch type {
            case 0:
                let guildTextChannel = GuildText(self, channelData)
                if let guild = guildTextChannel.guild,
                   let guildID = guild.id,
                   var cachedGuild = self.guilds[guildID] {
                    cachedGuild.channels[guildTextChannel.id!] = guildTextChannel
                    self.guilds[guildID] = cachedGuild
                }
                completion(guildTextChannel, nil)
            default:
                completion(nil, nil)
            }
        }
    }

}
