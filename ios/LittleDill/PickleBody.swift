import SwiftUI

enum PickleBody {
    static func profile(_ shape: PickleVariety.Shape) -> (width: Double, height: Double) {
        switch shape {
        case .long: return (0.8, 1)
        case .gherkin: return (0.84, 0.82)
        case .pear: return (0.9, 1)
        case .round: return (1.04, 0.78)
        case .tapered: return (0.76, 1.08)
        case .ribbed: return (0.86, 1.02)
        }
    }

    static func radius(_ shape: PickleVariety.Shape, at angle: Double, width: Double, height: Double) -> Double {
        let c = abs(cos(angle)), s = sin(angle), sy = abs(s)
        if shape == .long {
            let k = max(0, height - width)
            if c > 1e-9 && sy * width / c <= k { return width / c }
            return sy * k + sqrt(max(0, pow(sy * k, 2) - k * k + width * width))
        }
        if shape == .gherkin { return 1 / pow(pow(c / width, 3) + pow(sy / height, 3), 1 / 3.0) }
        let oval = 1 / hypot(c / width, sy / height)
        if shape == .pear { return oval * (1 + 0.28 * s * c * c) }
        if shape == .tapered { return oval * (1 - 0.32 * s * c * c) }
        if shape == .ribbed { return oval * (1 + 0.1 * cos(3 * .pi * s) * c * c) }
        return oval
    }

    static func points(_ shape: PickleVariety.Shape, width: Double, height: Double, count: Int = 72) -> [CGPoint] {
        (0..<count).map { i in
            let angle = Double(i) * .pi * 2 / Double(count)
            let r = radius(shape, at: angle, width: width, height: height)
            return CGPoint(x: cos(angle) * r, y: sin(angle) * r)
        }
    }

    static func path(_ shape: PickleVariety.Shape, in rect: CGRect) -> Path {
        let outline = points(shape, width: rect.width / 2, height: rect.height / 2)
            .map { CGPoint(x: $0.x + rect.midX, y: $0.y + rect.midY) }
        func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        var path = Path()
        path.move(to: midpoint(outline[outline.count - 1], outline[0]))
        for i in outline.indices {
            path.addQuadCurve(to: midpoint(outline[i], outline[(i + 1) % outline.count]), control: outline[i])
        }
        path.closeSubpath()
        return path
    }
}
