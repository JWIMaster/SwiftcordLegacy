import Foundation
import Dispatch
import FoundationCompatKit
import SocketRocket

public typealias DispatchWorkItem = FoundationCompatKit.DispatchWorkItem

public class Gateway: NSObject {
    
    let token: String
    let intents: Int
    var session: SRWebSocket?
    var isConnected = false
    var isReconnecting = false
    var lastSeq: Int?
    var sessionId: String?
    var gatewayUrl: String
    let slClient: SLClient
    
    // Heartbeat management
    var heartbeatInterval: TimeInterval = 30
    var heartbeatTimer: DispatchSourceTimer?
    let heartbeatQueue = DispatchQueue(label: "gateway.heartbeat.queue")
    private var awaitingHeartbeatAck = false
    private var lastHeartbeatSent: Date?
    private var lastHeartbeatAck: Date?
    
    // Rate limits
    let globalBucket = Bucket(limit: 120, interval: 60)
    let presenceBucket = Bucket(limit: 5, interval: 60)
    
    // Identify cooldown
    private var identifyCooldown = false
    private var lastIdentifyDate: Date?
    
    public var onMessageCreate: ((Message) -> Void)?
    public var onMessageUpdate: ((Message) -> Void)?
    public var onMessageDelete: ((Message) -> Void)?
    
    init(_ slClient: SLClient, token: String, intents: Int, gatewayUrl: String = "wss://gateway.discord.gg/?encoding=json&v=9") {
        self.slClient = slClient
        self.token = token
        self.intents = intents
        self.gatewayUrl = gatewayUrl
    }
    
    // MARK: - Connection
    func start() {
        guard let url = URL(string: gatewayUrl) else {
            print("[Gateway] Bad URL: \(gatewayUrl)")
            return
        }
        
        let socket = SRWebSocket(url: url)
        socket?.delegate = self
        socket?.setDelegateDispatchQueue(.global(qos: .background))
        self.session = socket
        socket?.open()
    }
    
    func stop() {
        session?.close()
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
        isConnected = false
        awaitingHeartbeatAck = false
    }
    
