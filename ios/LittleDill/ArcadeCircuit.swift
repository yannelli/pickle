import Foundation

struct ArcadeCircuit: Codable, Equatable {
    static let games: [ArcadeGame] = [.hop, .chop, .toss]
    static let targets: [ArcadeGame: Int] = [.hop: 12, .chop: 30, .toss: 8]
    static let maxRawScore = 100_000

    let day: String
    private(set) var scores: [String: Int]

    init(day: String, scores: [String: Int] = [:]) {
        self.day = day
        self.scores = scores.reduce(into: [:]) { result, entry in
            guard Self.games.contains(where: { $0.rawValue == entry.key }) else { return }
            result[entry.key] = min(Self.maxRawScore, max(0, entry.value))
        }
    }

    private enum CodingKeys: String, CodingKey { case day, scores }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let day = try c.decode(String.self, forKey: .day)
        guard DailyChallenge.validDay(day) else {
            throw DecodingError.dataCorruptedError(forKey: .day, in: c, debugDescription: "Invalid circuit day")
        }
        self.init(day: day, scores: (try? c.decode([String: Int].self, forKey: .scores)) ?? [:])
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(day, forKey: .day)
        try c.encode(scores, forKey: .scores)
    }

    static func seed(day: String, game: ArcadeGame) -> UInt64 {
        (day + "/" + game.rawValue).utf8.reduce(UInt64(14_695_981_039_346_656_037)) {
            ($0 ^ UInt64($1)) &* 1_099_511_628_211
        }
    }

    static func points(game: ArcadeGame, score: Int) -> Int {
        guard let target = targets[game] else { return 0 }
        return min(target, max(0, score)) * 100 / target
    }

    var completed: Bool { Self.games.allSatisfy { scores[$0.rawValue] != nil } }
    var total: Int { Self.games.reduce(0) { $0 + Self.points(game: $1, score: scores[$1.rawValue] ?? 0) } }
    var medal: String? {
        guard completed else { return nil }
        if total >= 270 { return "Gold" }
        if total >= 180 { return "Silver" }
        if total >= 90 { return "Bronze" }
        return nil
    }
    var nextGame: ArcadeGame? { Self.games.first { scores[$0.rawValue] == nil } }

    mutating func record(game: ArcadeGame, score: Int) {
        guard Self.games.contains(game) else { return }
        scores[game.rawValue] = max(scores[game.rawValue] ?? 0, min(Self.maxRawScore, max(0, score)))
    }
}
