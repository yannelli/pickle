import SwiftUI

/// The 360 × 580 play field shared by the action games, aspect-fit into a board.
struct ArcadeWorld {
    static let width = 360.0, height = 580.0
    static let aspect = width / height
    let scale: CGFloat
    let origin: CGPoint

    init(_ canvas: CGSize) {
        scale = min(canvas.width / Self.width, canvas.height / Self.height)
        origin = CGPoint(x: (canvas.width - Self.width * scale) / 2, y: (canvas.height - Self.height * scale) / 2)
    }

    func context(_ base: GraphicsContext) -> GraphicsContext {
        var world = base
        world.translateBy(x: origin.x, y: origin.y)
        world.scaleBy(x: scale, y: scale)
        world.clip(to: Path(CGRect(x: 0, y: 0, width: Self.width, height: Self.height)))
        return world
    }

    func point(_ screen: CGPoint) -> CGPoint {
        CGPoint(x: (screen.x - origin.x) / scale, y: (screen.y - origin.y) / scale)
    }
}

enum ArcadeArt {
    static let ink = DillTheme.ink
    static let heart = Color(hex: 0xC8553D)
    static let steel = Color(hex: 0xCDD3CF)
    static let wood = Color(hex: 0xE2C391)
    static let grain = Color(hex: 0xCFAA72)
    static let brine = Color(hex: 0xC9DF8E)

    static func look(_ pet: PetState, now: Date = Date()) -> PickleLook {
        let life = pet.life, ms = PetLife.ms(now)
        var look = PickleLook(variety: PickleVariety.of(life.variety))
        look.stage = PetLife.stage(life, now: ms)
        look.teen = PetLife.teen(life, now: ms)
        look.elder = PetLife.elder(life, now: ms)
        look.outfit = pet.outfit
        return look
    }

    /// Draws the pet centered on `center`, `height` tall, turned by `angle`.
    static func pet(_ c: GraphicsContext, look: PickleLook, pose: PicklePose, at center: CGPoint, height: CGFloat, angle: Angle = .zero) {
        let tall = PickleFrame(look: look).h + 6
        var g = c
        g.translateBy(x: center.x, y: center.y)
        g.rotate(by: angle)
        g.scaleBy(x: height / tall, y: height / tall)
        g.translateBy(x: 0, y: tall / 2)
        var floating = pose
        floating.shadowOpacity = 0
        PickleArtist.draw(g, look: look, pose: floating, time: 0)
    }

    static func heartPath(_ center: CGPoint, size: CGFloat) -> Path {
        let s = size / 20
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: center.x + (x - 12) * s, y: center.y + (y - 12) * s) }
        var path = Path()
        path.move(to: p(12, 21.35))
        path.addLine(to: p(10.55, 20.03))
        path.addCurve(to: p(2, 8.5), control1: p(5.4, 15.36), control2: p(2, 12.28))
        path.addCurve(to: p(7.5, 3), control1: p(2, 5.42), control2: p(4.42, 3))
        path.addCurve(to: p(12, 5.09), control1: p(9.24, 3), control2: p(10.91, 3.81))
        path.addCurve(to: p(16.5, 3), control1: p(13.09, 3.81), control2: p(14.76, 3))
        path.addCurve(to: p(22, 8.5), control1: p(19.58, 3), control2: p(22, 5.42))
        path.addCurve(to: p(13.45, 20.04), control1: p(22, 12.28), control2: p(18.6, 15.36))
        path.closeSubpath()
        return path
    }

    static func heart(_ c: GraphicsContext, at center: CGPoint, size: CGFloat, filled: Bool = true) {
        let path = heartPath(center, size: size)
        if filled { c.fill(path, with: .color(heart)) }
        c.stroke(path, with: .color(ink), lineWidth: 2)
    }

    static func lives(_ c: GraphicsContext, left: Int, of total: Int) {
        for n in 0..<total {
            heart(c, at: CGPoint(x: ArcadeWorld.width - 26 - Double(total - 1 - n) * 30, y: 30), size: 24, filled: n < left)
        }
    }

    static func score(_ c: GraphicsContext, _ value: Int, at point: CGPoint = CGPoint(x: 26, y: 30), anchor: UnitPoint = .leading) {
        c.draw(Text("\(value)").font(.system(size: 40, weight: .black, design: .rounded)).foregroundStyle(ink), at: point, anchor: anchor)
    }

    static func caption(_ c: GraphicsContext, _ text: String, at point: CGPoint, size: CGFloat = 18) {
        c.draw(Text(text).font(.system(size: size, weight: .heavy, design: .rounded)).foregroundStyle(ink), at: point)
    }
}

/// Fires once when a finger lands, instead of waiting for it to lift.
struct TouchDown: ViewModifier {
    let action: () -> Void
    @GestureState private var held = false
    func body(content: Content) -> some View {
        content
            .gesture(DragGesture(minimumDistance: 0).updating($held) { _, held, _ in held = true })
            .onChange(of: held) { _, down in if down { action() } }
    }
}
