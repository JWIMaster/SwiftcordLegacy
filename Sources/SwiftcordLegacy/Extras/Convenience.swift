//
//  File.swift
//  
//
//  Created by JWI on 16/10/2025.
//

import Foundation
import UIKit

extension SLClient {
    public func getSortedDMs(completion: @escaping ([DMChannel], Error?) -> ()) {
        self.getDMs() { dms, error in
            var sortedDMs: [DMChannel] = []
            
            for (_,dm) in dms {
                sortedDMs.append(dm)
            }
            
            sortedDMs.sort(by: {
                let id1 = $0.lastMessageID?.rawValue ?? 0
                let id2 = $1.lastMessageID?.rawValue ?? 0
                return id1 > id2
            })
            
            completion(sortedDMs, nil)
        }
    }
    
    public func send(image: UIImage, withMessage message: Message? = nil, in channel: TextChannel, completion: @escaping (Error?) -> ()) {
        let imageData = image.jpegData(compressionQuality: 0.9)!
        self.send(imageData: imageData, withMessage: message, in: channel, completion: { error in
            
        })
    }
}

public extension UIColor {
    convenience init(discordColor value: Int) {
        let red = CGFloat((value >> 16) & 0xFF) / 255.0
        let green = CGFloat((value >> 8) & 0xFF) / 255.0
        let blue = CGFloat(value & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}



public var userAgent: String {
    // 1. Get iOS version
    let osVersion = UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")
    
    // 3. Get device model (iPhone/iPad)
    let deviceModel = UIDevice.current.model // e.g., "iPhone"
    
    // 4. Discord app version info
    let discordVersion = "1.0.9211"
    let mobileBuild = "15E148"
    let webkitVersion = "605.1.15"
    let safariVersion = "604.1"
    
    // 5. Construct UA string
    return "Mozilla/5.0 (\(deviceModel); CPU \(deviceModel) OS \(osVersion) like Mac OS X) AppleWebKit/\(webkitVersion) (KHTML, like Gecko) discord/\(discordVersion) Mobile/\(mobileBuild) Safari/\(safariVersion)"
}
