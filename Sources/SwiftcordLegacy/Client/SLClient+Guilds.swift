//
//  File.swift
//  
//
//  Created by JWI on 1/11/2025.
//

import Foundation

extension SLClient {
    public func getUserGuilds(completion: @escaping ([Snowflake: Guild], Error?) -> ()) {
        self.request(.getGuilds) { data, error in
            let guildArray = data as? [[String: Any]]
            
            guard let guildArray = guildArray else { return }
            
            for guild in guildArray {
                
                let guild = Guild(self, guild)
                guard let guild = guild else {
                    return
                }
                
                self.guilds[guild.id!] = guild
            }
            
            completion(self.guilds, nil)
        }
    }
    
    
    public func getGuildMember(_ guild: Guild, _ user: User, completion: @escaping (GuildMember?, Error?) -> ()) {
        guard let guildMemberID = user.id, let guildMembers = guild.members else { return }
        
        // Check if the member already exists
        if let existingMember = guildMembers[guildMemberID] {
            completion(existingMember, nil)
            return
        }
        
        // Otherwise, fetch from API
        guard let guildID = guild.id else { return }
        
        self.request(.getGuildMember(guild: guildID, user: guildMemberID)) { data, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let memberData = data as? [String: Any] else {
                completion(nil, nil)
                return
            }
            
            let guildMember = GuildMember(self, memberData, guild)
            // Add to guild dictionary
            guild.members![guildMemberID] = guildMember
            completion(guildMember, nil)
        }
    }
    
    
    
    public func getFullGuild(_ guild: Guild, completion: @escaping ([Snowflake: Guild], Error?) -> ()) {
        self.request(.getGuild(guild: guild.id!)) { data, error in
            let guildData = data as? [String: Any]
            guard let guildData = guildData else { return }
            let guild = Guild(self, guildData)
            let guildID = guild?.id
            guard let guild = guild, let guildID = guildID else { return }
            let guildDict: [Snowflake: Guild] = [guildID: guild]
            self.guilds.merge(guildDict) { _, new in new }
            completion(guildDict, nil)
        }
    }
    
    public func subscribeToChannel(_ guild: Guild, _ channel: GuildChannel) {
        self.gateway?.subscribeToGuildChannel(guildId: guild.id!, channelId: channel.id!)
    }
    
    public func getGuildChannels(for guildId: Snowflake, completion: @escaping ([GuildChannel], Error?) -> ()) {
        self.request(.getGuildChannels(guild: guildId)) { data, error in
            guard let channelArray = data as? [[String: Any]] else {
                completion([], error)
                return
            }
            
            var channels: [GuildChannel] = []
            
            
            for channelData in channelArray {
                switch ChannelType(rawValue: channelData["type"] as? Int ?? 0) {
                case .guildText:
                    let guildTextChannel = GuildText(self, channelData)
                    channels.append(guildTextChannel)
                    
                    // Add channel to the guild's dictionary
                    if let channelID = guildTextChannel.id, let guild = self.guilds[guildId] {
                        guild.channels?[channelID] = guildTextChannel
                    }
                case .guildCategory:
                    let guildCategory = GuildCategory(self, channelData)
                    channels.append(guildCategory)
                    if let channelID = guildCategory.id, let guild = self.guilds[guildId] {
                        guild.channels?[channelID] = guildCategory
                    }
                default:
                    break
                }
            }
            
            if let guild = self.guilds[guildId] {
                for channel in channels {
                    print(channel.position)
                    guard let parentID = channel.parentID else { continue }
                    if let parent = guild.channels?[parentID] as? GuildCategory {
                        parent.channels?[channel.id!] = channel
                    }
                }
            }
            
            completion(channels, nil)
        }
    }
    
    public func getGuildChannels(for guild: Guild, completion: @escaping ([GuildChannel], Error?) -> ()) {
        guard let guildID = guild.id else { return }
        self.request(.getGuildChannels(guild: guildID)) { data, error in
            if let error = error {
                print(error)
                return
            }
            
            guard let channelArray = data as? [[String: Any]] else {
                completion([], error)
                return
            }
            
            var channels: [GuildChannel] = []
            
            
            for channelData in channelArray {
                switch channelData["type"] as? Int {
                case 0:
                    let guildTextChannel = GuildText(self, channelData)
                    channels.append(guildTextChannel)
                    
                    // Add channel to the guild's dictionary
                    if let channelID = guildTextChannel.id, let guild = self.guilds[guildID] {
                        guild.channels?[channelID] = guildTextChannel
                    }
                default:
                    break
                }
            }
            completion(channels, nil)
        }
    }
}
