import SwiftUI

struct ArenaView: View {
    let launch: ArenaLaunch
    @EnvironmentObject private var store: DillStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var client = ArenaClient()
    @State private var motion = ArenaMotion()
    @State private var leave = false
    @State private var showScores = false
    @State private var stick = CGSize.zero
    @State private var pickups = ArenaPickupCadence()
    @State private var tactile = ArenaFeedback()
    @State private var feedbackEvents = ArenaFeedbackEvents()
    @AppStorage("little-dill.arena-controls-swapped",store:ArenaResume.defaults) private var controlsSwapped = false
    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 430
            ZStack {
                Color(hex:0xE7ECD8).ignoresSafeArea()
                if let snapshot = client.snapshot, let me = client.me {
                    TimelineView(.animation(minimumInterval:1/60,paused:client.status != .playing)) { timeline in
                        ArenaCanvas(snapshot:snapshot,previous:client.previous,food:client.food,me:me,spitAt:client.spitAt,received:client.receivedAt,now:timeline.date,motion:motion)
                    }.ignoresSafeArea().accessibilityLabel("Live Brine Royale arena. You are \(me.name), mass \(Int(me.mass)), rank \(client.rank), \(me.pieces.count) \(me.isCucumber ? "cucumbers" : "pickle").")
                }
                VStack(spacing:0) {
                    topBar
                    if let me = client.me {
                        scoreBar(me,compact:compact)
                        Spacer(minLength:0)
                        if me.alive {
                            ArenaControls(me:me,compact:compact,swapped:controlsSwapped,stick:$stick,
                                          steer:client.steer,split:client.split,dash:client.dash,
                                          swap:{controlsSwapped.toggle()},feedback:tactile.play)
                                .disabled(client.status != .playing)
                        }
                    } else {Spacer()}
                }
                if client.status == .connecting {connectionCard}
                else if client.status == .reconnecting {reconnectingCard}
                else if client.status == .disconnected {disconnectedCard}
                else if let me = client.me, !me.alive {respawnCard(me)}
            }
        }.foregroundStyle(DillTheme.ink)
            .statusBarHidden()
            .persistentSystemOverlays(.hidden)
            .onAppear {client.connect(pet:store.pet,room:launch.room)}
            .onDisappear {saveBest(); client.suspend(); DillAudio.shared.stop(); tactile.enabled = false; feedbackEvents.reset()}
            .onChange(of:client.status) {_,status in
                if status == .reconnecting || status == .disconnected {saveBest(); stick = .zero}
                updateGadgetSound(); updateHaptics()
                if status == .playing {tactile.prepare()}
            }
            .onChange(of:client.me?.alive) { old,alive in
                if old == true && alive == false {saveBest(); tactile.stop(); tactile.play(.eaten); store.sound(.eaten)}
                if old == false && alive == true {store.sound(.respawn)}
            }
            .onChange(of:client.receivedAt) {_,_ in listen()}
            .onChange(of:store.pet.sounds) {_,_ in updateGadgetSound()}
            .onChange(of:store.pet.haptics) {_,_ in updateHaptics()}
            .onChange(of:client.me?.dash) {old,dash in
                if let old, let dash, dash > old + 0.2 {store.sound(.dash); tactile.play(.dash)}
            }
            .onChange(of:client.me?.splitCooldown) {old,cooldown in
                if let old, let cooldown, cooldown > old + 0.3 {store.sound(.slice); tactile.play(.split)}
            }
            .onChange(of:scenePhase) { _,phase in
                if phase == .background {saveBest(); client.suspend(); stick = .zero; DillAudio.shared.stop()}
                if phase == .active {client.resumeIfNeeded()}
                if phase != .active {stick = .zero; client.steer(.zero)}
                updateGadgetSound(); updateHaptics()
            }
            .confirmationDialog("Leave the garden?",isPresented:$leave,titleVisibility:.visible) {
                Button("Leave arena",role:.destructive) {saveBest(); client.leave(); dismiss()}
                Button("Keep growing",role:.cancel) {}
            } message: {Text("Leaving ends this run. Your personal best stays saved.")}
            .interactiveDismissDisabled()
    }
    /// Sounds from one snapshot to the next while alive; death and respawn are handled by the `alive` change.
    private func listen() {
        updateGadgetSound(); updateHaptics()
        guard let snapshot = client.snapshot else {feedbackEvents.reset(); return}
        let at = client.receivedAt.timeIntervalSinceReferenceDate
        let gadget = Self.drainingGadget(player:client.me,hazards:snapshot.hazards ?? [],enabled:tactile.enabled)
        let oldGadget = Self.drainingGadget(player:client.previous?.players.first(where:{$0.id == client.playerID}),
                                            hazards:client.previous?.hazards ?? [],enabled:tactile.enabled)
        if oldGadget != gadget {tactile.cancelGadgetPulses()}
        if let cue = feedbackEvents.gadgetCue(gadget,at:at,active:tactile.enabled) {tactile.play(cue)}
        guard let previous = client.previous,
              let before = previous.players.first(where:{$0.id == client.playerID}), let after = client.me, before.alive, after.alive else {
            _ = feedbackEvents.observe(before:nil,after:snapshot,playerID:client.playerID,at:at,active:tactile.enabled,combat:false)
            return
        }
        let regrouped = Self.regrouped(before:before,after:after)
        let hurt = Self.wasHit(before:before,after:after,regrouped:regrouped)
        let bite = after.kills > before.kills || Self.ateAPiece(before:previous,after:snapshot,playerID:client.playerID)
        if regrouped {tactile.play(.regroup)}
        if after.pieces.count > before.pieces.count && (after.splitCooldown ?? 0) <= (before.splitCooldown ?? 0) + 0.3 {
            store.sound(.slice); tactile.play(.split)
        }
        if hurt {
            tactile.play(.eaten); store.sound(.eaten)
        }
        else if bite {store.sound(.gulp); tactile.play(.bite)}
        else if after.mass >= before.mass + 2, store.pet.sounds, scenePhase == .active,
                let cue = pickups.next(at:Date().timeIntervalSinceReferenceDate) {
            DillAudio.shared.play(cue.sound,volume:Float(cue.volume))
        }
        for cue in feedbackEvents.observe(before:previous,after:snapshot,playerID:client.playerID,
                                          at:at,active:tactile.enabled,combat:hurt || bite) {tactile.play(cue)}
        if before.cooldown > 0 && after.cooldown <= 0 && after.mass >= 35 ||
            (before.splitCooldown ?? 0) > 0 && after.canSplit {tactile.play(.ready)}
    }
    private func updateHaptics() {
        tactile.enabled = store.pet.haptics && scenePhase == .active && client.status == .playing
        if !tactile.enabled {feedbackEvents.reset()}
    }
    private func updateGadgetSound() {
        let gadget = Self.drainingGadget(player:client.me,hazards:client.snapshot?.hazards ?? [],
                                        enabled:store.pet.sounds && scenePhase == .active && client.status == .playing)
        DillAudio.shared.setGadget(gadget?.drainSound)
    }
    static func drainingGadget(player:ArenaPlayer?,hazards:[ArenaHazard],enabled:Bool) -> ArenaGadget? {
        guard enabled, let player, player.alive, let cell = player.pieces.first(where:\.draining) else {return nil}
        return ArenaHazard.draining(cell,in:hazards)
    }
    static func regrouped(before:ArenaPlayer,after:ArenaPlayer) -> Bool {
        guard after.pieces.count < before.pieces.count, (before.merge ?? 0) < 0.2,
              after.mass >= before.mass * 0.98 else {return false}
        let surviving = Set(after.pieces.map(\.id))
        let removedMass = before.pieces.filter {!surviving.contains($0.id)}.reduce(0) {$0 + $1.mass}
        let oldMass = Dictionary(uniqueKeysWithValues:before.pieces.map {($0.id,$0.mass)})
        let absorbed = after.pieces.reduce(0) {$0 + max(0,$1.mass - (oldMass[$1.id] ?? $1.mass))}
        return removedMass > 0 && absorbed >= removedMass * 0.8
    }
    static func wasHit(before:ArenaPlayer,after:ArenaPlayer,regrouped:Bool) -> Bool {
        let lostPiece = !Set(before.pieces.map(\.id)).isSubset(of:after.pieces.map(\.id))
        return (after.hurt ?? 0) > (before.hurt ?? 0) + 0.2 ||
            lostPiece && !regrouped && after.mass < before.mass - 1
    }
    /// An enemy piece that touched one of yours vanished while your mass rose by at least half of it.
    static func ateAPiece(before:ArenaSnapshot,after:ArenaSnapshot,playerID:String) -> Bool {
        guard let was = before.players.first(where:{$0.id == playerID}), let mine = after.players.first(where:{$0.id == playerID}) else {return false}
        let gain = mine.mass - was.mass
        let remaining = Set(after.players.flatMap {player in player.pieces.map {player.id + ":" + $0.id}})
        return before.players.contains { other in
            other.id != playerID && other.pieces.contains { piece in
                !remaining.contains(other.id + ":" + piece.id) && gain >= piece.mass * 0.5
                    && mine.pieces.contains {hypot($0.x-piece.x,$0.y-piece.y) < $0.radius + piece.radius + 40}
            }
        }
    }
    private var topBar: some View {
        HStack(spacing:12) {
            Button {leave = true} label: {Image(systemName:"xmark").font(.system(size:15,weight:.semibold)).frame(width:44,height:44).background(DillTheme.cream.opacity(0.95),in:Circle())}.accessibilityLabel("Exit online game").accessibilityIdentifier("arenaLeave")
            VStack(alignment:.leading,spacing:4) {
                Text("brine royale.").font(DillTheme.display(24)).tracking(-1)
                HStack(spacing:5) {
                    Circle().fill(client.status == .playing ? Color(hex:0x5C873E) : DillTheme.muted).frame(width:5,height:5)
                    Text(populationStatus).font(.system(size:10,weight:.medium,design:.rounded)).accessibilityIdentifier("arenaPopulation")
                }
            }
            Spacer(minLength:0)
            if let code = launch.room {
                ShareLink(item:"Come find me in Brine Royale! Room \(code) · \(ArenaLaunch.shareURL(room:code).absoluteString)") {Image(systemName:"person.badge.plus").font(.system(size:18)).frame(width:44,height:44).background(DillTheme.cream.opacity(0.95),in:Circle())}.accessibilityLabel("Invite a friend to room \(code)")
            } else {Image(systemName:"globe").font(.system(size:20)).frame(width:44,height:44).background(DillTheme.cream.opacity(0.95),in:Circle())}
        }.padding(.horizontal,18).padding(.top,8)
    }
    private var populationStatus: String {
        switch client.status {
        case .playing: return "\(client.snapshot?.population ?? 0) in the garden"
        case .connecting: return "Finding your garden…"
        case .reconnecting: return "Reconnecting to your garden…"
        case .disconnected: return "Disconnected"
        }
    }
    private var connectionCard: some View {
        VStack(spacing:20) {
            PickleCharacter(pet:store.pet).frame(width:150,height:150)
            ProgressView().tint(DillTheme.ink)
            Text("Something’s growing.").font(DillTheme.display(29)).multilineTextAlignment(.center)
            Text("Joining a live garden. A little room to roam, a lot of room to grow.").font(.subheadline).foregroundStyle(DillTheme.muted).multilineTextAlignment(.center)
        }.padding(28).frame(maxWidth:350).background(DillTheme.cream,in:RoundedRectangle(cornerRadius:30)).padding(24)
    }
    private var disconnectedCard: some View {
        VStack(spacing:20) {
            Image(systemName:"wifi.exclamationmark").font(.system(size:35))
            Text("Lost in the brine.").font(DillTheme.display(29)).multilineTextAlignment(.center)
            Text(client.errorMessage).font(.subheadline).foregroundStyle(DillTheme.muted).multilineTextAlignment(.center)
            Button {saveBest(); client.connect(pet:store.pet,room:launch.room,fresh:true)} label: {Text("Start a fresh run")}.buttonStyle(DillButton()).accessibilityIdentifier("arenaReconnect")
            Button("Back to my pickle") {client.leave(); dismiss()}.font(.subheadline.bold())
        }.padding(28).frame(maxWidth:350).background(DillTheme.cream,in:RoundedRectangle(cornerRadius:30)).padding(24)
    }
    private var reconnectingCard: some View {
        VStack(spacing:16) {
            ProgressView().tint(DillTheme.ink)
            Text("Holding your pickle.").font(DillTheme.display(28)).multilineTextAlignment(.center)
            TimelineView(.periodic(from:.now,by:1)) { timeline in
                let seconds = max(0,Int(ceil(client.reconnectDeadline?.timeIntervalSince(timeline.date) ?? 0)))
                Text("Reconnecting · \(seconds)s to return").font(.subheadline.bold()).accessibilityIdentifier("arenaReconnecting")
            }
            Text("Your size and slices are waiting right where you left them.").font(.subheadline).foregroundStyle(DillTheme.muted).multilineTextAlignment(.center)
            Button("Leave this run") {saveBest(); client.leave(); dismiss()}.font(.subheadline.bold())
        }.padding(24).frame(maxWidth:330).background(DillTheme.cream,in:RoundedRectangle(cornerRadius:26)).padding(24)
    }
    private func respawnCard(_ me:ArenaPlayer) -> some View {
        VStack(spacing:18) {
            Eyebrow(text:"A little out-crunched")
            Text("You were\na big snack.").font(DillTheme.display(38)).tracking(-1).multilineTextAlignment(.center)
            Text("\(me.eatenBy) got the crunch this time.").font(.subheadline).foregroundStyle(DillTheme.muted).multilineTextAlignment(.center)
            HStack(spacing:25) {VStack {Text("\(me.best)").font(.system(size:30,weight:.bold,design:.rounded)); Eyebrow(text:"Best mass")}; VStack {Text("\(me.kills)").font(.system(size:30,weight:.bold,design:.rounded)); Eyebrow(text:"Pickles eaten")}}
            Button {client.respawn(); store.feedback(.medium)} label: {Text(me.respawn > 0 ? "Fresh brine in \(Int(ceil(me.respawn)))…" : "Grow again")}.buttonStyle(DillButton()).disabled(me.respawn > 0).accessibilityIdentifier("arenaRespawn")
            ShareCardButton(pet:store.pet,score:me.best,title:"Share your run",arenaScore:true,arenaRoom:launch.room)
            Text("Your pet is safe. This is just a little friendly chaos.").font(.caption).foregroundStyle(DillTheme.muted).multilineTextAlignment(.center)
        }.padding(26).frame(maxWidth:350).background(DillTheme.cream,in:RoundedRectangle(cornerRadius:30)).padding(24)
    }
    private func scoreBar(_ me:ArenaPlayer,compact:Bool) -> some View {
        HStack(alignment:.top,spacing:12) {
            VStack(alignment:.leading,spacing:6) {
                HStack(alignment:.center,spacing:10) {
                    VStack(alignment:.leading,spacing:3) {
                        Text("\(Int(me.mass))").font(.system(size:compact ? 28 : 38,weight:.black,design:.rounded)).lineLimit(1).minimumScaleFactor(0.4).contentTransition(.numericText())
                        Text("TOTAL MASS").font(.system(size:9,weight:.bold,design:.monospaced)).tracking(1).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    if let state = client.snapshot, !compact {
                        ArenaMinimap(snapshot:state,playerID:client.playerID).frame(width:38,height:38).accessibilityLabel("Garden minimap")
                    }
                }
                if me.shield > 0 && me.alive && !compact {
                    Label("Protected \(Int(ceil(me.shield)))s",systemImage:"shield.fill").font(.system(size:10,weight:.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                }
            }.padding(compact ? 10 : 14).background(DillTheme.cream.opacity(0.9),in:RoundedRectangle(cornerRadius:20))
            Spacer(minLength:0)
            Button {showScores.toggle()} label: {
                VStack(alignment:.trailing,spacing:compact ? 4 : 8) {
                    Label("#\(client.rank)",systemImage:"crown.fill").font(.system(size:compact ? 17 : 20,weight:.bold,design:.rounded))
                    ForEach(client.leaders.prefix(compact ? 1 : showScores ? 5 : 3)) { leader in
                        HStack(spacing:4) {
                            Text(leader.name).lineLimit(1)
                            Text("\(Int(leader.mass))").bold().lineLimit(1).minimumScaleFactor(0.6).layoutPriority(1)
                        }.font(.system(size:10)).frame(maxWidth:135,alignment:.trailing)
                    }
                }.padding(compact ? 10 : 14).background(DillTheme.cream.opacity(0.9),in:RoundedRectangle(cornerRadius:20))
            }.accessibilityLabel("Leaderboard. Rank \(client.rank). Tap to show more.")
        }.padding(.horizontal,18).padding(.top,compact ? 6 : 12)
    }
    private func saveBest() {if client.best > 0 {store.recordArena(best:client.best)}}
}


struct ArenaMinimap: View {
    let snapshot: ArenaSnapshot
    let playerID: String
    var body: some View {
        Canvas { context,size in
            for hazard in snapshot.hazards ?? [] {
                let point = CGPoint(x:hazard.x / snapshot.width * size.width,y:hazard.y / snapshot.height * size.height)
                let marker = Path(roundedRect:CGRect(x:point.x-2,y:point.y-2,width:4,height:4),cornerRadius:1)
                context.fill(marker,with:.color(ArenaCanvas.steel))
                context.stroke(marker,with:.color(DillTheme.ink.opacity(0.6)),lineWidth:0.8)
            }
            for p in snapshot.players where p.alive {
                let r:CGFloat = p.id == playerID ? 3.5 : 2
                for cell in p.pieces {
                    let point = CGPoint(x:cell.x / snapshot.width * size.width,y:cell.y / snapshot.height * size.height)
                    context.fill(Path(ellipseIn:CGRect(x:point.x-r,y:point.y-r,width:r*2,height:r*2)),with:.color(p.id == playerID ? DillTheme.ink : DillTheme.peach))
                }
            }
        }
    }
}

/// Frame-to-frame render state owned by `ArenaView`: eased zoom and one membrane per piece, keyed `playerID:cellID`.
final class ArenaMotion {
    var zoom = 0.0
    var center: CGPoint?
    var frameAt: Date?
    var alive = false
    var tick = Int.min
    var membranes: [String:ArenaMembrane] = [:]
    var membraneClock = 0.0
}

struct ArenaKillRing {
    let hunter: String
    let center: CGPoint
    let radius: Double
    let alpha: Double
}

/// Port of `bodyShape`: a piece's outline in its own frame, a capsule (corner radius `hw`) or an ellipse, turned by `lean`.
struct ArenaShape: Equatable {
    var hw: Double
    var hh: Double
    var lean = 0.0
    var ellipse = false
    var reach: Double {max(hw,hh)}
    init(hw:Double,hh:Double,lean:Double = 0,ellipse:Bool = false) {self.hw = hw; self.hh = hh; self.lean = lean; self.ellipse = ellipse}
    /// Cucumbers are 0.7r x r capsules, round varieties 0.96r x 0.9r ellipses, long and crooked 0.8r x r capsules; crooked leans 0.16 rad.
    init(_ player:ArenaPlayer,r:Double) {
        let cucumber = player.isCucumber, shape = player.look.shape
        if !cucumber && shape == .round {self.init(hw:r*0.96,hh:r*0.9,ellipse:true)}
        else {self.init(hw:r*(cucumber ? 0.7 : 0.8),hh:r,lean:!cucumber && shape == .crooked ? 0.16 : 0)}
    }
    /// Port of `shapeRadius`: distance from the center to the undeformed outline along a local angle.
    func radius(at angle:Double) -> Double {
        let c = abs(cos(angle)), s = abs(sin(angle))
        if ellipse {return 1 / hypot(c / hw,s / hh)}
        let k = max(0,hh - hw)
        if c > 1e-9 && s * hw / c <= k {return hw / c}
        return s * k + sqrt(max(0,(s * k) * (s * k) - k * k + hw * hw))
    }
}

/// Port of the web client's agar-style membrane: `dr` offsets the outline at `n` evenly spaced angles, `acc` drives them.
final class ArenaMembrane {
    let n: Int
    var acc: [Double]
    var dr: [Double]
    init(_ n:Int) {self.n = n; acc = Array(repeating:0,count:n); dr = Array(repeating:0,count:n)}
    /// Port of `membraneSize`: 18 to 72 points, in steps of 6, from the on-screen radius.
    static func size(screenRadius:Double) -> Int {Int(max(18,min(72,(screenRadius / 12).rounded() * 6)))}
    /// Port of `resizeMembrane`: resamples the dents to `count` points; the same count returns this membrane.
    func resized(to count:Int) -> ArenaMembrane {
        guard count != n else {return self}
        let next = ArenaMembrane(count)
        for i in 0..<count {
            let at = Double(i) / Double(count) * Double(n), j = Int(at), t = at - Double(j)
            next.dr[i] = dr[j % n] * (1 - t) + dr[(j + 1) % n] * t
        }
        return next
    }
    /// The dent at a local angle, interpolated between neighbouring points.
    func offset(at angle:Double) -> Double {
        let turn = ((angle / (2 * .pi)).truncatingRemainder(dividingBy:1) + 1).truncatingRemainder(dividingBy:1)
        let at = turn * Double(n), j = Int(at), t = at - Double(j)
        return dr[j % n] * (1 - t) + dr[(j + 1) % n] * t
    }
}

/// One piece for a membrane step, in world units.
struct ArenaBody {
    let key: String
    let x: Double
    let y: Double
    let shape: ArenaShape
    let membrane: ArenaMembrane
    /// Port of `outlineRadius`.
    func outlineRadius(at angle:Double) -> Double {shape.radius(at:angle) + membrane.offset(at:angle)}
    /// Port of `inside`, with the web's +4 reach prefilter and +1 contact margin.
    func contains(_ px:Double,_ py:Double) -> Bool {
        let dx = px - x, dy = py - y, reach = shape.reach + 4
        if dx * dx + dy * dy > reach * reach {return false}
        return hypot(dx,dy) < outlineRadius(at:atan2(dy,dx) - shape.lean) + 1
    }
    /// Port of `stepMembrane`: one 60 Hz step. Points inside another body or past `bounds` accelerate inward,
    /// neighbours smooth each other, and every point relaxes back toward the shape.
    /// Matches `MEMBRANE` in arena-web/arena-core.mjs.
    static let jitter = 0.15, damping = 0.6, push = 1.5, dent = 0.35, bulge = 0.08, relax = 8.0 / 9
    func step(among others:[ArenaBody],bounds:CGSize?,jitter:Double = ArenaBody.jitter,random:() -> Double = {Double.random(in:0..<1)}) {
        let m = membrane, n = m.n
        for i in 0..<n {m.acc[i] = max(-10,min(10,(m.acc[i] + (random() - 0.5) * jitter) * Self.damping))}
        let acc = m.acc
        for i in 0..<n {m.acc[i] = (acc[(i + n - 1) % n] + acc[(i + 1) % n] + 8 * acc[i]) / 10}
        let cosLean = cos(shape.lean), sinLean = sin(shape.lean)
        var next = [Double](repeating:0,count:n)
        for i in 0..<n {
            let angle = Double(i) / Double(n) * (2 * .pi), base = shape.radius(at:angle), r = base + m.dr[i]
            let lx = cos(angle) * r, ly = sin(angle) * r, px = x + lx * cosLean - ly * sinLean, py = y + lx * sinLean + ly * cosLean
            let outside = bounds.map {px < 0 || py < 0 || px > $0.width || py > $0.height} ?? false
            if outside || others.contains(where:{$0.membrane !== m && $0.contains(px,py)}) {
                if m.acc[i] > 0 {m.acc[i] = 0}
                m.acc[i] -= Self.push
            }
            next[i] = max(-Self.dent * base,min(Self.bulge * base,m.dr[i] + m.acc[i])) * Self.relax
        }
        for i in 0..<n {m.dr[i] = (next[(i + n - 1) % n] + next[(i + 1) % n] + 8 * next[i]) / 10}
    }
    /// Steps every body in order against the bodies whose bounding circles come within 8 units, updating membranes in place.
    static func step(_ bodies:[ArenaBody],bounds:CGSize,jitter:Double,random:() -> Double = {Double.random(in:0..<1)}) {
        for body in bodies {
            let near = bodies.filter {$0.membrane !== body.membrane && hypot($0.x - body.x,$0.y - body.y) < body.shape.reach + $0.shape.reach + 8}
            body.step(among:near,bounds:bounds,jitter:jitter,random:random)
        }
    }
    /// Port of `membraneOutline`: outline points in the piece's rotated frame, times `scale`.
    func outline(scale:Double = 1) -> [CGPoint] {
        (0..<membrane.n).map { i in
            let angle = Double(i) / Double(membrane.n) * (2 * .pi), r = (shape.radius(at:angle) + membrane.dr[i]) * scale
            return CGPoint(x:cos(angle) * r,y:sin(angle) * r)
        }
    }
}

struct ArenaCanvas: View {
    let snapshot: ArenaSnapshot
    let previous: ArenaSnapshot?
    let food: [[Double]]
    let me: ArenaPlayer
    var spitAt: [Double:Date] = [:]
    let received: Date
    let now: Date
    var motion = ArenaMotion()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    static let danger = Color(hex:0xC8553D)
    static let brine = Color(hex:0x9CC26B)
    static let steel = Color(hex:0xD5DEE1)

    var body: some View {
        let still = reduceMotion
        Canvas { context,size in
            let time = now.timeIntervalSinceReferenceDate
            let blend = min(1,max(0,now.timeIntervalSince(received) / 0.1))
            func keyed(_ players:[ArenaPlayer]) -> [String:ArenaCell] {
                Dictionary(players.flatMap {player in player.pieces.map {(player.id + ":" + $0.id,$0)}},uniquingKeysWith:{first,_ in first})
            }
            let old = keyed(previous?.players ?? []), raw = keyed(snapshot.players)
            let players = snapshot.players.map { player -> ArenaPlayer in
                guard player.alive else {return player}
                var moving = player
                moving.cells = player.pieces.map { cell in
                    guard let before = old[player.id + ":" + cell.id], hypot(cell.x-before.x,cell.y-before.y) < 400 else {return cell}
                    return ArenaCell(id:cell.id,x:before.x + (cell.x-before.x)*blend,y:before.y + (cell.y-before.y)*blend,mass:before.mass + (cell.mass-before.mass)*blend,drain:cell.drain)
                }
                return moving
            }
            let mine = players.first {$0.id == me.id} ?? me
            let own = mine.pieces
            let target = own.isEmpty && motion.center != nil
                ? ArenaCamera(center:motion.center!,zoom:motion.zoom)
                : ArenaPlayer.camera(cells:own,mass:own.isEmpty ? me.mass : own.reduce(0) {$0 + $1.mass},width:size.width,height:size.height)
            let dt = motion.frameAt.map {now.timeIntervalSince($0)} ?? .infinity
            let snap = !(0...0.5).contains(dt) || (mine.alive && !motion.alive)
            motion.zoom = snap ? target.zoom : ArenaPlayer.easeZoom(current:motion.zoom,target:target.zoom,dt:dt)
            motion.center = target.center; motion.frameAt = now; motion.alive = mine.alive
            let zoom = motion.zoom
            let cameraX = target.center.x
            let cameraY = target.center.y
            func screen(_ p:CGPoint) -> CGPoint {CGPoint(x:(p.x-cameraX)*zoom + size.width/2,y:(p.y-cameraY)*zoom + size.height/2)}
            func onScreen(_ p:CGPoint,margin:Double) -> Bool {p.x > -margin && p.y > -margin && p.x < size.width+margin && p.y < size.height+margin}
            let worldOrigin = screen(.zero)
            let world = CGRect(x:worldOrigin.x,y:worldOrigin.y,width:snapshot.width*zoom,height:snapshot.height*zoom)
            context.fill(Path(roundedRect:world,cornerRadius:30),with:.color(Color(hex:0xEDF1E3)))
            var scenery = context
            scenery.clip(to:Path(roundedRect:world,cornerRadius:30))
            let leafOffsets = [CGPoint(x:160,y:230),CGPoint(x:690,y:640),CGPoint(x:330,y:750)]
            for row in 0..<Int(ceil(snapshot.height/900)) {
                for column in 0..<Int(ceil(snapshot.width/900)) {
                    let origin = CGPoint(x:Double(column)*900,y:Double(row)*900)
                    let tile = screen(origin)
                    guard tile.x < size.width && tile.y < size.height && tile.x+900*zoom > 0 && tile.y+900*zoom > 0 else {continue}
                    let patch = screen(CGPoint(x:origin.x+450,y:origin.y+450))
                    let tint = Color(hex:(row+column)%2 == 0 ? 0xDDE7CC : 0xD9E3D3)
                    scenery.fill(Path(ellipseIn:CGRect(x:patch.x-330*zoom,y:patch.y-240*zoom,width:660*zoom,height:480*zoom)),with:.color(tint.opacity(0.22)))
                    let label = String(UnicodeScalar(65+column)!) + "\(row+1)"
                    scenery.draw(Text(label).font(.system(size:11,weight:.medium,design:.monospaced)).foregroundStyle(DillTheme.ink.opacity(0.13)),at:screen(CGPoint(x:origin.x+30,y:origin.y+40)),anchor:.topLeading)
                    for (index,offset) in leafOffsets.enumerated() {
                        let point = screen(CGPoint(x:origin.x+offset.x,y:origin.y+offset.y))
                        var leaf = scenery
                        leaf.translateBy(x:point.x,y:point.y)
                        leaf.rotate(by:.degrees(Double((column*37+row*53+index*71)%180)))
                        leaf.scaleBy(x:zoom,y:zoom)
                        var shape = Path(); shape.move(to:CGPoint(x:-21,y:0)); shape.addQuadCurve(to:CGPoint(x:21,y:0),control:CGPoint(x:0,y:-18)); shape.addQuadCurve(to:CGPoint(x:-21,y:0),control:CGPoint(x:0,y:18)); shape.closeSubpath()
                        leaf.fill(shape,with:.color(DillTheme.ink.opacity(0.055)))
                        var stem = Path(); stem.move(to:CGPoint(x:-18,y:0)); stem.addLine(to:CGPoint(x:18,y:0))
                        leaf.stroke(stem,with:.color(DillTheme.ink.opacity(0.06)),lineWidth:1)
                    }
                }
            }
            var grid = Path()
            for x in stride(from:0.0,through:snapshot.width,by:90) {let a = screen(CGPoint(x:x,y:0)); let b = screen(CGPoint(x:x,y:snapshot.height)); grid.move(to:a); grid.addLine(to:b)}
            for y in stride(from:0.0,through:snapshot.height,by:90) {let a = screen(CGPoint(x:0,y:y)); let b = screen(CGPoint(x:snapshot.width,y:y)); grid.move(to:a); grid.addLine(to:b)}
            context.stroke(grid,with:.color(DillTheme.ink.opacity(0.035)),lineWidth:1)
            var sectors = Path()
            for x in stride(from:0.0,through:snapshot.width,by:900) {sectors.move(to:screen(CGPoint(x:x,y:0))); sectors.addLine(to:screen(CGPoint(x:x,y:snapshot.height)))}
            for y in stride(from:0.0,through:snapshot.height,by:900) {sectors.move(to:screen(CGPoint(x:0,y:y))); sectors.addLine(to:screen(CGPoint(x:snapshot.width,y:y)))}
            context.stroke(sectors,with:.color(DillTheme.ink.opacity(0.065)),lineWidth:1)
            context.stroke(Path(roundedRect:world,cornerRadius:30),with:.color(DillTheme.ink.opacity(0.18)),style:StrokeStyle(lineWidth:3,dash:[6,8]))
            let hazards = (snapshot.hazards ?? []).filter {$0.r > 0}
            for pellet in food {
                var spot = CGPoint(x:pellet[1],y:pellet[2])
                let spit = pellet[3] == 4
                if spit, let born = spitAt[pellet[0]], now.timeIntervalSince(born) < 0.45,
                   let source = hazards.min(by:{hypot($0.x-spot.x,$0.y-spot.y) < hypot($1.x-spot.x,$1.y-spot.y)}) {
                    let eased = 1 - pow(1 - max(0,now.timeIntervalSince(born)) / 0.45,3)
                    spot = CGPoint(x:source.x + (spot.x-source.x)*eased,y:source.y + (spot.y-source.y)*eased)
                }
                let position = screen(spot)
                guard onScreen(position,margin:20) else {continue}
                if spit {
                    let r = 6 * zoom
                    context.fill(ArenaCanvas.dot(position,r),with:.color(ArenaCanvas.brine))
                    context.fill(ArenaCanvas.dot(CGPoint(x:position.x-r*0.3,y:position.y-r*0.3),r*0.38),with:.color(Color(hex:0xD4EB85)))
                    continue
                }
                let bonus = pellet[3] >= 9
                let r = (bonus ? 8.0 : 5.0) * zoom
                let color = bonus ? DillTheme.peach : [Color(hex:0xA6BF70),Color(hex:0xD1BC74),Color(hex:0xA4B8A0)][Int(pellet[0]) % 3]
                context.fill(Path(ellipseIn:CGRect(x:position.x-r,y:position.y-r,width:r*2,height:r*2)),with:.color(color))
                if bonus {context.stroke(Path(ellipseIn:CGRect(x:position.x-r-2,y:position.y-r-2,width:r*2+4,height:r*2+4)),with:.color(color.opacity(0.35)),lineWidth:2)}
            }
            let pieces = players.filter(\.alive).flatMap {player in player.pieces.map {(player,$0)}}.sorted {$0.1.mass < $1.1.mass}
            let drains = pieces.compactMap { _,cell -> (cell:ArenaCell,hazard:ArenaHazard)? in
                guard cell.draining, let field = hazards.min(by:{hypot($0.x-cell.x,$0.y-cell.y) - $0.r < hypot($1.x-cell.x,$1.y-cell.y) - $1.r}) else {return nil}
                return (cell,field)
            }
            let fields = (snapshot.hazards ?? []).enumerated().filter { _,hazard in
                hazard.r > 0 && onScreen(screen(CGPoint(x:hazard.x,y:hazard.y)),margin:hazard.r * 1.2 * zoom)
            }
            func worldAt(_ hazard:ArenaHazard) -> GraphicsContext {
                var world = context
                let center = screen(CGPoint(x:hazard.x,y:hazard.y))
                world.translateBy(x:center.x,y:center.y)
                world.scaleBy(x:zoom,y:zoom)
                return world
            }
            for (index,hazard) in fields {ArenaCanvas.drawScatter(worldAt(hazard),hazard:hazard,gadget:hazard.gadget(index:index))}
            for (cell,hazard) in drains {
                let dx = hazard.x - cell.x, dy = hazard.y - cell.y, d = max(1,hypot(dx,dy))
                let start = CGPoint(x:cell.x + dx/d*cell.radius,y:cell.y + dy/d*cell.radius)
                for drop in 0..<8 {
                    let travel = time / 0.5 + Double(drop) / 8, u = travel - floor(travel)
                    let sway = sin(u * .pi) * sin(time * 6 + Double(drop) * 2.4) * 9
                    let point = screen(CGPoint(x:start.x + (hazard.x-start.x)*u - dy/d*sway,y:start.y + (hazard.y-start.y)*u + dx/d*sway))
                    context.fill(ArenaCanvas.dot(point,4 * (1 - 0.3*u) * zoom),with:.color(ArenaCanvas.brine.opacity(min(1,u*6))))
                }
            }
            for (index,hazard) in fields {
                let nearest = pieces.map {(cell:$0.1,d:hypot($0.1.x-hazard.x,$0.1.y-hazard.y))}.filter {$0.d < hazard.r + 320}.min {$0.d < $1.d}
                let look = nearest.map {CGVector(dx:($0.cell.x-hazard.x)/max(1,$0.d),dy:($0.cell.y-hazard.y)/max(1,$0.d))} ?? .zero
                ArenaCanvas.drawGadget(worldAt(hazard),hazard:hazard,gadget:hazard.gadget(index:index),time:still ? 0 : time,
                                       hungry:drains.contains {$0.hazard.id == hazard.id},look:look)
            }
            if snapshot.tick != motion.tick {motion.membranes = motion.membranes.filter {raw[$0.key] != nil}}
            let danger = Dictionary(ArenaCanvas.killRings(players:players,me:mine).map {($0.hunter,$0.alpha)},uniquingKeysWith:max)
            let visible = pieces.compactMap { p,cell -> (player:ArenaPlayer,cell:ArenaCell,body:ArenaBody)? in
                guard onScreen(screen(CGPoint(x:cell.x,y:cell.y)),margin:cell.radius*zoom*2) else {return nil}
                let key = p.id + ":" + cell.id, size = ArenaMembrane.size(screenRadius:cell.radius*zoom)
                let membrane = motion.membranes[key]?.resized(to:size) ?? ArenaMembrane(size)
                motion.membranes[key] = membrane
                return (p,cell,ArenaBody(key:key,x:cell.x,y:cell.y,shape:ArenaShape(p,r:cell.radius),membrane:membrane))
            }
            let bodies = visible.map(\.body)
            motion.membraneClock = min(motion.membraneClock + max(0,dt),4/60)
            while motion.membraneClock >= 1/60 {
                motion.membraneClock -= 1/60
                ArenaBody.step(bodies,bounds:CGSize(width:snapshot.width,height:snapshot.height),jitter:still ? 0 : ArenaBody.jitter)
            }
            for (p,cell,body) in visible {
                var gaze = CGVector.zero
                if let before = old[body.key], let current = raw[body.key] {
                    let dx = (current.x-before.x)/4, dy = (current.y-before.y)/4, length = max(1,hypot(dx,dy))
                    gaze = CGVector(dx:dx/length,dy:dy/length)
                }
                let position = screen(CGPoint(x:cell.x,y:cell.y)), r = cell.radius * zoom
                var piece = context
                piece.translateBy(x:position.x,y:position.y)
                ArenaCanvas.drawPiece(piece,player:p,r:r,own:p.id == me.id,mood:ArenaCanvas.mood(p,cell:cell,pieces:pieces),gaze:gaze,time:time,
                                      danger:danger[body.key] ?? 0,outline:body.outline(scale:zoom))
                let label = p.id == me.id ? "you" : p.name
                context.draw(Text(label).font(.system(size:11,weight:p.id == me.id ? .bold : .medium,design:.rounded)).foregroundStyle(DillTheme.ink),at:CGPoint(x:position.x,y:position.y+r+14))
            }
            motion.tick = snapshot.tick
        }
    }

    static func dot(_ center:CGPoint,_ r:Double) -> Path {Path(ellipseIn:CGRect(x:center.x-r,y:center.y-r,width:r*2,height:r*2))}

    /// Hunters that could eat one of your pieces under the server rule: `mass >= 1.22 * prey` and `distance < R - 0.6 * r`, both unshielded.
    /// Alpha drives the red outline on that hunter piece, from 0.25 at 320 world units out to 0.9 at the eat boundary.
    static func killRings(players:[ArenaPlayer],me:ArenaPlayer) -> [ArenaKillRing] {
        guard me.alive, me.shield <= 0 else {return []}
        var rings:[ArenaKillRing] = []
        for hunter in players where hunter.id != me.id && hunter.alive && hunter.shield <= 0 {
            for piece in hunter.pieces {
                var closest:(gap:Double,reach:Double)?
                for prey in me.pieces where piece.mass >= 1.22 * prey.mass {
                    let reach = piece.radius - ArenaPlayer.eatOverlap * prey.radius
                    let gap = hypot(piece.x-prey.x,piece.y-prey.y) - reach
                    if gap < closest?.gap ?? .infinity {closest = (gap,reach)}
                }
                guard let closest, closest.gap < 320 else {continue}
                let alpha = 0.25 + 0.65 * min(1,max(0,1 - closest.gap / 320))
                rings.append(ArenaKillRing(hunter:hunter.id + ":" + piece.id,center:CGPoint(x:piece.x,y:piece.y),radius:closest.reach,alpha:alpha))
            }
        }
        return rings
    }

    /// Port of `traceOutline`: a closed path of quadratic curves through the midpoints of `points`, each point its control.
    static func outlinePath(_ points:[CGPoint]) -> Path {
        var path = Path()
        guard let last = points.last else {return path}
        func mid(_ a:CGPoint,_ b:CGPoint) -> CGPoint {CGPoint(x:(a.x + b.x) / 2,y:(a.y + b.y) / 2)}
        path.move(to:mid(last,points[0]))
        for (i,point) in points.enumerated() {path.addQuadCurve(to:mid(point,points[(i + 1) % points.count]),control:point)}
        path.closeSubpath()
        return path
    }

    /// Deterministic 0...1 noise matching `grain` in arena-web/arena-core.mjs, so every client scatters the same debris.
    static func grain(_ n:Double) -> Double {let v = sin(n * 127.1 + 311.7) * 43758.5453; return v - floor(v)}
    static func gadgetSeed(_ id:String) -> Int {id.utf16.reduce(0) {$0 + Int($1)}}
    private static func line(_ width:Double) -> StrokeStyle {StrokeStyle(lineWidth:width,lineCap:.round,lineJoin:.round)}
    private static func rounded(_ rect:CGRect,_ radius:Double) -> Path {Path(roundedRect:rect,cornerRadius:radius,style:.circular)}
    private static func polygon(_ points:[CGPoint]) -> Path {var path = Path(); path.addLines(points); path.closeSubpath(); return path}
    private static func segment(_ from:CGPoint,_ to:CGPoint) -> Path {var path = Path(); path.move(to:from); path.addLine(to:to); return path}

    /// Port of `drawScatter`: slices, salt or shreds thin out toward the field edge over a soft white patch.
    /// The context sits at the field center in world units.
    static func drawScatter(_ context:GraphicsContext,hazard:ArenaHazard,gadget:ArenaGadget) {
        let seed = Double(gadgetSeed(hazard.id)), r = hazard.r
        for (scale,alpha) in [(1.0,0.2),(0.6,0.22)] {
            var patch = Path()
            for n in 0...40 {
                let a = Double(n) / 40 * 2 * .pi, reach = r * scale * (1 + 0.08 * sin(3 * a + seed) + 0.05 * sin(5 * a + seed * 2))
                let point = CGPoint(x:cos(a) * reach,y:sin(a) * reach)
                if n == 0 {patch.move(to:point)} else {patch.addLine(to:point)}
            }
            context.fill(patch,with:.color(.white.opacity(alpha)))
        }
        let count = gadget == .slicer ? 30 : gadget == .shaker ? 56 : 40
        for n in 0..<count {
            let i = Double(n), a = i * 2.39996 + seed, d = r * (0.45 + 0.7 * sqrt((i + 0.5) / Double(count))), size = 1 + grain(i + seed)
            var bit = context
            bit.opacity = min(1,max(0,(r * 1.16 - d) / (r * 0.42)))
            bit.translateBy(x:cos(a) * d,y:sin(a) * d)
            bit.rotate(by:.radians(grain(i * 3 + seed) * 2 * .pi))
            switch gadget {
            case .slicer:
                let radius = 4.5 * size
                bit.fill(dot(.zero,radius),with:.color(Color(hex:0x6E9A4A)))
                bit.stroke(dot(.zero,radius),with:.color(DillTheme.ink.opacity(0.4)),style:line(1.2))
                bit.fill(dot(.zero,radius * 0.74),with:.color(Color(hex:0xE1ECB5)))
                for k in 0..<3 {
                    let angle = Double(k) * 2.1
                    bit.fill(dot(CGPoint(x:cos(angle) * radius * 0.35,y:sin(angle) * radius * 0.35),radius * 0.12),with:.color(DillTheme.cream))
                }
            case .shaker:
                let side = 3 + 3 * size, square = CGRect(x:-side/2,y:-side/2,width:side,height:side)
                bit.fill(Path(square.offsetBy(dx:1.2,dy:1.2)),with:.color(Color(hex:0xA9BFC5)))
                bit.fill(Path(square),with:.color(.white))
                bit.stroke(Path(square),with:.color(DillTheme.ink.opacity(0.25)),style:line(0.8))
            case .grater:
                let l = 5 + 4 * size
                var shred = Path(); shred.move(to:CGPoint(x:-l,y:0)); shred.addQuadCurve(to:CGPoint(x:l,y:0),control:CGPoint(x:0,y:-l * 0.5))
                bit.stroke(shred,with:.color(Color(hex:0x7FA653)),style:line(3))
                var shine = Path(); shine.move(to:CGPoint(x:-l * 0.7,y:-0.6)); shine.addQuadCurve(to:CGPoint(x:l * 0.7,y:-0.6),control:CGPoint(x:0,y:-l * 0.5))
                bit.stroke(shine,with:.color(Color(hex:0xD6E6A8)),style:line(1.2))
            }
        }
    }

    /// Port of `drawHazard` minus the scatter: the gadget at 1.25x over its shadow, at the field center in world units.
    /// `look` points toward the nearest pickle; `hungry` means a cell is draining in this field.
    static func drawGadget(_ context:GraphicsContext,hazard:ArenaHazard,gadget:ArenaGadget,time:Double,hungry:Bool,look:CGVector) {
        let seed = gadgetSeed(hazard.id)
        var c = context
        c.scaleBy(x:1.25,y:1.25)
        c.fill(Path(ellipseIn:CGRect(x:4-62,y:50-13,width:124,height:26)),with:.color(DillTheme.ink.opacity(0.08)))
        let face = {(context:GraphicsContext,center:CGPoint) in drawGadgetFace(context,at:center,time:time,hungry:hungry,look:look,seed:seed)}
        switch gadget {
        case .slicer: drawSlicer(c,time:time,hungry:hungry,face:face)
        case .shaker: drawShaker(c,time:time,hungry:hungry,face:face)
        case .grater: drawGrater(c,time:time,hungry:hungry,face:face)
        }
    }

    /// Watches the nearest pickle, blinks, and opens wide while it drains one.
    private static func drawGadgetFace(_ context:GraphicsContext,at center:CGPoint,time:Double,hungry:Bool,look:CGVector,seed:Int) {
        let ink = DillTheme.ink
        let eyeX = min(1,max(-1,look.dx)) * 2.4, eyeY = min(1,max(-1,look.dy)) * 1.8
        let blink = time > 0 && (time + Double(seed % 5)).truncatingRemainder(dividingBy:3.8) < 0.12
        var c = context
        c.translateBy(x:center.x,y:center.y)
        for side in [-1.0,1.0] {c.fill(Path(ellipseIn:CGRect(x:side * 14 - 5.5,y:8 - 3.2,width:11,height:6.4)),with:.color(DillTheme.peach))}
        for side in [-1.0,1.0] {
            if blink {c.stroke(segment(CGPoint(x:side * 9 - 3.5,y:-3),CGPoint(x:side * 9 + 3.5,y:-3)),with:.color(ink),style:line(2.4)); continue}
            let tall = hungry ? 4.6 : 3.8
            c.fill(Path(ellipseIn:CGRect(x:side * 9 + eyeX - 3.2,y:-3 + eyeY - tall,width:6.4,height:tall * 2)),with:.color(ink))
            c.fill(dot(CGPoint(x:side * 9 + eyeX - 1,y:-4.4 + eyeY),1.1),with:.color(.white))
        }
        if hungry {
            let open = 3 + 1.6 * abs(sin(time * 9))
            c.fill(Path(ellipseIn:CGRect(x:-3.6,y:9 - open,width:7.2,height:open * 2)),with:.color(ink))
        } else {
            var smile = Path()
            smile.addArc(center:CGPoint(x:-3,y:7),radius:3,startAngle:.radians(0.15 * .pi),endAngle:.radians(0.95 * .pi),clockwise:false)
            smile.move(to:CGPoint(x:6,y:7.6))
            smile.addArc(center:CGPoint(x:3,y:7),radius:3,startAngle:.radians(0.05 * .pi),endAngle:.radians(0.85 * .pi),clockwise:false)
            c.stroke(smile,with:.color(ink),style:line(2))
        }
    }

    /// Mandoline: the board sways and the pusher slides while draining.
    private static func drawSlicer(_ context:GraphicsContext,time:Double,hungry:Bool,face:(GraphicsContext,CGPoint) -> Void) {
        let ink = DillTheme.ink
        var c = context
        c.rotate(by:.radians(-0.32 + sin(time * 1.4) * 0.03))
        var legs = segment(CGPoint(x:-40,y:24),CGPoint(x:-46,y:44)); legs.addPath(segment(CGPoint(x:40,y:24),CGPoint(x:46,y:44)))
        c.stroke(legs,with:.color(ink),style:line(3))
        let board = rounded(CGRect(x:-58,y:-28,width:116,height:56),14)
        c.fill(board,with:.color(DillTheme.cream)); c.stroke(board,with:.color(ink),style:line(3))
        let blade = polygon([CGPoint(x:6,y:-28),CGPoint(x:22,y:-28),CGPoint(x:30,y:28),CGPoint(x:14,y:28)])
        c.fill(blade,with:.color(steel)); c.stroke(blade,with:.color(ink),style:line(3))
        var teeth = Path(); teeth.move(to:CGPoint(x:8,y:-24))
        for n in 1...10 {teeth.addLine(to:CGPoint(x:8 + Double(n) * 0.8 + (n % 2 == 1 ? 3 : 0),y:-24 + Double(n) * 4.8))}
        c.stroke(teeth,with:.color(ink),style:line(1.6))
        c.stroke(segment(CGPoint(x:20,y:-22),CGPoint(x:25,y:18)),with:.color(.white),style:line(2))
        let slide = hungry ? 18 * sin(time * 10) : 0
        for part in [rounded(CGRect(x:34 + slide,y:-20,width:18,height:40),7),dot(CGPoint(x:43 + slide,y:-26),6)] {
            c.fill(part,with:.color(DillTheme.lime)); c.stroke(part,with:.color(ink),style:line(3))
        }
        face(c,CGPoint(x:-24,y:0))
    }

    /// Salt shaker: tilts at rest, shakes while draining, and sprinkles grains from its cap.
    private static func drawShaker(_ context:GraphicsContext,time:Double,hungry:Bool,face:(GraphicsContext,CGPoint) -> Void) {
        let ink = DillTheme.ink
        var c = context
        c.rotate(by:.radians(hungry ? sin(time * 14) * 0.22 : 0.18 + sin(time * 1.5) * 0.05))
        let body = rounded(CGRect(x:-28,y:-30,width:56,height:78),20)
        c.fill(body,with:.color(Color(hex:0xEEF4F5)))
        var salt = c
        salt.clip(to:body)
        salt.fill(Path(CGRect(x:-28,y:4,width:56,height:44)),with:.color(.white))
        for n in 0..<9 {salt.fill(Path(CGRect(x:-20 + grain(Double(n)) * 40,y:8 + grain(Double(n + 9)) * 34,width:2.4,height:2.4)),with:.color(Color(hex:0xD9E6E8)))}
        c.stroke(body,with:.color(ink),style:line(3))
        c.stroke(segment(CGPoint(x:-19,y:-18),CGPoint(x:-19,y:2)),with:.color(.white),style:line(3))
        let cap = rounded(CGRect(x:-25,y:-52,width:50,height:24),10)
        c.fill(cap,with:.color(steel)); c.stroke(cap,with:.color(ink),style:line(3))
        for hole in [-12.0,-4,4,12] {c.fill(dot(CGPoint(x:hole,y:-44),1.8),with:.color(ink))}
        let count = hungry ? 7 : 3
        for n in 0..<count {
            let t = (time * (hungry ? 1.6 : 0.7) + Double(n) / Double(count)).truncatingRemainder(dividingBy:1)
            let x = -12 + Double((n * 8) % 26) + sin(Double(n) * 3) * 3
            let speck = Path(CGRect(x:x - 1.6,y:-58 - t * 26 - t * t * 10,width:3.2,height:3.2))
            var fall = c
            fall.opacity = 1 - t
            fall.fill(speck,with:.color(.white)); fall.stroke(speck,with:.color(ink.opacity(0.33)),style:line(0.8))
        }
        face(c,CGPoint(x:0,y:-12))
    }

    /// Box grater: bobs at rest and jiggles side to side while draining.
    private static func drawGrater(_ context:GraphicsContext,time:Double,hungry:Bool,face:(GraphicsContext,CGPoint) -> Void) {
        let ink = DillTheme.ink
        var c = context
        c.translateBy(x:hungry ? sin(time * 18) * 2.5 : 0,y:sin(time * 1.6) * 1.2)
        c.rotate(by:.radians(0.08))
        var handle = Path(); handle.move(to:CGPoint(x:-15,y:-52)); handle.addCurve(to:CGPoint(x:15,y:-52),control1:CGPoint(x:-15,y:-76),control2:CGPoint(x:15,y:-76))
        c.stroke(handle,with:.color(ink),style:line(5)); c.stroke(handle,with:.color(DillTheme.lime),style:line(2))
        let body = polygon([CGPoint(x:-28,y:-54),CGPoint(x:28,y:-54),CGPoint(x:42,y:54),CGPoint(x:-42,y:54)])
        c.fill(body,with:.color(steel)); c.stroke(body,with:.color(ink),style:line(3))
        c.stroke(segment(CGPoint(x:-22,y:-46),CGPoint(x:-33,y:44)),with:.color(.white),style:line(3))
        for row in 0..<4 {
            for column in 0..<4 {
                let w = 52 + Double(row) * 7, x = -w / 2 + (Double(column) + 0.5) * w / 4, y = 12 + Double(row) * 11
                var hole = Path()
                hole.addArc(center:CGPoint(x:x,y:y - 2),radius:3.4,startAngle:.radians(0.15 * .pi),endAngle:.radians(0.85 * .pi),clockwise:false)
                c.stroke(hole,with:.color(ink.opacity(0.65)),style:line(1.8))
            }
        }
        face(c,CGPoint(x:0,y:-24))
    }

    enum Mood { case calm, dash, threatened, sad }

    /// Matches `pieceMood` in arena-web/arena-core.mjs; a draining cell looks threatened.
    static func mood(_ player:ArenaPlayer,cell:ArenaCell,pieces:[(ArenaPlayer,ArenaCell)]) -> Mood {
        if (player.hurt ?? 0) > 0 && player.alive {return .sad}
        let threatened = cell.draining || player.shield <= 0 && pieces.contains {other,piece in
            other.id != player.id && other.shield <= 0 && piece.mass >= cell.mass * 1.22 && hypot(piece.x-cell.x,piece.y-cell.y) <= piece.radius + cell.radius * (1 - ArenaPlayer.eatOverlap) + 45
        }
        return threatened ? .threatened : player.dash > 0 ? .dash : .calm
    }

    static func blinking(_ id:String,time:Double) -> Bool {
        let offset = Double(id.unicodeScalars.reduce(0) {$0 + Int($1.value)} % 40) / 10
        return time > 0 && (time + offset).truncatingRemainder(dividingBy:4.2) < 0.13
    }

    /// One piece at the context origin, matching `drawPickle` in arena-web/arena-core.mjs.
    /// `outline` holds membrane points in the piece's rotated frame; without it the undeformed shape is drawn.
    static func drawPiece(_ context:GraphicsContext,player p:ArenaPlayer,r:Double,own:Bool,mood:Mood,gaze:CGVector,time:Double,danger:Double = 0,outline:[CGPoint]? = nil) {
        let ink = DillTheme.ink, variety = p.look, cucumber = p.isCucumber
        let shape = ArenaShape(p,r:r), halfWidth = shape.hw, halfHeight = shape.hh
        var c = context
        if shape.lean != 0 {c.rotate(by:.radians(shape.lean))}
        let rect = CGRect(x:-halfWidth,y:-halfHeight,width:halfWidth*2,height:halfHeight*2)
        let body = outline.map(outlinePath) ?? (shape.ellipse ? Path(ellipseIn:rect) : Path(roundedRect:rect,cornerRadius:halfWidth))
        if p.dash > 0 {c.fill(Path(ellipseIn:rect.insetBy(dx:-8,dy:-8)),with:.color(DillTheme.lime.opacity(0.4)))}
        if p.shield > 0 {c.stroke(Path(ellipseIn:rect.insetBy(dx:-7,dy:-7)),with:.color(.white.opacity(0.9)),style:StrokeStyle(lineWidth:2,dash:[4,4]))}
        c.fill(body.offsetBy(dx:1,dy:5),with:.color(ink.opacity(0.1)))
        c.fill(body,with:.color(cucumber ? Color(hex:0x6DA86B) : Color(hex:variety.color)))
        c.stroke(body,with:.color(ink),lineWidth:own ? 2.5 : 1.5)
        if danger > 0 {c.stroke(body,with:.color(ArenaCanvas.danger.opacity(min(1,danger))),lineWidth:3.5)}
        var inside = c
        inside.clip(to:body)
        if cucumber {
            for offset in [-0.35,0.0,0.35] {
                var stripe = Path(); stripe.move(to:CGPoint(x:r*offset,y:-r*0.58)); stripe.addQuadCurve(to:CGPoint(x:r*offset,y:r*0.62),control:CGPoint(x:r*(offset-0.08),y:0))
                inside.stroke(stripe,with:.color(Color(hex:0xB9D889).opacity(0.65)),style:StrokeStyle(lineWidth:max(1,r*0.075),lineCap:.round))
            }
            if p.outfit == .original {
                var stem = Path(); stem.move(to:CGPoint(x:0,y:-r*0.98)); stem.addQuadCurve(to:CGPoint(x:r*0.04,y:-r*1.16),control:CGPoint(x:-r*0.16,y:-r*1.18))
                c.stroke(stem,with:.color(ink),style:StrokeStyle(lineWidth:max(1,r*0.045),lineCap:.round))
            }
        } else {
            for (x,y) in [(0.42,-0.55),(0.5,0.38),(-0.45,0.5),(0.05,0.74)] {
                inside.fill(Path(roundedRect:CGRect(x:x*halfWidth-r*0.065,y:y*halfHeight-r*0.05,width:r*0.13,height:r*0.1),cornerRadius:r*0.04),with:.color(Color(hex:variety.dark)))
            }
        }
        let shine = CGRect(x:-halfWidth*0.68,y:-halfHeight*0.6,width:halfWidth*0.26,height:halfHeight*0.5)
        inside.fill(Path(roundedRect:shine,cornerRadius:5),with:.color(cucumber ? .white.opacity(0.3) : Color(hex:variety.light).opacity(0.6)))
        let eye = max(2,r*0.075)
        let lookX = max(-1,min(1,gaze.dx))*eye*0.6, lookY = max(-1,min(1,gaze.dy))*eye*0.5
        let line = StrokeStyle(lineWidth:max(1,r*0.04),lineCap:.round,lineJoin:.round)
        for side in [-1.0,1.0] {
            let ex = side*r*0.27, ey = -r*0.15 + eye*0.35
            c.fill(Path(ellipseIn:CGRect(x:side*r*0.47-eye*1.7,y:r*0.1,width:eye*3.4,height:eye*1.5)),with:.color(DillTheme.peach))
            var stroke = Path()
            switch mood {
            case .threatened:
                stroke.move(to:CGPoint(x:ex+side*r*0.1,y:ey-r*0.1)); stroke.addLine(to:CGPoint(x:ex-side*r*0.07,y:ey)); stroke.addLine(to:CGPoint(x:ex+side*r*0.1,y:ey+r*0.1))
            case .sad:
                c.fill(Path(ellipseIn:CGRect(x:ex-eye,y:ey-eye*0.7,width:eye*2,height:eye*1.9)),with:.color(ink))
                stroke.move(to:CGPoint(x:ex-side*eye*0.9,y:ey-eye*1.5))
                stroke.addLine(to:CGPoint(x:ex+side*eye,y:ey-eye*0.8))
            case .calm where blinking(p.id,time:time):
                stroke.move(to:CGPoint(x:ex-eye,y:ey)); stroke.addLine(to:CGPoint(x:ex+eye,y:ey))
            case .calm,.dash:
                let tall = mood == .dash ? 0.55 : 1.35
                c.fill(Path(ellipseIn:CGRect(x:ex+lookX-eye*1.1,y:ey+lookY-eye*tall,width:eye*2.2,height:eye*tall*2)),with:.color(ink))
            }
            c.stroke(stroke,with:.color(ink),style:line)
        }
        switch mood {
        case .dash:
            var mouth = Path(); mouth.move(to:CGPoint(x:-r*0.12,y:r*0.26)); mouth.addLine(to:CGPoint(x:r*0.12,y:r*0.26))
            c.stroke(mouth,with:.color(ink),style:line)
        case .threatened:
            c.fill(Path(ellipseIn:CGRect(x:-r*0.055,y:r*0.28-r*0.07,width:r*0.11,height:r*0.14)),with:.color(ink))
        case .sad:
            var mouth = Path(); mouth.move(to:CGPoint(x:-r*0.13,y:r*0.32))
            mouth.addQuadCurve(to:CGPoint(x:r*0.13,y:r*0.32),control:CGPoint(x:0,y:r*0.14))
            c.stroke(mouth,with:.color(ink),style:line)
        case .calm:
            ArenaSmile(variety:variety.id).draw(c,r:r,lineWidth:max(1,r*0.035))
        }
        if p.outfit != .original {
            let symbol = c.resolve(Image(systemName:p.outfit.symbol).resizable())
            c.draw(symbol,in:CGRect(x:-r*0.28,y:-halfHeight-r*0.28,width:r*0.56,height:r*0.45))
        }
    }
}
