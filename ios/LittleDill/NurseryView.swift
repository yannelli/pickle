import SwiftUI

/// The web nursery: pick a brine, wait one minute while it hatches, then name the pickle.
struct NurseryView: View {
    @EnvironmentObject private var store: DillStore
    @State private var brine: Brine = .classic
    @State private var name = ""
    @State private var error = ""
    @FocusState private var editing: Bool
    private var life: WebPet { store.pet.life }
    private var variety: PickleVariety { life.phase == .new ? PickleVariety.first(brine: brine.rawValue) : PickleVariety.of(life.variety) }
    private var remaining: Int { NestText.hatchRemaining(life) }

    var body: some View {
        ScrollView {
            VStack(spacing:22) {
                HStack { Text("little dill.").font(DillTheme.display(29)).tracking(-1); Spacer(); Eyebrow(text:"One tiny beginning") }
                VStack(spacing:8) {
                    Text(title).font(DillTheme.display(38)).tracking(-1.6).multilineTextAlignment(.center).accessibilityIdentifier("nurseryTitle")
                    Text(detail).font(.subheadline).foregroundStyle(DillTheme.muted).multilineTextAlignment(.center).accessibilityIdentifier("nurseryMessage")
                }
                BrineJar(phase:life.phase,variety:variety).frame(height:250).accessibilityHidden(true)
                controls
                Text("No account. No pressure. Just a little joy.").font(.caption).foregroundStyle(DillTheme.muted)
            }.padding(26).frame(maxWidth:540).frame(maxWidth:.infinity)
        }.scrollIndicators(.hidden).scrollDismissesKeyboard(.interactively)
            .animation(.spring(response:0.5,dampingFraction:0.8),value:life.phase)
            .onAppear { if life.phase == .naming { editing = true } }
            .onChange(of:life.phase) { _,phase in if phase == .naming { editing = true } }
    }

    private var title: String {
        switch life.phase {
        case .new: return "A friend, freshly brined."
        case .brining: return "Good things take a little brine."
        default: return "Hello, \(variety.name)!"
        }
    }

    private var detail: String {
        switch life.phase {
        case .new: return "Pick a brine. Pop in your cucumber. A tiny friend hatches in one minute."
        case .brining: return "Hatching in \(remaining)s. You can close the app; the brine keeps working."
        default: return "Your baby pickle is here. Every great dill needs a name."
        }
    }

    @ViewBuilder private var controls: some View {
        switch life.phase {
        case .new:
            VStack(alignment:.leading,spacing:12) {
                Eyebrow(text:"Choose a brine")
                HStack(spacing:8) {
                    ForEach(Brine.allCases) { option in
                        Button { brine = option; store.feedback(); store.sound(.pop) } label: {
                            VStack(spacing:6) { Circle().fill(option.color).frame(width:18,height:18); Text(option.title).font(.system(size:13,weight:.semibold,design:.rounded)) }
                                .frame(maxWidth:.infinity).padding(.vertical,14)
                                .background(brine == option ? DillTheme.sage : .white.opacity(0.6),in:RoundedRectangle(cornerRadius:18))
                                .overlay(RoundedRectangle(cornerRadius:18).stroke(brine == option ? DillTheme.ink : DillTheme.line,lineWidth:brine == option ? 2 : 1))
                        }.accessibilityAddTraits(brine == option ? .isSelected : []).accessibilityIdentifier("brine.\(option.rawValue)")
                    }
                }
                Text("\(brine.subtitle). Hatches a \(brine.varieties.map(\.name).joined(separator:" or ")).").font(.caption).foregroundStyle(DillTheme.muted)
            }
            Button(action:startBrine) { Text("Put pickle in brine ↓") }.buttonStyle(DillButton()).accessibilityIdentifier("brineStart")
        case .brining:
            ProgressView(value:Double(60 - remaining),total:60).tint(DillTheme.ink)
                .animation(.linear(duration:1),value:remaining)
                .accessibilityLabel("Brining progress").accessibilityValue("\(remaining) seconds left").accessibilityIdentifier("hatchProgress")
        default:
            VStack(alignment:.leading,spacing:10) {
                Text("What shall we call this little one?").font(.system(size:13,weight:.semibold,design:.rounded))
                TextField("Sir Crunch, perhaps?",text:$name).font(.system(.title3,design:.rounded,weight:.semibold)).padding(16)
                    .background(.white.opacity(0.7),in:RoundedRectangle(cornerRadius:18))
                    .focused($editing).submitLabel(.done).onSubmit(submit).autocorrectionDisabled().accessibilityIdentifier("petName")
                if !error.isEmpty { Text(error).font(.caption).foregroundStyle(Color(hex:0x993E24)).accessibilityIdentifier("nameError") }
            }
            Button(action:submit) { Text("Hello, little friend ♥") }.buttonStyle(DillButton()).accessibilityIdentifier("adopt")
        }
    }

