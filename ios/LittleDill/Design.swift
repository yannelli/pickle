import SwiftUI

extension Color {
    init(hex: UInt32) { self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1) }
}
enum DillTheme {
    static let cream = Color(hex: 0xF8F6ED)
    static let ink = Color(hex: 0x263E31)
    static let muted = Color(hex: 0x6A7868)
    static let lime = Color(hex: 0xD4EB85)
    static let sage = Color(hex: 0xE7ECD9)
    static let peach = Color(hex: 0xF1C9B4)
    static let line = Color(hex: 0xDDE1D2)
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .serif) }
}
struct DillButton: ButtonStyle {
    var light = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(.headline, design: .rounded)).frame(maxWidth: .infinity).padding(.vertical, 18)
            .foregroundStyle(light ? DillTheme.ink : DillTheme.cream)
            .background(light ? DillTheme.lime : DillTheme.ink, in: RoundedRectangle(cornerRadius: 22))
            .scaleEffect(configuration.isPressed ? 0.97 : 1).opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
struct Eyebrow: View {
    let text: String
    var body: some View { Text(text.uppercased()).font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(2).foregroundStyle(DillTheme.muted) }
}
struct CoinPill: View {
    let amount: Int
    var body: some View {
        HStack(spacing: 5) { Image(systemName: "sparkle"); Text("\(amount)").monospacedDigit() }
            .font(.system(size: 13, weight: .bold, design: .rounded)).padding(.horizontal, 12).padding(.vertical, 9)
            .background(.white.opacity(0.7), in: Capsule()).overlay(Capsule().stroke(DillTheme.line, lineWidth: 1))
            .accessibilityLabel("\(amount) crunch coins")
    }
}
struct PageHeading: View {
    let eyebrow: String
    let title: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Eyebrow(text: eyebrow)
            Text(title).font(DillTheme.display(38)).tracking(-1.5).fixedSize(horizontal: false, vertical: true)
            Text(detail).font(.subheadline).foregroundStyle(DillTheme.muted).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct SoftCard<Content: View>: View {
    var color: Color = .white.opacity(0.65)
    @ViewBuilder var content: Content
    var body: some View { content.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(color, in: RoundedRectangle(cornerRadius: 26)).overlay(RoundedRectangle(cornerRadius: 26).stroke(DillTheme.line.opacity(0.6), lineWidth: 1)) }
}

// Code-native vector art stays crisp at every size and can wear every collectible.
struct PickleCharacter: View {
    var brine: Brine = .classic
    var outfit: Outfit = .sprout
    var happy = false
    var sleeping = false
    var chewing: Double?
    var blinking = false
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 160
            context.translateBy(x: (size.width - 160 * scale) / 2, y: (size.height - 160 * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            func path(_ draw: (inout Path) -> Void, fill: Color? = nil, stroke: Color = DillTheme.ink, width: CGFloat = 3.5) {
                var p = Path(); draw(&p)
                if let fill { context.fill(p, with: .color(fill)) }
                context.stroke(p, with: .color(stroke), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            }
            func ellipse(_ rect: CGRect, _ color: Color) { context.fill(Path(ellipseIn: rect), with: .color(color)) }
            path({ p in p.move(to: CGPoint(x: 52,y: 95)); p.addQuadCurve(to: CGPoint(x: 29,y: happy ? 74 : 92), control: CGPoint(x: 32,y: 98)); p.move(to: CGPoint(x: 112,y: 91)); p.addQuadCurve(to: CGPoint(x: 134,y: 71), control: CGPoint(x: 133,y: 94)) })
            path({ p in p.move(to: CGPoint(x: 64,y: 129)); p.addLine(to: CGPoint(x: 60,y: 142)); p.addLine(to: CGPoint(x: 51,y: 142)); p.move(to: CGPoint(x: 93,y: 129)); p.addLine(to: CGPoint(x: 98,y: 142)); p.addLine(to: CGPoint(x: 107,y: 142)) })
            path({ p in p.move(to: CGPoint(x: 85,y: 26)); p.addCurve(to: CGPoint(x: 116,y: 65), control1: CGPoint(x: 108,y: 26), control2: CGPoint(x: 119,y: 41)); p.addLine(to: CGPoint(x: 112,y: 103)); p.addCurve(to: CGPoint(x: 77,y: 132), control1: CGPoint(x: 110,y: 124), control2: CGPoint(x: 96,y: 134)); p.addCurve(to: CGPoint(x: 43,y: 101), control1: CGPoint(x: 53,y: 131), control2: CGPoint(x: 39,y: 121)); p.addLine(to: CGPoint(x: 47,y: 61)); p.addCurve(to: CGPoint(x: 85,y: 26), control1: CGPoint(x: 48,y: 37), control2: CGPoint(x: 62,y: 25)); p.closeSubpath() }, fill: brine.color)
            path({ p in p.move(to: CGPoint(x: 61,y: 54)); p.addQuadCurve(to: CGPoint(x: 80,y: 39), control: CGPoint(x: 65,y: 40)) }, stroke: .white.opacity(0.35), width: 7)
            for point in [CGPoint(x:57,y:95),CGPoint(x:98,y:51),CGPoint(x:102,y:102),CGPoint(x:63,y:116)] { ellipse(CGRect(x:point.x,y:point.y,width:5,height:7), DillTheme.ink.opacity(0.18)) }
            ellipse(CGRect(x:54,y:84,width:12,height:6), DillTheme.peach.opacity(0.9)); ellipse(CGRect(x:96,y:83,width:12,height:6), DillTheme.peach.opacity(0.9))
            if sleeping || blinking || happy {
                path({ p in p.move(to: CGPoint(x:66,y:76)); p.addQuadCurve(to: CGPoint(x:75,y:76), control: CGPoint(x:70,y:80)); p.move(to: CGPoint(x:91,y:76)); p.addQuadCurve(to: CGPoint(x:100,y:76), control: CGPoint(x:95,y:80)) }, width: 3)
            } else {
                ellipse(CGRect(x:67,y:71,width:5,height:8), DillTheme.ink); ellipse(CGRect(x:92,y:70,width:5,height:8), DillTheme.ink)
            }
            if let chewing {
                ellipse(CGRect(x:74,y:85,width:17,height:4+chewing*13),DillTheme.ink)
                ellipse(CGRect(x:78,y:88+chewing*6,width:9,height:3+chewing*3),DillTheme.peach)
                if chewing > 0.55 {path({p in p.move(to:CGPoint(x:76,y:87)); p.addLine(to:CGPoint(x:86,y:87))},stroke:DillTheme.cream,width:3)}
            } else if sleeping {
                ellipse(CGRect(x:78,y:88,width:7,height:7),DillTheme.ink)
            } else {
                path({ p in p.move(to: CGPoint(x:76,y:89)); p.addQuadCurve(to: CGPoint(x:88,y:88), control: CGPoint(x:82,y:happy ? 103 : 99)) }, width: 2.5)
            }
            switch outfit {
            case .original: break
            case .sprout:
                path({ p in p.move(to: CGPoint(x:79,y:28)); p.addQuadCurve(to: CGPoint(x:80,y:12), control: CGPoint(x:75,y:19)) }, width: 3)
                path({ p in p.move(to: CGPoint(x:80,y:20)); p.addQuadCurve(to: CGPoint(x:64,y:7), control: CGPoint(x:66,y:22)); p.addQuadCurve(to: CGPoint(x:80,y:20), control: CGPoint(x:81,y:4)) }, fill: DillTheme.lime, width: 2)
                path({ p in p.move(to: CGPoint(x:80,y:17)); p.addQuadCurve(to: CGPoint(x:96,y:5), control: CGPoint(x:80,y:3)); p.addQuadCurve(to: CGPoint(x:80,y:17), control: CGPoint(x:99,y:17)) }, fill: brine.color, width: 2)
            case .bow:
                path({ p in p.move(to: CGPoint(x:87,y:37)); p.addLine(to: CGPoint(x:73,y:24)); p.addQuadCurve(to: CGPoint(x:73,y:45), control: CGPoint(x:62,y:33)); p.closeSubpath(); p.move(to: CGPoint(x:87,y:37)); p.addLine(to: CGPoint(x:101,y:25)); p.addQuadCurve(to: CGPoint(x:102,y:46), control: CGPoint(x:113,y:35)); p.closeSubpath() }, fill: DillTheme.peach, width: 2)
                ellipse(CGRect(x:82,y:32,width:9,height:9), DillTheme.ink)
            case .shades:
                path({ p in p.addRoundedRect(in: CGRect(x:58,y:66,width:23,height:17), cornerSize: CGSize(width:5,height:5)); p.addRoundedRect(in: CGRect(x:86,y:66,width:23,height:17), cornerSize: CGSize(width:5,height:5)); p.move(to: CGPoint(x:81,y:70)); p.addLine(to: CGPoint(x:86,y:70)) }, fill: DillTheme.ink, width: 2)
                path({ p in p.move(to: CGPoint(x:62,y:71)); p.addLine(to: CGPoint(x:67,y:71)); p.move(to: CGPoint(x:90,y:71)); p.addLine(to: CGPoint(x:95,y:71)) }, stroke: .white.opacity(0.8), width: 2)
            case .crown:
                path({ p in p.move(to: CGPoint(x:62,y:30)); p.addLine(to: CGPoint(x:57,y:7)); p.addLine(to: CGPoint(x:72,y:17)); p.addLine(to: CGPoint(x:83,y:1)); p.addLine(to: CGPoint(x:93,y:16)); p.addLine(to: CGPoint(x:108,y:7)); p.addLine(to: CGPoint(x:102,y:32)); p.closeSubpath() }, fill: Color(hex: 0xEFCA63), width: 2.5)
            case .party:
                path({ p in p.move(to: CGPoint(x:64,y:31)); p.addLine(to: CGPoint(x:85,y:0)); p.addLine(to: CGPoint(x:102,y:32)); p.closeSubpath() }, fill: DillTheme.peach, width: 2)
                ellipse(CGRect(x:80,y:11,width:6,height:6), DillTheme.cream); ellipse(CGRect(x:86,y:24,width:6,height:6), DillTheme.cream)
            }
        }.aspectRatio(1, contentMode: .fit).accessibilityHidden(true)
    }
}

struct PetGarden: View {
    let pet: PetState
    var message = "a little love goes a long way."
    var performance: CarePerformance?
    var onPet: (() -> Void)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(performance?.caption ?? "YOUR HAPPY PLACE", systemImage: performance?.action.symbol ?? "sun.max").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.5)
                Spacer()
                Image(systemName: "sparkle")
            }.padding(20)
                .foregroundStyle(performance?.action == .nap ? DillTheme.cream : DillTheme.ink)
            Text(message).font(.system(size: 12, weight: .medium, design: .rounded)).padding(.horizontal, 16).padding(.vertical, 10)
                .foregroundStyle(DillTheme.ink).background(DillTheme.cream.opacity(0.9), in: Capsule()).padding(.top, 1)
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
                CareScene(pet:pet,performance:performance,now:timeline.date,reduceMotion:reduceMotion)
            }.contentShape(Rectangle()).onTapGesture { onPet?() }
                .accessibilityElement(children: .contain).accessibilityLabel("Pet \(pet.name)")
                .accessibilityAddTraits(onPet == nil ? [] : .isButton).accessibilityAction { onPet?() }
            HStack(spacing: 6) { Circle().frame(width:5,height:5); Text("\(pet.name) · \(pet.brine.title) cutie").font(.system(size: 12,weight:.medium,design:.rounded)) }.padding(.bottom, 18)
                .foregroundStyle(performance?.action == .nap ? DillTheme.cream : DillTheme.ink)
        }.background(performance?.action == .nap ? Color(hex:0x344F50) : performance?.action == .wash ? Color(hex:0xDCEDE5) : Color(hex:0xE9EEDC),in:RoundedRectangle(cornerRadius:32))
    }
}
