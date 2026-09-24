import Foundation

enum ArtPaint: Equatable { case none, ink, accent, light, hex(UInt32) }

enum ArtShape: Equatable {
    case path(String)
    case circle(Double, Double, Double)
    case ellipse(Double, Double, Double, Double)
    case rect(Double, Double, Double, Double, Double)
}

/// One SVG element from pet-art.js. `rotation` turns an ellipse about its own centre.
struct ArtPart: Equatable {
    var shape: ArtShape
    var fill: ArtPaint
    var stroke: ArtPaint
    var width: Double
    var fillOpacity: Double
    var rotation: Double
    var dash: Double
    var flicker: Bool
    init(_ shape: ArtShape, fill: ArtPaint = .none, stroke: ArtPaint = .ink, width: Double = 2.5, fillOpacity: Double = 1,
         rotation: Double = 0, dash: Double = 0, flicker: Bool = false) {
        self.shape = shape; self.fill = fill; self.stroke = stroke; self.width = width
        self.fillOpacity = fillOpacity; self.rotation = rotation; self.dash = dash; self.flicker = flicker
    }
}

enum SVGSegment: Equatable {
    case move(Double, Double)
    case line(Double, Double)
    case quad(Double, Double, Double, Double)
    case cubic(Double, Double, Double, Double, Double, Double)
    case close
}

/// Parses SVG path data into absolute segments. Arcs become cubic curves.
enum SVGPathParser {
    static func parse(_ data: String) -> [SVGSegment]? {
        var scanner = Tokens(Array(data.utf8))
        var out: [SVGSegment] = []
        var x = 0.0, y = 0.0, startX = 0.0, startY = 0.0
        var lastControl: (Double, Double)?, lastQuad: (Double, Double)?
        var command: UInt8 = 0
        while true {
            scanner.skipSeparators()
            guard let next = scanner.peek else { break }
            if next.isLetter { command = next; scanner.index += 1 } else if command == 0 { return nil }
            let relative = command >= 97
            let ox = relative ? x : 0, oy = relative ? y : 0
            var control: (Double, Double)?, quad: (Double, Double)?
            switch command | 0x20 {
            case UInt8(ascii: "m"):
                guard let px = scanner.number(), let py = scanner.number() else { return nil }
                x = ox + px; y = oy + py; startX = x; startY = y
                out.append(.move(x, y))
                command = relative ? UInt8(ascii: "l") : UInt8(ascii: "L")
            case UInt8(ascii: "l"):
                guard let px = scanner.number(), let py = scanner.number() else { return nil }
                x = ox + px; y = oy + py; out.append(.line(x, y))
            case UInt8(ascii: "h"):
                guard let px = scanner.number() else { return nil }
                x = ox + px; out.append(.line(x, y))
            case UInt8(ascii: "v"):
                guard let py = scanner.number() else { return nil }
                y = oy + py; out.append(.line(x, y))
            case UInt8(ascii: "q"), UInt8(ascii: "t"):
                var cx: Double, cy: Double
                if command | 0x20 == UInt8(ascii: "q") {
                    guard let qx = scanner.number(), let qy = scanner.number() else { return nil }
                    cx = ox + qx; cy = oy + qy
                } else {
                    cx = 2 * x - (lastQuad?.0 ?? x); cy = 2 * y - (lastQuad?.1 ?? y)
                }
                guard let px = scanner.number(), let py = scanner.number() else { return nil }
                x = ox + px; y = oy + py; quad = (cx, cy)
                out.append(.quad(cx, cy, x, y))
            case UInt8(ascii: "c"), UInt8(ascii: "s"):
                var c1x: Double, c1y: Double
                if command | 0x20 == UInt8(ascii: "c") {
                    guard let ax = scanner.number(), let ay = scanner.number() else { return nil }
                    c1x = ox + ax; c1y = oy + ay
                } else {
                    c1x = 2 * x - (lastControl?.0 ?? x); c1y = 2 * y - (lastControl?.1 ?? y)
                }
                guard let bx = scanner.number(), let by = scanner.number(), let px = scanner.number(), let py = scanner.number() else { return nil }
                let c2x = ox + bx, c2y = oy + by
                x = ox + px; y = oy + py; control = (c2x, c2y)
                out.append(.cubic(c1x, c1y, c2x, c2y, x, y))
            case UInt8(ascii: "a"):
                guard let rx = scanner.number(), let ry = scanner.number(), let angle = scanner.number(),
                      let large = scanner.flag(), let sweep = scanner.flag(), let px = scanner.number(), let py = scanner.number() else { return nil }
                let ex = ox + px, ey = oy + py
                out.append(contentsOf: arc(from: (x, y), to: (ex, ey), rx: rx, ry: ry, angle: angle, large: large, sweep: sweep))
                x = ex; y = ey
            case UInt8(ascii: "z"):
                x = startX; y = startY; out.append(.close)
            default: return nil
            }
            lastControl = control; lastQuad = quad
        }
        return out
    }

