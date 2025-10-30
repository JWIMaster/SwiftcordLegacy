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
}


public var userAgent: String {
    // 1. Get iOS version
    let osVersion = UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")
    
    // 2. Get device architecture
    var systemInfo = utsname()
    uname(&systemInfo)
    let machine = withUnsafePointer(to: &systemInfo.machine) { ptr in
        ptr.withMemoryRebound(to: CChar.self, capacity: 1) {
            String(cString: $0)
        }
    }
    
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
