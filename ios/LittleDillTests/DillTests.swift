import XCTest
import AVFoundation
import SwiftUI
import CryptoKit
@testable import LittleDill

final class DillTests: XCTestCase {
    private func date(_ text:String) -> Date { ISO8601DateFormatter().date(from:text)! }

    func testDailyChallengeUsesUTCAndChangesAtMidnight() {
        XCTAssertEqual(DailyChallenge.today(date("2026-09-17T23:59:59Z")),"2026-09-17")
        XCTAssertEqual(DailyChallenge.today(date("2026-09-18T00:00:00Z")),"2026-09-18")
    }
    func testDailySeedIsDeterministicAndTargetsStayPlayable() {
        for day in 1...28 {
            let c = DailyChallenge(day:String(format:"2026-09-%02d",day))
            XCTAssertEqual(c.seed,DailyChallenge(day:c.day).seed)
            for round in 0..<3 { XCTAssertTrue((0.25...0.75).contains(c.target(round:round))) }
            XCTAssertNotEqual(c.target(round:0),c.target(round:1))
        }
    }
    func testScoringBoundariesAndSymmetry() {
        XCTAssertEqual(DailyChallenge.points(position:0.5,target:0.5),100)
        XCTAssertEqual(DailyChallenge.points(position:0,target:1),0)
        XCTAssertEqual(DailyChallenge.points(position:0.4,target:0.5),DailyChallenge.points(position:0.6,target:0.5))
        XCTAssertEqual(DailyChallenge.points(position:.nan,target:0.5),0)
        for step in 0...1000 { XCTAssertTrue((0...100).contains(DailyChallenge.points(position:Double(step)/1000,target:0.45))) }
    }
    func testCursorNeverLeavesTrack() {
        for round in 0..<3 { for step in 0...600 { XCTAssertTrue((0...1).contains(DailyChallenge.position(elapsed:Double(step)/100,round:round))) } }
        XCTAssertEqual(DailyChallenge.position(elapsed:0,round:0),0)
        XCTAssertEqual(DailyChallenge.position(elapsed:1.175,round:0),1,accuracy:0.001)
    }
    func testChallengeLinksValidateSchemeAndDate() {
        let c = DailyChallenge(day:"2026-09-17")
        XCTAssertEqual(DailyChallenge.from(c.url),c)
        for text in ["https://challenge/2026-09-17","littledill://other/2026-09-17","littledill://challenge/2026-02-30","littledill://challenge/nonsense"] { XCTAssertNil(DailyChallenge.from(URL(string:text)!)) }
    }
    func testArenaInviteLinksAndRoomCodes() {
        XCTAssertTrue(ArenaLaunch.validRoom("ABC123"))
        XCTAssertFalse(ArenaLaunch.validRoom("abc123"))
        XCTAssertFalse(ArenaLaunch.validRoom("ABC12/"))
        XCTAssertEqual(ArenaLaunch.from(URL(string:"littledill://arena?room=ABC123")!)?.room,"ABC123")
        XCTAssertNotNil(ArenaLaunch.from(URL(string:"littledill://arena")!))
        XCTAssertEqual(ArenaLaunch.from(ArenaLaunch.shareURL(room:"ABC123"))?.room,"ABC123")
        XCTAssertNotNil(ArenaLaunch.from(ArenaLaunch.shareURL()))
        XCTAssertEqual(ArenaLaunch.shareURL(room:"ABC123").absoluteString,"https://arena.littledill.app/?room=ABC123")
        XCTAssertEqual(ArenaLaunch.site(server:"wss://play.example.com:8443/arena?v=1").url?.absoluteString,"https://play.example.com:8443/")
        XCTAssertNil(ArenaLaunch.from(URL(string:"https://other.example/?room=ABC123")!))
        XCTAssertNil(ArenaLaunch.from(URL(string:"littledill://arena?room=invalid")!))
        for _ in 0..<100 {XCTAssertTrue(ArenaLaunch.validRoom(ArenaLaunch.newRoom()))}
    }
    func testLargeArenaPlayersFitCompactCameraAndMatchServerSize() {
        XCTAssertEqual(ArenaPlayer.radius(for:25),30,accuracy:0.001)
        XCTAssertEqual(ArenaPlayer.radius(for:1600),149,accuracy:0.001)
        var last = 0.0
        for mass in [25.0,1600,10000,1000000,1e12] {
            let radius = ArenaPlayer.radius(for:mass)
            XCTAssertGreaterThan(radius,last); XCTAssertLessThan(radius,409)
            for (width,height) in [(320.0,568.0),(852.0,393.0)] {
                let zoom = ArenaPlayer.cameraZoom(mass:mass,width:width,height:height)
                XCTAssertGreaterThan(zoom,0)
                XCTAssertLessThan(radius*zoom*2,min(width,height)/4)
            }
            last = radius
        }
    }
    private func arenaPlayer(_ additions:[String:Any] = [:]) throws -> ArenaPlayer {
        var state:[String:Any] = ["id":"you","name":"Dilly","brine":"classic","outfit":"sprout","bot":false,"x":100,"y":200,"mass":90,"best":120,"kills":0,"alive":true,"shield":0,"dash":0,"cooldown":0,"respawn":0,"eatenBy":""]
        state.merge(additions) {_,new in new}
        return try JSONDecoder().decode(ArenaPlayer.self,from:JSONSerialization.data(withJSONObject:state))
    }
    func testArenaCellsDecodeWithLegacyFallbackAndPartialSurvival() throws {
        let legacy = try arenaPlayer()
        XCTAssertEqual(legacy.pieces.count,1); XCTAssertEqual(legacy.pieces.first?.id,"you")
        XCTAssertEqual(legacy.pieces.first?.x,100); XCTAssertEqual(legacy.pieces.first?.mass,90)
        XCTAssertFalse(legacy.canSplit,"An older server cannot accept the split action")
        let split = try arenaPlayer(["cells":[["id":"a","x":80,"y":190,"mass":30],["id":"b","x":110,"y":205,"mass":60]],"splitCooldown":0,"merge":9.2])
        XCTAssertEqual(split.pieces.map(\.id),["a","b"])
        XCTAssertEqual(split.mass,90); XCTAssertTrue(split.canSplit)
        XCTAssertEqual(split.regroupHint,"2 cucumbers · regroup in 10s")
        let survivor = try arenaPlayer(["cells":[["id":"b","x":110,"y":205,"mass":60]],"mass":60,"merge":0])
        XCTAssertTrue(survivor.alive); XCTAssertEqual(survivor.pieces.count,1)
        XCTAssertEqual(survivor.pieces.first?.id,"b")
        XCTAssertTrue(try arenaPlayer(["alive":false]).pieces.isEmpty)
    }
    func testArenaPlayerUnknownLooksUseServerDefaults() throws {
        let unknown = try arenaPlayer(["brine":"pumpkin","outfit":"top-hat"])
        XCTAssertEqual(unknown.brine,.classic); XCTAssertEqual(unknown.outfit,.sprout)
        let known = try arenaPlayer(["brine":"spicy","outfit":"crown"])
        XCTAssertEqual(known.brine,.spicy); XCTAssertEqual(known.outfit,.crown)
    }
    func testArenaSplitRequiresOneEligibleCellAndAvailableSlot() throws {
        let small:[[String:Any]] = [["id":"a","x":100,"y":200,"mass":45],["id":"b","x":150,"y":200,"mass":45]]
        XCTAssertFalse(try arenaPlayer(["cells":small]).canSplit,"Total mass alone must not allow a split")
        let eligible:[[String:Any]] = [["id":"a","x":100,"y":200,"mass":90]]
        XCTAssertFalse(try arenaPlayer(["cells":eligible,"splitCooldown":0.1]).canSplit)
        XCTAssertFalse(try arenaPlayer(["cells":eligible,"alive":false]).canSplit)
        let four = (0..<4).map {["id":"cell-\($0)","x":100,"y":200,"mass":100] as [String:Any]}
        XCTAssertFalse(try arenaPlayer(["cells":four,"mass":400]).canSplit)
        XCTAssertTrue(try arenaPlayer(["cells":[["id":"a","x":100,"y":200,"mass":60]],"mass":60,"splitCooldown":0]).canSplit)
        XCTAssertFalse(try arenaPlayer(["cells":[["id":"a","x":100,"y":200,"mass":59.9]],"mass":59.9]).canSplit)
        XCTAssertEqual(try arenaPlayer(["cells":small,"merge":0]).regroupHint,"2 cucumbers · regrouping")
    }
    @MainActor func testCucumberAppearanceFollowsCellsAndRestoresOriginalLook() throws {
        for brine in Brine.allCases {
            for outfit in [Outfit.original,.crown] {
                let base:[String:Any] = ["brine":brine.rawValue,"outfit":outfit.rawValue,"x":3000,"y":2250,"mass":240]
                func player(cells:[[String:Any]],merge:Double) throws -> ArenaPlayer {
                    var fields = base; fields["cells"] = cells; fields["merge"] = merge
                    return try arenaPlayer(fields)
                }
                let whole:[[String:Any]] = [["id":"a","x":3000,"y":2250,"mass":240]]
                let halves:[[String:Any]] = [["id":"a","x":2905,"y":2250,"mass":120],["id":"b","x":3095,"y":2250,"mass":120]]
                let original = try player(cells:whole,merge:0)
                let split = try player(cells:halves,merge:12)
                let ready = try player(cells:halves,merge:0)
                let merged = try player(cells:whole,merge:0)
                let survivor = try player(cells:[halves[1]],merge:8)
                XCTAssertFalse(original.isCucumber); XCTAssertTrue(split.isCucumber)
                XCTAssertTrue(ready.isCucumber,"Timer expiry alone must not restore pickle art")
                XCTAssertFalse(merged.isCucumber); XCTAssertFalse(survivor.isCucumber)
                for state in [original,split,ready,merged,survivor] {
                    XCTAssertEqual(state.brine,brine); XCTAssertEqual(state.outfit,outfit)
                }
                if brine == .spicy {
                    func panel(_ player:ArenaPlayer,_ title:String) -> some View {
                        let state = ArenaSnapshot(tick:1,time:1,width:6000,height:4500,humans:1,bots:0,players:[player],food:[],foodAdded:nil,foodRemoved:nil)
                        return VStack(spacing:12) {
                            Text(title).font(.system(size:17,weight:.semibold,design:.rounded)).foregroundStyle(DillTheme.ink)
                            ArenaCanvas(snapshot:state,previous:nil,food:[],me:player,received:Date(timeIntervalSince1970:0),now:Date(timeIntervalSince1970:0))
                                .frame(width:1200,height:1200).frame(width:360,height:260).clipped()
                        }.padding(.vertical,16)
                    }
                    let renderer = ImageRenderer(content:HStack(spacing:12) {
                        panel(original,"Before split")
                        panel(ready,"Cucumbers · ready to regroup")
                        panel(merged,"Regrouped")
                    }.padding(16).background(DillTheme.cream))
                    renderer.scale = 2
                    let attachment = XCTAttachment(image:try XCTUnwrap(renderer.uiImage))
                    attachment.name = outfit == .original ? "arena-cucumber-native" : "arena-cucumber-outfit-native"
                    attachment.lifetime = .keepAlways; add(attachment)
                }
            }
        }
        XCTAssertFalse(try arenaPlayer().isCucumber,"Legacy one-body snapshots keep their original look")
        XCTAssertFalse(try arenaPlayer(["alive":false]).isCucumber)
    }
    func testSplitCameraFitsAllPiecesIncludingSeparatedLargePickles() {
        let formations = [
            [ArenaCell(id:"a",x:100,y:100,mass:30),ArenaCell(id:"b",x:600,y:950,mass:30)],
            [ArenaCell(id:"a",x:200,y:100,mass:1e12),ArenaCell(id:"b",x:1500,y:900,mass:80),ArenaCell(id:"c",x:1400,y:1300,mass:200)]
        ]
        for cells in formations {
            for (width,height) in [(320.0,548.0),(375,647),(440,860),(667,354),(852,372)] {
                let camera = ArenaPlayer.camera(cells:cells,mass:cells.reduce(0) {$0+$1.mass},width:width,height:height)
                XCTAssertGreaterThan(camera.zoom,0)
                for cell in cells {
                    let x = (cell.x-camera.center.x)*camera.zoom+width/2
                    let y = (cell.y-camera.center.y)*camera.zoom+height/2
                    XCTAssertGreaterThanOrEqual(x-cell.radius*1.3*camera.zoom,width*0.14-0.001)
                    XCTAssertLessThanOrEqual(x+cell.radius*1.3*camera.zoom,width*0.86+0.001)
                    XCTAssertGreaterThanOrEqual(y-cell.radius*1.4*camera.zoom,height*0.23-0.001)
                    XCTAssertLessThanOrEqual(y+cell.radius*1.4*camera.zoom,height*0.77+0.001)
                }
            }
        }
    }
    func testExpandedGardenSnapshotFitsTransportAndAcceptsFullRoom() throws {
        var players:[[String:Any]] = []
        for index in 0..<64 {
            let cells = (0..<4).map {cell -> [String:Any] in
                ["id":"cell-\(index)-\(cell)","x":5999.9,"y":4499.9,"mass":99999.9]
            }
            players.append(["id":"player-\(index)","name":"moonlitfern\(index)","brine":"classic","outfit":"sprout","bot":false,"x":5999.9,"y":4499.9,"mass":399999.6,"best":399999,"kills":9,"alive":true,"shield":0,"dash":0,"cooldown":0,"splitCooldown":0,"merge":10,"cells":cells,"respawn":0,"eatenBy":""])
        }
        let food = (0..<3375).map {[Double($0),5999.9,4499.9,9.0]}
        var value:[String:Any] = ["type":"state","tick":100,"time":5,"width":6000,"height":4500,"humans":64,"bots":0,"players":players,"food":food]
        let data = try JSONSerialization.data(withJSONObject:value)
        XCTAssertLessThan(data.count,ArenaSnapshot.maximumMessageSize)
        let snapshot = try JSONDecoder().decode(ArenaSnapshot.self,from:data)
        XCTAssertEqual(snapshot.players.count,64); XCTAssertEqual(snapshot.food?.count,3375)
        XCTAssertEqual(snapshot.population,64); XCTAssertTrue(snapshot.supports(playerID:"player-63"))
        XCTAssertFalse(snapshot.supports(playerID:"not-in-this-room"))
        players.append(players[0]); value["players"] = players
        let tooMany = try JSONDecoder().decode(ArenaSnapshot.self,from:JSONSerialization.data(withJSONObject:value))
        XCTAssertFalse(tooMany.supports(playerID:"player-0"))
        value["players"] = Array(players.prefix(32)); value["humans"] = 2; value["bots"] = 30
        let filled = try JSONDecoder().decode(ArenaSnapshot.self,from:JSONSerialization.data(withJSONObject:value))
        XCTAssertEqual(filled.population,32)
    }
    func testArenaFoodDeltasPreserveInventoryAndAllowFullResync() throws {
        func snapshot(_ update:[String:Any]) throws -> ArenaSnapshot {
            var state:[String:Any] = ["tick":1,"time":1,"width":6000,"height":4500,"humans":0,"bots":0,"players":[]]
            state.merge(update) {_,new in new}
            return try JSONDecoder().decode(ArenaSnapshot.self,from:JSONSerialization.data(withJSONObject:state))
        }
        let initial = [[1.0,10,20,3],[2,30,40,9]]
        var inventory = try XCTUnwrap(snapshot(["food":initial]).updatedFood(from:[]))
        XCTAssertEqual(inventory,initial)
        inventory = try XCTUnwrap(snapshot(["foodRemoved":[1],"foodAdded":[[3.0,50,60,3]]]).updatedFood(from:inventory))
        XCTAssertEqual(inventory,[[2,30,40,9],[3,50,60,3]])
        inventory = try XCTUnwrap(snapshot(["foodAdded":[[2.0,70,80,9]]]).updatedFood(from:inventory))
        XCTAssertEqual(inventory,[[2,70,80,9],[3,50,60,3]],"An existing ID must move, not duplicate")
        inventory = try XCTUnwrap(snapshot(["foodRemoved":[2],"foodAdded":[[2.0,90,100,3]]]).updatedFood(from:inventory))
        XCTAssertEqual(inventory,[[2,90,100,3],[3,50,60,3]],"Upserts follow removals in the same packet")
        XCTAssertNil(try snapshot([:]).updatedFood(from:inventory))
        XCTAssertNil(try snapshot(["foodAdded":[],"foodRemoved":[]]).updatedFood(from:inventory))
        inventory = try XCTUnwrap(snapshot(["food":[[9.0,110,120,9]]]).updatedFood(from:inventory))
        XCTAssertEqual(inventory,[[9,110,120,9]],"A full snapshot must replace stale inventory")
        XCTAssertEqual(try snapshot(["food":[]]).updatedFood(from:inventory),[])
    }
    @MainActor func testSoundPreferenceMigratesOldSavesAndPersists() throws {
        let suite = "test.sound.\(UUID())"
        // Absence of the optional sound key is the pre-audio v1 save format.
        let original = PetState()
        let decoded = try JSONDecoder().decode(PetState.self,from:JSONEncoder().encode(original))
        XCTAssertNil(decoded.soundEnabled); XCTAssertTrue(decoded.sounds)
        let isolated = UserDefaults(suiteName:suite)!
        defer {isolated.removePersistentDomain(forName:suite)}
        let store = DillStore(defaults:isolated); store.setSounds(false)
        XCTAssertFalse(DillStore(defaults:isolated).pet.sounds)
    }
    func testOriginalSoundEffectsDecodeAndHaveBoundedNonSilentSamples() throws {
        var clips = Set<Data>()
        for cue in DillSound.allCases {
            let wav = cue.waveData(), player = try AVAudioPlayer(data:wav)
            XCTAssertEqual(player.duration,cue.duration,accuracy:0.01)
            XCTAssertTrue(clips.insert(wav).inserted)
            let bytes = [UInt8](wav.dropFirst(44))
            var energy = 0.0, peak = 0.0
            for i in stride(from:0,to:bytes.count,by:2) {
                let value = Double(Int16(bitPattern:UInt16(bytes[i]) | UInt16(bytes[i+1]) << 8)) / 32767
                energy += value*value; peak = max(peak,abs(value))
            }
            XCTAssertGreaterThan(sqrt(energy / Double(bytes.count/2)),0.005,"Silent \(cue)")
            XCTAssertLessThanOrEqual(peak,0.851,"Clipped \(cue)")
        }
    }
}

