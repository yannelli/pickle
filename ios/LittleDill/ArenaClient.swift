import Foundation
import SwiftUI

struct ArenaLaunch: Identifiable {
    let id = UUID()
    var room: String?
    static func validRoom(_ room:String) -> Bool { room.utf8.count == 6 && room.utf8.allSatisfy { (48...57).contains($0) || (65...90).contains($0) } }
    static func newRoom() -> String { String((0..<6).map { _ in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".randomElement()! }) }
    static let defaultServer = "wss://arena.littledill.app/arena"
    static var server: String { Bundle.main.object(forInfoDictionaryKey:"ArenaServerURL") as? String ?? defaultServer }
    /// The arena web page on the server's host: `wss://host/arena` becomes `https://host/`.
    static func site(server:String = ArenaLaunch.server) -> URLComponents {
        guard var url = URLComponents(string:server), url.host != nil else {return site(server:defaultServer)}
        url.scheme = "https"; url.path = "/"; url.query = nil; url.fragment = nil
        return url
    }
    static func shareURL(room:String? = nil) -> URL {
        var url = site()
        if let room, validRoom(room) {url.queryItems = [URLQueryItem(name:"room",value:room)]}
        return url.url!
    }
    static func from(_ url:URL) -> ArenaLaunch? {
        let native = url.scheme == "littledill" && url.host == "arena"
        let web = url.scheme == "https" && url.host == site().host && (url.path.isEmpty || url.path == "/")
        guard native || web else {return nil}
        guard let code = URLComponents(url:url,resolvingAgainstBaseURL:false)?.queryItems?.first(where:{$0.name == "room"})?.value?.uppercased() else {return ArenaLaunch()}
        return validRoom(code) ? ArenaLaunch(room:code) : nil
    }
}
struct ArenaCell: Decodable, Identifiable {
    let id: String
    let x: Double
    let y: Double
    let mass: Double
    var drain: Double? = nil
    var radius: Double { ArenaPlayer.radius(for:mass) }
    var draining: Bool { (drain ?? 0) > 0 }
}
enum ArenaGadget: String, CaseIterable {
    case slicer, shaker, grater
    /// Bundled web audio loops keep each gadget's stroke rhythm.
    var drainSound: DillSound { switch self {case .slicer: .slicer; case .shaker: .shaker; case .grater: .grater} }
}
/// A kitchen gadget field: cells overlapping it slow down and leak mass.
struct ArenaHazard: Decodable, Identifiable {
    let id: String
    let x: Double
    let y: Double
    let r: Double
    var kind: String? = nil
    private enum CodingKeys: String, CodingKey { case id, x, y, r, kind }
    init(id:String,x:Double,y:Double,r:Double,kind:String? = nil) {self.id = id; self.x = x; self.y = y; self.r = r; self.kind = kind}
    init(from decoder:Decoder) throws {
        let c = try decoder.container(keyedBy:CodingKeys.self)
        x = try c.decode(Double.self,forKey:.x); y = try c.decode(Double.self,forKey:.y); r = try c.decode(Double.self,forKey:.r)
        id = (try? c.decode(String.self,forKey:.id)) ?? (try? c.decode(Int.self,forKey:.id)).map(String.init) ?? "\(x),\(y)"
        kind = try? c.decode(String.self,forKey:.kind)
    }
    /// Matches `hazardKind` in arena-web/arena-core.mjs: an unknown or missing kind falls back by list position.
    func gadget(index:Int) -> ArenaGadget { ArenaGadget(rawValue:kind ?? "") ?? ArenaGadget.allCases[index % ArenaGadget.allCases.count] }
    func touches(_ cell:ArenaCell) -> Bool { hypot(cell.x-x,cell.y-y) < r + cell.radius }
    /// The gadget draining a cell: the field whose edge is closest, like `hazardFor` on the web.
    static func draining(_ cell:ArenaCell,in hazards:[ArenaHazard]) -> ArenaGadget? {
        let edge = {(h:ArenaHazard) in hypot(cell.x-h.x,cell.y-h.y) - h.r}
        guard let index = hazards.indices.min(by:{edge(hazards[$0]) < edge(hazards[$1])}) else {return nil}
        return hazards[index].gadget(index:index)
    }
}
struct ArenaCamera {
    let center: CGPoint
    let zoom: Double
}
/// A look this build doesn't know decodes as the server default, so a new server look can't fail every state message.
protocol ArenaLook: RawRepresentable<String> { static var serverDefault: Self { get } }
extension Brine: ArenaLook { static var serverDefault: Brine { .classic } }
extension Outfit: ArenaLook { static var serverDefault: Outfit { .sprout } }
@propertyWrapper struct ServerLook<Value: ArenaLook>: Decodable {
    let wrappedValue: Value
    init(from decoder: Decoder) throws { wrappedValue = Value(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .serverDefault }
}
struct ArenaPlayer: Decodable, Identifiable {
    let id: String
    let name: String
    @ServerLook var brine: Brine
    @ServerLook var outfit: Outfit
    let variety: String?
    let bot: Bool
    let x: Double
    let y: Double
    let mass: Double
    let best: Int
    let earnedMass: Double?
    let kills: Int
    let alive: Bool
    let shield: Double
    let dash: Double
    let cooldown: Double
    let respawn: Double
    let eatenBy: String
    var cells: [ArenaCell]?
    let splitCooldown: Double?
    let merge: Double?
    let hurt: Double?
    let tear: Double?
    static let eatOverlap = 0.6
    var pieces: [ArenaCell] {
        guard alive else {return []}
        return cells ?? [ArenaCell(id:id,x:x,y:y,mass:mass)]
    }
    var isCucumber: Bool {pieces.count > 1}
    /// Older servers send no variety, so fall back to the brine's first variety like the web client.
    var look: PickleVariety {PickleVariety.all.first {$0.id == variety} ?? PickleVariety.first(brine:brine.rawValue)}
    var canSplit: Bool { cells != nil && alive && pieces.count < 8 && (splitCooldown ?? 0) <= 0 && pieces.contains {$0.mass >= 60} }
    var splitHint: String {
        guard alive else {return "Respawn to split"}
        guard cells != nil else {return "Rejoin to split"}
        if pieces.count >= 8 {return "8 cucumbers max"}
        if let splitCooldown, splitCooldown > 0 {return "Ready in \(Int(ceil(splitCooldown)))s"}
        return pieces.contains {$0.mass >= 60} ? "Launch a half" : isCucumber ? "One cucumber needs 60" : "One pickle needs 60"
    }
    var regroupHint: String {
        guard pieces.count > 1 else {return "Split to chase. Regroup to grow."}
        return (merge ?? 0) > 0 ? "\(pieces.count) cucumbers · regroup in \(Int(ceil(merge ?? 0)))s" : "\(pieces.count) cucumbers · regrouping"
    }
    var radius: Double { Self.radius(for:mass) }
    static func radius(for mass:Double) -> Double {
        let base = 13 + sqrt(max(0,mass)) * 3.4
        let excess = max(0,base - 149)
        return base <= 149 ? base : 149 + 260 * excess / (260 + excess)
    }
    static func cameraZoom(mass:Double,width:Double,height:Double) -> Double {
        min(1.08,min(width,height) / (radius(for:mass) * 8 + 340))
    }
    static func camera(cells:[ArenaCell],mass:Double,width:Double,height:Double) -> ArenaCamera {
        guard !cells.isEmpty else {return ArenaCamera(center:.zero,zoom:cameraZoom(mass:mass,width:width,height:height))}
        // Include every piece, with room for hats, labels and the controls around the playfield.
        let left = cells.map {$0.x - $0.radius * 1.3}.min()!
        let right = cells.map {$0.x + $0.radius * 1.3}.max()!
        let top = cells.map {$0.y - $0.radius * 1.4}.min()!
        let bottom = cells.map {$0.y + $0.radius * 1.4}.max()!
        let zoom = min(cameraZoom(mass:mass,width:width,height:height),width * 0.72 / max(1,right-left),height * 0.54 / max(1,bottom-top))
        return ArenaCamera(center:CGPoint(x:(left+right)/2,y:(top+bottom)/2),zoom:zoom)
    }
    /// Log-space exponential ease: 7/s while zooming out, 2.5/s while zooming in.
    static func easeZoom(current:Double,target:Double,dt:Double) -> Double {
        guard current.isFinite, current > 0, target.isFinite, target > 0 else {return target}
        let rate = target < current ? 7.0 : 2.5
        return exp(log(current) + (log(target) - log(current)) * (1 - exp(-rate * max(0,dt))))
    }
}
struct ArenaSnapshot: Decodable {
    static let maximumMessageSize = 524288
    let tick: Int
    let time: Double
    let width: Double
    let height: Double
    let humans: Int
    let bots: Int
    let players: [ArenaPlayer]
    let food: [[Double]]?
    let foodAdded: [[Double]]?
    let foodRemoved: [Int]?
    var hazards: [ArenaHazard]? = nil
    var population: Int { humans + bots }
    func supports(playerID:String) -> Bool {
        players.count <= 64 && width > 0 && height > 0 && players.contains {$0.id == playerID}
    }
    func updatedFood(from current:[[Double]]) -> [[Double]]? {
        guard food != nil || !(foodAdded ?? []).isEmpty || !(foodRemoved ?? []).isEmpty else {return nil}
        var inventory:[Double:[Double]] = [:]
        for pellet in food ?? current where pellet.count == 4 {inventory[pellet[0]] = pellet}
        for id in foodRemoved ?? [] {inventory.removeValue(forKey:Double(id))}
        for pellet in foodAdded ?? [] where pellet.count == 4 {inventory[pellet[0]] = pellet}
        return inventory.values.sorted {$0[0] < $1[0]}
    }
    /// First-seen times of spit pellets (value 4) that land near a device; ids missing from `food` are dropped.
    static func spitArrivals(food:[[Double]],hazards:[ArenaHazard],seen:[Double:Date],at time:Date) -> [Double:Date] {
        var arrivals:[Double:Date] = [:]
        for pellet in food where pellet.count == 4 && pellet[3] == 4 {
            if let first = seen[pellet[0]] {arrivals[pellet[0]] = first}
            else if hazards.contains(where:{hypot(pellet[1]-$0.x,pellet[2]-$0.y) <= $0.r + 200}) {arrivals[pellet[0]] = time}
        }
        return arrivals
    }
}
struct ArenaHeader: Decodable {
    let type: String
    var id: String?
    var room: String?
    var `protocol`: Int?
    var resumeToken: String?
    var resumeRoom: String?
    var reconnectGraceSeconds: Double?
    var resumed: Bool?
    func resume(at now:Date) -> ArenaResume? {
        guard let token = resumeToken, let room = resumeRoom, room == self.room, let seconds = reconnectGraceSeconds else {return nil}
        let candidate = ArenaResume(token:token,room:room,deadline:now.addingTimeInterval(seconds),grace:seconds)
        return candidate.isValid ? candidate : nil
    }
}

@MainActor final class ArenaClient: ObservableObject {
    enum Status { case connecting, reconnecting, playing, disconnected }
    @Published private(set) var status: Status = .connecting
    @Published private(set) var snapshot: ArenaSnapshot?
    @Published private(set) var previous: ArenaSnapshot?
    @Published private(set) var food: [[Double]] = []
    @Published private(set) var playerID = ""
    @Published private(set) var room = ""
    @Published private(set) var errorMessage = ""
    @Published private(set) var receivedAt = Date()
    @Published private(set) var ping = 0
    private(set) var spitAt: [Double:Date] = [:]
    @Published private(set) var reconnectDeadline: Date?
    private let defaults: UserDefaults
    private let cleanup: @MainActor (ArenaResume?,URLSessionWebSocketTask?) -> Void
    private var savedResume: ArenaResume?
    private var savedAt = Date.distantPast
    private var pet: PetState?
    private var requestedRoom: String?
    private var suspended = false
    private var retryCount = 0
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void,Never>?
    private var inputTask: Task<Void,Never>?
    private var timeoutTask: Task<Void,Never>?
    private var retryTask: Task<Void,Never>?
    private var direction = CGVector.zero
    private var sequence = 0
    private var pingAt = Date()
    private var lastReceived = Date()
    init(defaults:UserDefaults = ArenaResume.defaults,cleanup:@escaping @MainActor (ArenaResume?,URLSessionWebSocketTask?) -> Void = ArenaClient.finishLeave) {self.defaults = defaults; self.cleanup = cleanup}
    var me: ArenaPlayer? { snapshot?.players.first {$0.id == playerID} }
    var leaders: [ArenaPlayer] { Array((snapshot?.players.filter(\.alive) ?? []).sorted {$0.mass > $1.mass}.prefix(5)) }
    var best: Int { me?.best ?? 0 }
    var rank: Int { ((snapshot?.players.filter(\.alive).sorted {$0.mass > $1.mass}.firstIndex {$0.id == playerID}) ?? 0) + 1 }

    func connect(pet:PetState,room requestedRoom:String?,fresh:Bool = false) {
        guard requestedRoom.map(ArenaLaunch.validRoom) ?? true else {fail("That room code isn’t valid."); return}
        let oldResume = savedResume ?? ArenaResume.load(from:defaults)
        let oldSocket = socket
        closeTransport(cancelSocket:!fresh); retryTask?.cancel(); retryTask = nil
        self.pet = pet; self.requestedRoom = requestedRoom; suspended = false; retryCount = 0; errorMessage = ""
        if fresh {cleanup(oldResume,oldSocket); clearResume()}
        else {savedResume = oldResume}
        if savedResume?.matches(room:requestedRoom) == false {
            errorMessage = "A different garden is holding your run. Leave it or start a fresh run."
            status = .disconnected
            return
        }
        if savedResume == nil {clearResume(); snapshot = nil; previous = nil; food = []; spitAt = [:]; playerID = ""}
        openConnection()
    }
    private func openConnection() {
        guard let pet, !suspended else {return}
        closeTransport()
        let resuming = savedResume != nil
        if let savedResume, !savedResume.canResume(at:Date()) {expireResume(); return}
        status = resuming ? .reconnecting : .connecting
        reconnectDeadline = savedResume?.deadline
        let base = ArenaLaunch.server
        guard var url = URLComponents(string:base), url.scheme == "wss", url.host != nil else { fail("The arena server address is not configured."); return }
        var query = [URLQueryItem(name:"name",value:pet.name),URLQueryItem(name:"brine",value:pet.brine.rawValue),URLQueryItem(name:"outfit",value:pet.outfit.rawValue),URLQueryItem(name:"variety",value:pet.life.variety),URLQueryItem(name:"foodDeltas",value:"1"),URLQueryItem(name:"reconnect",value:"1")]
        if let savedResume {query += [URLQueryItem(name:"resumeToken",value:savedResume.token),URLQueryItem(name:"resumeRoom",value:savedResume.room)]}
        else if let requestedRoom {guard ArenaLaunch.validRoom(requestedRoom) else {fail("That room code isn’t valid."); return}; query.append(URLQueryItem(name:"room",value:requestedRoom))}
        url.queryItems = query
        guard let endpoint = url.url else {fail("Couldn’t open the arena address."); return}
        let socket = URLSession.shared.webSocketTask(with:endpoint)
        socket.maximumMessageSize = ArenaSnapshot.maximumMessageSize
        self.socket = socket; direction = .zero; sequence = 0; lastReceived = Date(); socket.resume()
        receiveTask = Task { [weak self,weak socket] in
            guard let socket else {return}
            do {
                while !Task.isCancelled {
                    let message = try await socket.receive()
                    guard let self, self.socket === socket else {return}
                    let data: Data
                    switch message {case .string(let string): data = Data(string.utf8); case .data(let bytes): data = bytes; @unknown default: continue}
                    self.consume(data)
                }
            } catch {guard !Task.isCancelled, let self, self.socket === socket else {return}; self.connectionLost(socket)}
        }
        timeoutTask = Task { [weak self,weak socket] in
            let seconds = resuming ? min(5,max(0.1,self?.savedResume?.deadline.timeIntervalSinceNow ?? 5)) : 12
            try? await Task.sleep(for:.seconds(seconds))
            guard !Task.isCancelled, let self, let socket, self.socket === socket, self.status != .playing else {return}
            self.connectionLost(socket)
        }
    }
    func consume(_ data:Data,at now:Date = Date()) {
        guard let header = try? JSONDecoder().decode(ArenaHeader.self,from:data) else {fail("The arena sent an unreadable message. Please start a fresh run."); return}
        lastReceived = now
        switch header.type {
        case "welcome":
            guard header.protocol == 1, let id = header.id, let room = header.room else {fail("This arena needs a newer version of Little Dill."); return}
            let incomingResume = header.resume(at:now)
            if let existing = savedResume {
                guard existing.canResume(at:now) else {expireResume(); return}
                guard header.resumed == true, let incomingResume,
                      incomingResume.token == existing.token, incomingResume.room == existing.room,
                      playerID.isEmpty || playerID == id else {fail("The server could not restore this run. Your best is saved."); return}
                // A welcome alone is not proof the run was restored. Keep its original return deadline until state arrives.
            } else {
                guard header.resumed != true else {fail("The arena sent an unsupported welcome. Please start a fresh run."); return}
                savedResume = incomingResume
            }
            playerID = id; self.room = room
            reconnectDeadline = savedResume?.deadline; persistResume(force:true)
        case "state":
            if status == .reconnecting, savedResume?.canResume(at:now) != true {expireResume(); return}
            guard !playerID.isEmpty, let next = try? JSONDecoder().decode(ArenaSnapshot.self,from:data), next.supports(playerID:playerID) else {fail("This arena sent an unsupported game state."); return}
            if status == .reconnecting && next.food == nil {fail("The garden could not restore its food. Start a fresh run."); return}
            if status != .reconnecting, let snapshot, next.tick < snapshot.tick {return}
            let restored = status != .playing
            previous = status == .reconnecting ? nil : snapshot; snapshot = next; receivedAt = now
            if let food = next.updatedFood(from:self.food) {
                self.food = food
                spitAt = ArenaSnapshot.spitArrivals(food:food,hazards:next.hazards ?? [],seen:spitAt,at:restored ? .distantPast : receivedAt)
            }
            if var resumed = savedResume {resumed.deadline = lastReceived.addingTimeInterval(resumed.grace); savedResume = resumed; persistResume(force:restored)}
            if restored {status = .playing; retryCount = 0; reconnectDeadline = nil; timeoutTask?.cancel(); startInputs()}
        case "resume-expired": fail("The server could not restore this run. Your best is saved.")
        case "pong": ping = min(9999,Int(Date().timeIntervalSince(pingAt) * 1000))
        default: break
        }
    }
    private func persistResume(force:Bool = false) {
        guard let savedResume, force || Date().timeIntervalSince(savedAt) >= 1 else {return}
        savedResume.save(to:defaults); savedAt = Date()
    }
    private func clearResume() {savedResume = nil; reconnectDeadline = nil; defaults.removeObject(forKey:ArenaResume.key)}
    private func expireResume() {fail("Your 30-second return window has ended. Your best is saved—ready for a fresh pickle?")}
    @discardableResult func handleTerminalClose(_ code:Int) -> Bool {
        if code == 4001 {fail("This run was reopened on another connection. You can start a fresh run here."); return true}
        if code == 1008 {fail("The garden ended this connection. Start a fresh run when you’re ready."); return true}
        return false
    }
    private func connectionLost(_ failedSocket:URLSessionWebSocketTask) {
        guard socket === failedSocket else {return}
        if handleTerminalClose(failedSocket.closeCode.rawValue) {return}
        closeTransport()
        guard !suspended else {return}
        guard let savedResume else {fail("The garden couldn’t be reached. Check your connection and try a fresh run."); return}
        guard savedResume.canResume(at:Date()) else {expireResume(); return}
        status = .reconnecting; reconnectDeadline = savedResume.deadline
        retryCount += 1
        let delay = min(Self.retryDelay(for:retryCount),savedResume.deadline.timeIntervalSinceNow)
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(for:.seconds(max(0,delay)))
            guard !Task.isCancelled, let self, !self.suspended else {return}
            self.retryTask = nil; self.openConnection()
        }
    }
    static func retryDelay(for attempt:Int) -> TimeInterval {
        let delays: [TimeInterval] = [0.25,0.7,1.5,2.5,4]
        return delays[min(max(0,attempt-1),delays.count-1)]
    }
    private func startInputs() {
        inputTask?.cancel()
        inputTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                guard let self, let socket = self.socket, self.status == .playing else {return}
                if Date().timeIntervalSince(self.lastReceived) > 8 {self.connectionLost(socket); return}
                self.sequence += 1
                let input: [String:Any] = ["type":"input","seq":self.sequence,"x":self.direction.dx,"y":self.direction.dy]
                do {
                    let data = try JSONSerialization.data(withJSONObject:input)
                    try await socket.send(.string(String(decoding:data,as:UTF8.self)))
                    tick += 1
                    if tick % 60 == 0 {self.pingAt = Date(); try await socket.send(.string("{\"type\":\"ping\"}"))}
                } catch {
                    // Let a server close frame (especially takeover/policy rejection) reach the receiver first.
                    try? await Task.sleep(for:.milliseconds(100))
                    if !Task.isCancelled, self.socket === socket {self.connectionLost(socket)}
                    return
                }
                try? await Task.sleep(for:.milliseconds(50))
            }
        }
    }
    func steer(_ vector:CGVector) {direction = vector}
    func dash() {sendAction("dash")}
    func split() {guard me?.canSplit == true else {return}; sendAction("split")}
    func respawn() {direction = .zero; sendAction("respawn")}
    private func sendAction(_ type:String) {
        guard let socket, status == .playing else {return}
        Task { [weak self,weak socket] in
            guard let socket else {return}
            do {try await socket.send(.string("{\"type\":\"\(type)\"}"))}
            catch {
                try? await Task.sleep(for:.milliseconds(100))
                guard let self, self.socket === socket else {return}; self.connectionLost(socket)
            }
        }
    }
    private func fail(_ message:String) {closeTransport(); retryTask?.cancel(); retryTask = nil; clearResume(); errorMessage = message; status = .disconnected}
    func suspend() {
        suspended = true; persistResume(force:true); retryTask?.cancel(); retryTask = nil; closeTransport()
        status = savedResume == nil ? .disconnected : .reconnecting
        reconnectDeadline = savedResume?.deadline
    }
    func resumeIfNeeded() {
        guard suspended else {return}
        suspended = false
        guard let savedResume else {fail("This garden could not hold your run. Start a fresh run."); return}
        guard savedResume.canResume(at:Date()) else {expireResume(); return}
        openConnection()
    }
    func leave() {
        let credentials = savedResume
        clearResume(); suspended = true; retryTask?.cancel(); retryTask = nil
        let leaving = socket; closeTransport(cancelSocket:false)
        cleanup(credentials,leaving)
        status = .disconnected
    }
    static func finishLeave(_ saved:ArenaResume?,_ existing:URLSessionWebSocketTask?) {
        var leaving = existing
        if leaving == nil, let saved, saved.canResume(at:Date()) {
            let base = ArenaLaunch.server
            if let url = saved.endpoint(base:base) {leaving = URLSession.shared.webSocketTask(with:url); leaving?.resume()}
        }
        guard let leaving else {return}
        Task {
            let timeout = Task {try? await Task.sleep(for:.seconds(2)); if !Task.isCancelled {leaving.cancel(with:.goingAway,reason:nil)}}
            defer {timeout.cancel(); leaving.cancel(with:.normalClosure,reason:nil)}
            try? await leaving.send(.string("{\"type\":\"leave\"}"))
        }
    }
    func stop() {suspend()}
    private func closeTransport(cancelSocket:Bool = true) {
        if cancelSocket {receiveTask?.cancel()}
        receiveTask = nil; inputTask?.cancel(); timeoutTask?.cancel()
        let closing = socket; socket = nil
        if cancelSocket {closing?.cancel(with:.goingAway,reason:nil)}
        direction = .zero; sequence = 0
    }
    deinit {receiveTask?.cancel(); inputTask?.cancel(); timeoutTask?.cancel(); retryTask?.cancel(); socket?.cancel(with:.goingAway,reason:nil)}
}