    // MARK: - Safe Send
    func send(_ payload: Payload, presence: Bool = false) {
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard let session = self.session, session.readyState == .OPEN else {
                print("[Gateway] ⚠️ Socket not open. Cannot send payload.")
                return
            }
            session.send(payload.encode())
        }
        (presence ? presenceBucket : globalBucket).queue(item)
    }
    
    // MARK: - Heartbeat System
    private func startHeartbeat() {
        heartbeatTimer?.cancel()
        heartbeatTimer = DispatchSource.makeTimerSource(queue: heartbeatQueue)
        heartbeatTimer?.schedule(deadline: .now(), repeating: heartbeatInterval)
        heartbeatTimer?.setEventHandler { [weak self] in
            self?.sendHeartbeat()
        }
        heartbeatTimer?.resume()
    }
    
    private func sendHeartbeat() {
        if awaitingHeartbeatAck {
            print("[Gateway] ⚠️ Missed heartbeat ACK — connection likely zombied")
            closeAndReconnect(code: 4000)
            return
        }
        
        let payload = Payload(op: 1, d: lastSeq ?? NSNull())
        send(payload)
        awaitingHeartbeatAck = true
        lastHeartbeatSent = Date()
        print("[Gateway] 💓 Heartbeat sent")
    }
    
    private func handleHeartbeatACK() {
        awaitingHeartbeatAck = false
        lastHeartbeatAck = Date()
        print("[Gateway] 💚 Heartbeat ACK received")
    }
    
    // MARK: - Identify / Resume with Cooldown
    func identify() {
        let now = Date()
        let cooldownInterval: TimeInterval = 5 // seconds
        
        if identifyCooldown, let last = lastIdentifyDate {
            let timeSinceLast = now.timeIntervalSince(last)
            if timeSinceLast < cooldownInterval {
                let delay = cooldownInterval - timeSinceLast + 1
                print("[Gateway] ⏱ Identify cooldown in effect. Delaying \(delay)s")
                DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.identify()
                }
                return
            }
        }
        
        identifyCooldown = true
        lastIdentifyDate = now
        
        let data: [String: Any] = [
            "token": token,
            "intents": intents,
            "properties": [
                "$os": "iOS",
                "$browser": "SwiftBot",
                "$device": "SwiftBot"
            ],
            "compress": false,
            "large_threshold": 250
        ]
        
        send(Payload(op: 2, d: data))
        print("[Gateway] 🪪 Identify sent")
        
        // Reset cooldown after interval
        DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + cooldownInterval) { [weak self] in
            self?.identifyCooldown = false
        }
    }
    
    func resume() {
        guard let sessionId = sessionId, let seq = lastSeq else {
            print("[Gateway] Missing session or sequence — cannot resume")
            identify()
            return
        }
        
        let data: [String: Any] = [
            "token": token,
            "session_id": sessionId,
            "seq": seq
        ]
        send(Payload(op: 6, d: data))
        print("[Gateway] 🔁 Resume sent")
    }
    
    // MARK: - Payload Handling
    func handlePayload(_ payload: Payload) {
        if let seq = payload.s { lastSeq = seq }
        
        switch payload.op {
        case 0: handleDispatch(payload)
        case 1, 7, 9, 10, 11: handleGateway(payload)
        default: print("[Gateway] Unknown OP: \(payload.op)")
        }
    }
    
    private func handleDispatch(_ payload: Payload) {
        guard let event = Event(rawValue: payload.t!) else { return }
        guard let eventData = payload.d as? [String: Any] else { return }
        
        switch event {
        case .messageCreate:
            let message = Message(self.slClient, eventData)
            DispatchQueue.main.async { self.onMessageCreate?(message) }
        case .messageDelete:
            let message = Message(self.slClient, eventData)
            DispatchQueue.main.async { self.onMessageDelete?(message) }
        case .messageUpdate:
            let message = Message(self.slClient, eventData)
            DispatchQueue.main.async { self.onMessageUpdate?(message) }
        }
    }
    
    private func handleGateway(_ payload: Payload) {
        guard let op = OP(rawValue: payload.op) else {
            print("[Gateway] Unknown gateway OP: \(payload.op)")
            return
        }
        
        switch op {
        case .heartbeat:
            sendHeartbeat()
        case .heartbeatACK:
            handleHeartbeatACK()
        case .hello:
            if let d = payload.d as? [String: Any],
               let interval = d["heartbeat_interval"] as? Double {
                heartbeatInterval = interval / 1000
                startHeartbeat()
                if isReconnecting, sessionId != nil, lastSeq != nil {
                    resume()
                } else {
                    identify()
                }
            }
        case .invalidSession:
            print("[Gateway] ❌ Invalid session, reconnecting...")
            reconnect()
        case .reconnect:
            print("[Gateway] 🔁 Server requested reconnect")
            reconnect()
        default:
            break
        }
    }
    
    // MARK: - Reconnect Handling
    private func closeAndReconnect(code: Int) {
        stop()
        isReconnecting = true
        print("[Gateway] Closing zombied connection (code \(code)) and reconnecting...")
        start()
    }
    
    func reconnect() {
        closeAndReconnect(code: 4000)
    }
}

// MARK: - SRWebSocketDelegate
extension Gateway: SRWebSocketDelegate {
    
    public func webSocketDidOpen(_ webSocket: SRWebSocket!) {
        isConnected = true
        isReconnecting = false
        print("[Gateway] ✅ Connected to Gateway")
    }
    
    public func webSocket(_ webSocket: SRWebSocket!, didReceiveMessage message: Any!) {
        guard let text = message as? String else {
            print("[Gateway] ⚠️ Received non-text message")
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
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
        print("[Gateway] 🔴 Closed with code \(code). Reason: \(reason ?? "none")")
        if code == 4004 {
            print("[Gateway] ❌ Invalid token — check your bot token.")
        } else {
            reconnect()
        }
    }
}