final class TestClock {
    var now: Date
    init(_ now: Date) { self.now = now }
    func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

final class PetModelTests: XCTestCase {
    private let t0 = ISO8601DateFormatter().date(from: "2026-09-17T12:00:00Z")!
    private var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    private func ms(_ date: Date) -> Int64 { PetLife.ms(date) }
    private func living(at now: Date, name: String = "Dilly") -> PetState {
        var p = PetState(now: now)
        p.life.phase = .living; p.life.name = name
        p.life.bornAt = ms(now); p.life.hatchAt = ms(now); p.life.brinedAt = ms(now) - PetLife.HATCH_MS
        return p
    }
    private func suite() -> UserDefaults {
        let name = "test.dill.\(UUID())", defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }
    @MainActor private func hatched(_ defaults: UserDefaults, _ clock: TestClock, brine: Brine = .classic, name: String = "Dilly") -> DillStore {
        let store = DillStore(defaults: defaults, clock: { clock.now })
        XCTAssertTrue(store.brine(brine)); clock.advance(60); store.tick()
        XCTAssertTrue(store.name(name))
        return store
    }
    private func seal(_ payload: String) throws -> Data {
        let nonce = AES.GCM.Nonce()
        let box = try AES.GCM.seal(Data(payload.utf8), using: DillBackup.key, nonce: nonce, authenticating: DillBackup.context)
        let iv = nonce.withUnsafeBytes { Data($0) }.base64EncodedString()
        return Data("{\"format\":\"little-dill-save\",\"version\":1,\"cipher\":\"AES-256-GCM\",\"iv\":\"\(iv)\",\"data\":\"\((box.ciphertext + box.tag).base64EncodedString())\"}".utf8)
    }