    private func startBrine() {
        guard store.brine(brine) else { return }
        #if DEBUG
        DebugClock.skipHatch()
        #endif
        store.sound(.feed); store.feedback(.medium)
    }

    private func submit() {
        guard store.name(name) else { error = "Give your pickle a name with 1–24 characters."; store.feedback(.rigid); return }
        editing = false; error = ""
        store.sound(.win); store.feedback(.medium)
    }
}

/// A brine jar with bubbles. The baby hovers above it, floats inside while brining, then hops out to be named.
struct BrineJar: View {
    let phase: PetPhase
    let variety: PickleVariety
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval:reduceMotion ? 0.2 : nil)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                var jar = context
                jar.translateBy(x:size.width / 2,y:size.height - 14)
                jar.scaleBy(x:1.7,y:1.7)
                BrineJar.draw(jar,phase:phase,variety:variety,time:time,still:reduceMotion)
            }
        }
    }

    static func draw(_ c: GraphicsContext, phase: PetPhase, variety: PickleVariety, time: Double, still: Bool) {
        let ink = DillTheme.ink
        let look = PickleLook(variety:variety,stage:.baby,outfit:.original)
        let bob = still ? 0 : sin(time * 2.2)
        if phase == .naming || phase == .living {
            var baby = c
            baby.scaleBy(x:1.25,y:1.25)
            let pose = PetMotion.pose(mood:.happy,vibe:.hop,act:nil,actElapsed:0,time:time,reduceMotion:still)
            PickleArtist.draw(baby,look:look,pose:pose,time:time)
            return
        }
        let body = PickleArtist.bodyPath(CGRect(x:-42.5,y:-96,width:85,height:96),[CGSize(width:9,height:9),CGSize(width:9,height:9),CGSize(width:22,height:22),CGSize(width:22,height:22)])
        c.fill(Path(ellipseIn:CGRect(x:-46,y:-4,width:92,height:8)),with:.color(ink.opacity(0.12)))
        c.fill(body,with:.color(Color.white.opacity(0.35)))
        var pose = PicklePose()
        pose.shadowOpacity = 0; pose.eyes = .happy
        pose.blink = PetMotion.blink.at(PetMotion.loop(time,4.4))
        if phase == .new {
            var baby = c
            baby.translateBy(x:0,y:-70 + CGFloat(bob) * 4); baby.rotate(by:.degrees(15))
            pose.eyes = .open; pose.armLeft = 60; pose.armRight = -60
            PickleArtist.draw(baby,look:look,pose:pose,time:time)
        } else {
            var baby = c
            baby.translateBy(x:0,y:-14 + CGFloat(bob) * 3); baby.rotate(by:.degrees(-12 + bob * 3))
            PickleArtist.draw(baby,look:look,pose:pose,time:time)
        }
        var brine = c
        brine.clip(to:body)
        let level: CGFloat = phase == .brining ? -67 + CGFloat(bob) * 1.5 : -67
        var surface = Path()
        surface.move(to:CGPoint(x:-44,y:level))
        surface.addCurve(to:CGPoint(x:44,y:level),control1:CGPoint(x:-15,y:level - 4 * CGFloat(bob)),control2:CGPoint(x:15,y:level + 4 * CGFloat(bob)))
        surface.addLine(to:CGPoint(x:44,y:2)); surface.addLine(to:CGPoint(x:-44,y:2)); surface.closeSubpath()
        brine.fill(surface,with:.color(Color(hex:0x8FA966).opacity(0.55)))
        if phase == .brining {
            for i in 0..<7 {
                let p = still ? 0.5 : PetMotion.loop(time + Double(i) * 0.37,2.1)
                let drift: CGFloat = still ? 0 : CGFloat(sin(time * 3 + Double(i))) * 2
                let x = CGFloat(sin(Double(i) * 1.7)) * 26 + drift
                let y = -8 - CGFloat(p) * 58, r = 1.6 + CGFloat(i % 3)
                var bubble = brine
                bubble.opacity = 1 - p * 0.8
                let circle = Path(ellipseIn:CGRect(x:x - r,y:y - r,width:2 * r,height:2 * r))
                bubble.fill(circle,with:.color(DillTheme.cream.opacity(0.7)))
                bubble.stroke(circle,with:.color(ink),lineWidth:1.2)
            }
        }
        c.stroke(body,with:.color(ink),style:PickleArtist.line)
        var shine = Path(); shine.move(to:CGPoint(x:-32,y:-80)); shine.addLine(to:CGPoint(x:-32,y:-30))
        c.stroke(shine,with:.color(Color.white.opacity(0.75)),style:StrokeStyle(lineWidth:3,lineCap:.round))
        if phase == .brining { c.fill(Path(roundedRect:CGRect(x:-44,y:-104,width:88,height:11),cornerRadius:3),with:.color(ink)) }
    }
}
