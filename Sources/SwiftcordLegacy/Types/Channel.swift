//
//  File.swift
//  
//
//  Created by JWI on 20/10/2025.
//

import Foundation

public protocol Channel {
    var slClient: SLClient? { get }
    var id: Snowflake? { get }
    var type: ChannelType { get }
}

public protocol TextChannel: Channel {
    var lastMessageID: Snowflake? { get }
}


public enum ChannelType: Int {
  case guildText
  case dm
  case guildVoice
  case groupDM
  case guildCategory
}

public protocol DMChannel: TextChannel {
    
}