    static func arc(from p0: (Double, Double), to p1: (Double, Double), rx: Double, ry: Double, angle: Double, large: Bool, sweep: Bool) -> [SVGSegment] {
        var rx = abs(rx), ry = abs(ry)
        if rx == 0 || ry == 0 || (p0.0 == p1.0 && p0.1 == p1.1) { return [.line(p1.0, p1.1)] }
        let phi = angle * .pi / 180, cosPhi = cos(phi), sinPhi = sin(phi)
        let dx = (p0.0 - p1.0) / 2, dy = (p0.1 - p1.1) / 2
        let x1 = cosPhi * dx + sinPhi * dy, y1 = -sinPhi * dx + cosPhi * dy
        let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lambda > 1 { rx *= lambda.squareRoot(); ry *= lambda.squareRoot() }
        let numerator = max(0, rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1)
        let denominator = rx * rx * y1 * y1 + ry * ry * x1 * x1
        var factor = denominator == 0 ? 0 : (numerator / denominator).squareRoot()
        if large == sweep { factor = -factor }
        let cxp = factor * rx * y1 / ry, cyp = -factor * ry * x1 / rx
        let cx = cosPhi * cxp - sinPhi * cyp + (p0.0 + p1.0) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (p0.1 + p1.1) / 2
        func angleOf(_ ux: Double, _ uy: Double) -> Double { atan2(uy, ux) }
        let theta = angleOf((x1 - cxp) / rx, (y1 - cyp) / ry)
        var delta = angleOf((-x1 - cxp) / rx, (-y1 - cyp) / ry) - theta
        if sweep && delta < 0 { delta += 2 * .pi }
        if !sweep && delta > 0 { delta -= 2 * .pi }
        let count = max(1, Int((abs(delta) / (.pi / 2)).rounded(.up)))
        let step = delta / Double(count), k = 4.0 / 3 * tan(step / 4)
        func point(_ t: Double) -> (Double, Double) {
            let px = rx * cos(t), py = ry * sin(t)
            return (cx + cosPhi * px - sinPhi * py, cy + sinPhi * px + cosPhi * py)
        }
        func tangent(_ t: Double) -> (Double, Double) {
            let px = -rx * sin(t), py = ry * cos(t)
            return (cosPhi * px - sinPhi * py, sinPhi * px + cosPhi * py)
        }
        var segments: [SVGSegment] = []
        var t = theta
        for index in 0..<count {
            let t2 = t + step
            let a = point(t), b = index == count - 1 ? p1 : point(t2)
            let da = tangent(t), db = tangent(t2)
            segments.append(.cubic(a.0 + k * da.0, a.1 + k * da.1, b.0 - k * db.0, b.1 - k * db.1, b.0, b.1))
            t = t2
        }
        return segments
    }

    private struct Tokens {
        let bytes: [UInt8]
        var index = 0
        init(_ bytes: [UInt8]) { self.bytes = bytes }
        var peek: UInt8? { index < bytes.count ? bytes[index] : nil }
        mutating func skipSeparators() {
            while let c = peek, c == 32 || c == 44 || c == 9 || c == 10 || c == 13 { index += 1 }
        }
        mutating func flag() -> Bool? {
            skipSeparators()
            guard let c = peek, c == 48 || c == 49 else { return nil }
            index += 1
            return c == 49
        }
        mutating func number() -> Double? {
            skipSeparators()
            let start = index
            if let c = peek, c == 43 || c == 45 { index += 1 }
            var dot = false, digits = false
            while let c = peek {
                if c >= 48 && c <= 57 { digits = true; index += 1 }
                else if c == 46 && !dot { dot = true; index += 1 }
                else { break }
            }
            if digits, let c = peek, c == 101 || c == 69 {
                index += 1
                if let s = peek, s == 43 || s == 45 { index += 1 }
                while let d = peek, d >= 48 && d <= 57 { index += 1 }
            }
            guard digits else { index = start; return nil }
            return Double(String(decoding: bytes[start..<index], as: UTF8.self))
        }
    }
}

private extension UInt8 {
    var isLetter: Bool { (self >= 65 && self <= 90) || (self >= 97 && self <= 122) }
}
