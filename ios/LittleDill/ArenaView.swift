import SwiftUI

struct ArenaView: View {
    let launch: ArenaLaunch
    @EnvironmentObject private var store: DillStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var client = ArenaClient()
    @State private var leave = false
    @State private var showScores = false
    @State private var stick = CGSize.zero
    @State private var away = false
    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 430
            ZStack {
                Color(hex:0xE7ECD8).ignoresSafeArea()
                if let snapshot = client.snapshot, let me = client.me {
                    TimelineView(.animation(minimumInterval:1/60,paused:client.status != .playing)) { timeline in
                        ArenaCanvas(snapshot:snapshot,previous:client.previous,food:client.food,me:me,received:client.receivedAt,now:timeline.date)
                    }.accessibilityLabel("Live Brine Royale arena. You are \(me.name), mass \(Int(me.mass)), rank \(client.rank), \(me.pieces.count) \(me.isCucumber ? "cucumbers" : "pickle").")
                }
                VStack(spacing:0) {
                    topBar
                    if client.status == .playing, let me = client.me {
                        scoreBar(me,compact:compact)
                        Spacer(minLength:0)
                        if me.alive {controls(me,compact:compact)}
                    } else {Spacer()}
                }
                if client.status == .connecting {connectionCard}
                else if client.status == .disconnected || away {disconnectedCard}
                else if let me = client.me, !me.alive {respawnCard(me)}
            }
        }.foregroundStyle(DillTheme.ink)
            .onAppear {client.connect(pet:store.pet,room:launch.room)}
            .onDisappear {saveBest(); client.stop(); DillAudio.shared.stop()}
            .onChange(of:client.me?.alive) { old,alive in
                if old == true && alive == false {saveBest(); store.feedback(.heavy); store.sound(.pop)}
                if old == false && alive == true {store.sound(.respawn)}
            }
            .onChange(of:client.me?.kills) {old,kills in if let old, let kills, kills > old {store.sound(.win)} }
            .onChange(of:client.me?.dash) {old,dash in if let old, let dash, dash > old + 0.2 {store.sound(.dash)} }
            .onChange(of:client.me?.splitCooldown) {old,cooldown in
                if let old, let cooldown, cooldown > old + 0.3 {store.sound(.dash)}
            }
            .onChange(of:scenePhase) { _,phase in
                if phase == .background {saveBest(); client.stop(); away = true; stick = .zero}
            }
            .confirmationDialog("Leave the garden?",isPresented:$leave,titleVisibility:.visible) {
                Button("Leave arena",role:.destructive) {saveBest(); client.stop(); dismiss()}
                Button("Keep growing",role:.cancel) {}
            } message: {Text("Your personal best stays saved. Rejoining starts a fresh pickle.")}
            .interactiveDismissDisabled()
    }
    private var topBar: some View {
        HStack(spacing:12) {
            Button {leave = true} label: {Image(systemName:"xmark").font(.system(size:15,weight:.semibold)).frame(width:44,height:44).background(DillTheme.cream.opacity(0.95),in:Circle())}.accessibilityLabel("Exit online game").accessibilityIdentifier("arenaLeave")
            VStack(alignment:.leading,spacing:4) {
                Text("brine royale.").font(DillTheme.display(24)).tracking(-1)
                HStack(spacing:5) {
                    Circle().fill(client.status == .playing ? Color(hex:0x5C873E) : DillTheme.muted).frame(width:5,height:5)
                    Text(client.status == .playing ? "\(client.snapshot?.population ?? 0) in the garden" : "Finding your garden…").font(.system(size:10,weight:.medium,design:.rounded)).accessibilityIdentifier("arenaPopulation")
                }
            }
            Spacer(minLength:0)
            if let code = launch.room {
                ShareLink(item:"Come find me in Brine Royale! Room \(code) · \(ArenaLaunch.shareURL(room:code).absoluteString)") {Image(systemName:"person.badge.plus").font(.system(size:18)).frame(width:44,height:44).background(DillTheme.cream.opacity(0.95),in:Circle())}.accessibilityLabel("Invite a friend to room \(code)")
            } else {Image(systemName:"globe").font(.system(size:20)).frame(width:44,height:44).background(DillTheme.cream.opacity(0.95),in:Circle())}
        }.padding(.horizontal,18).padding(.top,8)
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
            Image(systemName:away ? "moon.zzz.fill" : "wifi.exclamationmark").font(.system(size:35))
            Text(away ? "A little breather." : "Lost in the brine.").font(DillTheme.display(29)).multilineTextAlignment(.center)
            Text(away ? "You left the garden while the app was in the background. Ready for a fresh spawn?" : client.errorMessage).font(.subheadline).foregroundStyle(DillTheme.muted).multilineTextAlignment(.center)
            Button {away = false; client.connect(pet:store.pet,room:launch.room)} label: {Text("Jump back in")}.buttonStyle(DillButton()).accessibilityIdentifier("arenaReconnect")
            Button("Back to my pickle") {dismiss()}.font(.subheadline.bold())
        }.padding(28).frame(maxWidth:350).background(DillTheme.cream,in:RoundedRectangle(cornerRadius:30)).padding(24)
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
    private func controls(_ me:ArenaPlayer,compact:Bool) -> some View {
        let diameter:CGFloat = compact ? 88 : 104
        let reach:CGFloat = compact ? 28 : 34
        return VStack(spacing:compact ? 5 : 10) {
            HStack(alignment:.bottom,spacing:12) {
                ZStack {
                    Circle().fill(DillTheme.cream.opacity(0.7)).overlay(Circle().stroke(DillTheme.ink.opacity(0.15),lineWidth:1)).frame(width:diameter,height:diameter)
                    Image(systemName:"plus").font(.system(size:35,weight:.ultraLight)).foregroundStyle(DillTheme.ink.opacity(0.2))
                    Circle().fill(DillTheme.ink.opacity(0.9)).frame(width:44,height:44).overlay(Image(systemName:"leaf.fill").foregroundStyle(DillTheme.lime)).offset(stick)
                }.contentShape(Circle()).gesture(DragGesture(minimumDistance:0).onChanged { value in
                    let dx = value.location.x - diameter/2, dy = value.location.y - diameter/2
                    let length = max(1,hypot(dx,dy)), distance = min(reach,length)
                    stick = CGSize(width:dx / length * distance,height:dy / length * distance)
                    client.steer(CGVector(dx:stick.width / reach,dy:stick.height / reach))
                }.onEnded { _ in stick = .zero; client.steer(.zero) })
                    .accessibilityElement(children:.ignore).accessibilityLabel("Steer your pickle")
                    .accessibilityAction(named:Text("Move up")) {client.steer(CGVector(dx:0,dy:-1))}
                    .accessibilityAction(named:Text("Move down")) {client.steer(CGVector(dx:0,dy:1))}
                    .accessibilityAction(named:Text("Move left")) {client.steer(CGVector(dx:-1,dy:0))}
                    .accessibilityAction(named:Text("Move right")) {client.steer(CGVector(dx:1,dy:0))}
                    .accessibilityAction(named:Text("Stop moving")) {client.steer(.zero)}
                    .accessibilityIdentifier("arenaJoystick")
                Spacer(minLength:0)
                HStack(alignment:.top,spacing:10) {
                    VStack(spacing:5) {
                        Button {client.split(); store.feedback(.rigid)} label: {
                            VStack(spacing:4) {
                                Image(systemName:"arrow.triangle.branch").font(.system(size:23,weight:.semibold))
                                Text((me.splitCooldown ?? 0) > 0 ? "\(Int(ceil(me.splitCooldown ?? 0)))s" : "SPLIT").font(.system(size:10,weight:.black,design:.rounded))
                            }.frame(width:68,height:68).foregroundStyle(DillTheme.ink).background(DillTheme.lime,in:Circle())
                                .overlay(Circle().stroke(DillTheme.ink.opacity(0.15),lineWidth:2))
                        }.disabled(!me.canSplit).opacity(me.canSplit ? 1 : 0.5).accessibilityLabel("Split your pickle").accessibilityValue(me.splitHint).accessibilityIdentifier("arenaSplit")
                        Text(me.splitHint).font(.system(size:8,weight:.medium)).lineLimit(2).multilineTextAlignment(.center).frame(width:76,height:20)
                    }
                    VStack(spacing:5) {
                        Button {client.dash(); store.feedback(.rigid)} label: {
                            VStack(spacing:4) {
                                Image(systemName:"bolt.fill").font(.system(size:24))
                                Text(me.cooldown > 0 ? "\(Int(ceil(me.cooldown)))s" : "DASH").font(.system(size:10,weight:.black,design:.rounded))
                            }.frame(width:68,height:68).foregroundStyle(DillTheme.lime).background(DillTheme.ink,in:Circle())
                                .overlay(Circle().stroke(DillTheme.cream.opacity(0.5),lineWidth:3))
                        }.disabled(me.cooldown > 0 || me.mass < 35).opacity(me.mass < 35 || me.cooldown > 0 ? 0.55 : 1).accessibilityIdentifier("arenaDash")
                        Text(me.mass < 35 ? "Grow to 35" : "Costs 5 mass").font(.system(size:8,weight:.medium)).frame(width:70,height:20)
                    }
                }.foregroundStyle(DillTheme.muted)
            }
            Text(me.regroupHint).font(.system(size:compact ? 10 : 11,weight:.medium,design:.rounded)).lineLimit(1).minimumScaleFactor(0.7).padding(.horizontal,14).padding(.vertical,compact ? 5 : 7).background(DillTheme.cream.opacity(0.85),in:Capsule()).accessibilityIdentifier("arenaRegroup")
        }.padding(.horizontal,20).padding(.bottom,compact ? 5 : 12)
    }
    private func saveBest() {if client.best > 0 {store.recordArena(best:client.best)}}
}

