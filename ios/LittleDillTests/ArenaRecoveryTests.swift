import XCTest
@testable import LittleDill

final class ArenaRecoveryTests: XCTestCase {
    private func isolatedDefaults() -> (UserDefaults,String) {
        let suite = "arena-recovery-\(UUID())"
        return (UserDefaults(suiteName:suite)!,suite)
    }

    @MainActor private func send(_ packet:[String:Any],to client:ArenaClient,at date:Date) throws {
        client.consume(try JSONSerialization.data(withJSONObject:packet),at:date)
    }

    private func welcome(token:String? = nil,room:String = "public-7",resumed:Bool = false) -> [String:Any] {
        var packet:[String:Any] = ["type":"welcome","protocol":1,"id":"you","room":room]
        if let token {
            packet["resumeToken"] = token
            packet["resumeRoom"] = room
            packet["reconnectGraceSeconds"] = 30
            packet["resumed"] = resumed
        }
        return packet
    }

    private func state(tick:Int,food:[[Double]]? = nil) -> [String:Any] {
        let player:[String:Any] = [
            "id":"you","name":"Dilly","brine":"classic","outfit":"sprout","variety":"classic",
            "bot":false,"x":100,"y":200,"mass":120,"best":120,"kills":1,"alive":true,
            "shield":0,"dash":0,"cooldown":0,"respawn":0,"eatenBy":"",
            "cells":[["id":"a","x":100,"y":200,"mass":60],["id":"b","x":140,"y":200,"mass":60]]
        ]
        var packet:[String:Any] = ["type":"state","tick":tick,"time":1,"width":6000,"height":4500,"humans":1,"bots":0,"players":[player]]
        if let food {packet["food"] = food}
        return packet
    }

    func testCredentialsHaveExactThirtySecondWindowAndRoom() throws {
        let (defaults,suite) = isolatedDefaults()
        defer {defaults.removePersistentDomain(forName:suite)}
        let now = Date(), token = UUID().uuidString
        let saved = ArenaResume(token:token,room:"crew-IO01AZ",deadline:now.addingTimeInterval(30),grace:30)
        XCTAssertTrue(saved.canResume(at:now))
        XCTAssertTrue(saved.matches(room:"IO01AZ"))
        XCTAssertFalse(saved.matches(room:"OTHER1"))
        XCTAssertTrue(ArenaLaunch.validRoom("IO01AZ"))
        saved.save(to:defaults)
        XCTAssertEqual(ArenaResume.load(from:defaults,at:now.addingTimeInterval(29.9)),saved)
        XCTAssertNil(ArenaResume.load(from:defaults,at:now.addingTimeInterval(30)))
        XCTAssertNil(defaults.data(forKey:ArenaResume.key))
        XCTAssertFalse(ArenaResume(token:token,room:"public-7",deadline:now.addingTimeInterval(29),grace:29).isValid)
        XCTAssertFalse(saved.canResume(at:now.addingTimeInterval(-0.1)))
        let endpoint = try XCTUnwrap(saved.endpoint(base:"wss://arena.littledill.app/arena"))
        let query = try XCTUnwrap(URLComponents(url:endpoint,resolvingAgainstBaseURL:false)?.queryItems)
        XCTAssertEqual(query.first(where:{$0.name == "resumeToken"})?.value,token)
        XCTAssertEqual(query.first(where:{$0.name == "resumeRoom"})?.value,"crew-IO01AZ")
    }

