import SwiftUI

/// Everything that changes how the pickle looks, independent of motion.
struct PickleLook {
    var variety: PickleVariety
    var stage: LifeStage = .adult
    var teen: TeenLook? = nil
    var elder: ElderLook? = nil
    var outfit: Outfit = .original
    var vibe: PetVibe? = nil
    var bites = 0
    var sick = false
    var accessories = true
    var hat: String? { elder?.hat ?? teen?.hat }
    var prop: String? { elder?.prop ?? teen?.prop }
    var accent: Color { (elder?.accent ?? teen?.accent).map { Color(hex: $0) } ?? DillTheme.ink }
    var baby: Bool { ![LifeStage.young, .teen, .adult, .elder].contains(stage) }
}

/// Web body geometry (index.html `.pickle` rules and pet-art.js BODY) in the body's padding-box coordinates.
struct PickleFrame {
    let w: CGFloat, h: CGFloat, face: CGFloat, arm: CGFloat, armWidth: CGFloat
    let radii: [CGSize]
    let eye: CGSize
    let spots: [CGPoint]
    init(look: PickleLook) {
        let spot = { (x: CGFloat, y: CGFloat, offsets: [(CGFloat, CGFloat)]) -> [CGPoint] in
            [CGPoint(x: x, y: y)] + offsets.map { CGPoint(x: x + $0.0, y: y + $0.1) }
        }
        let adultSpots = spot(9, 20, [(28, -7), (32, 30), (2, 43), (20, 52)])
        switch look.stage {
        case .young: (w, h, face, arm, armWidth) = (48, 70, 25, 42, 14); spots = spot(9, 14, [(24, -5), (28, 25), (2, 38), (18, 43)])
        case .teen: (w, h, face, arm, armWidth) = (52, 78, 30, 48, 14); spots = spot(9, 17, [(26, -6), (30, 27), (2, 40), (19, 47)])
        case .adult: (w, h, face, arm, armWidth) = (56, 86, 34, 53, 14); spots = adultSpots
        case .elder: (w, h, face, arm, armWidth) = (60, 82, 34, 53, 14); spots = adultSpots
        default: (w, h, face, arm, armWidth) = (42, 51, 15, 29, 10); spots = spot(9, 8, [(21, 1), (15, 29)])
        }
        eye = look.baby ? CGSize(width: 6, height: 9) : CGSize(width: 5, height: 7)
        let bw = w + 6, bh = h + 6
        func px(_ v: [CGFloat]) -> [CGSize] { v.map { CGSize(width: $0, height: $0) } }
        func pct(_ v: [CGFloat]) -> [CGSize] { v.map { CGSize(width: $0 / 100 * bw, height: $0 / 100 * bh) } }
        var r: [CGSize]
        switch look.stage {
        case .young: r = px([27, 25, 18, 20])
        case .teen: r = px([29, 27, 24, 22])
        case .adult, .elder:
            switch look.variety.shape {
            case .long: r = px([31, 28, 28, 25])
            case .round: r = pct([48, 46, 43, 45])
            case .crooked: r = px([48, 18, 42, 20])
            }
        default: r = pct([45, 45, 40, 40])
        }
        // CSS shrinks every corner when the two radii on one side are longer than that side.
        let top = bw / (r[0].width + r[1].width), bottom = bw / (r[3].width + r[2].width)
        let left = bh / (r[0].height + r[3].height), right = bh / (r[1].height + r[2].height)
        let f = min(1, top, bottom, left, right)
        radii = r.map { CGSize(width: $0.width * f, height: $0.height * f) }
    }
}

final class ArtPathCache {
    static let shared = ArtPathCache()
    private var paths: [String: Path] = [:]
    func path(_ data: String) -> Path {
        if let cached = paths[data] { return cached }
        var path = Path()
        for segment in SVGPathParser.parse(data) ?? [] {
            switch segment {
            case .move(let x, let y): path.move(to: CGPoint(x: x, y: y))
            case .line(let x, let y): path.addLine(to: CGPoint(x: x, y: y))
            case .quad(let cx, let cy, let x, let y): path.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: cx, y: cy))
            case .cubic(let ax, let ay, let bx, let by, let x, let y):
                path.addCurve(to: CGPoint(x: x, y: y), control1: CGPoint(x: ax, y: ay), control2: CGPoint(x: bx, y: by))
            case .close: path.closeSubpath()
            }
        }
        paths[data] = path
        return path
    }
}

