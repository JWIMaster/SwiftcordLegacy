import Foundation

public struct Snowflake: Comparable, Hashable, CustomStringConvertible {
    public let rawValue: UInt64
    
    public var description: String { "\(rawValue)" }

    // Convert to creation date
    public var timestamp: Date {
        let discordEpoch = Date(timeIntervalSince1970: 1420070400)
        let msSinceEpoch = Double(rawValue >> 22)
        return Date(timeInterval: msSinceEpoch / 1000, since: discordEpoch)
    }

    // Init from UInt64
    public init(_ rawValue: UInt64) {
        self.rawValue = rawValue
    }

    // Init from String
    public init?(_ string: String) {
        guard let value = UInt64(string) else { return nil }
        self.rawValue = value
    }
    
    public init?(_ any: Any?) {
      guard let any = any else {
        return nil
      }
      
      if let string = any as? String, let snowflake = UInt64(string) {
        self.init(snowflake)
        return
      }
      
      return nil
    }

    // Comparable
    public static func < (lhs: Snowflake, rhs: Snowflake) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    // Hashable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}
