import XCTest
import AVFoundation
import SwiftUI
@testable import LittleDill

final class DillTests: XCTestCase {
    private var utc: Calendar {
        var c = Calendar(identifier:.gregorian); c.timeZone = TimeZone(secondsFromGMT:0)!; return c
    }
    private func date(_ text:String) -> Date { ISO8601DateFormatter().date(from:text)! }
    private func pet(at now:Date) -> PetState { var p = PetState(); p.adopted = true; p.birthday = now; p.updatedAt = now; return p }

    func testCareAwardsEachActionOnlyOncePerDay() {
        let now = date("2026-09-17T12:00:00Z")
        var p = pet(at:now)
        for action in Care.allCases { XCTAssertEqual(p.care(action,at:now),5); XCTAssertEqual(p.care(action,at:now),0) }
        XCTAssertEqual(p.coins,40); XCTAssertEqual(p.dailyCare.count,4)
        XCTAssertEqual(p.care(.feed,at:now.addingTimeInterval(86400)),5)
    }
    func testDailyDecayAndWeekendFloor() {
        let now = date("2026-09-17T12:00:00Z"); var p = pet(at:now)
        p.refresh(at:now.addingTimeInterval(86400),calendar:utc)
        XCTAssertEqual(p.food,44); XCTAssertEqual(p.joy,61); XCTAssertEqual(p.clean,50); XCTAssertEqual(p.energy,100)
        p.refresh(at:now.addingTimeInterval(86400*365),calendar:utc)
        XCTAssertEqual(p.food,10); XCTAssertEqual(p.joy,10); XCTAssertEqual(p.clean,10); XCTAssertTrue(p.adopted)
    }
    func testClockRollbackDoesNotDuplicateDecay() {
        let now = date("2026-09-17T12:00:00Z"); var p = pet(at:now)
        p.refresh(at:now.addingTimeInterval(-86400),calendar:utc)
        XCTAssertEqual(p.updatedAt,now); XCTAssertEqual(p.food,80)
        p.refresh(at:now,calendar:utc); XCTAssertEqual(p.food,80)
    }
    func testStreakAndMissedDay() {
        let now = date("2026-09-17T12:00:00Z"); var p = pet(at:now)
        p.refresh(at:now,calendar:utc); XCTAssertEqual(p.streak,1)
        p.refresh(at:now.addingTimeInterval(3600),calendar:utc); XCTAssertEqual(p.streak,1)
        p.refresh(at:now.addingTimeInterval(86400),calendar:utc); XCTAssertEqual(p.streak,2)
        p.refresh(at:now.addingTimeInterval(86400*3),calendar:utc); XCTAssertEqual(p.streak,1)
    }
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
    func testBestScoreAndRewardsAreIdempotent() {
        let now = date("2026-09-17T12:00:00Z"); var p = pet(at:now)
        XCTAssertEqual(p.record(score:150,day:"2026-09-17",at:now),25)
        XCTAssertEqual(p.record(score:140,day:"2026-09-17",at:now),0)
        XCTAssertEqual(p.record(score:280,day:"2026-09-17",at:now),0)
        XCTAssertEqual(p.scores.count,1); XCTAssertEqual(p.scores.first?.score,280); XCTAssertEqual(p.coins,45)
        XCTAssertEqual(p.record(score:300,day:"2026-09-16",at:now),0)
        XCTAssertEqual(p.record(score:301,day:"2026-09-17",at:now),0)
        XCTAssertEqual(p.record(score:-1,day:"2026-09-17",at:now),0)
        XCTAssertEqual(p.scores.count,2)
    }
    func testUnlockCannotOverdrawOrChargeTwice() {
        var p = PetState()
        XCTAssertFalse(p.equip(.crown)); XCTAssertEqual(p.coins,20); XCTAssertEqual(p.outfit,.sprout)
        p.coins = 50
        XCTAssertTrue(p.equip(.shades)); XCTAssertEqual(p.coins,0)
        XCTAssertTrue(p.equip(.original)); XCTAssertTrue(p.equip(.shades)); XCTAssertEqual(p.coins,0)
    }
    func testSaveRoundtripPreservesProgress() throws {
        var p = PetState(); p.adopted = true; p.name = "Sir Crunch"; p.brine = .spicy; p.coins = 150
        _ = p.equip(.crown); _ = p.care(.feed)
        let loaded = try JSONDecoder().decode(PetState.self,from:JSONEncoder().encode(p))
        XCTAssertTrue(loaded.isValid); XCTAssertEqual(loaded.name,"Sir Crunch"); XCTAssertEqual(loaded.outfit,.crown); XCTAssertEqual(loaded.dailyCare,p.dailyCare); XCTAssertEqual(loaded.coins,p.coins)
    }
    func testInvalidSaveIsRejected() {
        var p = PetState(); XCTAssertTrue(p.isValid)
        p.coins = -1; XCTAssertFalse(p.isValid)
        p.coins = 10; p.name = ""; XCTAssertFalse(p.isValid)
        p.name = "Dilly"; p.outfit = .crown; XCTAssertFalse(p.isValid)
    }
    @MainActor func testPersistenceAndCorruptSaveRecovery() {
        let suite = "test.dill.\(UUID())"; let defaults = UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite) }
        let store = DillStore(defaults:defaults); store.adopt(name:"  Crunch  ",brine:.garlic)
        _ = store.care(.feed)
        let reloaded = DillStore(defaults:defaults)
        XCTAssertEqual(reloaded.pet.name,"Crunch"); XCTAssertEqual(reloaded.pet.brine,.garlic); XCTAssertEqual(reloaded.pet.coins,25)
        let broken = Data("broken-save".utf8); defaults.set(broken,forKey:"little-dill.native.v1")
        let recovered = DillStore(defaults:defaults)
        XCTAssertFalse(recovered.pet.adopted); XCTAssertNotNil(recovered.notice)
        XCTAssertEqual(defaults.data(forKey:"little-dill.native.v1.recovery"),broken)
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
        XCTAssertNil(ArenaLaunch.from(URL(string:"https://other.example/?room=ABC123")!))
        XCTAssertNil(ArenaLaunch.from(URL(string:"littledill://arena?room=invalid")!))
        for _ in 0..<100 {XCTAssertTrue(ArenaLaunch.validRoom(ArenaLaunch.newRoom()))}
    }
    @MainActor func testArenaBestPersistsWithoutReplacingPet() {
        let suite = "test.arena.\(UUID())"; let defaults = UserDefaults(suiteName:suite)!
        defer {defaults.removePersistentDomain(forName:suite)}
        let store = DillStore(defaults:defaults); store.adopt(name:"Big Dill",brine:.spicy)
        store.recordArena(best:120); store.recordArena(best:80); store.recordArena(best:9999); store.recordArena(best:-1)
        let loaded = DillStore(defaults:defaults)
        XCTAssertEqual(loaded.pet.arenaBest,9999); XCTAssertEqual(loaded.pet.name,"Big Dill")
        XCTAssertEqual(loaded.pet.brine,.spicy)
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
