import SwiftUI

struct CarePerformance {
    let action: Care
    let started = Date()
    var duration: Double {switch action {case .feed:return 3.8; case .pet:return 4; case .wash:return 5; case .nap:return 6}}
    var caption: String {switch action {case .feed:return "NOM NOM NOM"; case .pet:return "ABSOLUTELY ADORED"; case .wash:return "SQUEAKY CLEAN CLUB"; case .nap:return "DO NOT DISTURB"}}
}

struct CareScene: View {
    let pet: PetState
    let performance: CarePerformance?
    let now: Date
    let reduceMotion: Bool
    private var action: Care? {performance?.action}
    private var elapsed: Double {max(0,now.timeIntervalSince(performance?.started ?? now))}
    private var t: Double {reduceMotion ? 1.3 : elapsed}
    private var idle: Double {reduceMotion ? 0 : now.timeIntervalSinceReferenceDate}
    private var wave: Double {sin(t * 13)}
    private var sleeping: Bool {action == .nap}
    private var angle: Double {
        if reduceMotion {return sleeping ? -16 : 0}
        switch action {
        case .feed:return wave * 4
        case .pet:return sin(t * 5) * 9
        case .wash:return sin(t * 11) * (t < 3.4 ? 5 : 2)
        case .nap:return -16 + sin(t * 2) * 1.5
        case nil:return sin(idle * 1.6) * 2.5
        }
    }
    var body: some View {
        ZStack {
            CareScenery(action:action,time:t,foreground:false,reduceMotion:reduceMotion)
            Ellipse().fill((sleeping ? Color.black : DillTheme.ink).opacity(0.1))
                .frame(width:action == .pet ? 115 + wave * 5 : 120,height:17).offset(y:86)
            PickleCharacter(brine:pet.brine,outfit:pet.outfit,happy:action == .pet || action == .wash,
                            sleeping:sleeping,chewing:action == .feed ? (wave + 1) / 2 : nil,
                            blinking:action == nil && idle.truncatingRemainder(dividingBy:4.8) < 0.16)
                .frame(width:200,height:200)
                .scaleEffect(x:reduceMotion ? 1 : (action == .feed ? 1 + wave * 0.055 : 1),
                             y:reduceMotion ? 1 : (sleeping ? 1 + sin(t*2)*0.025 : action == .feed ? 1 - wave * 0.045 : 1))
                .rotationEffect(.degrees(angle))
                .offset(y:reduceMotion ? 0 : action == .pet ? -abs(sin(t*5))*13 : sleeping ? 9 : sin(idle*2)*3)
            CareScenery(action:action,time:t,foreground:true,reduceMotion:reduceMotion)
        }.frame(height:230).frame(maxWidth:.infinity).clipped()
            .accessibilityElement(children:.ignore)
            .accessibilityLabel(performance?.caption ?? "Your happy pickle")
            .accessibilityIdentifier("careScene.\(action?.rawValue ?? "idle")")
    }
}

// Layered, code-native cartoon props. Motion and character expressions share one clock.
private struct CareScenery: View {
    let action: Care?
    let time: Double
    let foreground: Bool
    let reduceMotion: Bool
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
                    let approach = reduceMotion ? 1 : min(1,time / 0.45)
                    let chews = min(1,max(0,(time - 0.45) / 2.1))
                    var carrot = context
                    carrot.translateBy(x:72 - approach*53,y:30 - approach*15)
                    carrot.rotate(by:.degrees(-38))
                    let length = 43 * (1 - chews) + 8
                    var p = Path(); p.move(to:CGPoint(x:0,y:0)); p.addQuadCurve(to:CGPoint(x:length,y:-10),control:CGPoint(x:20,y:-15)); p.addLine(to:CGPoint(x:length,y:10)); p.addQuadCurve(to:.zero,control:CGPoint(x:20,y:15))
                    carrot.fill(p,with:.color(Color(hex:0xED9C53))); carrot.stroke(p,with:.color(ink),lineWidth:2.5)
                    for i in -1...1 {var leaf = Path(); leaf.move(to:CGPoint(x:length,y:0)); leaf.addQuadCurve(to:CGPoint(x:length+14,y:Double(i)*12),control:CGPoint(x:length+8,y:Double(i)*5)); carrot.stroke(leaf,with:.color(Color(hex:0x698E4E)),style:StrokeStyle(lineWidth:4,lineCap:.round))}
                    if time > 0.4 && time < 2.9 {
                        for i in 0..<9 {
                            let phase = (time*1.8 + Double(i)*0.19).truncatingRemainder(dividingBy:1)
                            let side = i%2 == 0 ? 1.0 : -1.0
                            oval(8 + side*(10+phase*42),18+phase*42,4+Double(i%3),4,Color(hex:0xD89B58))
                        }
                    }
                    if time > 2.5 {symbol("heart.fill",65,-35,25,DillTheme.peach); sparkle(-68,-42,12,DillTheme.lime)}
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
}
