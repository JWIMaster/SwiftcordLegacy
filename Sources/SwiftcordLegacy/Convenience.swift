//
//  File.swift
//  
//
//  Created by JWI on 16/10/2025.
//

import Foundation

extension SwiftcordLegacy {
    public func getSortedDMs(completion: @escaping ([DM], Error?) -> ()) {
        self.getDMs() { dms, error in
            var sortedDMs: [DM] = []
            
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
