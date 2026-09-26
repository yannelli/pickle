import SwiftUI

struct HopScene: Equatable {
    enum Kind: CaseIterable, Equatable { case pantry, sink, stove, prep, fridge }
    let kind: Kind
    let variant: Int
}

enum HopScenery {
    static func scene(seed: UInt64, index: Int) -> HopScene {
        let group = index / HopScene.Kind.allCases.count
        var arrangement = order(seed: seed, group: group)
        if group > 0, arrangement[0] == order(seed: seed, group: group - 1)[arrangement.count - 1] {
            arrangement.swapAt(0, 1)
        }
        var rng = ArcadeRNG(seed: seed ^ (UInt64(index) &* 0xD134_2543_DE82_EF95))
        return HopScene(kind: arrangement[index % arrangement.count], variant: Int(rng.next() % 4))
    }

    private static func order(seed: UInt64, group: Int) -> [HopScene.Kind] {
        var rng = ArcadeRNG(seed: seed ^ (UInt64(group) &* 0x9E37_79B9_7F4A_7C15))
        var kinds = HopScene.Kind.allCases
        for index in stride(from: kinds.count - 1, through: 1, by: -1) {
            kinds.swapAt(index, Int(rng.next() % UInt64(index + 1)))
        }
        if group == 0, let pantry = kinds.firstIndex(of: .pantry) {
            kinds.swapAt(0, pantry)
        }
        return kinds
    }

    static func draw(_ context: GraphicsContext, height: Double, distance: Double, seed: UInt64, reduceMotion: Bool) {
        let travel = distance * 360 / HopRules.zoneLength
        let panel = Int(floor(travel / 360))
        let offset = reduceMotion ? 0 : travel.truncatingRemainder(dividingBy: 360)
        let panels = reduceMotion ? [panel] : [panel, panel + 1]
        for index in panels {
            var c = context
            c.translateBy(x: reduceMotion ? 0 : Double(index - panel) * 360 - offset, y: 0)
            let scene = scene(seed: seed, index: index)
            switch scene.kind {
            case .pantry: pantry(c, height: height, variant: scene.variant)
            case .sink: sink(c, height: height, variant: scene.variant)
            case .stove: stove(c, height: height, variant: scene.variant)
            case .prep: prep(c, height: height, variant: scene.variant)
            case .fridge: fridge(c, height: height, variant: scene.variant)
            }
        }
    }