struct ArenaMinimap: View {
    let snapshot: ArenaSnapshot
    let playerID: String
    var body: some View {
        Canvas { context,size in
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

struct ArenaCanvas: View {
    let snapshot: ArenaSnapshot
    let previous: ArenaSnapshot?
    let food: [[Double]]
    let me: ArenaPlayer
    let received: Date
    let now: Date
    var body: some View {
        Canvas { context,size in
            let blend = min(1,max(0,now.timeIntervalSince(received) / 0.1))
            let old = Dictionary(uniqueKeysWithValues:(previous?.players ?? []).flatMap { player in player.pieces.map {(player.id + ":" + $0.id,$0)} })
            func location(_ cell:ArenaCell,player:ArenaPlayer) -> CGPoint {
                guard let before = old[player.id + ":" + cell.id], hypot(cell.x-before.x,cell.y-before.y) < 400 else {return CGPoint(x:cell.x,y:cell.y)}
                return CGPoint(x:before.x + (cell.x-before.x)*blend,y:before.y + (cell.y-before.y)*blend)
            }
            let own = me.pieces.map {cell in
                let position = location(cell,player:me)
                return ArenaCell(id:cell.id,x:position.x,y:position.y,mass:cell.mass)
            }
            let camera = ArenaPlayer.camera(cells:own,mass:me.mass,width:size.width,height:size.height)
            let zoom = camera.zoom
            let cameraX = camera.center.x
            let cameraY = camera.center.y
            func screen(_ p:CGPoint) -> CGPoint {CGPoint(x:(p.x-cameraX)*zoom + size.width/2,y:(p.y-cameraY)*zoom + size.height/2)}
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
            for pellet in food {
                let position = screen(CGPoint(x:pellet[1],y:pellet[2]))
                guard position.x > -20 && position.y > -20 && position.x < size.width+20 && position.y < size.height+20 else {continue}
                let bonus = pellet[3] >= 9
                let r = (bonus ? 8.0 : 5.0) * zoom
                let color = bonus ? DillTheme.peach : [Color(hex:0xA6BF70),Color(hex:0xD1BC74),Color(hex:0xA4B8A0)][Int(pellet[0]) % 3]
                context.fill(Path(ellipseIn:CGRect(x:position.x-r,y:position.y-r,width:r*2,height:r*2)),with:.color(color))
                if bonus {context.stroke(Path(ellipseIn:CGRect(x:position.x-r-2,y:position.y-r-2,width:r*2+4,height:r*2+4)),with:.color(color.opacity(0.35)),lineWidth:2)}
            }
            let pieces = snapshot.players.filter(\.alive).flatMap {player in player.pieces.map {(player,$0)}}.sorted {$0.1.mass < $1.1.mass}
            for (p,cell) in pieces {
                let position = screen(location(cell,player:p)), r = cell.radius * zoom
                guard position.x > -r*2 && position.y > -r*2 && position.x < size.width+r*2 && position.y < size.height+r*2 else {continue}
                let cucumber = p.isCucumber
                let halfWidth = r * (cucumber ? 0.70 : 0.85)
                let rect = CGRect(x:position.x-halfWidth,y:position.y-r,width:halfWidth*2,height:r*2)
                if p.dash > 0 {context.fill(Path(ellipseIn:rect.insetBy(dx:-8,dy:-8)),with:.color(DillTheme.lime.opacity(0.4)))}
                if p.shield > 0 {context.stroke(Path(ellipseIn:rect.insetBy(dx:-7,dy:-7)),with:.color(.white.opacity(0.9)),style:StrokeStyle(lineWidth:2,dash:[4,4]))}
                context.fill(Path(ellipseIn:rect.offsetBy(dx:1,dy:5)),with:.color(DillTheme.ink.opacity(0.1)))
                context.fill(Path(roundedRect:rect,cornerRadius:halfWidth),with:.color(cucumber ? Color(hex:0x6DA86B) : p.brine.color))
                context.stroke(Path(roundedRect:rect,cornerRadius:halfWidth),with:.color(DillTheme.ink),lineWidth:p.id == me.id ? 2.5 : 1.5)
                if cucumber {
                    for offset in [-0.35,0.0,0.35] {
                        let x = position.x+r*offset
                        var stripe = Path(); stripe.move(to:CGPoint(x:x,y:position.y-r*0.58)); stripe.addQuadCurve(to:CGPoint(x:x,y:position.y+r*0.62),control:CGPoint(x:x-r*0.08,y:position.y))
                        context.stroke(stripe,with:.color(Color(hex:0xB9D889).opacity(0.65)),style:StrokeStyle(lineWidth:max(1,r*0.075),lineCap:.round))
                    }
                    if p.outfit == .original {
                        var stem = Path(); stem.move(to:CGPoint(x:position.x,y:position.y-r*0.98)); stem.addQuadCurve(to:CGPoint(x:position.x+r*0.04,y:position.y-r*1.16),control:CGPoint(x:position.x-r*0.16,y:position.y-r*1.18))
                        context.stroke(stem,with:.color(DillTheme.ink),style:StrokeStyle(lineWidth:max(1,r*0.045),lineCap:.round))
                    }
                }
                let shine = CGRect(x:position.x-r*(cucumber ? 0.46 : 0.55),y:position.y-r*0.6,width:r*(cucumber ? 0.18 : 0.22),height:r*0.5)
                context.fill(Path(roundedRect:shine,cornerRadius:5),with:.color(.white.opacity(0.3)))
                let eye = max(2,r*0.075)
                for side in [-1.0,1.0] {
                    context.fill(Path(ellipseIn:CGRect(x:position.x+side*r*0.27-eye,y:position.y-r*0.15-eye,width:eye*2,height:eye*2.7)),with:.color(DillTheme.ink))
                    context.fill(Path(ellipseIn:CGRect(x:position.x+side*r*0.47-eye*1.7,y:position.y+r*0.1,width:eye*3.4,height:eye*1.5)),with:.color(DillTheme.peach))
                }
                var smile = Path(); smile.move(to:CGPoint(x:position.x-r*0.13,y:position.y+r*0.19)); smile.addQuadCurve(to:CGPoint(x:position.x+r*0.13,y:position.y+r*0.19),control:CGPoint(x:position.x,y:position.y+r*0.42))
                context.stroke(smile,with:.color(DillTheme.ink),style:StrokeStyle(lineWidth:max(1,r*0.035),lineCap:.round))
                if p.outfit != .original {
                    let symbol = context.resolve(Image(systemName:p.outfit.symbol).resizable())
                    context.draw(symbol,in:CGRect(x:position.x-r*0.28,y:position.y-r*1.28,width:r*0.56,height:r*0.45))
                }
                let label = p.id == me.id ? "you" : p.name
                context.draw(Text(label).font(.system(size:11,weight:p.id == me.id ? .bold : .medium,design:.rounded)).foregroundStyle(DillTheme.ink),at:CGPoint(x:position.x,y:position.y+r+14))
            }
        }
    }
}
