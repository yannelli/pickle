import SwiftUI

struct TossBoard: View {
    let run: TossRun
    let look: PickleLook
    let reduceMotion: Bool
    let aim: (CGVector) -> Void
    let release: () -> Void

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
                        aim(CGVector(dx: (value.startLocation.x - value.location.x) / world.scale,
                                     dy: (value.startLocation.y - value.location.y) / world.scale))
                    }
                    .onEnded { _ in release() })
        }
        .accessibilityElement()
        .accessibilityLabel("Jar toss board")
        .accessibilityValue("\(run.score) points, \(run.lives) throws left")
        .accessibilityAddTraits(.allowsDirectInteraction)
        .accessibilityIdentifier("arcade.toss.board")
    }

    private func draw(_ c: GraphicsContext) {
        let w = ArcadeWorld.width, h = ArcadeWorld.height, floor = TossRules.floor
        c.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)), with: .color(DillTheme.cream))
        for n in 1..<10 {
            c.fill(Path(CGRect(x: Double(n) * 36, y: 0, width: 1.5, height: floor)), with: .color(DillTheme.line))
            c.fill(Path(CGRect(x: 0, y: Double(n) * 54, width: w, height: 1.5)), with: .color(DillTheme.line))
        }
        drawWind(c)
        c.fill(Path(CGRect(x: 0, y: floor, width: w, height: h - floor)), with: .color(ArcadeArt.wood))
        c.fill(Path(CGRect(x: 0, y: floor, width: w, height: 4)), with: .color(ArcadeArt.ink))
        drawSling(c, front: false)
        let center = run.jar.x(at: run.time)
        drawJarBack(c, center: center)
        if run.state == .landed {
            var pose = PicklePose()
            pose.eyes = .happy; pose.mouth = .grin; pose.armLeft = 70; pose.armRight = -70
            let bob = reduceMotion ? 0 : sin((run.time - run.settledAt) * 6) * 3
            ArcadeArt.pet(c, look: look, pose: pose, at: CGPoint(x: center + run.sink, y: run.jar.top + 24 + bob), height: 46)
        }
        drawJarFront(c, center: center)
        for (n, dot) in run.preview().enumerated() {
            let r = 4.5 - Double(n) * 0.35
            c.fill(Path(ellipseIn: CGRect(x: dot.x - r, y: dot.y - r, width: r * 2, height: r * 2)), with: .color(ArcadeArt.ink.opacity(0.4)))
        }
        if run.state != .landed { drawPickle(c) }
        drawSling(c, front: true)
        if run.state == .landed { drawSplash(c, center: center) }
        ArcadeArt.score(c, run.score)
        ArcadeArt.lives(c, left: run.lives, of: TossRules.lives)
        if run.score == 0, run.lives == TossRules.lives, run.state == .aiming, run.pull == nil {
            ArcadeArt.caption(c, "pull back & let go", at: CGPoint(x: w / 2, y: 150), size: 22)
        }
    }

    private func drawWind(_ c: GraphicsContext) {
        guard run.wind != 0 else { return }
        ArcadeArt.caption(c, "wind \(run.wind > 0 ? "→" : "←") \(Int(abs(run.wind).rounded()))", at: CGPoint(x: ArcadeWorld.width / 2, y: 76), size: 15)
        let flow = reduceMotion ? 0 : run.time * run.wind * 2.2
        for n in 0..<6 {
            let raw = (Double(n) * 67 + flow).truncatingRemainder(dividingBy: 420)
            let x = (raw < 0 ? raw + 420 : raw) - 30, y = 110 + Double(n * 53 % 240)
            var gust = Path()
            gust.move(to: CGPoint(x: x, y: y)); gust.addLine(to: CGPoint(x: x + 26, y: y))
            c.stroke(gust, with: .color(ArcadeArt.ink.opacity(0.22)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
    }

    private func drawSling(_ c: GraphicsContext, front: Bool) {
        let a = TossRules.anchor
        let left = CGPoint(x: a.x - 22, y: a.y + 2), right = CGPoint(x: a.x + 22, y: a.y + 2)
        let holding = run.state == .aiming
        let pocket = holding ? CGPoint(x: run.x, y: run.y + 12) : CGPoint(x: a.x, y: a.y + 14)
        var band = Path()
        band.move(to: front ? right : left)
        band.addLine(to: pocket)
        c.stroke(band, with: .color(Color(hex: 0x8A5A3C)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        guard !front else { return }
        var stick = Path()
        stick.move(to: CGPoint(x: a.x, y: TossRules.floor))
        stick.addLine(to: CGPoint(x: a.x, y: a.y + 46))
        stick.move(to: left); stick.addQuadCurve(to: CGPoint(x: a.x, y: a.y + 48), control: CGPoint(x: a.x - 20, y: a.y + 40))
        stick.move(to: right); stick.addQuadCurve(to: CGPoint(x: a.x, y: a.y + 48), control: CGPoint(x: a.x + 20, y: a.y + 40))
        c.stroke(stick, with: .color(ArcadeArt.ink), style: StrokeStyle(lineWidth: 13, lineCap: .round, lineJoin: .round))
        c.stroke(stick, with: .color(Color(hex: 0xC99B62)), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
    }

    private func jarBody(center: Double) -> CGRect {
        let jar = run.jar
        return CGRect(x: center - jar.mouth / 2 - TossRules.wall, y: jar.top + 6, width: jar.mouth + TossRules.wall * 2, height: TossRules.jarHeight - 6)
    }

    private func drawJarBack(_ c: GraphicsContext, center: Double) {
        let body = jarBody(center: center)
        let shelf = TossRules.floor - body.maxY
        if shelf > 1 {
            let colors = [DillTheme.peach, DillTheme.lime, Color(hex: 0xBFD7EA)]
            let count = max(1, Int((shelf / 34).rounded()))
            for n in 0..<count {
                let height = shelf / Double(count)
                let book = Path(roundedRect: CGRect(x: body.minX - 10 + Double(n % 2) * 6, y: TossRules.floor - height * Double(n + 1), width: body.width + 14, height: height), cornerRadius: 4)
                c.fill(book, with: .color(colors[n % colors.count]))
                c.stroke(book, with: .color(ArcadeArt.ink), lineWidth: 2.5)
            }
        }
        c.fill(Path(roundedRect: body, cornerRadius: 16), with: .color(.white.opacity(0.35)))
        let wave = reduceMotion ? 0 : sin(run.time * 3) * 3
        var brine = Path()
        let surface = body.minY + 30
        brine.move(to: CGPoint(x: body.minX + 3, y: surface + wave))
        brine.addQuadCurve(to: CGPoint(x: body.maxX - 3, y: surface - wave), control: CGPoint(x: body.midX, y: surface - wave * 2))
        brine.addLine(to: CGPoint(x: body.maxX - 3, y: body.maxY - 3))
        brine.addLine(to: CGPoint(x: body.minX + 3, y: body.maxY - 3))
        brine.closeSubpath()
        c.fill(brine, with: .color(ArcadeArt.brine.opacity(0.9)))
        c.fill(Path(ellipseIn: CGRect(x: body.minX + 10, y: body.maxY - 70, width: 16, height: 56)), with: .color(Color(hex: 0x7FA24A)))
        c.fill(Path(ellipseIn: CGRect(x: body.maxX - 28, y: body.maxY - 62, width: 15, height: 50)), with: .color(Color(hex: 0x6E9440)))
    }

    private func drawJarFront(_ c: GraphicsContext, center: Double) {
        let body = jarBody(center: center)
        let glass = Path(roundedRect: body, cornerRadius: 16)
        c.fill(Path(roundedRect: CGRect(x: body.minX + 7, y: body.minY + 40, width: 5, height: body.height - 60), cornerRadius: 2.5), with: .color(.white.opacity(0.55)))
        let label = CGRect(x: body.midX - 26, y: body.maxY - 58, width: 52, height: 28)
        c.fill(Path(roundedRect: label, cornerRadius: 6), with: .color(DillTheme.cream))
        c.stroke(Path(roundedRect: label, cornerRadius: 6), with: .color(ArcadeArt.ink), lineWidth: 2)
        c.draw(Text("dill").font(.system(size: 13, weight: .heavy, design: .serif)).foregroundStyle(ArcadeArt.ink), at: CGPoint(x: label.midX, y: label.midY))
        c.stroke(glass, with: .color(ArcadeArt.ink), lineWidth: 3)
        let rim = Path(roundedRect: CGRect(x: center - run.jar.mouth / 2 - 6, y: run.jar.top - 5, width: run.jar.mouth + 12, height: 11), cornerRadius: 5.5)
        c.fill(rim, with: .color(ArcadeArt.steel))
        c.stroke(rim, with: .color(ArcadeArt.ink), lineWidth: 2.5)
    }

    private func drawPickle(_ c: GraphicsContext) {
        var pose = PicklePose()
        var angle = Angle.radians(run.angle)
        switch run.state {
        case .aiming:
            pose.eyes = run.pull == nil ? .open : .wide
            pose.mouth = run.pull == nil ? .smile : .grin
            angle = .zero
        case .flying:
            pose.eyes = .happy; pose.mouth = .grin; pose.armLeft = 80; pose.armRight = -80
        case .missed:
            pose.eyes = .squint; pose.mouth = .frown; pose.sweat = 1
            angle = .degrees(90)
        case .landed: return
        }
        ArcadeArt.pet(c, look: look, pose: pose, at: CGPoint(x: run.x, y: run.y), height: 48, angle: angle)
    }

    private func drawSplash(_ c: GraphicsContext, center: Double) {
        let age = (run.time - run.settledAt) / 0.6
        guard age < 1 else { return }
        for n in 0..<7 {
            let spread = (Double(n) - 3) * 0.32
            let x = center + sin(spread) * age * 70, y = run.jar.top - sin(age * .pi) * (36 + Double(n % 3) * 12)
            let r = 5 * (1 - age) + 1
            c.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(ArcadeArt.brine))
            c.stroke(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(ArcadeArt.ink.opacity(0.5)), lineWidth: 1)
        }
    }
}
