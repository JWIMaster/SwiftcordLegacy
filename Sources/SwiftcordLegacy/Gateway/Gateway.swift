import Foundation
import Dispatch
import FoundationCompatKit
import SocketRocket
import UIKit
import Darwin

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
    
    // Heartbeat
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
    
    public var onGuildMemberListUpdate: (([Snowflake: GuildMember]) -> Void)?
    let logger = LegacyLogger(fileName: "swiftcordlog.txt")
    /// Called after a reconnect so views can reattach observers
    public var onReconnect: (() -> Void)?
    
    
    private var pendingGuildSubscriptions: [(guildId: Snowflake, channelId: Snowflake   )] = []
    private var isReady = false
    
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
        socket?.setDelegateDispatchQueue(.global(qos: .userInitiated))
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
        heartbeatTimer?.schedule(deadline: .now() + heartbeatInterval, repeating: heartbeatInterval)
        heartbeatTimer?.setEventHandler { [weak self] in
            self?.sendHeartbeat()
        }
        heartbeatTimer?.resume()
    }
    
    private func sendHeartbeat() {
        if awaitingHeartbeatAck {
            print("[Gateway] ⚠️ Missed heartbeat ACK — connection may be zombied")
            handleZombiedConnection()
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
    
    private func handleZombiedConnection() {
        print("[Gateway] ⚠️ Missed heartbeat ACK — reconnecting...")
        closeAndReconnect(code: 4000)
    }

    
    // MARK: - Identify / Resume
    func identify() {
        let now = Date()
        let cooldownInterval: TimeInterval = 5
        
        if identifyCooldown, let last = lastIdentifyDate {
            let delta = now.timeIntervalSince(last)
            if delta < cooldownInterval {
                let delay = cooldownInterval - delta + 1
                print("[Gateway] ⏱ Identify cooldown. Delaying \(delay)s")
                DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.identify()
                }
                return
            }
        }
        
        identifyCooldown = true
        lastIdentifyDate = now
        
        let osVersion = UIDevice.current.systemVersion
        let systemLocale = Locale.current.identifier
        let device: String = {
            switch UIDevice.current.userInterfaceIdiom {
            case .phone:
                return "iPhone"
            case .pad:
                return "iPad"
            case .unspecified:
                return "iPhone"
            case .mac:
                return "Mac"
            default:
                return "iPhone"
            }
        }()
        // Get machine architecture
        var systemInfo = utsname()
        uname(&systemInfo)
        let arch = withUnsafePointer(to: &systemInfo.machine) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        
        
        let data: [String: Any] = [
            "token": token,
            "properties": [
                "browser": "Discord Client",
                "os": "iOS",
                "device": device,
                "release_channel": "stable",
                "client_version": "0.0.296",
                "os_version": osVersion,
                "os_arch": arch,
                "system_locale": systemLocale,
                "client_build_number": 197575
            ],
            "compress": false,
            "large_threshold": 250,
            "presence": [
                "status": "online",
                "since": nil,
                "afk": false,
                "activities": [
                ]
            ],
            "capabilities": 157,
            "client_state": [:]
        ]
        send(Payload(op: 2, d: data))
        print("[Gateway] 🪪 Identify sent")
        
        DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + cooldownInterval) { [weak self] in
            self?.identifyCooldown = false
        }
    }
    
    func resume() {
        guard let sessionId = sessionId, let seq = lastSeq else {
            print("[Gateway] Missing session or seq — cannot resume, identifying instead")
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
        logger.log("gateway resume")
    }
    
    // MARK: - Payload Handling
    func handlePayload(_ payload: Payload) {
        if let seq = payload.s { lastSeq = seq }
        //print("[Gateway] Event: \(payload.t ?? "nil")")

        switch payload.op {
        case 0: handleDispatch(payload)
        case 1, 7, 9, 10, 11: handleGateway(payload)
        default: logger.log("[Gateway] Unknown OP: \(payload.op)")
        }
    }
    
    private var guildMemberListUpdateObservers: [( [Snowflake: GuildMember] ) -> Void] = []
    
    public func addGuildMemberListUpdateObserver(_ observer: @escaping ([Snowflake: GuildMember]) -> Void) {
        guildMemberListUpdateObservers.append(observer)
    }
    
    // Call this when event arrives:
    private func handleGuildMemberListUpdate(_ members: [Snowflake: GuildMember]) {
        for observer in guildMemberListUpdateObservers {
            observer(members)
        }
    }
    
    private func handleDispatch(_ payload: Payload) {
        guard let event = Event(rawValue: payload.t!) else { return }
        guard let data = payload.d as? [String: Any] else { return }
        switch event {
        case .ready:
            print("READY")
            isReady = true
            for (guildId, channelId) in pendingGuildSubscriptions {
                sendGuildSubscription(guildId: guildId, channelId: channelId)
            }
            pendingGuildSubscriptions.removeAll()

        case .guildCreate:
            print("a")
        case .messageCreate:
            let message = Message(slClient, data)
            DispatchQueue.main.async { self.onMessageCreate?(message) }
        case .messageUpdate:
            let message = Message(slClient, data)
            DispatchQueue.main.async { self.onMessageUpdate?(message) }
        case .messageDelete:
            let message = Message(slClient, data)
            DispatchQueue.main.async { self.onMessageDelete?(message) }
        case .guildMembersChunk:
            guard let guildIdStr = data["guild_id"] as? String,
                  let guildId = Snowflake(guildIdStr),
                  let membersArray = data["members"] as? [[String: Any]],
                  let guild = slClient.guilds[guildId] else { return }
            
            for memberJson in membersArray {
                let member = GuildMember(slClient, memberJson, guild)
                guild.members[member.user.id!] = member
            }

            
            let members = guild.members
            if !members.isEmpty {
                DispatchQueue.main.async {
                    self.handleGuildMemberListUpdate(members)
                }
            }
        case .guildMemberListUpdate:
            let guildID = Snowflake(data["guild_id"] as? String)
            
            guard let guild = self.slClient.guilds[guildID!] else { return }
            
            if let ops = data["ops"] as? [[String: Any]] {
                for op in ops {
                    if let items = op["items"] as? [[String: Any]] {
                        for item in items {
                            if let memberJson = item["member"] as? [String: Any] {
                                let member = GuildMember(slClient, memberJson, guild)
                                guild.members[member.user.id!] = member
                            }
                        }
                    }
                }
            }
            let members = guild.members
            guard !members.isEmpty else { return }
            DispatchQueue.main.async {
                self.handleGuildMemberListUpdate(members)
            }
        }
    }
    
    public func requestGuildMemberChunk(guildId: Snowflake, userIds: Set<Snowflake>, includePresences: Bool = false) {
        guard !userIds.isEmpty else { return }
        
        // Convert user IDs to array of strings
        let userIdsArray = userIds.map { "\($0.rawValue)" }
        
        // Prepare the payload data
        let data: [String: Any] = [
            "guild_id": [ "\(guildId.rawValue)" ],  // Discord expects array of guild IDs
            "user_ids": userIdsArray,
            "presences": includePresences,
            "limit": NSNull(),  // Not used in this mode
            "query": NSNull()   // Not used in this mode
        ]
        
        // Wrap in REQUEST_GUILD_MEMBERS op
        let payload = Payload(op: 8, d: data) // 8 = REQUEST_GUILD_MEMBERS
        send(payload)
        
        print("[Gateway] Requested \(userIds.count) members from guild \(guildId.rawValue)")
    }

    
    public func subscribeToGuildChannel(guildId: Snowflake, channelId: Snowflake) {
        if isReady {
            sendGuildSubscription(guildId: guildId, channelId: channelId)
        } else {
            pendingGuildSubscriptions.append((guildId, channelId))
        }
    }
    
    public func unsubscribeFromGuildChannel(guildId: Snowflake, channelId: Snowflake) {
        let data: [String: Any] = [
            "guild_id": "\(guildId.rawValue)",
            "typing": false,
            "threads": false,
            "activities": false,
            "thread_member_lists": [],
            "members": [],
            "channels": [
                "\(channelId.rawValue)": []
            ]
        ]
        
        send(Payload(op: 14, d: data))
    }


    
    private func sendGuildSubscription(guildId: Snowflake, channelId: Snowflake) {
        let data: [String: Any] = [
            "guild_id": "\(guildId.rawValue)",
            "typing": true,
            "threads": true,
            "activities": true,
            "thread_member_lists": [],
            "members": [],
            "channels": [
                "\(channelId.rawValue)": [[0, 99]]
            ]
        ]
        send(Payload(op: 14, d: data))
    }
    
    private func handleGateway(_ payload: Payload) {
        guard let op = OP(rawValue: payload.op) else { return }
        
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
            print("[Gateway] ❌ Invalid session — reconnecting")
            reconnect()
        case .reconnect:
            logger.log("[Gateway] 🔁 Server requested reconnect")
            reconnect()
        default:
            break
        }
    }
    
    
    
    // MARK: - Reconnect
    private func closeAndReconnect(code: Int) {
        stop()
        isReconnecting = true
        
        // Reset buckets so old items don't block the queue
        globalBucket.reset()
        presenceBucket.reset()
        
        print("[Gateway] Closing zombied connection (code \(code)) and reconnecting...")
        start()
        
        // notify observers so they can reattach
        DispatchQueue.main.async { [weak self] in
            self?.onReconnect?()
        }
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
