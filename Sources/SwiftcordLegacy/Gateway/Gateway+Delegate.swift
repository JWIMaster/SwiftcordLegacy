//
//  File.swift
//  
//
//  Created by JWI on 5/11/2025.
//

import Foundation
import SocketRocket
import FoundationCompatKit

// MARK: - SRWebSocketDelegate
extension Gateway: SRWebSocketDelegate {
    
    public func webSocketDidOpen(_ webSocket: SRWebSocket!) {
        isConnected = true
        isReconnecting = false
        print("[Gateway] ✅ Connected")
    }
    
    public func webSocket(_ webSocket: SRWebSocket!, didReceiveMessage message: Any!) {
        guard let text = message as? String else { return }
        DispatchQueue.global(qos: .userInteractive).async { [self] in
            let payload = Payload(with: text)
            self.handlePayload(payload)
        }
    }
    
    public func webSocket(_ webSocket: SRWebSocket!, didFailWithError error: Error!) {
        isConnected = false
        print("[Gateway] ❌ Connection failed:", error.localizedDescription)
        reconnect()
    }
    
    public func webSocket(_ webSocket: SRWebSocket!, didCloseWithCode code: Int, reason: String!, wasClean: Bool) {
        print("[Gateway] 🔴 Closed with code \(code), reason: \(reason ?? "none")")
        if code == 4004 {
            print("[Gateway] ❌ Invalid token")
        } else if !isReconnecting {
            isReconnecting = true
            reconnect()
        }
    }
    
    
}