/// Draws the web pickle into a context whose origin is the ground under the pickle, one unit per CSS pixel.
enum PickleArtist {
    static let ink = DillTheme.ink
    static let light = Color(hex: 0xF2F7DA)
    static let line = StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)

    static func draw(_ base: GraphicsContext, look: PickleLook, pose: PicklePose, time: Double) {
        let f = PickleFrame(look: look)
        let shadowWidth = 64 * f.w / 56 * CGFloat(pose.shadowScale)
        base.fill(Path(ellipseIn: CGRect(x: CGFloat(pose.shadowX) - shadowWidth / 2, y: -4.5, width: shadowWidth, height: 9)), with: .color(ink.opacity(0.17 * pose.shadowOpacity)))
        var size = base
        if look.variety.shape == .round { size.scaleBy(x: 1.18, y: 0.87) }
        if look.accessories, let vibe = look.vibe {
            var scene = size
            scene.translateBy(x: -f.w / 2, y: -97)
            drawParts(PetArt.scene(vibe.rawValue), in: scene, accent: ink, time: time)
        }
        var body = size
        apply(pose.actor, to: &body)
        apply(pose.body, to: &body)
        body.translateBy(x: -f.w / 2, y: -(f.h + 6))
        drawPickle(body, f: f, look: look, pose: pose, time: time)
    }

    static func apply(_ m: Motion, to c: inout GraphicsContext) {
        let sx = abs(m.sx) < 0.02 ? (m.sx < 0 ? -0.02 : 0.02) : m.sx
        c.translateBy(x: m.x, y: m.y)
        c.rotate(by: .degrees(m.rotation))
        c.scaleBy(x: sx, y: m.sy)
    }

    static func drawPickle(_ c: GraphicsContext, f: PickleFrame, look: PickleLook, pose: PicklePose, time: Double) {
        let skin = look.sick ? Color(hex: 0x8BA46A) : Color(hex: look.variety.color)
        let sprout = look.accessories && look.outfit == .sprout
        var clipped = c
        if look.bites > 0 { clipped.clip(to: biteClip(f, bites: look.bites)) }
        let outline = bodyPath(CGRect(x: -1.5, y: -1.5, width: f.w + 3, height: f.h + 3), f.radii)
        clipped.fill(outline, with: .color(skin))
        clipped.stroke(outline, with: .color(ink), style: line)
        var sheen = Path()
        sheen.move(to: CGPoint(x: 8, y: f.h * 0.34)); sheen.addQuadCurve(to: CGPoint(x: f.w * 0.3, y: 6), control: CGPoint(x: 7, y: 9))
        clipped.stroke(sheen, with: .color(Color(hex: look.variety.light).opacity(0.7)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        if !sprout { drawStem(clipped, look: look) }
        let spot = Color(hex: look.variety.dark)
        for s in f.spots { clipped.fill(Path(roundedRect: CGRect(x: s.x, y: s.y, width: 6, height: 5), cornerRadius: 2), with: .color(spot)) }
        if look.bites > 0 { c.stroke(biteEdge(f, bites: look.bites), with: .color(ink), style: line) }
        var face = clipped
        face.translateBy(x: (f.w - 32) / 2 + CGFloat(pose.faceX), y: f.face)
        drawFace(face, f: f, look: look, pose: pose)
        drawArms(c, f: f, pose: pose)
        c.fill(Path(CGRect(x: 6, y: f.h + 1, width: 14, height: 5)), with: .color(ink))
        c.fill(Path(CGRect(x: f.w - 20, y: f.h + 1, width: 14, height: 5)), with: .color(ink))
        if let sweat = pose.sweat { drawSweat(c, x: f.w + 5, y: 16, progress: sweat) }
        if look.accessories { drawAccessories(c, f: f, look: look, sprout: sprout, time: time) }
    }

    static func bodyPath(_ rect: CGRect, _ radii: [CGSize]) -> Path {
        let r = radii.map { CGSize(width: max(0, $0.width - 1.5), height: max(0, $0.height - 1.5)) }
        let k: CGFloat = 0.4477
        let x0 = rect.minX, y0 = rect.minY, x1 = rect.maxX, y1 = rect.maxY
        var p = Path()
        p.move(to: CGPoint(x: x0 + r[0].width, y: y0))
        p.addLine(to: CGPoint(x: x1 - r[1].width, y: y0))
        p.addCurve(to: CGPoint(x: x1, y: y0 + r[1].height), control1: CGPoint(x: x1 - r[1].width * k, y: y0), control2: CGPoint(x: x1, y: y0 + r[1].height * k))
        p.addLine(to: CGPoint(x: x1, y: y1 - r[2].height))
        p.addCurve(to: CGPoint(x: x1 - r[2].width, y: y1), control1: CGPoint(x: x1, y: y1 - r[2].height * k), control2: CGPoint(x: x1 - r[2].width * k, y: y1))
        p.addLine(to: CGPoint(x: x0 + r[3].width, y: y1))
        p.addCurve(to: CGPoint(x: x0, y: y1 - r[3].height), control1: CGPoint(x: x0 + r[3].width * k, y: y1), control2: CGPoint(x: x0, y: y1 - r[3].height * k))
        p.addLine(to: CGPoint(x: x0, y: y0 + r[0].height))
        p.addCurve(to: CGPoint(x: x0 + r[0].width, y: y0), control1: CGPoint(x: x0, y: y0 + r[0].height * k), control2: CGPoint(x: x0 + r[0].width * k, y: y0))
        p.closeSubpath()
        return p
    }

    /// The `.pickle::before` stem, or the young pickle's leaf.
    static func drawStem(_ c: GraphicsContext, look: PickleLook) {
        var stem = c
        if look.stage == .young {
            stem.translateBy(x: 25.5, y: -3); stem.rotate(by: .degrees(20))
            let leaf = bodyPath(CGRect(x: -9.5, y: -6, width: 19, height: 12), [.zero, CGSize(width: 12, height: 12), .zero, CGSize(width: 12, height: 12)])
            stem.fill(leaf, with: .color(Color(hex: look.variety.light)))
            stem.stroke(leaf, with: .color(ink), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        } else {
            stem.translateBy(x: 25.5, y: -4.5); stem.rotate(by: .degrees(20))
            var p = Path()
            p.move(to: CGPoint(x: -4, y: 4.5)); p.addLine(to: CGPoint(x: -4, y: -3)); p.addLine(to: CGPoint(x: 5.5, y: -3))
            stem.stroke(p, with: .color(ink), style: line)
        }
    }

    static func bitePoints(bites: Int) -> [(CGFloat, CGFloat)] {
        var points: [(CGFloat, CGFloat)] = [(-0.6, -1), (1.6, -1), (1.6, 0.16), (1, 0.16), (0.9, 0.17), (0.84, 0.22), (0.79, 0.27), (0.8, 0.33),
                                            (0.85, 0.38), (0.92, 0.41), (1, 0.44), (1.6, 0.44), (1.6, 1.3), (-0.6, 1.3)]
        if bites > 1 { points += [(-0.6, 0.97), (0, 0.97), (0.11, 0.95), (0.18, 0.9), (0.21, 0.85), (0.18, 0.8), (0.11, 0.76), (0, 0.75), (-0.6, 0.75)] }
        return points
    }

    /// The web `data-bites` clip-path polygons, in border-box fractions.
    static func biteClip(_ f: PickleFrame, bites: Int) -> Path {
        var p = Path()
        p.addLines(bitePoints(bites: bites).map { CGPoint(x: -3 + $0.0 * (f.w + 6), y: -3 + $0.1 * (f.h + 6)) })
        p.closeSubpath()
        return p
    }

    static func biteEdge(_ f: PickleFrame, bites: Int) -> Path {
        let points = bitePoints(bites: bites).map { CGPoint(x: -3 + $0.0 * (f.w + 6), y: -3 + $0.1 * (f.h + 6)) }
        var p = Path()
        p.addLines(Array(points[3...10]))
        if bites > 1 { p.addLines(Array(points[15...21])) }
        return p
    }

    static func drawFace(_ c: GraphicsContext, f: PickleFrame, look: PickleLook, pose: PicklePose) {
        let ew = f.eye.width, eh = f.eye.height
        let cheekWidth = 7 * CGFloat(pose.cheek), cheekHeight = 3 * CGFloat(pose.cheek), blink = CGFloat(pose.blink)
        for x in [CGFloat(-0.5), 32.5] {
            let rect = CGRect(x: x - cheekWidth / 2, y: 10.5 - cheekHeight / 2, width: cheekWidth, height: cheekHeight)
            c.fill(Path(roundedRect: rect, cornerRadius: cheekHeight / 2), with: .color(Color(hex: 0xDCAD86)))
        }
        func eye(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
            let height = h * blink
            c.fill(Path(ellipseIn: CGRect(x: x, y: y + 0.6 * (h - height), width: w, height: height)), with: .color(ink))
        }
        let right = 31 - ew
        switch pose.eyes {
        case .open: eye(1, 0, ew, eh); eye(right, 0, ew, eh)
        case .squint: eye(1, 2, ew, 4); eye(right, 2, ew, 4)
        case .wide: eye(1, -2, 7, 9); eye(24, -2, 7, 9)
        case .reading:
            for x in [CGFloat(1), right] { c.fill(Path(CGRect(x: x, y: 3 + 5 * (1 - blink), width: ew, height: 5 * blink)), with: .color(ink)) }
        case .happy, .closed:
            var p = Path()
            for x in [CGFloat(1), right] {
                if pose.eyes == .happy {
                    p.move(to: CGPoint(x: x - 0.5, y: 4.5)); p.addQuadCurve(to: CGPoint(x: x + ew + 0.5, y: 4.5), control: CGPoint(x: x + ew / 2, y: -2))
                } else {
                    p.move(to: CGPoint(x: x - 0.5, y: 5.5)); p.addLine(to: CGPoint(x: x + ew + 0.5, y: 5.5))
                }
            }
            c.stroke(p, with: .color(ink), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        case .sickX:
            eye(1, 0, ew, eh)
            var p = Path()
            p.move(to: CGPoint(x: 24.3, y: 0.3)); p.addLine(to: CGPoint(x: 30.7, y: 6.7))
            p.move(to: CGPoint(x: 30.7, y: 0.3)); p.addLine(to: CGPoint(x: 24.3, y: 6.7))
            c.stroke(p, with: .color(ink), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        if look.baby && pose.mouth != .chew {
            let pacifier = Path(ellipseIn: CGRect(x: 9, y: 14, width: 14, height: 8))
            c.fill(pacifier, with: .color(Color(hex: look.variety.light)))
            c.stroke(pacifier, with: .color(ink), lineWidth: 2)
            c.fill(Path(ellipseIn: CGRect(x: 14.3, y: 16.3, width: 3.4, height: 3.4)), with: .color(ink))
            return
        }
        drawMouth(c, pose: pose)
    }

    static func drawMouth(_ c: GraphicsContext, pose: PicklePose) {
        let soft = StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
        switch pose.mouth {
        case .smile:
            var p = Path(); p.move(to: CGPoint(x: 11, y: 10)); p.addCurve(to: CGPoint(x: 21, y: 10), control1: CGPoint(x: 11, y: 16.5), control2: CGPoint(x: 21, y: 16.5))
            c.stroke(p, with: .color(ink), style: soft)
        case .grin:
            var p = Path(); p.move(to: CGPoint(x: 10, y: 9.5)); p.addCurve(to: CGPoint(x: 22, y: 9.5), control1: CGPoint(x: 10, y: 19), control2: CGPoint(x: 22, y: 19)); p.closeSubpath()
            c.fill(p, with: .color(ink))
            c.fill(Path(ellipseIn: CGRect(x: 13, y: 13, width: 6, height: 3.5)), with: .color(Color(hex: 0xE59C8F)))
            c.stroke(p, with: .color(ink), style: soft)
        case .frown:
            var p = Path(); p.move(to: CGPoint(x: 11, y: 15)); p.addCurve(to: CGPoint(x: 21, y: 15), control1: CGPoint(x: 11, y: 9.5), control2: CGPoint(x: 21, y: 9.5))
            c.stroke(p, with: .color(ink), style: soft)
        case .sleepO: c.stroke(Path(ellipseIn: CGRect(x: 14, y: 10, width: 5, height: 5)), with: .color(ink), lineWidth: 2)
        case .scaredO: c.fill(Path(ellipseIn: CGRect(x: 12, y: 9, width: 8, height: 9)), with: .color(ink))
        case .yawnO: c.fill(Path(ellipseIn: CGRect(x: 12.5, y: 9, width: 7, height: 8)), with: .color(ink))
        case .chew:
            let height = 2 + 7 * pose.mouthOpen
            c.fill(Path(ellipseIn: CGRect(x: 10.5, y: 10, width: 11, height: height)), with: .color(ink))
            if pose.mouthOpen > 0.5 { c.fill(Path(ellipseIn: CGRect(x: 13, y: 10 + height - 3.5, width: 6, height: 2.5)), with: .color(Color(hex: 0xE59C8F))) }
        }
    }

    static func drawArms(_ c: GraphicsContext, f: PickleFrame, pose: PicklePose) {
        let aw = f.armWidth, x0 = -aw + 1.5, r = min(10.5, aw - 1.5)
        var p = Path()
        p.move(to: CGPoint(x: x0, y: -15)); p.addLine(to: CGPoint(x: x0, y: -1.5 - r))
        p.addQuadCurve(to: CGPoint(x: x0 + r, y: -1.5), control: CGPoint(x: x0, y: -1.5)); p.addLine(to: CGPoint(x: 0, y: -1.5))
        var left = c
        left.translateBy(x: -13 + aw, y: f.arm + 15); left.rotate(by: .degrees(pose.armLeft))
        left.stroke(p, with: .color(ink), style: line)
        var right = c
        right.translateBy(x: f.w + 13 - aw, y: f.arm + 15); right.rotate(by: .degrees(pose.armRight)); right.scaleBy(x: -1, y: 1)
        right.stroke(p, with: .color(ink), style: line)
    }

    static func drawSweat(_ c: GraphicsContext, x: CGFloat, y: CGFloat, progress: Double) {
        let t = CGFloat(progress), rising = t < 0.2
        let opacity = rising ? t / 0.2 : 1 - (t - 0.2) / 0.8
        let dy = rising ? 2 * t / 0.2 : 2 + 22 * (t - 0.2) / 0.8
        let s = rising ? 0.6 + 0.4 * t / 0.2 : 1 - 0.1 * (t - 0.2) / 0.8
        let cy = y + dy
        var p = Path()
        p.move(to: CGPoint(x: x, y: cy - 5 * s))
        p.addQuadCurve(to: CGPoint(x: x + 3.5 * s, y: cy + 1.5 * s), control: CGPoint(x: x + 3.5 * s, y: cy - 1.5 * s))
        p.addQuadCurve(to: CGPoint(x: x - 3.5 * s, y: cy + 1.5 * s), control: CGPoint(x: x, y: cy + 5.5 * s))
        p.addQuadCurve(to: CGPoint(x: x, y: cy - 5 * s), control: CGPoint(x: x - 3.5 * s, y: cy - 1.5 * s))
        var drop = c
        drop.opacity = max(0, min(1, opacity))
        drop.fill(p, with: .color(Color(hex: 0xDFE9B6)))
        drop.stroke(p, with: .color(ink), lineWidth: 2)
    }

    /// Mirrors pet-art.js render(): look hat, elder readers, vibe items, then the prop. Native outfits yield to a look's hat or glasses.
    static func drawAccessories(_ c: GraphicsContext, f: PickleFrame, look: PickleLook, sprout: Bool, time: Double) {
        let scale = f.w / 56, accent = look.accent
        var hat = c; hat.translateBy(x: f.w / 2, y: 0); hat.scaleBy(x: scale, y: scale)
        var face = c; face.translateBy(x: f.w / 2, y: f.face)
        var held = face; held.scaleBy(x: scale, y: scale)
        var hand = c; hand.translateBy(x: -13, y: f.arm + 15)
        let vibe = look.vibe?.rawValue ?? ""
        let vibeFace = PetArt.worn(vibe + ".face")
        let lookHat = look.hat.map { PetArt.hatIDs.contains($0) } ?? false
        let outfitHat = look.outfit != .original && look.outfit != .shades
        if sprout { drawSprout(hat, look: look) }
        if outfitHat { drawOutfit(hat, outfit: look.outfit) }
        else if lookHat, let id = look.hat { drawParts(PetArt.hat(id), in: hat, accent: accent) }
        if look.outfit == .shades { drawParts(PetArt.face("sunglasses"), in: face, accent: ink) }
        else if let id = look.hat, !lookHat { drawParts(PetArt.face(id), in: face, accent: accent) }
        if look.elder != nil && lookHat && vibeFace.isEmpty && look.outfit != .shades { drawParts(PetArt.face("readers"), in: face, accent: accent) }
        drawParts(vibeFace, in: face, accent: accent)
        drawParts(PetArt.worn(vibe + ".held"), in: held, accent: accent)
        drawParts(PetArt.worn(vibe + ".hand"), in: hand, accent: accent)
        if let prop = look.prop {
            var stand = c; stand.translateBy(x: f.w + 16, y: f.h + 6)
            drawParts(PetArt.prop(prop), in: stand, accent: accent, time: time)
        }
    }

    static func drawSprout(_ c: GraphicsContext, look: PickleLook) {
        let thin = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        var stem = Path(); stem.move(to: CGPoint(x: -3, y: 3)); stem.addQuadCurve(to: CGPoint(x: -2, y: -11), control: CGPoint(x: -6, y: -4))
        c.stroke(stem, with: .color(ink), style: line)
        var left = Path(); left.move(to: CGPoint(x: -2.5, y: -6)); left.addQuadCurve(to: CGPoint(x: -17, y: -18), control: CGPoint(x: -16, y: -4)); left.addQuadCurve(to: CGPoint(x: -2.5, y: -6), control: CGPoint(x: -3, y: -20))
        c.fill(left, with: .color(DillTheme.lime)); c.stroke(left, with: .color(ink), style: thin)
        var right = Path(); right.move(to: CGPoint(x: -2.5, y: -8)); right.addQuadCurve(to: CGPoint(x: 14, y: -21), control: CGPoint(x: -1, y: -22)); right.addQuadCurve(to: CGPoint(x: -2.5, y: -8), control: CGPoint(x: 15, y: -8))
        c.fill(right, with: .color(Color(hex: look.variety.light))); c.stroke(right, with: .color(ink), style: thin)
    }

    static func drawOutfit(_ c: GraphicsContext, outfit: Outfit) {
        let thin = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        switch outfit {
        case .original, .sprout, .shades: break
        case .bow:
            var p = Path()
            p.move(to: CGPoint(x: 10, y: 6)); p.addLine(to: CGPoint(x: -3, y: -6)); p.addQuadCurve(to: CGPoint(x: -3, y: 15), control: CGPoint(x: -14, y: 4)); p.closeSubpath()
            p.move(to: CGPoint(x: 10, y: 6)); p.addLine(to: CGPoint(x: 23, y: -5)); p.addQuadCurve(to: CGPoint(x: 24, y: 16), control: CGPoint(x: 35, y: 5)); p.closeSubpath()
            c.fill(p, with: .color(DillTheme.peach)); c.stroke(p, with: .color(ink), style: thin)
            c.fill(Path(ellipseIn: CGRect(x: 5.5, y: 1.5, width: 9, height: 9)), with: .color(ink))
        case .crown: drawParts(PetArt.hat("crown"), in: c, accent: Color(hex: 0xEFCA63))
        case .party:
            var p = Path(); p.move(to: CGPoint(x: -19, y: 4)); p.addLine(to: CGPoint(x: 0, y: -30)); p.addLine(to: CGPoint(x: 19, y: 4)); p.closeSubpath()
            c.fill(p, with: .color(DillTheme.peach)); c.stroke(p, with: .color(ink), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            c.fill(Path(ellipseIn: CGRect(x: -5, y: -17, width: 6, height: 6)), with: .color(DillTheme.cream))
            c.fill(Path(ellipseIn: CGRect(x: 2, y: -6, width: 6, height: 6)), with: .color(DillTheme.cream))
            let pom = Path(ellipseIn: CGRect(x: -4.5, y: -35.5, width: 9, height: 9))
            c.fill(pom, with: .color(DillTheme.lime)); c.stroke(pom, with: .color(ink), style: thin)
        case .beanie, .beret, .headphones, .sunhat, .chef, .cowboy,
             .pirate, .mushroom, .wizard, .rainhat, .halo, .helmet:
            WardrobeArt.draw(c, outfit: outfit)
        }
    }

    static func paint(_ paint: ArtPaint, accent: Color) -> Color? {
        switch paint {
        case .none: return nil
        case .ink: return ink
        case .accent: return accent
        case .light: return light
        case .hex(let value): return Color(hex: value)
        }
    }

    static func path(_ part: ArtPart) -> Path {
        switch part.shape {
        case .path(let data): return ArtPathCache.shared.path(data)
        case .circle(let x, let y, let r): return Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
        case .ellipse(let x, let y, let rx, let ry):
            let oval = Path(ellipseIn: CGRect(x: x - rx, y: y - ry, width: 2 * rx, height: 2 * ry))
            guard part.rotation != 0 else { return oval }
            let angle = CGFloat(part.rotation * Double.pi / 180)
            return oval.applying(CGAffineTransform(translationX: x, y: y).rotated(by: angle).translatedBy(x: -x, y: -y))
        case .rect(let x, let y, let w, let h, let r): return Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
        }
    }

    static func drawParts(_ parts: [ArtPart], in c: GraphicsContext, accent: Color, time: Double = 0) {
        for part in parts {
            var ctx = c
            if part.flicker {
                // `.flame` flickers about (-25, 90): scale(.9, 1.1) skewX(-5deg), alternating every 0.45 s.
                let p = PetMotion.swing.at(PetMotion.loop(time, 0.9))
                let sx = CGFloat(1 - 0.1 * p), sy = CGFloat(1 + 0.1 * p), skew = CGFloat(tan(-5 * p * Double.pi / 180))
                ctx.translateBy(x: -25, y: 90)
                ctx.concatenate(CGAffineTransform(a: sx, b: 0, c: sx * skew, d: sy, tx: 0, ty: 0))
                ctx.translateBy(x: 25, y: -90)
            }
            let shape = path(part)
            if let fill = paint(part.fill, accent: accent) { ctx.fill(shape, with: .color(fill.opacity(part.fillOpacity))) }
            if let stroke = paint(part.stroke, accent: accent) {
                let dash: [CGFloat] = part.dash > 0 ? [CGFloat(part.dash), CGFloat(part.dash)] : []
                ctx.stroke(shape, with: .color(stroke), style: StrokeStyle(lineWidth: part.width, lineCap: .round, lineJoin: .round, dash: dash))
            }
        }
    }
}

/// A still pickle for cards and sheets. The Nest animates the same art through `CareScene`.
struct PickleCharacter: View {
    var brine: Brine = .classic
    var outfit: Outfit = .sprout
    var happy = false
    var sleeping = false
    var chewing: Double? = nil
    var blinking = false
    var variety: PickleVariety? = nil
    var stage: LifeStage = .adult
    var teen: TeenLook? = nil
    var elder: ElderLook? = nil
    var body: some View {
        Canvas { context, size in
            let look = PickleLook(variety: variety ?? PickleVariety.first(brine: brine.rawValue), stage: stage, teen: teen, elder: elder, outfit: outfit)
            let unit = min(size.width, size.height) / 140
            var ground = context
            ground.translateBy(x: size.width / 2, y: size.height / 2 + 58 * unit)
            ground.scaleBy(x: unit, y: unit)
            PickleArtist.draw(ground, look: look, pose: pose, time: 0)
        }.aspectRatio(1, contentMode: .fit).accessibilityHidden(true)
    }
    private var pose: PicklePose {
        var pose = PicklePose()
        if happy { pose.eyes = .happy; pose.mouth = .grin; pose.armLeft = 60; pose.armRight = -24; pose.cheek = 1.3 }
        if sleeping { pose.eyes = .closed; pose.mouth = .sleepO; pose.armLeft = -42; pose.armRight = 42 }
        if blinking && pose.eyes == .open { pose.blink = 0.12 }
        if let chewing { pose.mouth = .chew; pose.mouthOpen = chewing }
        return pose
    }
}

extension PickleCharacter {
    /// Draws the pet's own variety and stage. `wearLook: false` drops teen and elder hats so an outfit stays visible.
    init(pet: PetState, outfit: Outfit? = nil, happy: Bool = false, wearLook: Bool = true, at now: Date = Date()) {
        self.init(brine: pet.brine, outfit: outfit ?? pet.outfit, happy: happy, variety: pet.variety, stage: pet.stage(at: now),
                  teen: wearLook ? pet.teen(at: now) : nil, elder: wearLook ? pet.elder(at: now) : nil)
    }
}