    func testCareFollowsWebRules() {
        var p = living(at: t0)
        p.life.fullness = 50; p.life.happiness = 50; p.life.hygiene = 50
        XCTAssertEqual(p.care(.feed, at: t0), CareResult(applied: true, coins: 5, message: "finest brine. +40 food, +3 happy."))
        XCTAssertEqual(p.life.fullness, 90); XCTAssertEqual(p.life.happiness, 53)
        XCTAssertEqual(p.care(.feed, at: t0).message, "finest brine. +10 food, +3 happy.")
        XCTAssertEqual(p.life.fullness, 100)
        let later = t0.addingTimeInterval(60)
        XCTAssertEqual(p.care(.feed, at: later), CareResult(applied: false, coins: 0, message: "full to the brim. try a little pet!"))
        XCTAssertEqual(p.life.lastCareAt, ms(later), "The web records care even when food is refused")
        let energy = p.life.energy, happy = p.life.happiness
        XCTAssertEqual(p.care(.pet, at: later), CareResult(applied: true, coins: 5, message: "+8 happy. you’re my favorite human."))
        XCTAssertEqual(p.life.happiness, happy + 8, accuracy: 1e-9); XCTAssertEqual(p.life.energy, energy)
        XCTAssertEqual(p.care(.pet, at: later.addingTimeInterval(1.999)).message, "so loved. another pet in a moment. ♥")
        XCTAssertTrue(p.care(.pet, at: later.addingTimeInterval(2)).applied)
        XCTAssertEqual(p.care(.wash, at: later.addingTimeInterval(2)), CareResult(applied: true, coins: 5, message: "a sudsy little bath. +4 happy, too."))
        XCTAssertEqual(p.life.hygiene, 100)
        XCTAssertEqual(p.care(.wash, at: later.addingTimeInterval(3)), CareResult(applied: false, coins: 0, message: "already sparkling. how about a game?"))
        XCTAssertEqual(p.coins, 35)
    }
    func testCareAwardsEachActionOnlyOncePerDay() {
        var p = living(at: t0)
        for action in Care.allCases {
            p.life.fullness = 10; p.life.hygiene = 10
            XCTAssertEqual(p.care(action, at: t0).coins, 5)
            p.life.fullness = 10; p.life.hygiene = 10
            XCTAssertEqual(p.care(action, at: t0.addingTimeInterval(3)).coins, 0)
        }
        XCTAssertEqual(p.coins, 40); XCTAssertEqual(p.dailyCare.count, 4)
        p.life.fullness = 50
        XCTAssertEqual(p.care(.feed, at: t0.addingTimeInterval(86400)).coins, 5)
    }
    func testSleepBlocksCareAndPettingWakes() {
        var p = living(at: t0)
        XCTAssertEqual(p.care(.nap, at: t0), CareResult(applied: true, coins: 5, message: "night night. don’t let the dill bugs bite."))
        XCTAssertTrue(p.life.sleeping)
        XCTAssertEqual(p.care(.feed, at: t0), CareResult(applied: false, coins: 0, message: "zzZ... use Wake to rise & brine."))
        XCTAssertEqual(p.care(.pet, at: t0), CareResult(applied: true, coins: 5, message: "rise & brine, sleepyhead."))
        XCTAssertFalse(p.life.sleeping)
    }
    func testSleepRecoversThirtyEnergyAnHourAndWakesWhenFull() {
        var p = living(at: t0)
        p.life.energy = 5; p.life.sleeping = true
        p.refresh(at: t0.addingTimeInterval(3600))
        XCTAssertEqual(p.life.energy, 35, accuracy: 1e-9); XCTAssertTrue(p.life.sleeping)
        p.refresh(at: t0.addingTimeInterval(4 * 3600))
        XCTAssertEqual(p.life.energy, 100); XCTAssertFalse(p.life.sleeping)
    }
    func testDailyDecayMatchesWebRates() {
        var p = living(at: t0)
        p.refresh(at: t0.addingTimeInterval(86400), calendar: utc)
        XCTAssertEqual(p.life.fullness, 54, accuracy: 1e-9); XCTAssertEqual(p.life.happiness, 61, accuracy: 1e-9)
        XCTAssertEqual(p.life.hygiene, 65, accuracy: 1e-9); XCTAssertEqual(p.life.energy, 100)
    }
    func testClockRollbackDoesNotDuplicateDecay() {
        var p = living(at: t0)
        p.refresh(at: t0.addingTimeInterval(-86400), calendar: utc)
        XCTAssertEqual(p.life.updatedAt, ms(t0)); XCTAssertEqual(p.life.fullness, 90)
        p.refresh(at: t0, calendar: utc); XCTAssertEqual(p.life.fullness, 90)
    }
    func testEmptyNeedMustStayEmptyFor48HoursBeforeDeath() {
        var p = living(at: t0)
        p.refresh(at: t0.addingTimeInterval(107 * 3600))
        XCTAssertFalse(p.life.dead); XCTAssertEqual(p.life.neglectMs, 47 * 3_600_000, accuracy: 1e-3)
        p.refresh(at: t0.addingTimeInterval(109 * 3600))
        XCTAssertTrue(p.life.dead); XCTAssertEqual(p.life.diedAt, ms(t0) + 108 * PetLife.HOUR)
        XCTAssertEqual(p.care(.feed, at: t0.addingTimeInterval(110 * 3600)), CareResult(applied: false, coins: 0, message: "a good dill. gone, but not forgotten."))
    }
    func testSicknessStartsAtEightAndEndsWhenEveryMeterReachesThirty() {
        var p = living(at: t0)
        p.life.fullness = 9
        p.refresh(at: t0.addingTimeInterval(3600))
        XCTAssertTrue(p.life.sick)
        _ = p.care(.feed, at: t0.addingTimeInterval(3600))
        XCTAssertFalse(p.life.sick)
    }
    func testArcadeCostsSixEnergyAndRewardsLikeTheWeb() {
        var p = living(at: t0)
        p.life.happiness = 40
        XCTAssertTrue(p.startArcade(at: t0)); XCTAssertEqual(p.life.energy, 84)
        XCTAssertEqual(p.finishArcade(game: "hunt", score: 2, completed: true, at: t0), 26)
        XCTAssertEqual(p.life.happiness, 66); XCTAssertEqual(p.arcadeRecords["hunt"], 2)
        XCTAssertEqual(p.finishArcade(game: "hunt", score: 3, completed: false, at: t0), 0); XCTAssertEqual(p.arcadeRecords["hunt"], 2)
        for (game, score, reward) in [("hunt", 3, 34), ("memory", 3, 22), ("memory", 5, 34), ("catch", 5, 20), ("catch", 40, 34), ("catch", 0, 10), ("other", 9, 0)] {
            XCTAssertEqual(PetState.arcadeReward(game: game, score: score), reward, game)
        }
        p.life.energy = 5; XCTAssertFalse(p.startArcade(at: t0))
        p.life.energy = 50; p.life.sleeping = true; XCTAssertFalse(p.startArcade(at: t0))
    }
    func testNameRulesMatchTheWeb() {
        XCTAssertEqual(PetLife.cleanName("  Sir \t\n Crunch "), "Sir Crunch")
        XCTAssertNotNil(PetLife.cleanName(String(repeating: "a", count: 24)))
        XCTAssertNil(PetLife.cleanName(String(repeating: "a", count: 25)))
        XCTAssertEqual(PetLife.cleanName(String(repeating: "e\u{301}", count: 24))?.unicodeScalars.count, 24)
        XCTAssertNotNil(PetLife.cleanName(String(repeating: "\u{1F952}", count: 24)))
        XCTAssertNil(PetLife.cleanName(String(repeating: "\u{1F952}", count: 25)))
        for bad in ["", "   ", "\u{200B}name", "bell\u{7}", "a\u{200D}b"] { XCTAssertNil(PetLife.cleanName(bad), bad) }
    }
    func testStagesTeensAndEldersFollowAge() {
        let pet = living(at: t0).life
        for (days, stage) in [(0.5, LifeStage.baby), (1, .young), (3, .teen), (7, .adult), (14, .elder)] {
            XCTAssertEqual(PetLife.stage(pet, now: pet.bornAt + Int64(days * 86_400_000)), stage)
        }
        let teen = PetLife.teen(pet, now: pet.bornAt + 3 * PetLife.DAY)
        XCTAssertEqual(teen?.id, TeenLook.all[Int((pet.bornAt / 1000) % 8)].id); XCTAssertEqual(teen?.day, 0)
        let elder = PetLife.elder(pet, now: pet.bornAt + (14 + 3 * 32) * PetLife.DAY)
        XCTAssertEqual(elder?.id, "grandill"); XCTAssertEqual(elder?.unlocked, 32); XCTAssertEqual(elder?.lap, 2)
        XCTAssertEqual(PickleVariety.all.count, 6); XCTAssertEqual(ElderLook.all.count, 32); XCTAssertEqual(TeenLook.all.count, 8)
    }
    func testStreakAndMissedDay() {
        var p = living(at: t0)
        p.refresh(at: t0, calendar: utc); XCTAssertEqual(p.streak, 1)
        p.refresh(at: t0.addingTimeInterval(3600), calendar: utc); XCTAssertEqual(p.streak, 1)
        p.refresh(at: t0.addingTimeInterval(86400), calendar: utc); XCTAssertEqual(p.streak, 2)
        p.refresh(at: t0.addingTimeInterval(86400 * 3), calendar: utc); XCTAssertEqual(p.streak, 1)
    }
    func testBestScoreAndRewardsAreIdempotent() {
        var p = living(at: t0)
        XCTAssertEqual(p.record(score: 150, day: "2026-09-17", at: t0), 25)
        XCTAssertEqual(p.record(score: 140, day: "2026-09-17", at: t0), 0)
        XCTAssertEqual(p.record(score: 280, day: "2026-09-17", at: t0), 0)
        XCTAssertEqual(p.scores.count, 1); XCTAssertEqual(p.scores.first?.score, 280); XCTAssertEqual(p.coins, 45)
        XCTAssertEqual(p.record(score: 300, day: "2026-09-16", at: t0), 0)
        XCTAssertEqual(p.record(score: 301, day: "2026-09-17", at: t0), 0)
        XCTAssertEqual(p.record(score: -1, day: "2026-09-17", at: t0), 0)
        XCTAssertEqual(p.scores.count, 2)
    }
    func testUnlockCannotOverdrawOrChargeTwice() {
        var p = PetState(now: t0)
        XCTAssertFalse(p.equip(.crown)); XCTAssertEqual(p.coins, 20); XCTAssertEqual(p.outfit, .sprout)
        p.coins = 50
        XCTAssertTrue(p.equip(.shades)); XCTAssertEqual(p.coins, 0)
        XCTAssertTrue(p.equip(.original)); XCTAssertTrue(p.equip(.shades)); XCTAssertEqual(p.coins, 0)
    }
    func testCoinRewardsStopAtTheSaveLimit() {
        var p = living(at: t0)
        p.coins = PetState.maxCoins - 2; p.life.fullness = 50
        XCTAssertEqual(p.care(.feed, at: t0).coins, 2); XCTAssertEqual(p.coins, PetState.maxCoins)
        XCTAssertEqual(p.record(score: 150, day: DailyChallenge.today(t0), at: t0), 0); XCTAssertEqual(p.coins, PetState.maxCoins)
        XCTAssertTrue(p.isValid)
        p.coins = PetState.maxCoins + 1; XCTAssertFalse(p.isValid)
    }
    func testStreakStopsAtItsLimitWithoutOverflow() {
        var p = living(at: t0)
        p.refresh(at: t0, calendar: utc)
        p.streak = PetState.maxStreak
        p.refresh(at: t0.addingTimeInterval(86400), calendar: utc); XCTAssertEqual(p.streak, PetState.maxStreak)
        p.streak = Int.max
        p.refresh(at: t0.addingTimeInterval(2 * 86400), calendar: utc); XCTAssertEqual(p.streak, PetState.maxStreak)
        p.streak = PetState.maxStreak + 1; XCTAssertFalse(p.isValid)
        var native = p.native; native.streak = Int.max; native.coins = Int.max
        p.apply(native)
        XCTAssertEqual(p.streak, PetState.maxStreak); XCTAssertEqual(p.coins, PetState.maxCoins); XCTAssertTrue(p.isValid)
    }
    func testInvalidSaveIsRejected() {
        var p = living(at: t0); XCTAssertTrue(p.isValid)
        p.coins = -1; XCTAssertFalse(p.isValid)
        p.coins = 10; p.life.name = " "; XCTAssertFalse(p.isValid)
        p.life.name = "Dilly"; p.outfit = .crown; XCTAssertFalse(p.isValid)
        p.outfit = .sprout; p.arcadeRecords = ["darts": 1]; XCTAssertFalse(p.isValid)
        p.arcadeRecords = [:]; p.life.fullness = 101; XCTAssertFalse(p.isValid)
    }
    @MainActor func testHatchingTakesOneMinuteThenNaming() {
        let clock = TestClock(t0), store = DillStore(defaults: suite(), clock: { clock.now })
        XCTAssertFalse(store.pet.adopted); XCTAssertFalse(store.name("Early"))
        XCTAssertTrue(store.brine(.garlic)); XCTAssertFalse(store.brine(.spicy))
        XCTAssertEqual(store.pet.life.phase, .brining); XCTAssertTrue(["garlic", "butter"].contains(store.pet.life.variety))
        clock.advance(59.999); store.tick(); XCTAssertEqual(store.pet.life.phase, .brining)
        clock.advance(1); store.tick(); XCTAssertEqual(store.pet.life.phase, .naming)
        XCTAssertFalse(store.name("   "))
        XCTAssertTrue(store.name("  Sir \n  Crunch ")); XCTAssertEqual(store.pet.name, "Sir Crunch")
        XCTAssertTrue(store.pet.adopted); XCTAssertEqual(store.pet.streak, 1); XCTAssertEqual(store.pet.brine, .garlic)
    }
    @MainActor func testArcadeNeedsAPaidEntry() {
        let clock = TestClock(t0), store = hatched(suite(), clock)
        XCTAssertEqual(store.finishArcade(game: "hunt", score: 3, completed: true), 0)
        XCTAssertTrue(store.startArcade()); XCTAssertTrue(store.arcadeActive); XCTAssertEqual(store.pet.life.energy, 84)
        XCTAssertFalse(store.care(.feed).applied)
        XCTAssertEqual(store.finishArcade(game: "hunt", score: 3, completed: true), 15)
        XCTAssertFalse(store.arcadeActive); XCTAssertEqual(store.pet.arcadeRecords["hunt"], 3)
    }
    @MainActor func testEatingThePickleTakesThreeBitesAndCanBeCancelled() {
        let clock = TestClock(t0), store = hatched(suite(), clock)
        XCTAssertEqual(store.bite(), 0); XCTAssertEqual(store.pet.life.happiness, 75)
        XCTAssertEqual(store.bite(), 1); XCTAssertEqual(store.pet.life.happiness, 65)
        store.cancelBite(); XCTAssertNil(store.snackBites)
        XCTAssertEqual(store.speech, "you took a BITE and stopped?! ...it grows back. i won’t forget.")
        XCTAssertTrue(store.startBite()); clock.advance(10); store.tick(); XCTAssertNil(store.snackBites)
        XCTAssertEqual(store.speech, "phew. i’m a friend, not a snack.")
        XCTAssertEqual(store.bite(), 0); XCTAssertEqual(store.bite(), 1); XCTAssertEqual(store.bite(), 2)
        XCTAssertTrue(store.pet.life.dead); XCTAssertEqual(store.pet.life.eaten, true)
        XCTAssertEqual(store.bite(), -1)
        let coins = store.pet.coins
        store.restart()
        XCTAssertEqual(store.pet.life.phase, .new); XCTAssertEqual(store.pet.coins, coins); XCTAssertNil(store.pet.life.eaten)
    }
    @MainActor func testPersistenceAndCorruptSaveRecovery() {
        let defaults = suite(), clock = TestClock(t0)
        let store = hatched(defaults, clock, brine: .garlic, name: "Crunch")
        _ = store.care(.wash)
        let reloaded = DillStore(defaults: defaults, clock: { clock.now })
        XCTAssertEqual(reloaded.pet.life, store.pet.life); XCTAssertEqual(reloaded.pet.coins, 25)
        let broken = Data("broken-save".utf8); defaults.set(broken, forKey: "little-dill.native.v1")
        let recovered = DillStore(defaults: defaults, clock: { clock.now })
        XCTAssertFalse(recovered.pet.adopted); XCTAssertNotNil(recovered.notice)
        XCTAssertEqual(defaults.data(forKey: "little-dill.native.v1.recovery"), broken)
    }
    @MainActor func testArenaBestPersistsWithoutReplacingPet() {
        let defaults = suite(), clock = TestClock(t0)
        let store = hatched(defaults, clock, brine: .spicy, name: "Big Dill")
        store.recordArena(best: 120); store.recordArena(best: 80); store.recordArena(best: 9999); store.recordArena(best: -1)
        let loaded = DillStore(defaults: defaults, clock: { clock.now })
        XCTAssertEqual(loaded.pet.arenaBest, 9999); XCTAssertEqual(loaded.pet.name, "Big Dill"); XCTAssertEqual(loaded.pet.brine, .spicy)
    }
    @MainActor func testNativeV1SaveMigratesToWebLife() throws {
        let defaults = suite(), birthday = t0.addingTimeInterval(-3 * 86400), now = t0
        var legacy: [String: Any] = ["version": 1, "name": "Sir Crunch", "brine": "garlic", "outfit": "crown", "adopted": true,
            "birthday": birthday.timeIntervalSinceReferenceDate, "updatedAt": birthday.timeIntervalSinceReferenceDate,
            "food": 44.5, "joy": 61, "clean": 50, "energy": 100, "coins": 150, "unlocked": ["original", "sprout", "crown"],
            "careDay": "2026-09-16", "dailyCare": ["feed"], "streak": 3, "lastVisitDay": "2026-09-16", "scores": [String](),
            "rewardedDays": ["2026-09-16"], "haptics": false, "arenaBest": 120]
        defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "little-dill.native.v1")
        let store = DillStore(defaults: defaults, clock: { now })
        let life = store.pet.life
        XCTAssertEqual(life.phase, .living); XCTAssertEqual(life.name, "Sir Crunch"); XCTAssertEqual(life.variety, "garlic"); XCTAssertEqual(life.brine, "garlic")
        XCTAssertEqual(life.fullness, 44.5); XCTAssertEqual(life.happiness, 61); XCTAssertEqual(life.hygiene, 50); XCTAssertEqual(life.energy, 100)
        XCTAssertEqual(life.bornAt, ms(birthday)); XCTAssertEqual(life.hatchAt, ms(birthday)); XCTAssertEqual(life.brinedAt, ms(birthday) - 60_000)
        XCTAssertEqual(life.lastCareAt, ms(now)); XCTAssertEqual(life.updatedAt, ms(now)); XCTAssertFalse(life.sick); XCTAssertFalse(life.dead)
        XCTAssertEqual(store.pet.version, 2); XCTAssertEqual(store.pet.coins, 150); XCTAssertEqual(store.pet.outfit, .crown)
        XCTAssertFalse(store.pet.haptics); XCTAssertEqual(store.pet.arenaBest, 120); XCTAssertNil(store.notice)
        XCTAssertEqual(DillStore(defaults: defaults, clock: { now }).pet.life, life)
        legacy["adopted"] = false
        defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "little-dill.native.v1")
        let unadopted = DillStore(defaults: defaults, clock: { now })
        XCTAssertEqual(unadopted.pet.life.phase, .new); XCTAssertEqual(unadopted.pet.coins, 150)
        legacy["adopted"] = true; legacy["name"] = "   "
        let broken = try JSONSerialization.data(withJSONObject: legacy)
        defaults.set(broken, forKey: "little-dill.native.v1")
        let reset = DillStore(defaults: defaults, clock: { now })
        XCTAssertNotNil(reset.notice); XCTAssertFalse(reset.pet.adopted); XCTAssertEqual(reset.pet.coins, 150, "A new egg keeps native progress")
        XCTAssertEqual(defaults.data(forKey: "little-dill.native.v1.recovery"), broken)
    }
    @MainActor func testOutOfRangeSaveIsRepairedAndKeepsThePickle() throws {
        let defaults = suite(), clock = TestClock(t0)
        var saved = hatched(defaults, clock, name: "Crunch").pet
        saved.coins = 5_000_000; saved.streak = Int.max; saved.outfit = .crown
        let original = try JSONEncoder().encode(saved)
        defaults.set(original, forKey: "little-dill.native.v1")
        let store = DillStore(defaults: defaults, clock: { clock.now })
        XCTAssertTrue(store.pet.adopted); XCTAssertEqual(store.pet.name, "Crunch"); XCTAssertEqual(store.pet.life.bornAt, saved.life.bornAt)
        XCTAssertEqual(store.pet.coins, PetState.maxCoins); XCTAssertEqual(store.pet.streak, PetState.maxStreak); XCTAssertEqual(store.pet.outfit, .sprout)
        XCTAssertTrue(store.pet.isValid); XCTAssertEqual(store.recoveryCopy, original)
        XCTAssertEqual(store.notice?.hasPrefix("Some saved progress was out of range"), true)
        XCTAssertNil(DillStore(defaults: defaults, clock: { clock.now }).notice, "The repaired save loads cleanly")
        defaults.set(Data("broken-save".utf8), forKey: "little-dill.native.v1")
        let reset = DillStore(defaults: defaults, clock: { clock.now })
        XCTAssertFalse(reset.pet.adopted); XCTAssertEqual(reset.recoveryCopy, original, "A later failure keeps the first recovery copy")
        XCTAssertEqual(reset.notice?.hasSuffix("An earlier recovery copy is still in Settings → Backups."), true)
    }
    @MainActor func testBackupRoundTripCarriesNativeExtrasAndCanBeUndone() throws {
        let clockA = TestClock(t0), a = hatched(suite(), clockA, brine: .spicy, name: "Sir Crunch")
        XCTAssertEqual(a.care(.feed).coins, 5)
        XCTAssertEqual(a.record(score: 250, day: DailyChallenge.today(clockA.now)), 25)
        XCTAssertTrue(a.equip(.shades))
        XCTAssertTrue(a.startArcade()); a.finishArcade(game: "catch", score: 7, completed: true)
        let file = try a.exportBackup()
        XCTAssertLessThanOrEqual(file.count, DillBackup.MAX_FILE_BYTES)
        let clockB = TestClock(t0.addingTimeInterval(3600)), b = DillStore(defaults: suite(), clock: { clockB.now })
        let preview = try b.previewBackup(file)
        XCTAssertEqual(preview.name, "Sir Crunch"); XCTAssertEqual(preview.condition, "Awake"); XCTAssertEqual(preview.ageDays, 0)
        XCTAssertEqual(preview.savedAt, clockA.now); XCTAssertEqual(preview.rows.map(\.label), ["Name", "Age", "Food", "Happy", "Energy", "Clean", "Condition"])
        let exported = a.pet.life
        b.restoreBackup(preview)
        XCTAssertEqual(b.pet.name, "Sir Crunch"); XCTAssertEqual(b.pet.coins, 0); XCTAssertEqual(b.pet.outfit, .shades)
        XCTAssertEqual(b.pet.arcadeRecords["catch"], 7); XCTAssertEqual(b.pet.scores.first?.score, 250)
        XCTAssertEqual(b.pet.life.fullness, exported.fullness - 1.5 * 3540 / 3600, accuracy: 1e-9, "Elapsed time applies after restore")
        XCTAssertTrue(b.canUndoRestore); XCTAssertTrue(b.undoRestore())
        XCTAssertEqual(b.pet.life.phase, .new); XCTAssertEqual(b.pet.coins, 20); XCTAssertFalse(b.canUndoRestore); XCTAssertFalse(b.undoRestore())
    }
    @MainActor func testWebBackupWithoutNativeKeepsNativeExtras() throws {
        var pet = PetLife.fresh(now: ms(t0))
        pet.phase = .living; pet.name = "Web Dill"; pet.variety = "gherkin"; pet.brinedAt = ms(t0) - 60_000; pet.hatchAt = ms(t0); pet.bornAt = ms(t0)
        let file = try DillBackup.encode(pet: pet, native: nil, savedAt: ms(t0))
        let clock = TestClock(t0), store = hatched(suite(), clock)
        _ = store.care(.wash)
        store.restoreBackup(try store.previewBackup(file))
        XCTAssertEqual(store.pet.name, "Web Dill"); XCTAssertEqual(store.pet.variety.name, "Tiny Gherkin"); XCTAssertEqual(store.pet.coins, 25)
    }
    @MainActor func testLegacyWebBackupRestoresThroughMigration() throws {
        let v1 = "{\"version\":1,\"savedAt\":\(ms(t0)),\"pet\":{\"version\":1,\"fullness\":83.25,\"happiness\":71.75,\"energy\":44.5,\"hygiene\":90,\"ageTicks\":1200,\"neglect\":0,\"sleeping\":true,\"sick\":false,\"dead\":false,\"updatedAt\":\(ms(t0))}}"
        let clock = TestClock(t0), store = DillStore(defaults: suite(), clock: { clock.now })
        let preview = try store.previewBackup(try seal(v1))
        XCTAssertEqual(preview.rows.map(\.value), ["Unnamed pickle", "14 days", "83/100", "72/100", "45/100", "90/100", "Sleeping"])
        store.restoreBackup(preview)
        XCTAssertEqual(store.pet.name, "Little Dill"); XCTAssertTrue(store.pet.life.sleeping); XCTAssertEqual(store.pet.stage(at: t0), .elder)
    }
    func testDamagedBackupsUseTheWebMessages() throws {
        var pet = PetLife.fresh(now: ms(t0)); pet.phase = .naming; pet.brinedAt = ms(t0) - 60_000; pet.hatchAt = ms(t0)
        let file = try DillBackup.encode(pet: pet, native: DillBackup.Native(), savedAt: ms(t0))
        var envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: file) as? [String: Any])
        var bytes = try XCTUnwrap(Data(base64Encoded: envelope["data"] as? String ?? ""))
        bytes[bytes.count / 2] ^= 1
        envelope["data"] = bytes.base64EncodedString()
        XCTAssertThrowsError(try DillBackup.decode(JSONSerialization.data(withJSONObject: envelope))) {
            XCTAssertEqual($0.localizedDescription, "This save has been changed or damaged. Your current pickle is safe.")
        }
        envelope["extra"] = 1
        XCTAssertThrowsError(try DillBackup.decode(JSONSerialization.data(withJSONObject: envelope))) {
            XCTAssertEqual($0.localizedDescription, "This save format is not supported. Choose an encrypted .dill backup from little dill.")
        }
        XCTAssertThrowsError(try DillBackup.decode(Data("not json".utf8))) { XCTAssertEqual($0.localizedDescription, "This is not a readable .dill save file.") }
        XCTAssertThrowsError(try DillBackup.decode(try seal("{\"version\":1,\"savedAt\":1,\"pet\":{\"version\":2}}"))) {
            XCTAssertEqual($0.localizedDescription, "This file contains invalid pickle progress.")
        }
        XCTAssertEqual(try DillBackup.decode(file).pet, .current(pet))
    }
    func testBackupNativeKeepsDefaultsForMissingKeys() throws {
        var pet = PetLife.fresh(now: ms(t0)); pet.phase = .naming; pet.brinedAt = ms(t0) - 60_000; pet.hatchAt = ms(t0)
        let json = String(decoding: try JSONEncoder().encode(pet), as: UTF8.self)
        let decoded = try DillBackup.decode(try seal("{\"version\":1,\"savedAt\":\(ms(t0)),\"pet\":\(json),\"native\":{\"coins\":42,\"streak\":3}}"))
        XCTAssertEqual(decoded.native, DillBackup.Native(coins: 42, streak: 3))
    }
    @MainActor func testOversizedImportIsRejectedBeforeDecoding() {
        let store = DillStore(defaults: suite())
        XCTAssertThrowsError(try store.previewBackup(Data(count: 16385))) { XCTAssertEqual($0.localizedDescription, "Choose a .dill save file under 16 KB.") }
    }
}
