import SwiftUI

/// Jar and bounty artwork; the web client uses the same colors, dash, and pulse timing.
enum ArenaEventArt {
    static let ring = Color(hex:0xC8E06B)
    static let glass = Color(hex:0xD9EEF0)
    static let brine = Color(hex:0x7FA34A)
    static let lid = Color(hex:0x8C6A3C)
    static let gold = Color(hex:0xF2C14E)
    static let dash: [CGFloat] = [18,12]

    /// Warning ring width in screen points, 3 to 6 over a 1-second pulse.
    static func ringWidth(time:Double,still:Bool) -> Double { still ? 4 : 4.5 + 1.5 * sin(time * 2 * .pi) }
    /// Seconds for the jar to tip over once it spills.
    static let tipSeconds = 0.6

    static func tip(spilled:Bool,spillAge:Double?,still:Bool) -> Double {
        guard spilled else {return 0}
        return still ? 1 : min(1,(spillAge ?? tipSeconds) / tipSeconds)
    }

    static func drawJar(_ context:GraphicsContext,jar:ArenaJar,center:CGPoint,zoom:Double,time:Double,still:Bool,spillAge:Double?) {
        let r = ArenaJar.radius * zoom
        let area = Path(ellipseIn:CGRect(x:center.x-r,y:center.y-r,width:r*2,height:r*2))
        var fade = 1.0
        if jar.spilled {
            fade = spillAge.map {max(0,min(1,(ArenaJar.lingerSeconds - $0) / 1.5))} ?? 1
            context.fill(area,with:.color(ring.opacity(0.14 * fade)))
            context.stroke(area,with:.color(ring.opacity(0.45 * fade)),lineWidth:2)
        } else {
            context.stroke(area,with:.color(ring.opacity(0.6)),
                           style:StrokeStyle(lineWidth:ringWidth(time:time,still:still),lineCap:.round,dash:dash))
        }
        var sprite = context
        sprite.opacity = fade
        sprite.translateBy(x:center.x,y:center.y)
        let scale = max(zoom,0.4)
        sprite.scaleBy(x:scale,y:scale)
        let urgency = max(0,1 - jar.warn / ArenaJar.warnSeconds)
        let wobble = jar.spilled || still ? 0 : sin(time * 9) * 0.07 * urgency
        drawSprite(sprite,tip:tip(spilled:jar.spilled,spillAge:spillAge,still:still),wobble:wobble)
    }

    /// A 56 x 72 glass jar centered on the origin. `tip` 0...1 lays it on its right side and pours the brine out.
    static func drawSprite(_ context:GraphicsContext,tip:Double,wobble:Double = 0) {
        let ink = DillTheme.ink.opacity(0.6)
        if tip > 0 {
            let spread = 34 + 46 * tip
            let puddle = Path(ellipseIn:CGRect(x:70 - spread / 2,y:24,width:spread,height:16 + 8 * tip))
            context.fill(puddle,with:.color(brine.opacity(0.7 * tip)))
        }
        var jar = context
        jar.translateBy(x:28,y:36)
        jar.rotate(by:.radians(tip * 1.62 + wobble))
        jar.translateBy(x:-28,y:-36)
        let body = Path(roundedRect:CGRect(x:-28,y:-26,width:56,height:62),cornerRadius:13)
        jar.fill(body,with:.color(glass.opacity(0.94)))
        let level = 0.62 * (1 - tip)
        if level > 0.02 {
            var inside = jar
            inside.clip(to:body)
            inside.fill(Path(CGRect(x:-28,y:36 - 62 * level,width:56,height:62 * level)),with:.color(brine))
            inside.fill(Path(ellipseIn:CGRect(x:-12,y:36 - 62 * level + 8,width:10,height:22)),with:.color(DillTheme.lime.opacity(0.55)))
        }
        var shine = Path(); shine.move(to:CGPoint(x:-18,y:-14)); shine.addLine(to:CGPoint(x:-18,y:16))
        jar.stroke(shine,with:.color(.white.opacity(0.75)),style:StrokeStyle(lineWidth:4,lineCap:.round))
        jar.stroke(body,with:.color(ink),lineWidth:2.5)
        let lid = Path(roundedRect:CGRect(x:-24,y:-36 - 18 * tip,width:48,height:12),cornerRadius:4)
        jar.fill(lid,with:.color(ArenaEventArt.lid))
        jar.stroke(lid,with:.color(ink),lineWidth:2)
    }

    static func drawMinimap(_ context:GraphicsContext,jar:ArenaJar?,world:CGSize,size:CGSize,time:Double,still:Bool) {
        guard let jar, world.width > 0, world.height > 0 else {return}
        let point = CGPoint(x:jar.x / world.width * size.width,y:jar.y / world.height * size.height)
        if jar.spilled {
            context.fill(ArenaCanvas.dot(point,3.5),with:.color(ring))
            context.stroke(ArenaCanvas.dot(point,3.5),with:.color(DillTheme.ink.opacity(0.6)),lineWidth:0.8)
            return
        }
        let pulse = still ? 0.5 : time - floor(time)
        context.fill(ArenaCanvas.dot(point,2.2),with:.color(ring))
        context.stroke(ArenaCanvas.dot(point,3 + 3 * pulse),with:.color(ring.opacity(1 - 0.7 * pulse)),lineWidth:1.2)
    }

    /// A three-point crown centered 1.25 radii above the bounty holder's largest piece.
    static func drawCrown(_ context:GraphicsContext,piece center:CGPoint,r:Double) {
        let w = max(16,r * 0.9), h = w * 0.6, cx = center.x, cy = center.y - 1.25 * r
        var crown = Path()
        crown.move(to:CGPoint(x:cx - w / 2,y:cy + h / 2))
        crown.addLine(to:CGPoint(x:cx - w / 2,y:cy - h / 2))
        crown.addLine(to:CGPoint(x:cx - w / 4,y:cy))
        crown.addLine(to:CGPoint(x:cx,y:cy - h / 2))
        crown.addLine(to:CGPoint(x:cx + w / 4,y:cy))
        crown.addLine(to:CGPoint(x:cx + w / 2,y:cy - h / 2))
        crown.addLine(to:CGPoint(x:cx + w / 2,y:cy + h / 2))
        crown.closeSubpath()
        context.fill(crown,with:.color(gold))
        context.stroke(crown,with:.color(DillTheme.ink.opacity(0.7)),style:StrokeStyle(lineWidth:max(1.5,w * 0.06),lineJoin:.round))
    }

    static func bountyPiece(players:[ArenaPlayer],bounty:String?) -> ArenaCell? {
        guard let bounty, let holder = players.first(where:{$0.id == bounty}) else {return nil}
        return holder.pieces.max {$0.mass < $1.mass}
    }
}
