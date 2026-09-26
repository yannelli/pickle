import SwiftUI

enum WardrobeArt {
    static let newOutfits: [Outfit] = [.beanie, .beret, .headphones, .sunhat, .chef, .cowboy,
                                       .pirate, .mushroom, .wizard, .rainhat, .halo, .helmet]

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
        PickleArtist.drawParts(PetArt.hat(outfit.rawValue), in: c, accent: color)
        return true
    }
}
