//
//  File.swift
//  
//
//  Created by JWI on 22/10/2025.
//

import Foundation

//MARK: Don't know, ChatGPT, need to revise
class Bucket {
    private let limit: Int
    private let interval: TimeInterval
    private var queueItems: [DispatchWorkItem] = []
    private var counter = 0
    private let queue = DispatchQueue(label: "gateway.bucket.queue")
    
    init(limit: Int, interval: TimeInterval) {
        self.limit = limit
        self.interval = interval
    }
    
    func queue(_ item: DispatchWorkItem) {
        queue.async {
            self.queueItems.append(item)
            self.processQueue()
        }
    }
    
    private func processQueue() {
        guard !queueItems.isEmpty else { return }
        if counter < limit {
            counter += 1
            let item = queueItems.removeFirst()
            item.perform()
            
            queue.asyncAfter(deadline: .now() + interval) {
                self.counter -= 1
                self.processQueue()
            }
        }
    }
}
