import SwiftUI

enum FeedFood: String, CaseIterable {
    case carrot, strawberry, broccoli, apple, cheese

    static func at(_ successfulFeeds: Int) -> FeedFood {
        allCases[successfulFeeds % allCases.count]
    }

    var name: String {
        switch self {
        case .carrot: "carrot"
        case .strawberry: "strawberry"
        case .broccoli: "broccoli"
        case .apple: "apple slice"
        case .cheese: "cheese wedge"
        }
    }

    var crumb: Color {
        switch self {
        case .carrot: Color(hex: 0xED9C53)
        case .strawberry: Color(hex: 0xD95660)
        case .broccoli: Color(hex: 0x76A353)
        case .apple: Color(hex: 0xF6D798)
        case .cheese: Color(hex: 0xF2BD58)
        }
    }

    func draw(_ context: GraphicsContext, eaten: CGFloat) {
        var c = context
        let ink = DillTheme.ink
        if eaten > 0 {
            let edge = Path(CGRect(x: eaten, y: -36, width: 90, height: 72))
            c.clip(to: edge)
            var scallops = Path()
            for y in stride(from: -30.0, through: 30.0, by: 7.0) {
                scallops.addEllipse(in: CGRect(x: eaten - 3, y: y - 3, width: 6, height: 6))
            }
            c.clip(to: scallops, options: .inverse)
        }
        func fill(_ path: Path, _ color: Color, line: CGFloat = 2.5) {
            c.fill(path, with: .color(color))
            c.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: line, lineJoin: .round))
        }
        func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color) {
            fill(Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h)), color)
        }
        switch self {
        case .carrot:
            var body = Path()
            body.move(to: .zero)
            body.addQuadCurve(to: CGPoint(x: 58, y: -11), control: CGPoint(x: 26, y: -11))
            body.addQuadCurve(to: CGPoint(x: 58, y: 11), control: CGPoint(x: 67, y: 0))
            body.addQuadCurve(to: .zero, control: CGPoint(x: 26, y: 11))
            fill(body, crumb)
            for angle in [-38.0, 0, 38] {
                var leaf = c
                leaf.translateBy(x: 59, y: 0)
                leaf.rotate(by: .degrees(angle))
                var path = Path()
                path.move(to: .zero)
                path.addQuadCurve(to: CGPoint(x: 18, y: 0), control: CGPoint(x: 9, y: -8))
                path.addQuadCurve(to: .zero, control: CGPoint(x: 9, y: 8))
                leaf.fill(path, with: .color(Color(hex: 0x77A35B)))
                leaf.stroke(path, with: .color(ink), lineWidth: 2)
            }
            var shine = Path()
            shine.move(to: CGPoint(x: 23, y: -5))
            shine.addQuadCurve(to: CGPoint(x: 49, y: -7), control: CGPoint(x: 38, y: -9))
            c.stroke(shine, with: .color(Color(hex: 0xFFD49A)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        case .strawberry:
            var berry = Path()
            berry.move(to: .zero)
            berry.addCurve(to: CGPoint(x: 48, y: -19), control1: CGPoint(x: 12, y: -17), control2: CGPoint(x: 38, y: -27))
            berry.addQuadCurve(to: CGPoint(x: 48, y: 19), control: CGPoint(x: 64, y: 0))
            berry.addCurve(to: .zero, control1: CGPoint(x: 38, y: 27), control2: CGPoint(x: 12, y: 17))
            fill(berry, crumb)
            for x in [20.0, 34.0, 45.0] {
                for side in [-1.0, 1.0] {
                    c.fill(Path(ellipseIn: CGRect(x: x, y: side * (x < 30 ? 8 : 12) - 2, width: 3, height: 4)), with: .color(Color(hex: 0xFFE4A8)))
                }
            }
            var crown = Path()
            crown.move(to: CGPoint(x: 48, y: -8))
            crown.addLines([CGPoint(x: 59, y: -16), CGPoint(x: 56, y: -4), CGPoint(x: 68, y: 0), CGPoint(x: 56, y: 4), CGPoint(x: 59, y: 16), CGPoint(x: 48, y: 8)])
            crown.closeSubpath()
            fill(crown, Color(hex: 0x76A353), line: 2)
        case .broccoli:
            fill(Path(roundedRect: CGRect(x: 0, y: -7, width: 42, height: 14), cornerRadius: 6), Color(hex: 0xA6BE75))
            ellipse(31, -22, 24, 29, Color(hex: 0x6E9B51))
            ellipse(42, -19, 24, 26, Color(hex: 0x76A353))
            ellipse(39, -29, 22, 25, Color(hex: 0x86B460))
            ellipse(52, -11, 17, 20, Color(hex: 0x6E9B51))
            for (x, y) in [(44.0, -20.0), (53.0, -13.0), (58.0, 0.0)] {
                c.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 4, height: 4)), with: .color(Color(hex: 0xA7CC76)))
            }
        case .apple:
            var wedge = Path()
            wedge.move(to: .zero)
            wedge.addQuadCurve(to: CGPoint(x: 55, y: -19), control: CGPoint(x: 19, y: -19))
            wedge.addQuadCurve(to: CGPoint(x: 57, y: 17), control: CGPoint(x: 64, y: -1))
            wedge.addQuadCurve(to: .zero, control: CGPoint(x: 26, y: 14))
            fill(wedge, Color(hex: 0xFFE7B1))
            var peel = Path()
            peel.move(to: CGPoint(x: 54, y: -19))
            peel.addQuadCurve(to: CGPoint(x: 57, y: 17), control: CGPoint(x: 66, y: -1))
            c.stroke(peel, with: .color(Color(hex: 0xD95555)), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            c.stroke(peel, with: .color(ink), lineWidth: 1.6)
            ellipse(34, -4, 5, 3, Color(hex: 0x9F744C))
        case .cheese:
            var wedge = Path()
            wedge.move(to: .zero)
            wedge.addLines([CGPoint(x: 56, y: -22), CGPoint(x: 61, y: 13), CGPoint(x: 7, y: 13)])
            wedge.closeSubpath()
            fill(wedge, crumb)
            for (x, y, r) in [(30.0, 2.0, 4.0), (47.0, -9.0, 3.0), (50.0, 7.0, 2.5)] {
                c.fill(Path(ellipseIn: CGRect(x: x-r, y: y-r, width: r*2, height: r*2)), with: .color(Color(hex: 0xD99339)))
            }
            var top = Path()
            top.move(to: .zero)
            top.addLines([CGPoint(x: 56, y: -22), CGPoint(x: 61, y: 13)])
            c.stroke(top, with: .color(Color(hex: 0xFFE19A)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }
}
