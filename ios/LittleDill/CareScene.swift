import SwiftUI

struct CarePerformance {
    let action: Care
    let started = Date()
    var duration: Double {switch action {case .feed:return 3.8; case .pet:return 4; case .wash:return 5; case .nap:return 6}}
    var caption: String {switch action {case .feed:return "NOM NOM NOM"; case .pet:return "ABSOLUTELY ADORED"; case .wash:return "SQUEAKY CLEAN CLUB"; case .nap:return "DO NOT DISTURB"}}
}

/// Feed timing shared by the pickle's pose and the carrot, so each chomp lands on the carrot.
struct FeedBeat {
    static let arrive = 0.5, bite = 0.55, bites = 4, chomp = 0.4
    static let gulp = arrive + bite * Double(bites)
    static let rest: CGFloat = 14, chunk: CGFloat = 15
    let t: Double
    private var beat: Double { (t - FeedBeat.arrive) / FeedBeat.bite }
    var biting: Bool { t >= FeedBeat.arrive && t < FeedBeat.gulp }
    var phase: Double { beat - floor(beat) }
    var chewing: Bool { biting && phase >= FeedBeat.chomp }
    var eaten: Int { t < FeedBeat.arrive ? 0 : min(FeedBeat.bites, Int(floor(beat - FeedBeat.chomp)) + 1) }
    /// 0 while the carrot waits at the lips, 1 when it is pushed into the mouth.
    var push: Double { biting && !chewing ? Ease.inOut(phase / FeedBeat.chomp) : 0 }
    var squash: Double { chewing ? max(0, 1 - (phase - FeedBeat.chomp) / 0.3) : 0 }
    var mouthOpen: Double {
        if t < FeedBeat.arrive { return 0.8 * Ease.out(t / FeedBeat.arrive) }
        if !biting { return 0 }
        if chewing { return 0.15 + 0.3 * abs(sin((phase - FeedBeat.chomp) / (1 - FeedBeat.chomp) * .pi * 2)) }
        let from = eaten == 0 ? 0.8 : 0.15
        return from + (1 - from) * Ease.inOut(phase / FeedBeat.chomp)
    }
    func chompTime(_ k: Int) -> Double { FeedBeat.arrive + (Double(k) + FeedBeat.chomp) * FeedBeat.bite }
}

/// One frame of the Nest. Scenery, pickle, mess and effects all read the TimelineView date.
struct CareScene: View {
    static let unit: CGFloat = 1.6
    static let groundOffset: CGFloat = 84
    let pet: PetState
    let bites: Int?
    let stage: PetStage
    let performance: CarePerformance?
    let now: Date
    let reduceMotion: Bool
    private var clock: Double { now.timeIntervalSinceReferenceDate }
    private var elapsed: Double { max(0, now.timeIntervalSince(performance?.started ?? now)) }
    private var performanceTime: Double { reduceMotion ? 1.3 : elapsed }

