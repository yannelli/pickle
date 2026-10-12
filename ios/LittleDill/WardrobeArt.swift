import SwiftUI

enum WardrobeArt {
    static let newOutfits: [Outfit] = [.beanie, .beret, .headphones, .sunhat, .chef, .cowboy,
                                       .pirate, .mushroom, .wizard, .rainhat, .halo, .helmet,
                                       .cap, .backcap, .headband, .antenna, .captain, .bonnet,
                                       .deerstalker, .mortarboard, .witch, .tophat, .headset, .shako,
                                       .viking, .tiara, .jester, .unicorn, .phoenix, .emperor]
    static let premium: [Outfit] = [.viking, .tiara, .jester, .unicorn, .phoenix, .emperor]

    static func accent(_ outfit: Outfit) -> Color? {
        switch outfit {
        case .beanie: return Color(hex: 0xA26A87)
        case .beret: return Color(hex: 0xB85C52)
        case .headphones: return Color(hex: 0x47677F)
        case .sunhat: return Color(hex: 0xC9A55E)
        case .chef: return Color(hex: 0xC8553D)
        case .cowboy: return Color(hex: 0x986841)
        case .pirate: return Color(hex: 0x3D596B)
        case .mushroom: return Color(hex: 0xC8553D)
        case .wizard: return Color(hex: 0x755B94)
        case .rainhat: return Color(hex: 0xD7AD42)
        case .halo: return Color(hex: 0xE8BF5D)
        case .helmet: return Color(hex: 0x708F9F)
        case .cap: return Color(hex: 0x4F7FA6)
        case .backcap: return Color(hex: 0xD2694B)
        case .headband: return Color(hex: 0xD65A5A)
        case .antenna: return Color(hex: 0x7FA3A8)
        case .captain: return Color(hex: 0x2F4F6F)
        case .bonnet: return Color(hex: 0xE3A3B5)
        case .deerstalker: return Color(hex: 0x8A6E4B)
        case .mortarboard: return Color(hex: 0x3A3F52)
        case .witch: return Color(hex: 0x5B4B7A)
        case .tophat: return Color(hex: 0x2E3A3F)
        case .headset: return Color(hex: 0x3F7D74)
        case .shako: return Color(hex: 0xB8473D)
        case .viking: return Color(hex: 0x8D9CA8)
        case .tiara: return Color(hex: 0xE3B94E)
        case .jester: return Color(hex: 0x7B52A8)
        case .unicorn: return Color(hex: 0xE79BBE)
        case .phoenix: return Color(hex: 0xE4683A)
        case .emperor: return Color(hex: 0xE8BF3F)
        default: return nil
        }
    }

    /// Draw in head coordinates: x=0 at center, y=0 at crown, scaled by body width / 56.
    @discardableResult static func draw(_ c: GraphicsContext, outfit: Outfit) -> Bool {
        guard let color = accent(outfit) else { return false }
        if outfit == .halo {
            let ring = Path(ellipseIn: CGRect(x: -15, y: -20, width: 30, height: 10))
            c.stroke(ring, with: .color(color), lineWidth: 5.5)
            c.stroke(ring, with: .color(Color(hex: 0xF2F7DA)), lineWidth: 2)
            return true
        }
        PickleArtist.drawParts(parts(outfit), in: c, accent: color)
        return true
    }

