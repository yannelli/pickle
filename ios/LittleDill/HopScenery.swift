import SwiftUI

enum HopScenery {
    static func draw(_ context: GraphicsContext, height: Double, distance: Double, reduceMotion: Bool) {
        let travel = distance * 360 / HopRules.zoneLength
        let panel = Int(floor(travel / 360))
        let offset = reduceMotion ? 0 : travel.truncatingRemainder(dividingBy: 360)
        let panels = reduceMotion ? [panel] : [panel, panel + 1]
        for index in panels {
            var c = context
            c.translateBy(x: reduceMotion ? 0 : Double(index - panel) * 360 - offset, y: 0)
            switch index % 3 {
            case 0: pantry(c, height: height)
            case 1: sink(c, height: height)
            default: stove(c, height: height)
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

    private static func pantry(_ c: GraphicsContext, height: Double) {
        wall(c, height: height, color: Color(hex: 0xF6F0DD), grout: Color(hex: 0xDCD6C5))
        header(c, color: Color(hex: 0xD2DFC4))
        c.fill(Path(roundedRect: CGRect(x: 135, y: 174, width: 210, height: 13), cornerRadius: 3), with: .color(ArcadeArt.wood))
        c.stroke(Path(CGRect(x: 135, y: 174, width: 210, height: 13)), with: .color(ArcadeArt.ink), lineWidth: 2)
        for (x, width, color) in [(162.0, 40.0, Color(hex: 0xD8E4B9)), (223, 34, Color(hex: 0xE8B98B)), (276, 43, Color(hex: 0xB5C59F))] {
            let jar = Path(roundedRect: CGRect(x: x, y: 100, width: width, height: 73), cornerRadius: 7)
            c.fill(jar, with: .color(color))
            c.stroke(jar, with: .color(ArcadeArt.ink), lineWidth: 2)
            c.fill(Path(roundedRect: CGRect(x: x - 2, y: 94, width: width + 4, height: 11), cornerRadius: 3), with: .color(ArcadeArt.ink))
            c.fill(Path(roundedRect: CGRect(x: x + 7, y: 124, width: width - 14, height: 20), cornerRadius: 3), with: .color(.white.opacity(0.65)))
        }
        c.draw(Text("fresh from the jar").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(ArcadeArt.ink.opacity(0.6)), at: CGPoint(x: 252, y: 230))
    }

    private static func sink(_ c: GraphicsContext, height: Double) {
        wall(c, height: height, color: Color(hex: 0xDCEDE8), grout: Color(hex: 0xAED1C9))
        header(c, color: Color(hex: 0x9CC9C4))
        let window = Path(roundedRect: CGRect(x: 102, y: 87, width: 162, height: 163), cornerRadius: 8)
        c.fill(window, with: .color(Color(hex: 0xA8DCE5)))
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
    }

    private static func stove(_ c: GraphicsContext, height: Double) {
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
            c.fill(Path(ellipseIn: CGRect(x: x, y: 310, width: 12, height: 8)), with: .color(Color(hex: 0xEFA665)))
        }
        c.draw(Text("chef's corner").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(ArcadeArt.ink.opacity(0.6)), at: CGPoint(x: 180, y: 241))
    }
}
