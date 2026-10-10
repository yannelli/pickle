import Foundation

/// Plays 10 Hz server snapshots on a steady clock slightly behind the newest tick.
/// Early or late packets nudge the playback rate instead of jumping or stalling the camera.
struct ArenaPlayback {
    static let tickRate = 20.0
    static let delay = 0.13
    static let maxRateChange = 0.15
    static let maxLead = 0.05
    private(set) var history: [ArenaSnapshot] = []
    private var anchor: (tick:Int,at:Date)?
    private var clock: Double?
    private var frameAt: Date?

    static func seconds(_ snapshot:ArenaSnapshot) -> Double {Double(snapshot.tick) / tickRate}

    /// Keeps the newest four snapshots; a repeated tick is ignored and an older tick restarts playback.
    mutating func receive(_ snapshot:ArenaSnapshot,at date:Date) {
        if let last = history.last {
            if snapshot.tick == last.tick {return}
            if snapshot.tick < last.tick {self = ArenaPlayback()}
        }
        history.append(snapshot)
        if history.count > 4 {history.removeFirst(history.count - 4)}
        anchor = (snapshot.tick,date)
    }

    /// Server seconds to show at `now`. The clock follows real time and corrects at most 15% toward the newest arrival.
    mutating func time(at now:Date) -> Double? {
        guard let anchor else {return nil}
        let target = Double(anchor.tick) / Self.tickRate - Self.delay + now.timeIntervalSince(anchor.at)
        defer {frameAt = now}
        guard let clock, let frameAt else {self.clock = target; return target}
        let dt = now.timeIntervalSince(frameAt), drift = target - clock - dt
        guard (0...0.5).contains(dt), abs(drift) < 0.25 else {self.clock = target; return target}
        let limit = Self.maxRateChange * dt
        let next = clock + dt + max(-limit,min(limit,drift * dt * 4))
        self.clock = next
        return next
    }

    /// The snapshots on either side of `time` and the blend between them. Before the history it holds the oldest snapshot;
    /// past the newest tick it extrapolates the last step for up to `maxLead` seconds, then holds.
    func frame(at time:Double) -> (from:ArenaSnapshot,to:ArenaSnapshot,blend:Double)? {
        guard let last = history.last else {return nil}
        for (from,to) in zip(history,history.dropFirst()) where time <= Self.seconds(to) {
            let start = Self.seconds(from), span = Self.seconds(to) - start
            return (from,to,max(0,min(1,(time - start) / span)))
        }
        guard history.count > 1 else {return (last,last,1)}
        let from = history[history.count - 2], start = Self.seconds(from), span = Self.seconds(last) - start
        return (from,last,min(time - start,span + Self.maxLead) / span)
    }
}
