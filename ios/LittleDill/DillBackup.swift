import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

// Swift port of ../../save-codec.js. Web builds read these files and ignore the `native` block.
struct DillBackupError: LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
    static let tooLarge = DillBackupError(message: "This file is too large to be a little dill. save. Choose a .dill backup under 16 KB.")
    static let fileTooLarge = DillBackupError(message: "Choose a .dill save file under 16 KB.")
    static let unreadable = DillBackupError(message: "This is not a readable .dill save file.")
    static let unsupported = DillBackupError(message: "This save format is not supported. Choose an encrypted .dill backup from little dill.")
    static let damaged = DillBackupError(message: "This save file is damaged or incomplete.")
    static let changed = DillBackupError(message: "This save has been changed or damaged. Your current pickle is safe.")
    static let invalid = DillBackupError(message: "This file contains invalid pickle progress.")
    static let exportFailed = DillBackupError(message: "The download could not be created. Your pickle is still here; please try again.")
}

struct BackupPreview: Equatable {
    struct Row: Equatable { let label: String, value: String }
    let savedAt: Date
    let name: String
    let ageDays: Int
    let stats: [PetStat: Int]
    let condition: String
    let backup: DillBackup.Decoded
    var rows: [Row] {
        [Row(label: "Name", value: name), Row(label: "Age", value: "\(ageDays) days"),
         Row(label: "Food", value: "\(stats[.fullness] ?? 0)/100"), Row(label: "Happy", value: "\(stats[.happiness] ?? 0)/100"),
         Row(label: "Energy", value: "\(stats[.energy] ?? 0)/100"), Row(label: "Clean", value: "\(stats[.hygiene] ?? 0)/100"),
         Row(label: "Condition", value: condition)]
    }
}

enum DillBackup {
    static let MAX_FILE_BYTES = 16384
    static let MAX_DATA_BYTES = 4096
    static let format = "little-dill-save"
    static let context = Data("little-dill-save/1/AES-256-GCM".utf8)
    // Same public format key as save-codec.js. It deters casual edits and is not a secret.
    static let key = SymmetricKey(data: Data([185, 74, 216, 57, 134, 211, 99, 244, 68, 143, 31, 167, 29, 200, 116, 5,
                                               162, 45, 228, 83, 174, 149, 63, 233, 120, 20, 98, 203, 75, 186, 47, 156]))

    struct Score: Codable, Equatable { var d: String; var s: Int; var t: Int64 }
    struct Native: Codable, Equatable {
        var coins = 0
        var outfit = "sprout"
        var unlocked: [String] = []
        var streak = 0
        var lastVisitDay = ""
        var careDay = ""
        var dailyCare: [String] = []
        var rewardedDays: [String] = []
        var scores: [Score] = []
        var arenaBest: Int?
        var arcade: [String: Int] = [:]
        var haptics = true
        var sounds: Bool?
    }
    enum Pet: Equatable { case current(WebPet), legacy(JSONValue) }
    struct Decoded: Equatable {
        let savedAt: Int64
        let pet: Pet
        let native: Native?
        func restored(now: Int64) -> WebPet {
            switch pet {
            case .current(let pet): return pet
            case .legacy(let value): return (try? PetLife.restore(json: value, now: now)) ?? PetLife.fresh(now: now)
            }
        }
    }

    static func encode(pet: WebPet, native: Native?, savedAt: Int64) throws -> Data {
        struct Payload: Encodable { let version = 1; let savedAt: Int64; let pet: WebPet; let native: Native? }
        let pet = try PetLife.validate(pet)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        var attempts: [Native?] = [native]
        if var smaller = native { smaller.scores = []; smaller.rewardedDays = Array(smaller.rewardedDays.suffix(7)); attempts.append(smaller) }
        for extras in attempts {
            let plaintext = try encoder.encode(Payload(savedAt: savedAt, pet: pet, native: extras))
            let nonce = AES.GCM.Nonce()
            let box = try AES.GCM.seal(plaintext, using: key, nonce: nonce, authenticating: context)
            let sealed = box.ciphertext + box.tag
            guard sealed.count <= MAX_DATA_BYTES else { continue }
            let iv = nonce.withUnsafeBytes { Data($0) }.base64EncodedString()
            let raw = "{\"format\":\"\(format)\",\"version\":1,\"cipher\":\"AES-256-GCM\",\"iv\":\"\(iv)\",\"data\":\"\(sealed.base64EncodedString())\"}"
            return Data(raw.utf8)
        }
        throw DillBackupError.exportFailed
    }

