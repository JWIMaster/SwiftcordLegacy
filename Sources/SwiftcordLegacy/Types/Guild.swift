import Foundation

public class Guild {
    public let id: Snowflake?
    public let name: String?
    public let icon: String?
    public let slClient: SLClient?
    public var members = [Snowflake: GuildMember]()
    public var roles = [Snowflake: Role]()
    public var channels = [Snowflake: GuildChannel]()
    public var fullGuild: Bool = false

    public init?(_ slClient: SLClient, _ json: [String: Any]) {
        self.slClient = slClient
        self.id = Snowflake(json["id"] as! String)
        self.name = json["name"] as? String
        self.icon = json["icon"] as? String
        if let roleArray = json["roles"] as? [[String: Any]] {
            for roleJson in roleArray {
                let role = Role(roleJson)
                self.roles[role.id] = role
            }
        }

    }
}