    @MainActor func testResumeKeepsRunUntilMatchingFullStateThenReplacesFood() throws {
        let (defaults,suite) = isolatedDefaults()
        defer {defaults.removePersistentDomain(forName:suite)}
        var released:ArenaResume?
        let client = ArenaClient(defaults:defaults,cleanup:{resume,_ in released = resume})
        let now = Date(), token = UUID().uuidString
        try send(welcome(token:token),to:client,at:now)
        try send(state(tick:100,food:[[1,10,20,3]]),to:client,at:now)
        XCTAssertEqual(client.status,.playing)
        client.suspend()
        XCTAssertEqual(client.status,.reconnecting)
        XCTAssertEqual(client.me?.pieces.count,2)
        XCTAssertEqual(client.food,[[1,10,20,3]])
        try send(welcome(token:token,resumed:true),to:client,at:now.addingTimeInterval(10))
        XCTAssertEqual(ArenaResume.load(from:defaults,at:now.addingTimeInterval(10))?.deadline,now.addingTimeInterval(30))
        try send(state(tick:98,food:[[2,30,40,4]]),to:client,at:now.addingTimeInterval(11))
        XCTAssertEqual(client.status,.playing)
        XCTAssertEqual(client.snapshot?.tick,98)
        XCTAssertNil(client.previous)
        XCTAssertEqual(client.food,[[2,30,40,4]])
        XCTAssertEqual(ArenaResume.load(from:defaults,at:now.addingTimeInterval(11))?.deadline,now.addingTimeInterval(41))
        client.suspend()
        client.leave()
        XCTAssertEqual(released?.token,token)
        XCTAssertNil(defaults.data(forKey:ArenaResume.key))
        XCTAssertEqual(client.status,.disconnected)
    }

    @MainActor func testRecoveryRejectsLegacyMissingFoodAndMismatchedWelcome() throws {
        let (defaults,suite) = isolatedDefaults()
        defer {defaults.removePersistentDomain(forName:suite)}
        let now = Date(), token = UUID().uuidString
        let legacy = ArenaClient(defaults:defaults,cleanup:{_,_ in})
        try send(welcome(),to:legacy,at:now)
        try send(state(tick:1,food:[]),to:legacy,at:now)
        legacy.suspend()
        XCTAssertEqual(legacy.status,.disconnected)
        XCTAssertNil(defaults.data(forKey:ArenaResume.key))

        let missingFood = ArenaClient(defaults:defaults,cleanup:{_,_ in})
        try send(welcome(token:token),to:missingFood,at:now)
        try send(state(tick:1,food:[]),to:missingFood,at:now)
        missingFood.suspend()
        try send(welcome(token:token,resumed:true),to:missingFood,at:now.addingTimeInterval(1))
        try send(state(tick:2),to:missingFood,at:now.addingTimeInterval(2))
        XCTAssertEqual(missingFood.status,.disconnected)
        XCTAssertNil(defaults.data(forKey:ArenaResume.key))

        let mismatched = ArenaClient(defaults:defaults,cleanup:{_,_ in})
        try send(welcome(token:token),to:mismatched,at:now)
        mismatched.suspend()
        try send(welcome(token:UUID().uuidString,resumed:true),to:mismatched,at:now.addingTimeInterval(1))
        XCTAssertEqual(mismatched.status,.disconnected)
        XCTAssertNil(defaults.data(forKey:ArenaResume.key))

        let rejected = ArenaClient(defaults:defaults,cleanup:{_,_ in})
        try send(welcome(token:token),to:rejected,at:now)
        rejected.suspend()
        try send(welcome(token:token,resumed:false),to:rejected,at:now.addingTimeInterval(1))
        XCTAssertEqual(rejected.status,.disconnected)
        XCTAssertNil(defaults.data(forKey:ArenaResume.key))

        let expired = ArenaClient(defaults:defaults,cleanup:{_,_ in})
        try send(welcome(token:token),to:expired,at:now)
        expired.suspend()
        try send(welcome(token:token,resumed:true),to:expired,at:now.addingTimeInterval(30))
        XCTAssertEqual(expired.status,.disconnected)
        XCTAssertTrue(expired.errorMessage.contains("30-second"))
        XCTAssertNil(defaults.data(forKey:ArenaResume.key))
    }

    @MainActor func testTerminalClosesAndRetrySchedule() throws {
        let (defaults,suite) = isolatedDefaults()
        defer {defaults.removePersistentDomain(forName:suite)}
        let now = Date(), token = UUID().uuidString
        for code in [4001,1008] {
            let client = ArenaClient(defaults:defaults,cleanup:{_,_ in})
            try send(welcome(token:token),to:client,at:now)
            XCTAssertTrue(client.handleTerminalClose(code))
            XCTAssertEqual(client.status,.disconnected)
            XCTAssertNil(defaults.data(forKey:ArenaResume.key))
        }
        XCTAssertFalse(ArenaClient(defaults:defaults,cleanup:{_,_ in}).handleTerminalClose(1006))
        XCTAssertEqual((1...7).map(ArenaClient.retryDelay(for:)),[0.25,0.7,1.5,2.5,4,4,4])
    }
}
