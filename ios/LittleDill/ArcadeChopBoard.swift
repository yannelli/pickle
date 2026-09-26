import SwiftUI

struct ChopBoard: View {
    let run: ChopRun
    let look: PickleLook
    let swipe: (CGPoint, CGPoint) -> Void
    let lift: () -> Void
    @State private var last: CGPoint?

    var body: some View {
        GeometryReader { proxy in
            let world = ArcadeWorld(proxy.size)
            Canvas { context, _ in draw(world.context(context)) }
                .frame(width: ArcadeWorld.width * world.scale, height: ArcadeWorld.height * world.scale)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let point = world.point(value.location)
                        swipe(last ?? point, point)
                        last = point
                    }
                    .onEnded { _ in last = nil; lift() })
        }
        .accessibilityElement()
        .accessibilityLabel("Cuke chop board")
        .accessibilityValue("\(run.score) chopped, \(run.lives) hearts")
        .accessibilityAddTraits(.allowsDirectInteraction)
        .accessibilityIdentifier("arcade.chop.board")
    }

    private func draw(_ c: GraphicsContext) {
        let w = ArcadeWorld.width, h = ArcadeWorld.height
        c.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)), with: .color(ArcadeArt.wood))
        for n in 0..<9 {
            var grain = Path()
            let y = 40 + Double(n) * 64
            grain.move(to: CGPoint(x: -10, y: y))
            grain.addCurve(to: CGPoint(x: w + 10, y: y + 10), control1: CGPoint(x: 120, y: y - 18), control2: CGPoint(x: 240, y: y + 26))
            c.stroke(grain, with: .color(ArcadeArt.grain), lineWidth: 2)
        }
        for splash in run.splashes { drawSplash(c, splash) }
        for half in run.halves { drawHalf(c, half) }
        for item in run.items {
            if item.kind == .pal { drawPal(c, item) } else { drawCuke(c, item) }
        }
        for drop in run.drops {
            let fade = 1 - (run.time - drop.born) / 0.9
            c.draw(Text("×").font(.system(size: 44, weight: .black, design: .rounded)).foregroundStyle(ArcadeArt.heart.opacity(fade)), at: CGPoint(x: drop.x, y: drop.y))
        }
        drawTrail(c)
        ArcadeArt.score(c, run.score)
        ArcadeArt.lives(c, left: run.lives, of: ChopRules.lives)
        if run.time < 2.2, run.score == 0 {
            ArcadeArt.caption(c, "swipe to chop", at: CGPoint(x: w / 2, y: h / 2), size: 22)
        }
    }

    private func cukePath(_ right: Bool? = nil) -> Path {
        let path = Path(roundedRect: CGRect(x: -33, y: -15, width: 66, height: 30), cornerRadius: 15)
        guard let right else { return path }
        return path.intersection(Path(CGRect(x: right ? 0 : -40, y: -20, width: 40, height: 40)))
    }

    private func place(_ c: GraphicsContext, x: Double, y: Double, angle: Double) -> GraphicsContext {
        var g = c
        g.translateBy(x: x, y: y)
        g.rotate(by: .radians(angle))
        return g
    }

    private func drawCuke(_ c: GraphicsContext, _ item: ChopItem) {
        let g = place(c, x: item.x, y: item.y, angle: item.angle)
        let gold = item.kind == .gold
        let body = cukePath()
        g.fill(body, with: .color(Color(hex: gold ? 0xE9BE4F : 0x5F8F3E)))
        for (x, y) in [(-18.0, -5.0), (-4, 5), (10, -6), (22, 4)] {
            g.fill(Path(ellipseIn: CGRect(x: x - 2.5, y: y - 2.5, width: 5, height: 5)), with: .color(Color(hex: gold ? 0xC99A2A : 0x46722C)))
        }
        g.fill(Path(roundedRect: CGRect(x: -20, y: -10, width: 30, height: 4), cornerRadius: 2), with: .color(.white.opacity(0.35)))
        g.stroke(body, with: .color(ArcadeArt.ink), lineWidth: 2.5)
    }

    private func drawHalf(_ c: GraphicsContext, _ half: ChopHalf) {
        let g = place(c, x: half.x, y: half.y, angle: half.angle)
        let body = cukePath(half.right)
        g.fill(body, with: .color(Color(hex: half.gold ? 0xE9BE4F : 0x5F8F3E)))
        g.fill(Path(ellipseIn: CGRect(x: -5, y: -13, width: 10, height: 26)), with: .color(Color(hex: half.gold ? 0xF7E3A0 : 0xDCEDA8)))
        for y in [-6.0, 0, 6] {
            g.fill(Path(ellipseIn: CGRect(x: -1.5, y: y - 1.5, width: 3, height: 3)), with: .color(Color(hex: 0xA9C46A)))
        }
        g.stroke(body, with: .color(ArcadeArt.ink), lineWidth: 2.5)
    }

    private func drawPal(_ c: GraphicsContext, _ item: ChopItem) {
        var pose = PicklePose()
        pose.eyes = item.bonked ? .closed : .wide
        pose.mouth = item.bonked ? .frown : .scaredO
        pose.armLeft = 70
        pose.armRight = -70
        if item.bonked { pose.sweat = 1 }
        let angle = item.bonked ? item.angle : sin(item.angle) * 0.35
        ArcadeArt.pet(c, look: look, pose: pose, at: CGPoint(x: item.x, y: item.y), height: 64, angle: .radians(angle))
    }

    private func drawSplash(_ c: GraphicsContext, _ splash: ChopMark) {
        let age = (run.time - splash.born) / 0.6
        let color = Color(hex: splash.gold ? 0xF2D06B : 0xB8D86A)
        c.fill(Path(ellipseIn: CGRect(x: splash.x - 26, y: splash.y - 18, width: 52, height: 36)), with: .color(color.opacity(0.45 * (1 - age))))
        for n in 0..<8 {
            let angle = Double(n) * .pi / 4 + splash.born
            let reach = 14 + age * 70, size = 7 * (1 - age)
            c.fill(Path(ellipseIn: CGRect(x: splash.x + cos(angle) * reach - size / 2, y: splash.y + sin(angle) * reach - size / 2, width: size, height: size)), with: .color(color))
        }
    }

    private func drawTrail(_ c: GraphicsContext) {
        for (a, b) in zip(run.trail, run.trail.dropFirst()) where a.stroke == b.stroke {
            let fresh = max(0, 1 - (run.time - a.time) / ChopRules.trailSeconds)
            var line = Path()
            line.move(to: CGPoint(x: a.x, y: a.y))
            line.addLine(to: CGPoint(x: b.x, y: b.y))
            c.stroke(line, with: .color(ArcadeArt.ink.opacity(0.18 * fresh)), style: StrokeStyle(lineWidth: 11 * fresh + 2, lineCap: .round))
            c.stroke(line, with: .color(.white.opacity(0.95 * fresh)), style: StrokeStyle(lineWidth: 7 * fresh + 1, lineCap: .round))
        }
    }
}