    var body: some View {
        let mood = stage.mood(pet.life, snacking: bites != nil, now: now)
        let vibe = performance == nil ? stage.vibe(for: mood, now: now) : nil
        let look = currentLook(mood: mood, vibe: vibe)
        let pose = resolvedPose(mood: mood, vibe: vibe)
        let mouth = CareScene.mouth(look: look, pose: pose)
        let scenery: Care? = performance?.action ?? (mood == .sleeping ? .nap : nil)
        let sceneTime = performance == nil ? clock.truncatingRemainder(dividingBy: 3600) : performanceTime
        let effect = stage.effect, time = clock, current = now
        let dead = pet.life.dead, eaten = pet.life.eaten == true, messy = pet.life.hygiene < 40
        let headTop = -(PickleFrame(look: look).h + 6) * CareScene.unit - 22
        ZStack {
            CareScenery(action: scenery, time: sceneTime, foreground: false, reduceMotion: reduceMotion)
            Canvas { context, size in
                var ground = context
                ground.translateBy(x: size.width / 2, y: size.height / 2 + CareScene.groundOffset)
                if messy && !dead { CareScene.drawMess(ground, x: -size.width / 2 + 40, time: time, still: reduceMotion) }
                if dead {
                    CareScene.drawTomb(ground, eaten: eaten)
                    return
                }
                var body = ground
                body.scaleBy(x: CareScene.unit, y: CareScene.unit)
                PickleArtist.draw(body, look: look, pose: pose, time: time)
                if let effect { CareScene.drawEffect(ground, effect: effect, now: current, top: headTop, still: reduceMotion) }
            }
            CareScenery(action: scenery, time: sceneTime, foreground: true, reduceMotion: reduceMotion, mouth: mouth)
        }.frame(height: 260).frame(maxWidth: .infinity).clipped()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label(mood))
            .accessibilityIdentifier("careScene.\(identifier(mood))")
    }

    private func identifier(_ mood: PetMood) -> String {
        if let performance { return performance.action.rawValue }
        switch mood {
        case .dead: return "dead"
        case .sleeping: return "sleeping"
        case .scared: return "scared"
        default: return "idle"
        }
    }

    private func label(_ mood: PetMood) -> String {
        if let performance { return performance.caption }
        let name = pet.name
        switch mood {
        case .dead: return pet.life.eaten == true ? "Your pickle has been eaten. Crumbs remain." : "Your pickle has passed away"
        case .sleeping: return "\(name) is asleep"
        case .scared: return "\(name) is scared you will eat them"
        case .sick: return "\(name) feels sick"
        case .hungry: return "\(name) needs a little care"
        case .happy: return "\(name) is happy"
        case .idle: return "\(name) is just being a pickle"
        }
    }

    private func currentLook(mood: PetMood, vibe: PetVibe?) -> PickleLook {
        let life = pet.life, ms = PetLife.ms(now)
        var look = PickleLook(variety: PickleVariety.of(life.variety))
        look.stage = PetLife.stage(life, now: ms)
        look.teen = PetLife.teen(life, now: ms)
        look.elder = PetLife.elder(life, now: ms)
        look.outfit = pet.outfit
        look.vibe = vibe
        look.bites = bites ?? 0
        look.sick = mood == .sick
        look.accessories = mood != .sleeping && performance?.action != .wash
        return look
    }

    @MainActor private func resolvedPose(mood: PetMood, vibe: PetVibe?) -> PicklePose {
        let target: PicklePose
        if let performance {
            target = CareScene.performancePose(performance.action, t: performanceTime, clock: clock, reduceMotion: reduceMotion)
        } else {
            target = PetMotion.pose(mood: mood, vibe: vibe, act: stage.act, actElapsed: now.timeIntervalSince(stage.actStarted), time: clock, reduceMotion: reduceMotion)
        }
        let key = mood.rawValue + "|" + (vibe?.rawValue ?? "") + "|" + (performance?.action.rawValue ?? "")
        return stage.memory.resolve(target, key: key, time: clock, blend: reduceMotion ? 0 : 0.35)
    }

    /// The care performances, now expressed as poses so they blend with the idle loop.
    static func performancePose(_ action: Care, t: Double, clock: Double, reduceMotion: Bool) -> PicklePose {
        var pose = PicklePose()
        pose.blink = PetMotion.blink.at(PetMotion.loop(clock, 4.4))
        let move = reduceMotion ? 0.0 : 1.0
        switch action {
        case .feed:
            let beat = FeedBeat(t: t), squash = beat.squash * move
            pose.body = Motion(sx: 1 + squash * 0.06, sy: 1 - squash * 0.05)
            pose.eyes = t < FeedBeat.arrive ? .wide : beat.chewing ? .happy : .open
            pose.mouth = .chew; pose.mouthOpen = beat.mouthOpen; pose.cheek = 1.3 + squash * 0.4
            pose.armLeft = 40; pose.armRight = -40
            if t >= FeedBeat.gulp {
                let hop = sin(min(1, (t - FeedBeat.gulp) / 0.4) * .pi) * move
                pose.body = Motion(y: -hop * 7, sx: 1 - hop * 0.04, sy: 1 + hop * 0.07)
                pose.eyes = .happy; pose.mouth = .grin; pose.cheek = 1.4
                pose.armLeft = 70; pose.armRight = -70
            }
        case .pet:
            let bob = abs(sin(t * 5)) * move
            pose.body = Motion(y: -bob * 8, rotation: sin(t * 5) * 9 * move, sx: 1 - bob * 0.04, sy: 1 + bob * 0.05)
            pose.eyes = .happy; pose.mouth = .grin; pose.cheek = 1.4
            pose.armLeft = 70 + 30 * bob; pose.armRight = -70 - 30 * bob
            pose.shadowScale = 1 - 0.25 * bob
        case .wash:
            let swish = sin(t * 11) * (t < 3.4 ? 5 : 2) * move
            pose.body = Motion(rotation: swish, sx: 1 + swish * 0.006, sy: 1 - swish * 0.006)
            pose.eyes = .happy; pose.mouth = .grin
            pose.armLeft = 85 + 15 * sin(t * 9) * move; pose.armRight = -85 + 15 * sin(t * 9) * move
        case .nap:
            let breath = sin(t * 2) * move
            pose.body = Motion(y: 5, rotation: -16 + breath * 1.5, sy: 1 + breath * 0.025)
            pose.eyes = .closed; pose.mouth = .sleepO; pose.blink = 1
            pose.armLeft = -42; pose.armRight = 42
        }
        return pose
    }

    /// The mouth's scene position, following the pose's squash and hop so the carrot meets it.
    static func mouth(look: PickleLook, pose: PicklePose) -> CGPoint {
        let f = PickleFrame(look: look), round = look.variety.shape == .round
        var t = CGAffineTransform(translationX: 0, y: groundOffset).scaledBy(x: unit * (round ? 1.18 : 1), y: unit * (round ? 0.87 : 1))
        for m in [pose.actor, pose.body] {
            t = t.translatedBy(x: m.x, y: m.y).rotated(by: m.rotation * .pi / 180).scaledBy(x: m.sx, y: m.sy)
        }
        return CGPoint(x: pose.faceX, y: f.face + 12.5 - f.h - 6).applying(t)
    }

    static func drawEffect(_ c: GraphicsContext, effect: FloatEffect, now: Date, top: CGFloat, still: Bool) {
        let t = now.timeIntervalSince(effect.started) / 1.6
        guard t >= 0, t < 1 else { return }
        var ctx = c
        ctx.opacity = t < 0.2 ? t / 0.2 : t < 0.6 ? 1 : 1 - (t - 0.6) / 0.4
        let rise = still ? 0.4 : CGFloat(Ease.out(t))
        let text = Text(effect.text).font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(DillTheme.ink)
        ctx.draw(text, at: CGPoint(x: 0, y: top + 12 - 28 * rise))
        guard effect.hearts else { return }
        for i in 0..<3 {
            let side = CGFloat(i - 1)
            let heart = Text(Image(systemName: "heart.fill")).font(.system(size: 13 + CGFloat(i % 2) * 5)).foregroundStyle(Color(hex: 0xD8888D))
            let x = side * 54 + CGFloat(sin(t * 7 + Double(i) * 2)) * 6
            ctx.draw(heart, at: CGPoint(x: x, y: top + 60 + abs(side) * -16 + CGFloat(i % 2) * 24 - 70 * rise))
        }
    }

    static func drawMess(_ ground: GraphicsContext, x: CGFloat, time: Double, still: Bool) {
        var c = ground
        c.translateBy(x: x, y: 0); c.scaleBy(x: 1.5, y: 1.5)
        let ink = DillTheme.ink
        c.fill(Path(roundedRect: CGRect(x: -11, y: -8, width: 22, height: 8), cornerRadius: 4), with: .color(ink))
        c.fill(Path(roundedRect: CGRect(x: -8, y: -13, width: 16, height: 7), cornerRadius: 3.5), with: .color(ink))
        c.fill(Path(roundedRect: CGRect(x: -4, y: -18, width: 8, height: 7), cornerRadius: 3.5), with: .color(ink))
        for i in 0..<2 {
            let p = still ? 0.4 : PetMotion.loop(time + Double(i) * 0.8, 1.6)
            let x0 = CGFloat(i == 0 ? -5 : 5), y0 = -22 - CGFloat(p) * 14
            var fume = Path()
            fume.move(to: CGPoint(x: x0, y: y0))
            fume.addCurve(to: CGPoint(x: x0, y: y0 - 12), control1: CGPoint(x: x0 + 4, y: y0 - 4), control2: CGPoint(x: x0 - 4, y: y0 - 8))
            var smell = c
            smell.opacity = 0.5 * (1 - p)
            smell.stroke(fume, with: .color(DillTheme.muted), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }
    }

    static func drawTomb(_ ground: GraphicsContext, eaten: Bool) {
        var c = ground
        c.scaleBy(x: 1.4, y: 1.4)
        let ink = DillTheme.ink
        c.fill(Path(ellipseIn: CGRect(x: -40, y: -4, width: 80, height: 8)), with: .color(ink.opacity(0.14)))
        let corner = CGSize(width: 33, height: 33), foot = CGSize(width: 3, height: 3)
        let stone = PickleArtist.bodyPath(CGRect(x: -36.5, y: -79, width: 73, height: 79), [corner, corner, foot, foot])
        c.fill(stone, with: .color(Color(hex: 0x9BAD78)))
        c.stroke(stone, with: .color(ink), style: PickleArtist.line)
        var stem = c
        stem.translateBy(x: 3, y: -86); stem.rotate(by: .degrees(20))
        var p = Path(); p.move(to: CGPoint(x: -3, y: 6)); p.addLine(to: CGPoint(x: -3, y: -4)); p.addLine(to: CGPoint(x: 5, y: -4))
        stem.stroke(p, with: .color(ink), style: PickleArtist.line)
        c.draw(Text(eaten ? "YUM." : "R.I.P.").font(.system(size: 12, weight: .heavy, design: .monospaced)).foregroundStyle(ink), at: CGPoint(x: 0, y: -52))
        c.draw(Text("little dill").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(ink), at: CGPoint(x: 0, y: -37))
        guard eaten else { return }
        for i in 0..<9 {
            let x = 46 + CGFloat(i % 5) * 7 + CGFloat(i / 5) * 3, y = -3 - CGFloat(i / 5) * 4
            c.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 3, height: 3)), with: .color(ink))
        }
    }
}

