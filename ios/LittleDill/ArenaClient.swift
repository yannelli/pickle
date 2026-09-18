import Foundation
import SwiftUI

struct ArenaLaunch: Identifiable {
    let id = UUID()
    var room: String?
    static func validRoom(_ room:String) -> Bool { room.count == 6 && room.utf8.allSatisfy { (48...57).contains($0) || (65...90).contains($0) } }
    static func newRoom() -> String { String((0..<6).map { _ in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".randomElement()! }) }
    static func shareURL(room:String? = nil) -> URL {
        var url = URLComponents(string:"https://arena.littledill.app/")!
        if let room, validRoom(room) {url.queryItems = [URLQueryItem(name:"room",value:room)]}
        return url.url!
    }
    static func from(_ url:URL) -> ArenaLaunch? {
        let native = url.scheme == "littledill" && url.host == "arena"
        let web = url.scheme == "https" && url.host == "arena.littledill.app" && (url.path.isEmpty || url.path == "/")
        guard native || web else {return nil}
        guard let code = URLComponents(url:url,resolvingAgainstBaseURL:false)?.queryItems?.first(where:{$0.name == "room"})?.value else {return ArenaLaunch()}
        return validRoom(code) ? ArenaLaunch(room:code) : nil
    }
}
struct ArenaCell: Decodable, Identifiable {
    let id: String
    let x: Double
    let y: Double
    let mass: Double
    var radius: Double { ArenaPlayer.radius(for:mass) }
}
struct ArenaCamera {
    let center: CGPoint
    let zoom: Double
}
struct ArenaPlayer: Decodable, Identifiable {
    let id: String
    let name: String
    let brine: Brine
    let outfit: Outfit
    let bot: Bool
    let x: Double
    let y: Double
    let mass: Double
    let best: Int
    let kills: Int
    let alive: Bool
    let shield: Double
    let dash: Double
    let cooldown: Double
    let respawn: Double
    let eatenBy: String
    let cells: [ArenaCell]?
    let splitCooldown: Double?
    let merge: Double?
    var pieces: [ArenaCell] {
        guard alive else {return []}
        return cells ?? [ArenaCell(id:id,x:x,y:y,mass:mass)]
    }
    var isCucumber: Bool {pieces.count > 1}
    var canSplit: Bool { cells != nil && alive && pieces.count < 4 && (splitCooldown ?? 0) <= 0 && pieces.contains {$0.mass >= 60} }
    var splitHint: String {
        guard cells != nil else {return "Rejoin to split"}
        if pieces.count >= 4 {return "4 cucumbers max"}
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
}
private struct ArenaHeader: Decodable {
    let type: String
    var id: String?
    var room: String?
    var `protocol`: Int?
}

@MainActor final class ArenaClient: ObservableObject {
    enum Status { case connecting, playing, disconnected }
    @Published private(set) var status: Status = .connecting
    @Published private(set) var snapshot: ArenaSnapshot?
    @Published private(set) var previous: ArenaSnapshot?
    @Published private(set) var food: [[Double]] = []
    @Published private(set) var playerID = ""
    @Published private(set) var room = ""
    @Published private(set) var errorMessage = ""
    @Published private(set) var receivedAt = Date()
    @Published private(set) var ping = 0
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void,Never>?
    private var inputTask: Task<Void,Never>?
    private var timeoutTask: Task<Void,Never>?
    private var direction = CGVector.zero
    private var sequence = 0
    private var pingAt = Date()
    private var lastReceived = Date()
    var me: ArenaPlayer? { snapshot?.players.first {$0.id == playerID} }
    var leaders: [ArenaPlayer] { Array((snapshot?.players.filter(\.alive) ?? []).sorted {$0.mass > $1.mass}.prefix(5)) }
    var best: Int { me?.best ?? 0 }
    var rank: Int { ((snapshot?.players.filter(\.alive).sorted {$0.mass > $1.mass}.firstIndex {$0.id == playerID}) ?? 0) + 1 }

    func connect(pet:PetState,room requestedRoom:String?) {
        stop(); status = .connecting; errorMessage = ""; playerID = ""; snapshot = nil; previous = nil; food = []
        let base = Bundle.main.object(forInfoDictionaryKey:"ArenaServerURL") as? String ?? "wss://arena.littledill.app/arena"
        guard var url = URLComponents(string:base), url.scheme == "wss", url.host != nil else { fail("The arena server address is not configured."); return }
        var query = [URLQueryItem(name:"name",value:pet.name),URLQueryItem(name:"brine",value:pet.brine.rawValue),URLQueryItem(name:"outfit",value:pet.outfit.rawValue),URLQueryItem(name:"foodDeltas",value:"1")]
        if let requestedRoom { guard ArenaLaunch.validRoom(requestedRoom) else {fail("That room code isn’t valid."); return}; query.append(URLQueryItem(name:"room",value:requestedRoom)) }
        url.queryItems = query
        guard let endpoint = url.url else {fail("Couldn’t open the arena address."); return}
        let socket = URLSession.shared.webSocketTask(with:endpoint)
        socket.maximumMessageSize = ArenaSnapshot.maximumMessageSize
        self.socket = socket; socket.resume()
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
            } catch { guard !Task.isCancelled, let self, self.socket === socket else {return}; self.fail("The connection to the garden was lost. Check your internet and jump back in.") }
        }
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for:.seconds(12))
            guard !Task.isCancelled, let self, self.status == .connecting else {return}
            self.fail("The garden didn’t answer in time. Check your internet, then try again.")
        }
    }
    private func consume(_ data:Data) {
        guard let header = try? JSONDecoder().decode(ArenaHeader.self,from:data) else {fail("The arena sent an unreadable message. Please rejoin."); return}
        lastReceived = Date()
        switch header.type {
        case "welcome":
            guard header.protocol == 1, let id = header.id, let room = header.room else {fail("This arena needs a newer version of Little Dill."); return}
            playerID = id; self.room = room
        case "state":
            guard !playerID.isEmpty, let next = try? JSONDecoder().decode(ArenaSnapshot.self,from:data), next.supports(playerID:playerID) else {fail("This arena sent an unsupported game state."); return}
            guard snapshot == nil || next.tick >= snapshot!.tick else {return}
            previous = snapshot; snapshot = next; receivedAt = Date()
            if let food = next.updatedFood(from:self.food) {self.food = food}
            if status == .connecting { status = .playing; timeoutTask?.cancel(); startInputs() }
        case "pong": ping = min(9999,Int(Date().timeIntervalSince(pingAt) * 1000))
        default: break
        }
    }
    private func startInputs() {
        inputTask?.cancel()
        inputTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                guard let self, let socket = self.socket, self.status == .playing else {return}
                if Date().timeIntervalSince(self.lastReceived) > 8 {self.fail("The garden stopped responding. Rejoin for a fresh spawn."); return}
                self.sequence += 1
                let input: [String:Any] = ["type":"input","seq":self.sequence,"x":self.direction.dx,"y":self.direction.dy]
                do {
                    let data = try JSONSerialization.data(withJSONObject:input)
                    try await socket.send(.string(String(decoding:data,as:UTF8.self)))
                    tick += 1
                    if tick % 60 == 0 {self.pingAt = Date(); try await socket.send(.string("{\"type\":\"ping\"}"))}
                } catch {if !Task.isCancelled {self.fail("Your connection dropped. Your pet is safe; rejoin to play again.")}; return}
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
            catch {guard let self, self.socket === socket else {return}; self.fail("Couldn’t reach the garden. Please rejoin.")}
        }
    }
    private func fail(_ message:String) {stop(); errorMessage = message; status = .disconnected}
    func stop() {
        receiveTask?.cancel(); inputTask?.cancel(); timeoutTask?.cancel()
        socket?.cancel(with:.goingAway,reason:nil); socket = nil; direction = .zero; sequence = 0
    }
    deinit { receiveTask?.cancel(); inputTask?.cancel(); timeoutTask?.cancel(); socket?.cancel(with:.goingAway,reason:nil) }
}
