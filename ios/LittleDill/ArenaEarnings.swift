import Foundation

struct ArenaEarnings: Codable, Equatable {
    static let massPerCoin = 1_000.0
    static let dailyMassLimit = 1_000_000.0
    static let dailyCoinLimit = 1_000

    private(set) var day: String
    private(set) var mass: Double
    private(set) var session: String
    private(set) var total: Double

    init(day: String = "", mass: Double = 0, session: String = "", total: Double = 0) {
        self.day = day
        self.mass = mass
        self.session = session
        self.total = total
        self = normalized()
    }

    mutating func record(session incomingSession: String, earnedMass: Double, day incomingDay: String) -> Int {
        guard Self.validSession(incomingSession), Self.validDay(incomingDay),
              earnedMass.isFinite, earnedMass >= 0 else { return 0 }
        self = normalized()
        guard day.isEmpty || incomingDay >= day else { return 0 }
        if day != incomingDay {
            day = incomingDay
            mass = 0
        }
        if session != incomingSession {
            session = incomingSession
            total = 0
        }
        guard earnedMass > total else { return 0 }
        let delta = earnedMass - total
        total = earnedMass
        let before = Int(mass / Self.massPerCoin)
        mass = min(Self.dailyMassLimit, mass + min(delta, Self.dailyMassLimit - mass))
        let after = Int(mass / Self.massPerCoin)
        return max(0, min(Self.dailyCoinLimit - before, after - before))
    }

    func normalized() -> Self {
        var result = self
        if !Self.validDay(result.day) { result.day = ""; result.mass = 0 }
        if !result.mass.isFinite { result.mass = 0 }
        result.mass = min(Self.dailyMassLimit, max(0, result.mass))
        if !Self.validSession(result.session) { result.session = ""; result.total = 0 }
        if !result.total.isFinite || result.total < 0 { result.total = 0 }
        return result
    }

    private static func validSession(_ value: String) -> Bool {
        guard value.utf8.count <= 160 else { return false }
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        return parts.count == 2 && parts.allSatisfy { part in
            !part.isEmpty && part.utf8.allSatisfy { $0 >= 33 && $0 <= 126 }
        }
    }

    private static func validDay(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        guard bytes.count == 10, bytes[4] == 45, bytes[7] == 45,
              bytes.enumerated().allSatisfy({ index, byte in index == 4 || index == 7 || (48...57).contains(byte) }),
              let year = Int(String(decoding: bytes[0..<4], as: UTF8.self)),
              let month = Int(String(decoding: bytes[5..<7], as: UTF8.self)),
              let day = Int(String(decoding: bytes[8..<10], as: UTF8.self)),
              year > 0, (1...12).contains(month) else { return false }
        let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
        let days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        return (1...days[month - 1]).contains(day)
    }

    private enum CodingKeys: String, CodingKey { case day, mass, session, total }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(day: (try? values.decode(String.self, forKey: .day)) ?? "",
                  mass: (try? values.decode(Double.self, forKey: .mass)) ?? 0,
                  session: (try? values.decode(String.self, forKey: .session)) ?? "",
                  total: (try? values.decode(Double.self, forKey: .total)) ?? 0)
    }

    func encode(to encoder: Encoder) throws {
        let clean = normalized()
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(clean.day, forKey: .day)
        try values.encode(clean.mass, forKey: .mass)
        try values.encode(clean.session, forKey: .session)
        try values.encode(clean.total, forKey: .total)
    }
}