// Layered, code-native cartoon props. Motion and character expressions share one clock.
private struct CareScenery: View {
    let action: Care?
    let time: Double
    let foreground: Bool
    let reduceMotion: Bool
    var mouth = CGPoint.zero
    private var ink: Color {DillTheme.ink}
    var body: some View {
        Canvas { context,size in
            context.translateBy(x:size.width/2,y:size.height/2)
            func shape(_ path:Path,_ color:Color,_ width:Double = 2.5) {
                context.fill(path,with:.color(color))
                context.stroke(path,with:.color(ink),style:StrokeStyle(lineWidth:width,lineCap:.round,lineJoin:.round))
            }
            func oval(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ color:Color,outline:Bool = false) {
                let p = Path(ellipseIn:CGRect(x:x,y:y,width:w,height:h))
                if outline {shape(p,color,1.7)} else {context.fill(p,with:.color(color))}
            }
            func symbol(_ name:String,_ x:Double,_ y:Double,_ side:Double,_ color:Color) {
                context.draw(Text(Image(systemName:name)).font(.system(size:side,weight:.bold)).foregroundStyle(color),at:CGPoint(x:x,y:y))
            }
            func sparkle(_ x:Double,_ y:Double,_ radius:Double,_ color:Color) {
                var p = Path(); p.move(to:CGPoint(x:x,y:y-radius))
                p.addQuadCurve(to:CGPoint(x:x+radius,y:y),control:CGPoint(x:x+2,y:y-2))
                p.addQuadCurve(to:CGPoint(x:x,y:y+radius),control:CGPoint(x:x+2,y:y+2))
                p.addQuadCurve(to:CGPoint(x:x-radius,y:y),control:CGPoint(x:x-2,y:y+2))
                p.addQuadCurve(to:CGPoint(x:x,y:y-radius),control:CGPoint(x:x-2,y:y-2))
                context.fill(p,with:.color(color))
            }
            switch action {
            case .feed:
                if !foreground {
                    oval(-109,65,58,17,Color(hex:0xEBCB95),outline:true)
                    shape(Path(roundedRect:CGRect(x:-109,y:52,width:58,height:22),cornerRadius:9),DillTheme.peach)
                    for i in 0..<3 {oval(-101+Double(i)*15,46,15,12,DillTheme.lime,outline:true)}
                } else {
                    // The carrot tip rests at the lips, gets pushed in, and loses a chunk on every chomp.
                    let beat = FeedBeat(t:time), tilt = -14 - beat.squash*6
                    let swoop = 1 - Ease.springy(min(1,time/FeedBeat.arrive))
                    if beat.eaten < FeedBeat.bites {
                        let eaten = CGFloat(beat.eaten)*FeedBeat.chunk
                        var carrot = context
                        carrot.translateBy(x:mouth.x + 150*swoop,y:mouth.y - 80*swoop)
                        carrot.rotate(by:.degrees(tilt + 50*swoop))
                        carrot.translateBy(x:FeedBeat.rest - FeedBeat.chunk*beat.push - eaten,y:0)
                        CareScenery.drawCarrot(carrot,eaten:eaten)
                    }
                    if !reduceMotion {
                        let lips = CGPoint(x:mouth.x + cos(tilt * .pi/180)*4,y:mouth.y + sin(tilt * .pi/180)*4)
                        for k in 0..<beat.eaten {
                            let age = time - beat.chompTime(k)
                            guard age < 0.6 else {continue}
                            var bits = context; bits.opacity = 1 - age/0.6
                            for i in 0..<6 {
                                let angle = (-130 + Double(i)*30 + Double(k)*9) * .pi/180, speed = 70 + Double((i*37 + k*11)%50), side = 4 + Double(i%3)
                                let x = lips.x + cos(angle)*speed*age, y = lips.y + sin(angle)*speed*age + 260*age*age
                                let color = k == FeedBeat.bites-1 && i%2 == 0 ? Color(hex:0x7FA35A) : i%3 == 0 ? Color(hex:0xF8C58E) : Color(hex:0xED9C53)
                                let bit = Path(roundedRect:CGRect(x:x - side/2,y:y - side/2,width:side,height:side),cornerRadius:1.2)
                                bits.fill(bit,with:.color(color)); bits.stroke(bit,with:.color(ink),lineWidth:1)
                            }
                        }
                    }
                    if time > FeedBeat.gulp {
                        for i in 0..<3 {
                            let age = time - FeedBeat.gulp - Double(i)*0.14
                            guard age > 0 else {continue}
                            let pop = Ease.springy(min(1,age/0.3))
                            symbol("heart.fill",mouth.x + [52,70,36][i],mouth.y - [34,54,70][i] - age*18,max(1,[24,15,12][i]*pop),[DillTheme.peach,Color(hex:0xD8888D),Color(hex:0xEFAF9D)][i])
                        }
                        sparkle(mouth.x - 62,mouth.y - 50,12*Ease.springy(min(1,(time - FeedBeat.gulp)/0.3)),DillTheme.lime)
                    }
                }
            case .pet:
                if foreground {
                    // A soft cartoon mitten strokes the sprout, while hearts drift up.
                    let x = reduceMotion ? 0 : sin(time*5)*14
                    var hand = Path(); hand.move(to:CGPoint(x:x-14,y:-80)); hand.addLine(to:CGPoint(x:x-16,y:-97))
                    hand.addQuadCurve(to:CGPoint(x:x-7,y:-99),control:CGPoint(x:x-12,y:-108))
                    hand.addLine(to:CGPoint(x:x-3,y:-87)); hand.addLine(to:CGPoint(x:x+21,y:-87))
                    hand.addQuadCurve(to:CGPoint(x:x+24,y:-66),control:CGPoint(x:x+33,y:-74))
                    hand.addQuadCurve(to:CGPoint(x:x-10,y:-67),control:CGPoint(x:x+7,y:-57)); hand.closeSubpath()
                    shape(hand,Color(hex:0xF2CAA5))
                    for i in 0..<6 {
                        let phase = (time*0.5 + Double(i)/6).truncatingRemainder(dividingBy:1)
                        let x = (i%2 == 0 ? -1.0 : 1.0)*(58+Double(i%3)*12)
                        symbol("heart.fill",x,48-phase*136,12+Double(i%3)*5,[DillTheme.peach,Color(hex:0xD8888D),Color(hex:0xEFAF9D)][i%3])
                    }
                    sparkle(-89,49,10,DillTheme.lime); sparkle(94,-61,8,DillTheme.peach)
                }
            case .wash:
                if !foreground {
                    shape(Path(roundedRect:CGRect(x:-78,y:48,width:156,height:46),cornerRadius:22),Color(hex:0x9BC9C7))
                    var pipe = Path(); pipe.move(to:CGPoint(x:95,y:44)); pipe.addLine(to:CGPoint(x:95,y:-72)); pipe.addQuadCurve(to:CGPoint(x:60,y:-88),control:CGPoint(x:95,y:-102))
                    context.stroke(pipe,with:.color(ink),style:StrokeStyle(lineWidth:6,lineCap:.round))
                    shape(Path(roundedRect:CGRect(x:37,y:-89,width:36,height:10),cornerRadius:5),DillTheme.cream)
                    if time < 3.5 {
                        for i in 0..<9 {
                            let phase = (time*1.6+Double(i)*0.17).truncatingRemainder(dividingBy:1)
                            oval(30+Double(i%3)*13,-68+phase*106,3,9,Color(hex:0x7AAFAF))
                        }
                    }
                } else {
                    shape(Path(roundedRect:CGRect(x:-81,y:55,width:162,height:39),cornerRadius:19),Color(hex:0xCDE5DE))
                    for i in 0..<10 {oval(-80+Double(i)*16,43+sin(time*3+Double(i))*3,23,20,.white,outline:true)}
                    for i in 0..<12 {
                        let phase = (time*0.23+Double(i)*0.13).truncatingRemainder(dividingBy:1)
                        let x = sin(Double(i)*2.4)*92 + sin(time*2+Double(i))*5
                        let r = 6 + Double(i%3)*4
                        oval(x,43-phase*141,r*2,r*2,Color.white.opacity(0.65),outline:true)
                        oval(x+r*0.5,46-phase*141,r*0.4,r*0.4,.white)
                    }
                    if time > 3.2 {for i in 0..<4 {sparkle(Double(i%2)*144-72,Double(i/2)*76-60,10+sin(time*7+Double(i))*3,Color(hex:0xF2D87D))}}
                }
            case .nap:
                if !foreground {
                    oval(68,-95,33,33,Color(hex:0xF4E4A2))
                    oval(78,-101,31,31,Color(hex:0x344F50))
                    for i in 0..<10 {sparkle(sin(Double(i)*5.2)*129,-90+Double(i%4)*47,2+Double(i%3),DillTheme.cream.opacity(0.65))}
                    shape(Path(roundedRect:CGRect(x:-77,y:55,width:154,height:39),cornerRadius:18),Color(hex:0xE7D4B7))
                } else {
                    var blanket = Path(); blanket.move(to:CGPoint(x:-59,y:26)); blanket.addQuadCurve(to:CGPoint(x:57,y:34),control:CGPoint(x:5,y:45)); blanket.addLine(to:CGPoint(x:63,y:89)); blanket.addQuadCurve(to:CGPoint(x:-61,y:87),control:CGPoint(x:0,y:101)); blanket.closeSubpath()
                    shape(blanket,Color(hex:0xB6C89C))
                    for i in 0..<6 {sparkle(-39+Double(i%3)*37,54+Double(i/3)*24,4,DillTheme.cream)}
                    for i in 0..<3 {
                        let phase = (time*0.3+Double(i)*0.3).truncatingRemainder(dividingBy:1)
                        context.draw(Text("z").font(.system(size:14+phase*10,weight:.bold,design:.rounded)).foregroundStyle(DillTheme.cream.opacity(1-phase*0.5)),at:CGPoint(x:58+phase*31,y:-8-phase*63))
                    }
                }
            case nil:
                if !foreground {
                    oval(80,-77,48,48,Color(hex:0xF6E4A9))
                    sparkle(-112,-47,12,DillTheme.muted.opacity(0.5)); sparkle(-102,68,9,DillTheme.muted.opacity(0.4))
                    symbol("leaf",112,80,26,DillTheme.muted.opacity(0.5))
                }
            }
        }.accessibilityHidden(true)
    }