    static func decode(_ file: Data) throws -> Decoded {
        var raw = String(decoding: file, as: UTF8.self)
        if raw.unicodeScalars.first == "\u{FEFF}" { raw.unicodeScalars.removeFirst() }
        guard raw.utf16.count <= MAX_FILE_BYTES, raw.utf8.count <= MAX_FILE_BYTES else { throw DillBackupError.tooLarge }
        guard let envelope = try? JSONValue.parse(Data(raw.utf8)) else { throw DillBackupError.unreadable }
        guard case .object(let fields) = envelope, envelope["format"]?.string == format, envelope["version"]?.number == 1,
              envelope["cipher"]?.string == "AES-256-GCM",
              fields.keys.allSatisfy({ ["format", "version", "cipher", "iv", "data"].contains($0) })
        else { throw DillBackupError.unsupported }
        let iv = try bytes(envelope["iv"], size: 12)
        let encrypted = try bytes(envelope["data"], size: nil)
        let text: Data, payload: JSONValue
        do {
            let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: iv), ciphertext: Data(encrypted.prefix(encrypted.count - 16)),
                                            tag: Data(encrypted.suffix(16)))
            var plain = try AES.GCM.open(box, using: key, authenticating: context)
            if plain.starts(with: [0xEF, 0xBB, 0xBF]) { plain = Data(plain.dropFirst(3)) }
            guard let string = String(data: plain, encoding: .utf8) else { throw DillBackupError.changed }
            text = Data(string.utf8)
            payload = try JSONValue.parse(text)
        } catch { throw DillBackupError.changed }
        guard payload.isObject, payload["version"]?.number == 1, let savedAt = payload["savedAt"]?.safeInteger,
              PetLife.isTimestamp(savedAt)
        else { throw DillBackupError.invalid }
        struct Extras: Decodable { let native: Native? }
        return Decoded(savedAt: savedAt, pet: try validateState(payload["pet"]), native: (try? JSONDecoder().decode(Extras.self, from: text))?.native)
    }

    static func validateState(_ value: JSONValue?) throws -> Pet {
        guard let value else { throw DillBackupError.invalid }
        if value["version"]?.number == 2 {
            do { return .current(try PetLife.validate(json: value)) } catch { throw DillBackupError.invalid }
        }
        func integer(_ key: String, _ limit: Int64) -> Bool { value[key]?.safeInteger.map { $0 >= 0 && $0 <= limit } == true }
        guard value.isObject, value["version"]?.number == 1,
              PetLife.STATS.allSatisfy({ value[$0.rawValue]?.number.map { $0.isFinite && $0 >= 0 && $0 <= 100 } == true }),
              integer("ageTicks", 1_000_000_000), integer("neglect", 60), integer("updatedAt", PetLife.MAX_TIMESTAMP),
              let sleeping = value["sleeping"]?.bool, value["sick"]?.bool != nil, let dead = value["dead"]?.bool, !(dead && sleeping)
        else { throw DillBackupError.invalid }
        return .legacy(value)
    }

    static func preview(_ decoded: Decoded, now: Int64) -> BackupPreview {
        let restored = decoded.restored(now: now)
        var stats: [PetStat: Int] = [:]
        let name: String, sleeping: Bool, sick: Bool, dead: Bool
        switch decoded.pet {
        case .current(let pet):
            for stat in PetLife.STATS { stats[stat] = Int(pet[stat].rounded(.toNearestOrAwayFromZero)) }
            name = pet.name; sleeping = pet.sleeping; sick = pet.sick; dead = pet.dead
        case .legacy(let value):
            for stat in PetLife.STATS { stats[stat] = Int((value[stat.rawValue]?.number ?? 0).rounded(.toNearestOrAwayFromZero)) }
            name = ""; sleeping = value["sleeping"]?.bool == true; sick = value["sick"]?.bool == true; dead = value["dead"]?.bool == true
        }
        return BackupPreview(savedAt: PetLife.date(decoded.savedAt), name: name.isEmpty ? "Unnamed pickle" : name,
                             ageDays: Int(PetLife.age(restored, now: now) / PetLife.DAY), stats: stats,
                             condition: dead ? "Passed away" : sleeping ? "Sleeping" : sick ? "Feeling sick" : "Awake", backup: decoded)
    }

    private static func bytes(_ value: JSONValue?, size: Int?) throws -> Data {
        guard let text = value?.string, let result = strictBase64(text),
              size.map({ result.count == $0 }) ?? (17...MAX_DATA_BYTES).contains(result.count)
        else { throw DillBackupError.damaged }
        return result
    }

    // Mirrors the save-codec.js regex: padded standard alphabet, no whitespace.
    static func strictBase64(_ text: String) -> Data? {
        let chars = Array(text.utf8)
        guard chars.count % 4 == 0 else { return nil }
        func sextet(_ c: UInt8) -> UInt32? {
            switch c {
            case 65...90: return UInt32(c - 65)
            case 97...122: return UInt32(c - 71)
            case 48...57: return UInt32(c + 4)
            case 43: return 62
            case 47: return 63
            default: return nil
            }
        }
        var out = Data()
        for start in stride(from: 0, to: chars.count, by: 4) {
            let g = Array(chars[start..<start + 4])
            let pad = g[2] == 61 ? (g[3] == 61 ? 2 : -1) : (g[3] == 61 ? 1 : 0)
            guard pad >= 0, pad == 0 || start + 4 == chars.count else { return nil }
            var v: UInt32 = 0
            for k in 0..<(4 - pad) { guard let s = sextet(g[k]) else { return nil }; v = v << 6 | s }
            v <<= UInt32(6 * pad)
            out.append(UInt8(v >> 16 & 255))
            if pad < 2 { out.append(UInt8(v >> 8 & 255)) }
            if pad < 1 { out.append(UInt8(v & 255)) }
        }
        return out
    }
}

