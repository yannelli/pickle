import SwiftUI

enum ArenaSmile: String, CaseIterable {
    case smile, beam, smirk, dimples, grin, crooked

    init(variety:String) {
        self = ["dill":.smile,"gherkin":.beam,"garlic":.smirk,"butter":.dimples,"chili":.grin,"pepper":.crooked][variety] ?? .smile
    }

    func draw(_ context:GraphicsContext,r:Double,lineWidth:Double) {
        var c = context
        c.scaleBy(x:r,y:r)
        let ink = GraphicsContext.Shading.color(DillTheme.ink)
        let stroke = StrokeStyle(lineWidth:lineWidth/r,lineCap:.round,lineJoin:.round)
        var path = Path()
        switch self {
        case .smile:
            path.move(to:CGPoint(x:-0.13,y:0.19))
            path.addQuadCurve(to:CGPoint(x:0.13,y:0.19),control:CGPoint(x:0,y:0.42))
            c.stroke(path,with:ink,style:stroke)
        case .beam:
            path.move(to:CGPoint(x:-0.15,y:0.19))
            path.addQuadCurve(to:CGPoint(x:0.15,y:0.19),control:CGPoint(x:0,y:0.24))
            path.addQuadCurve(to:CGPoint(x:0,y:0.4),control:CGPoint(x:0.14,y:0.43))
            path.addQuadCurve(to:CGPoint(x:-0.15,y:0.19),control:CGPoint(x:-0.14,y:0.43))
            c.fill(path,with:ink)
        case .smirk:
            path.move(to:CGPoint(x:-0.13,y:0.26))
            path.addQuadCurve(to:CGPoint(x:0.17,y:0.16),control:CGPoint(x:0.03,y:0.35))
            path.move(to:CGPoint(x:0.135,y:0.15)); path.addLine(to:CGPoint(x:0.19,y:0.17))
            c.stroke(path,with:ink,style:stroke)
        case .dimples:
            path.move(to:CGPoint(x:-0.18,y:0.23))
            path.addQuadCurve(to:CGPoint(x:0,y:0.23),control:CGPoint(x:-0.09,y:0.38))
            path.addQuadCurve(to:CGPoint(x:0.18,y:0.23),control:CGPoint(x:0.09,y:0.38))
            c.stroke(path,with:ink,style:stroke)
        case .grin:
            path.move(to:CGPoint(x:-0.19,y:0.2)); path.addQuadCurve(to:CGPoint(x:0.19,y:0.2),control:CGPoint(x:0,y:0.17))
            path.addQuadCurve(to:CGPoint(x:0,y:0.4),control:CGPoint(x:0.13,y:0.43))
            path.addQuadCurve(to:CGPoint(x:-0.19,y:0.2),control:CGPoint(x:-0.13,y:0.43))
            c.fill(path,with:ink)
            var teeth = Path()
            teeth.move(to:CGPoint(x:-0.16,y:0.212))
            teeth.addQuadCurve(to:CGPoint(x:0.16,y:0.212),control:CGPoint(x:0,y:0.193))
            teeth.addQuadCurve(to:CGPoint(x:0.12,y:0.275),control:CGPoint(x:0.155,y:0.27))
            teeth.addQuadCurve(to:CGPoint(x:0.04,y:0.27),control:CGPoint(x:0.08,y:0.292))
            teeth.addQuadCurve(to:CGPoint(x:-0.04,y:0.27),control:CGPoint(x:0,y:0.3))
            teeth.addQuadCurve(to:CGPoint(x:-0.12,y:0.275),control:CGPoint(x:-0.08,y:0.292))
            teeth.addQuadCurve(to:CGPoint(x:-0.16,y:0.212),control:CGPoint(x:-0.155,y:0.27))
            c.fill(teeth,with:.color(Color(hex:0xF8F6ED)))
        case .crooked:
            path.move(to:CGPoint(x:-0.16,y:0.16))
            path.addQuadCurve(to:CGPoint(x:0.13,y:0.28),control:CGPoint(x:-0.05,y:0.39))
            path.move(to:CGPoint(x:-0.195,y:0.175)); path.addLine(to:CGPoint(x:-0.135,y:0.15))
            c.stroke(path,with:ink,style:stroke)
        }
    }
}

enum ArenaTear {
    static func pose(remaining:Double,reduceMotion:Bool) -> (offset:Double,alpha:Double)? {
        guard remaining > 0 else {return nil}
        let progress = max(0,min(1,1 - remaining / 1.4))
        return (reduceMotion ? 0 : progress * 2.1,reduceMotion ? 0.7 : 0.85 * (1 - progress))
    }
}

struct ArenaPickupCadence {
    struct Cue {
        let at:Double
        let index:Int
        let streak:Int
        var volume:Double {0.7 * (1 - Double(streak) * 0.08)}
        var sound:DillSound {[.nibble,.nibble2,.nibble3,.nibble4][index]}
    }
    private(set) var previous:Cue?

    mutating func next(at now:Double) -> Cue? {
        let streak = previous.map {now - $0.at <= 1 ? min(5,$0.streak + 1) : 0} ?? 0
        if let previous, now - previous.at < 0.3 + Double(min(4,previous.streak)) * 0.04 {return nil}
        let cue = Cue(at:now,index:previous.map {($0.index + 1) % 4} ?? 0,streak:streak)
        previous = cue
        return cue
    }
}
