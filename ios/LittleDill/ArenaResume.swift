import Foundation

struct ArenaResume: Codable, Equatable {
    let token: String
    let room: String
    var deadline: Date
    let grace: TimeInterval
    static let key = "little-dill.arena-resume.v1"
    static var defaults: UserDefaults {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {return UserDefaults(suiteName:"little-dill.ui-tests")!}
        #endif
        return .standard
    }
    var privateRoom: String? {room.hasPrefix("crew-") ? String(room.dropFirst(5)) : nil}
    var isValid: Bool {
        guard UUID(uuidString:token) != nil, grace == 30 else {return false}
        if let privateRoom {return ArenaLaunch.validRoom(privateRoom)}
        guard room.hasPrefix("public-"), let number = Int(room.dropFirst(7)), (1...16).contains(number) else {return false}
        return room == "public-\(number)"
    }
    func canResume(at now:Date) -> Bool {isValid && deadline > now && deadline.timeIntervalSince(now) <= 30}
    func matches(room requested:String?) -> Bool {requested.map {room == "crew-\($0)"} ?? room.hasPrefix("public-")}
    func save(to defaults:UserDefaults) {if let data = try? JSONEncoder().encode(self) {defaults.set(data,forKey:Self.key)}}
    func endpoint(base:String) -> URL? {
        guard isValid, var url = URLComponents(string:base), url.scheme == "wss", url.host != nil else {return nil}
        url.queryItems = [URLQueryItem(name:"reconnect",value:"1"),URLQueryItem(name:"resumeToken",value:token),URLQueryItem(name:"resumeRoom",value:room),URLQueryItem(name:"foodDeltas",value:"1")]
        return url.url
    }
    static func load(from defaults:UserDefaults = Self.defaults,at now:Date = Date()) -> ArenaResume? {
        guard let data = defaults.data(forKey:key), let saved = try? JSONDecoder().decode(Self.self,from:data), saved.canResume(at:now) else {defaults.removeObject(forKey:key); return nil}
        return saved
    }
}