    /// Premium looks are wardrobe-only art; the rest reuse pet hats. Matches `looks` in arena-web/arena-wardrobe.mjs.
    static func parts(_ outfit: Outfit) -> [ArtPart] {
        switch outfit {
        case .tophat: return PetArt.hat("top")
        case .viking: return [
            ArtPart(.path("M-19-1Q-33-6-34-26Q-24-14-13-9Z"), fill: .light),
            ArtPart(.path("M19-1Q33-6 34-26Q24-14 13-9Z"), fill: .light),
            ArtPart(.path("M-22 9q0-27 22-27t22 27q-22 7-44 0z"), fill: .accent),
            ArtPart(.path("M0-18V4"), stroke: .light, width: 3),
            ArtPart(.path("M-21 3q21 7 42 0"), stroke: .light, width: 3)
        ]
        case .tiara: return [
            ArtPart(.path("M-21 6-15-9-7-1 0-19 7-1 15-9 21 6q-21 7-42 0z"), fill: .accent),
            ArtPart(.ellipse(0, -6, 4, 5), fill: .hex(0xE0607E)),
            ArtPart(.circle(-12, 1, 2.6), fill: .hex(0x6FA8DC)),
            ArtPart(.circle(12, 1, 2.6), fill: .hex(0x6FA8DC)),
            ArtPart(.circle(0, -20, 2.4), fill: .light),
            ArtPart(.circle(-15, -10, 2), fill: .light),
            ArtPart(.circle(15, -10, 2), fill: .light)
        ]
        case .jester: return [
            ArtPart(.path("M-20 8Q-26-10-37-9Q-22-24-4-10Z"), fill: .accent),
            ArtPart(.path("M20 8Q26-10 37-9Q22-24 4-10Z"), fill: .accent),
            ArtPart(.path("M-12 6Q-10-22 0-35Q10-22 12 6Z"), fill: .hex(0xE9B949)),
            ArtPart(.path("M-23 5q23 8 46 0l1 6q-24 9-48 0z"), fill: .light),
            ArtPart(.circle(-37, -9, 3.5), fill: .hex(0xE9B949)),
            ArtPart(.circle(37, -9, 3.5), fill: .hex(0xE9B949)),
            ArtPart(.circle(0, -35, 3.5), fill: .accent)
        ]
        case .unicorn: return [
            ArtPart(.path("M-20 7l-4-18 13 10z"), fill: .accent),
            ArtPart(.path("M20 7l4-18-13 10z"), fill: .accent),
            ArtPart(.path("M-6 2 0-32 6 2z"), fill: .hex(0xF3D46B)),
            ArtPart(.path("M-4.5-4l8-3M-3-12l6-2.4M-1.6-20l3.4-1.2"), width: 1.6)
        ]
        case .phoenix: return [
            ArtPart(.path("M-22 8Q-30-8-20-22Q-18-12-12-10Q-14-24-4-34Q-4-20 0-16Q4-20 4-34Q14-24 12-10Q18-12 20-22Q30-8 22 8Q0 15-22 8Z"), fill: .accent),
            ArtPart(.path("M-12 7Q-16-4-8-14Q-6-6-2-5Q-2-14 2-22Q6-12 4-5Q8-6 10-14Q16-4 12 7Q0 11-12 7Z"), fill: .hex(0xF4C34E), stroke: .none),
            ArtPart(.path("M-23 6q23 8 46 0l1 5q-24 9-48 0z"), fill: .hex(0x9C3D2A))
        ]
        case .emperor: return [
            ArtPart(.path("M-20 4q0-26 20-26t20 26z"), fill: .hex(0xB23A48)),
            ArtPart(.path("M-25 9-27-14-15-4-8-20 0-8 8-20 15-4 27-14 25 9q-25 8-50 0z"), fill: .accent),
            ArtPart(.path("M-24 4q24 8 48 0"), stroke: .light, width: 3),
            ArtPart(.ellipse(0, 2, 4, 4.5), fill: .hex(0x4FA3D9)),
            ArtPart(.circle(-14, 1, 3), fill: .hex(0x3FA76A)),
            ArtPart(.circle(14, 1, 3), fill: .hex(0x3FA76A)),
            ArtPart(.circle(-27, -14, 2.4), fill: .light),
            ArtPart(.circle(27, -14, 2.4), fill: .light),
            ArtPart(.circle(-8, -20, 2.4), fill: .light),
            ArtPart(.circle(8, -20, 2.4), fill: .light),
            ArtPart(.circle(0, -27, 3.5), fill: .accent),
            ArtPart(.path("M0-31v-6M-3-34h6"), width: 2)
        ]
        default: return PetArt.hat(outfit.rawValue)
        }
    }
}