    private static func wall(_ c: GraphicsContext, height: Double, color: Color, grout: Color) {
        c.fill(Path(CGRect(x: 0, y: 0, width: 361, height: height)), with: .color(color))
        for row in 0..<max(1, Int(ceil(height / 64))) {
            let y = Double(row) * 64 + 62
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: 360, y: y))
            c.stroke(line, with: .color(grout), lineWidth: 2)
            for column in 0..<5 {
                let x = Double(column) * 96 + (row.isMultiple(of: 2) ? 0 : 48)
                var seam = Path()
                seam.move(to: CGPoint(x: x, y: y))
                seam.addLine(to: CGPoint(x: x, y: y + 64))
                c.stroke(seam, with: .color(grout), lineWidth: 2)
            }
        }
    }

    private static func header(_ c: GraphicsContext, color: Color) {
        c.fill(Path(CGRect(x: 0, y: 0, width: 360, height: 62)), with: .color(color))
        c.fill(Path(CGRect(x: 0, y: 59, width: 360, height: 5)), with: .color(ArcadeArt.ink))
    }

    private static func pantry(_ c: GraphicsContext, height: Double, variant: Int) {
        wall(c, height: height, color: Color(hex: 0xF6F0DD), grout: Color(hex: 0xDCD6C5))
        header(c, color: Color(hex: 0xD2DFC4))
        let shift = Double(variant) * 9 - 14
        c.fill(Path(roundedRect: CGRect(x: 135 + shift, y: 174, width: 210, height: 13), cornerRadius: 3), with: .color(ArcadeArt.wood))
        c.stroke(Path(CGRect(x: 135 + shift, y: 174, width: 210, height: 13)), with: .color(ArcadeArt.ink), lineWidth: 2)
        for (x, width, color) in [(162.0, 40.0, Color(hex: 0xD8E4B9)), (223, 34, Color(hex: 0xE8B98B)), (276, 43, Color(hex: 0xB5C59F))] {
            let jar = Path(roundedRect: CGRect(x: x + shift, y: 100, width: width, height: 73), cornerRadius: 7)
            c.fill(jar, with: .color(color))
            c.stroke(jar, with: .color(ArcadeArt.ink), lineWidth: 2)
            c.fill(Path(roundedRect: CGRect(x: x + shift - 2, y: 94, width: width + 4, height: 11), cornerRadius: 3), with: .color(ArcadeArt.ink))
            c.fill(Path(roundedRect: CGRect(x: x + shift + 7, y: 124, width: width - 14, height: 20), cornerRadius: 3), with: .color(.white.opacity(0.65)))
        }
        if variant.isMultiple(of: 2) {
            c.fill(Path(ellipseIn: CGRect(x: 37, y: 202, width: 71, height: 23)), with: .color(Color(hex: 0xC59A69)))
            for x in [43.0, 63.0, 83.0] {
                c.fill(Path(ellipseIn: CGRect(x: x, y: 188, width: 17, height: 28)), with: .color(Color(hex: 0xA8C874)))
            }
        }
    }

    private static func sink(_ c: GraphicsContext, height: Double, variant: Int) {
        wall(c, height: height, color: Color(hex: 0xDCEDE8), grout: Color(hex: 0xAED1C9))
        header(c, color: Color(hex: 0x9CC9C4))
        let window = Path(roundedRect: CGRect(x: 102, y: 87, width: 162, height: 163), cornerRadius: 8)
        c.fill(window, with: .color(Color(hex: variant.isMultiple(of: 2) ? 0xA8DCE5 : 0x829DB9)))
        c.stroke(window, with: .color(ArcadeArt.ink), lineWidth: 6)
        c.fill(Path(ellipseIn: CGRect(x: 128, y: 107, width: 39, height: 39)), with: .color(Color(hex: 0xFFF5C5)))
        var horizon = Path()
        horizon.move(to: CGPoint(x: 106, y: 207))
        horizon.addQuadCurve(to: CGPoint(x: 260, y: 207), control: CGPoint(x: 184, y: 153))
        horizon.addLine(to: CGPoint(x: 260, y: 246))
        horizon.addLine(to: CGPoint(x: 106, y: 246))
        horizon.closeSubpath()
        c.fill(horizon, with: .color(Color(hex: 0x8EB899)))
        c.stroke(Path(CGRect(x: 181, y: 89, width: 3, height: 160)), with: .color(ArcadeArt.ink), lineWidth: 4)
        c.stroke(Path(CGRect(x: 104, y: 164, width: 158, height: 3)), with: .color(ArcadeArt.ink), lineWidth: 4)
        c.fill(Path(roundedRect: CGRect(x: 78, y: 325, width: 205, height: 15), cornerRadius: 6), with: .color(ArcadeArt.steel))
        c.stroke(Path(roundedRect: CGRect(x: 78, y: 325, width: 205, height: 15), cornerRadius: 6), with: .color(ArcadeArt.ink), lineWidth: 3)
        var tap = Path()
        tap.move(to: CGPoint(x: 184, y: 324))
        tap.addLine(to: CGPoint(x: 184, y: 270))
        tap.addQuadCurve(to: CGPoint(x: 227, y: 282), control: CGPoint(x: 184, y: 251))
        tap.addLine(to: CGPoint(x: 227, y: 305))
        c.stroke(tap, with: .color(ArcadeArt.ink), style: StrokeStyle(lineWidth: 13, lineCap: .round, lineJoin: .round))
        c.stroke(tap, with: .color(ArcadeArt.steel), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
        for n in 0..<3 {
            let x = 227.0 + Double(n) * 10
            c.fill(Path(ellipseIn: CGRect(x: x, y: 318 + Double(n % 2) * 12, width: 5, height: 9)), with: .color(Color(hex: 0x7DBBD0)))
        }
        if variant >= 2 {
            c.fill(Path(roundedRect: CGRect(x: 37, y: 263, width: 31, height: 73), cornerRadius: 6), with: .color(Color(hex: 0xE6A77F)))
            c.stroke(Path(roundedRect: CGRect(x: 37, y: 263, width: 31, height: 73), cornerRadius: 6), with: .color(ArcadeArt.ink), lineWidth: 2)
        }
    }

    private static func stove(_ c: GraphicsContext, height: Double, variant: Int) {
        wall(c, height: height, color: Color(hex: 0xF2DCCE), grout: Color(hex: 0xDDBBAA))
        header(c, color: Color(hex: 0xDEA68D))
        var hood = Path()
        hood.move(to: CGPoint(x: 108, y: 87))
        hood.addLine(to: CGPoint(x: 253, y: 87))
        hood.addLine(to: CGPoint(x: 280, y: 180))
        hood.addLine(to: CGPoint(x: 81, y: 180))
        hood.closeSubpath()
        c.fill(hood, with: .color(Color(hex: 0xD2D6CF)))
        c.stroke(hood, with: .color(ArcadeArt.ink), lineWidth: 4)
        c.fill(Path(roundedRect: CGRect(x: 74, y: 179, width: 213, height: 14), cornerRadius: 4), with: .color(ArcadeArt.steel))
        c.stroke(Path(roundedRect: CGRect(x: 74, y: 179, width: 213, height: 14), cornerRadius: 4), with: .color(ArcadeArt.ink), lineWidth: 3)
        c.fill(Path(roundedRect: CGRect(x: 76, y: 327, width: 211, height: 16), cornerRadius: 6), with: .color(Color(hex: 0x545858)))
        let pan = Path(ellipseIn: CGRect(x: 111, y: 297, width: 135, height: 30))
        c.fill(pan, with: .color(Color(hex: 0x596463)))
        c.stroke(pan, with: .color(ArcadeArt.ink), lineWidth: 4)
        c.fill(Path(roundedRect: CGRect(x: 232, y: 305, width: 70, height: 9), cornerRadius: 4), with: .color(Color(hex: 0x596463)))
        c.stroke(Path(roundedRect: CGRect(x: 232, y: 305, width: 70, height: 9), cornerRadius: 4), with: .color(ArcadeArt.ink), lineWidth: 2)
        for x in [139.0, 177.0, 215.0] {
            c.fill(Path(ellipseIn: CGRect(x: x, y: 310, width: 12, height: 8)), with: .color(Color(hex: variant.isMultiple(of: 2) ? 0xEFA665 : 0xA8C874)))
        }
        if variant >= 2 {
            c.fill(Path(roundedRect: CGRect(x: 46, y: 264, width: 47, height: 56), cornerRadius: 8), with: .color(Color(hex: 0xD4D7CF)))
            c.stroke(Path(roundedRect: CGRect(x: 46, y: 264, width: 47, height: 56), cornerRadius: 8), with: .color(ArcadeArt.ink), lineWidth: 3)
        }
    }

    private static func prep(_ c: GraphicsContext, height: Double, variant: Int) {
        wall(c, height: height, color: Color(hex: 0xF2E9CF), grout: Color(hex: 0xD8CDAF))
        header(c, color: Color(hex: 0xB5CDA3))
        c.fill(Path(roundedRect: CGRect(x: 43, y: 103, width: 274, height: 14), cornerRadius: 4), with: .color(ArcadeArt.wood))
        c.stroke(Path(roundedRect: CGRect(x: 43, y: 103, width: 274, height: 14), cornerRadius: 4), with: .color(ArcadeArt.ink), lineWidth: 3)
        for (index, x) in [93.0, 173.0, 253.0].enumerated() {
            let length = index == variant % 3 ? 95.0 : 71.0
            c.stroke(Path(CGRect(x: x, y: 114, width: 1, height: length - 22)), with: .color(ArcadeArt.ink), lineWidth: 5)
            let head = Path(ellipseIn: CGRect(x: x - 12, y: 110 + length - 20, width: 25, height: 33))
            c.fill(head, with: .color(index == 1 ? ArcadeArt.steel : ArcadeArt.wood))
            c.stroke(head, with: .color(ArcadeArt.ink), lineWidth: 2)
        }
        let board = Path(roundedRect: CGRect(x: 104, y: 268, width: 163, height: 84), cornerRadius: 13)
        c.fill(board, with: .color(Color(hex: 0xD8AC76)))
        c.stroke(board, with: .color(ArcadeArt.ink), lineWidth: 4)
        c.fill(Path(ellipseIn: CGRect(x: 117, y: 279, width: 15, height: 15)), with: .color(Color(hex: 0xF2E9CF)))
        for index in 0..<3 {
            let color: UInt32 = [0xEAA279, 0xA8C874, 0xE7CA78][(index + variant) % 3]
            c.fill(Path(ellipseIn: CGRect(x: 160 + Double(index) * 25, y: 287 + Double(index % 2) * 14, width: 24, height: 29)), with: .color(Color(hex: color)))
        }
    }

    private static func fridge(_ c: GraphicsContext, height: Double, variant: Int) {
        wall(c, height: height, color: Color(hex: 0xE0E9E8), grout: Color(hex: 0xC3D4D2))
        header(c, color: Color(hex: 0xB8CED4))
        let body = Path(roundedRect: CGRect(x: 135, y: 80, width: 176, height: 294), cornerRadius: 13)
        c.fill(body, with: .color(Color(hex: variant.isMultiple(of: 2) ? 0xF7F6E9 : 0xD8E9D8)))
        c.stroke(body, with: .color(ArcadeArt.ink), lineWidth: 4)
        c.stroke(Path(CGRect(x: 138, y: 198, width: 170, height: 2)), with: .color(ArcadeArt.ink), lineWidth: 3)
        c.fill(Path(roundedRect: CGRect(x: 151, y: 150, width: 9, height: 38), cornerRadius: 4), with: .color(ArcadeArt.steel))
        c.fill(Path(roundedRect: CGRect(x: 151, y: 217, width: 9, height: 43), cornerRadius: 4), with: .color(ArcadeArt.steel))
        for index in 0..<4 {
            let x = 194.0 + Double((index * 37 + variant * 11) % 85)
            let y = 112.0 + Double((index * 31 + variant * 17) % 61)
            let color: UInt32 = [0xE9A18D, 0xE8CC76, 0x96BD99, 0xA3C9D3][index]
            c.fill(Path(roundedRect: CGRect(x: x, y: y, width: 15, height: 14), cornerRadius: 4), with: .color(Color(hex: color)))
            c.stroke(Path(roundedRect: CGRect(x: x, y: y, width: 15, height: 14), cornerRadius: 4), with: .color(ArcadeArt.ink), lineWidth: 1.5)
        }
        c.fill(Path(ellipseIn: CGRect(x: 25, y: 306, width: 91, height: 28)), with: .color(Color(hex: 0xC69D6C)))
        for (index, x) in [34.0, 57.0, 80.0].enumerated() {
            let color: UInt32 = [0xE8A75C, 0x9BBB76, 0xD87F69][(index + variant) % 3]
            c.fill(Path(ellipseIn: CGRect(x: x, y: 282, width: 24, height: 36)), with: .color(Color(hex: color)))
        }
    }
}
