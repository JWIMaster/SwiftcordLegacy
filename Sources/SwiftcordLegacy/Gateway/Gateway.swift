import Foundation
import Dispatch
import FoundationCompatKit
import SocketRocket
import UIKit
import Darwin
import zlib

public typealias DispatchWorkItem = FoundationCompatKit.DispatchWorkItem

public class Gateway: NSObject {
    
    let token: String
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
    
    public var onTypingStart: ((Snowflake, Snowflake) -> Void)?
    
    public var onGuildMemberListUpdate: (([Snowflake: GuildMember]) -> Void)?
    public var handleThreadListSync: ((_ guildId: Snowflake) -> Void)?
    let logger = LegacyLogger(fileName: "swiftcordlog.txt")
    /// Called after a reconnect so views can reattach observers
    public var onReconnect: (() -> Void)?
    
    internal var guildMemberChunkObservers: [( [Snowflake: GuildMember] ) -> Void] = []
    
    internal var presenceUpdateObservers: [( [Snowflake: PresenceType] ) -> Void] = []
    
    internal var pendingGuildSubscriptions: [(guildId: Snowflake, channelId: Snowflake   )] = []
    internal var isReady = false
    
    public var onInvalidToken: (() -> Void)?
    
    let payloadQueue = DispatchQueue(label: "com.swiftcord.payloadQueue")
    var didHandleReady = false
    let readyLock = NSLock()



    
    init(_ slClient: SLClient, token: String, gatewayUrl: String = "wss://gateway.discord.gg/?encoding=json&v=9") {
        self.slClient = slClient
        self.token = token
        self.gatewayUrl = gatewayUrl
    }
    
    // MARK: - Connection
    func start() {
        logger.log("began connection")
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
        
        
        let data: [String: Any] = [
            "token": token,
            "properties": discordSuperProperties,
            "compress": false,
            "large_threshold": 50,
            "capabilities": 8209,
            "client_state": [:]
        ]
        send(Payload(op: 2, d: data))
        print("[Gateway] 🪪 Identify sent")
        logger.log("identify sent")
        
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
            logger.log("recieved ready")
            self.slClient.handleReady(data)
            
            isReady = true
            for (guildId, channelId) in pendingGuildSubscriptions {
                sendGuildSubscription(guildId: guildId, channelId: channelId)
            }
            pendingGuildSubscriptions.removeAll()
            
        case .guildCreate:
            break
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
                    self.handleGuildMemberChunk(members)
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
        case .threadListSync:
            guard let guildIdStr = data["guild_id"] as? String,
                  let guildId = Snowflake(guildIdStr),
                  let guild = slClient.guilds[guildId],
                  let threadsArray = data["threads"] as? [[String: Any]] else { return }
            
            for threadData in threadsArray {
                let thread = GuildThread(slClient, threadData)
                
                // Make sure it's assigned to the correct forum
                if let parentId = thread.parentID,
                   let parentForum = guild.channels[parentId] as? GuildForum {
                    parentForum.threads[thread.id!] = thread
                }
            }
            
            // Notify UI if needed
            DispatchQueue.main.async {
                self.handleThreadListSync?(guildId)
            }
        case .typingStart:
            guard let channelID = Snowflake(data["channel_id"] as? String), let userID = Snowflake(data["user_id"] as? String) else { return }
            if let guildID = Snowflake(data["guild_id"] as? String),
                let guild = self.slClient.guilds[guildID],
                let memberJson = data["member"] as? [String: Any] {
                
                let member = GuildMember(self.slClient, memberJson, guild)
                if (guild.members[member.user.id!] == nil) {
                    guild.members[member.user.id!] = member
                }
            }
            DispatchQueue.main.async {
                self.onTypingStart?(channelID, userID)
            }
        case .presenceUpdate:
            guard let presence = PresenceType(rawValue: data["status"] as! String), let userJson = data["user"] as? [String: Any], let userID = Snowflake(userJson["id"] as? String) else { return }
            self.slClient.presences[userID] = presence
            DispatchQueue.main.async {
                self.handlePresenceUpdate([userID: presence])
            }
            
        }
        
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