    static let carrotLength: CGFloat = 58

    /// Half-width `x` points from the tip, solved from the upper quad curve in `drawCarrot`.
    static func carrotHalfWidth(_ x: CGFloat) -> CGFloat {
        let s = (sqrt(0.81 + 0.4 * min(1, max(0, x) / carrotLength)) - 0.9) / 0.2
        return 20 * s * (1 - s) + 11 * s * s
    }

    /// A carrot lying along +x with its tip at the origin. `eaten` points are bitten off the tip.
    static func drawCarrot(_ context: GraphicsContext, eaten: CGFloat) {
        let ink = DillTheme.ink, length = carrotLength, flesh = Color(hex: 0xF8C58E)
        var c = context
        var marks = Path()
        if eaten > 0 {
            let r: CGFloat = 3.2, count = Int((2 * (carrotHalfWidth(eaten) + r) / 5.5).rounded(.up))
            for i in 0..<count { marks.addEllipse(in: CGRect(x: eaten - r, y: (CGFloat(i) - CGFloat(count - 1) / 2) * 5.5 - r, width: 2 * r, height: 2 * r)) }
            c.clip(to: Path(CGRect(x: eaten, y: -40, width: 120, height: 80)))
            c.clip(to: marks, options: .inverse)
        }
        for angle in [-34.0, 0, 34] {
            var leaf = c
            leaf.translateBy(x: length + 2, y: 0); leaf.rotate(by: .degrees(angle))
            var p = Path(); p.move(to: .zero)
            p.addQuadCurve(to: CGPoint(x: 18, y: 0), control: CGPoint(x: 9, y: -8))
            p.addQuadCurve(to: .zero, control: CGPoint(x: 9, y: 8))
            leaf.fill(p, with: .color(Color(hex: 0x7FA35A))); leaf.stroke(p, with: .color(ink), lineWidth: 2)
        }
        var body = Path(); body.move(to: .zero)
        body.addQuadCurve(to: CGPoint(x: length, y: -11), control: CGPoint(x: length * 0.45, y: -10))
        body.addQuadCurve(to: CGPoint(x: length, y: 11), control: CGPoint(x: length + 9, y: 0))
        body.addQuadCurve(to: .zero, control: CGPoint(x: length * 0.45, y: 10))
        c.fill(body, with: .color(Color(hex: 0xED9C53)))
        var shine = Path(); shine.move(to: CGPoint(x: 26, y: -4.5)); shine.addQuadCurve(to: CGPoint(x: 52, y: -6.5), control: CGPoint(x: 40, y: -8))
        c.stroke(shine, with: .color(flesh), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        for (x, side) in [(CGFloat(18), CGFloat(1)), (31, -1), (44, 1)] {
            let w = carrotHalfWidth(x)
            var ridge = Path(); ridge.move(to: CGPoint(x: x, y: side * w))
            ridge.addQuadCurve(to: CGPoint(x: x + 2, y: side * w * 0.3), control: CGPoint(x: x - 1.5, y: side * w * 0.65))
            c.stroke(ridge, with: .color(Color(hex: 0xC46A2C)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        if eaten > 0 {
            var bite = c; bite.clip(to: body)
            bite.stroke(marks, with: .color(flesh), lineWidth: 9)
            bite.stroke(marks, with: .color(ink), lineWidth: 4)
        }
        c.stroke(body, with: .color(ink), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
    }
}
