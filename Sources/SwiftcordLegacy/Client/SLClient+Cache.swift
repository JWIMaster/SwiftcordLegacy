import Foundation
import UIKit

public extension UIColor {
    var argbInt: Int {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let ai = Int(a * 255) << 24
        let ri = Int(r * 255) << 16
        let gi = Int(g * 255) << 8
        let bi = Int(b * 255)
        
        return ai | ri | gi | bi
    }
    
    convenience init(argbInt: Int) {
        let a = CGFloat((argbInt >> 24) & 0xFF) / 255
        let r = CGFloat((argbInt >> 16) & 0xFF) / 255
        let g = CGFloat((argbInt >> 8) & 0xFF) / 255
        let b = CGFloat(argbInt & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}




public class CacheManager {

    private let fileName: String

    public init(fileName: String = "SLClientCache.json") {
        self.fileName = fileName
    }

    private var filePath: String {
        let dirs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let dir = dirs.first ?? NSTemporaryDirectory()
        return dir + "/" + fileName
    }


    public func save(client: SLClient) {
        var cacheDict: [String: Any] = [:]

        // DMs
        var dmDict: [String: [String: Any]] = [:]
        for (id, dmChannel) in client.dms {
            // DM
            if let dm = dmChannel as? DM {
                dmDict[id.description] = dm.convertToDict()
            }

            // GroupDM
            if let gdm = dmChannel as? GroupDM {
                dmDict[id.description] = gdm.convertToDict()
            }

        }
        cacheDict["dms"] = dmDict

        // Guilds
        // MARK: - Save Guilds with Members and Channels
        var guildDict: [String: [String: Any]] = [:]
        for (id, guild) in client.guilds {
            guildDict[id.description] = guild.convertToDict()
        }
        cacheDict["guilds"] = guildDict


        // Relationships
        var relDict: [String: [String: Any]] = [:]
        for (id, (rel, nickname)) in client.relationships {
            relDict[id.description] = [
                "type": rel.rawValue,
                "nickname": nickname ?? NSNull()
            ]
        }
        cacheDict["relationships"] = relDict

        // User settings
        if let settings = client.clientUserSettings {
            var foldersArray: [[String: Any]] = []
            guard let guildFolders = settings.guildFolders else { return }
            for folder in guildFolders {
                let folderDict: [String: Any] = [
                    "id": folder.id?.description ?? "",
                    "name": folder.name ?? "",
                    "guildIDs": folder.guildIDs?.map { $0.description } ?? [],
                    "opened": folder.opened ?? false,
                    //"color": folder.color?.hexString ?? "" // store as hex string
                ]
                foldersArray.append(folderDict)
            }
            
            cacheDict["userSettings"] = [
                "guild_folders": foldersArray
            ]
        }


        do {
            try autoreleasepool {
                let data = try JSONSerialization.data(withJSONObject: cacheDict, options: [.prettyPrinted])
                let nsData = data as NSData
                try nsData.write(to: URL(fileURLWithPath: filePath), options: .atomic)
            }
            client.logger.log("Cache saved successfully.")
        } catch {
            client.logger.log("Error saving cache: \(error)")
        }

    }

    public func load(client: SLClient) {
        guard FileManager.default.fileExists(atPath: filePath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            client.logger.log("No cache found.")
            return
        }

        // MARK: 1. Load Relationships first
        autoreleasepool {
            if let cachedRelationships = json["relationships"] as? [String: [String: Any]] {
                var rels: [Snowflake: (Relationship, String?)] = [:]
                for (id, dict) in cachedRelationships {
                    if let typeRaw = dict["type"] as? Int {
                        let relType = Relationship(rawValue: typeRaw) ?? .unknown
                        let nickname = dict["nickname"] as? String
                        rels[Snowflake(id)!] = (relType, nickname)
                    }
                }
                client.relationships = rels
            }
        }

        // MARK: 2. Load User Settings
        autoreleasepool {
            if let settingsJSON = json["userSettings"] as? [String: Any] {
                client.clientUserSettings = UserSettings(client, settingsJSON)
            }
        }

        // MARK: 3. Load Guilds
        autoreleasepool {
            if let cachedGuilds = json["guilds"] as? [String: [String: Any]] {
                for (id, guildJSON) in cachedGuilds {
                    let guild = Guild(client, guildJSON)
                    client.guilds[Snowflake(id)!] = guild
                }
            }
        }

        // MARK: 4. Load DMs (requires relationships to exist)
        autoreleasepool {
            if let cachedDMs = json["dms"] as? [String: [String: Any]] {
                for (id, dmJSON) in cachedDMs {
                    guard let recipients = dmJSON["recipients"] as? [[String: Any]], !recipients.isEmpty else {
                        client.logger.log("Skipping DM \(id) with no recipients")
                        continue
                    }

                    if let dm = DM(client, dmJSON, client.relationships) {
                        client.dms[Snowflake(id)!] = dm
                    } else if let gdm = GroupDM(client, dmJSON, client.relationships) {
                        client.dms[Snowflake(id)!] = gdm
                    } else {
                        client.logger.log("Failed to load DM \(id)")
                    }
                }
            }
        }

        client.logger.log("Cache loaded successfully.")
    }
    
    public func clearCache() {
        let path = filePath
        if FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.removeItem(atPath: path)
                print("Cache cleared successfully.")
            } catch {
                print("Failed to clear cache: \(error)")
            }
        } else {
            print("No cache file found to clear.")
        }
    }
}

import FoundationCompatKit

extension SLClient {
    public var cacheManager: CacheManager {
        return CacheManager()
    }

    public func saveCache() {
        DispatchQueue.global(qos: .background).async {
            self.cacheManager.save(client: self)
        }
    }

    public func loadCache(_ completion: @escaping () -> ()) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.cacheManager.load(client: self)
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    public func clearCache() {
        cacheManager.clearCache()
    }
}

