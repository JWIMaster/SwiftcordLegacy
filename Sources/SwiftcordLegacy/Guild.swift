import Foundation

public struct Guild {
    public let id: Snowflake?
    public let name: String?
    public let icon: String?

    public init?(_ json: [String: Any]) {
        self.id = Snowflake(json["id"] as! String)
        self.name = json["name"] as? String
        self.icon = json["icon"] as? String
    }
}