extension DillBackup.Native {
    /// Missing or mistyped keys keep their defaults, so one bad field does not drop the whole native block.
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        coins = (try? c.decodeIfPresent(Int.self, forKey: .coins)) ?? coins
        outfit = (try? c.decodeIfPresent(String.self, forKey: .outfit)) ?? outfit
        unlocked = (try? c.decodeIfPresent([String].self, forKey: .unlocked)) ?? unlocked
        streak = (try? c.decodeIfPresent(Int.self, forKey: .streak)) ?? streak
        lastVisitDay = (try? c.decodeIfPresent(String.self, forKey: .lastVisitDay)) ?? lastVisitDay
        careDay = (try? c.decodeIfPresent(String.self, forKey: .careDay)) ?? careDay
        dailyCare = (try? c.decodeIfPresent([String].self, forKey: .dailyCare)) ?? dailyCare
        rewardedDays = (try? c.decodeIfPresent([String].self, forKey: .rewardedDays)) ?? rewardedDays
        scores = (try? c.decodeIfPresent([DillBackup.Score].self, forKey: .scores)) ?? scores
        arenaBest = try? c.decodeIfPresent(Int.self, forKey: .arenaBest)
        arcade = (try? c.decodeIfPresent([String: Int].self, forKey: .arcade)) ?? arcade
        haptics = (try? c.decodeIfPresent(Bool.self, forKey: .haptics)) ?? haptics
        sounds = try? c.decodeIfPresent(Bool.self, forKey: .sounds)
    }
}
