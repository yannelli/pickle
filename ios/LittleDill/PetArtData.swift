import Foundation

// Ported from ../../pet-art.js (HATS, FACES, PROPS, WORN, SCENES). Each table keeps the web coordinate space documented at the top of that file.
enum PetArt {
    static let hatIDs: Set<String> = ["cap", "headphones", "wizard", "sunhat", "turban", "afro", "captain", "mortarboard", "crown", "cowboy", "bonnet", "antenna", "headband", "pirate", "deerstalker", "witch", "top", "mushroom", "chef", "helmet", "rainhat", "mohawk", "vampire", "halo", "beret", "fringe", "backcap", "beanie", "headset", "shako"]
    /// x 0 at the head centre, y 0 at the crown, scaled by body width / 56.
    static func hat(_ id: String) -> [ArtPart] {
        switch id {
        case "cap": return [
            ArtPart(.path("M-18 4q-21 0-18 8 8 5 18-2z"), fill: .accent),
            ArtPart(.path("M-22 9q0-26 22-26t22 26q-22 7-44 0z"), fill: .accent),
            ArtPart(.circle(0, -18, 2.6), fill: .light)
        ]
        case "headphones": return [
            ArtPart(.path("M-27 12q0-29 27-29t27 29"), width: 5),
            ArtPart(.rect(-32, 6, 12, 21, 6), fill: .accent),
            ArtPart(.rect(20, 6, 12, 21, 6), fill: .accent)
        ]
        case "wizard": return [
            ArtPart(.ellipse(0, 4, 27, 6), fill: .accent),
            ArtPart(.path("M-16 5Q-9-17 0-36 9-17 16 5Z"), fill: .accent),
            ArtPart(.path("m0-25 1.8 5 5.2.3-4 3.2 1.4 5L0-14.4l-4.4 3 1.4-5-4-3.2 5.2-.3z"), fill: .light, stroke: .none)
        ]
        case "sunhat": return [
            ArtPart(.ellipse(0, 6, 30, 7), fill: .accent),
            ArtPart(.path("M-17 5q0-20 17-20t17 20z"), fill: .accent),
            ArtPart(.path("M-16 1q16 5 32 0"), stroke: .light)
        ]
        case "turban": return [
            ArtPart(.path("M-26 14q0-31 26-31t26 31q-26 9-52 0z"), fill: .accent),
            ArtPart(.path("M-25 9q15-22 38-20M-24 16q19-25 46-17M-13 18q13-13 33-11")),
            ArtPart(.circle(-3, -2, 5), fill: .light)
        ]
        case "afro": return [
            ArtPart(.path("M-28 12a9 9 0 0 1-1-14 10 10 0 0 1 8-12 10 10 0 0 1 12-8 11 11 0 0 1 18 0 10 10 0 0 1 12 8 10 10 0 0 1 8 12 9 9 0 0 1-1 14q-28 9-56 0z"), fill: .accent)
        ]
        case "captain": return [
            ArtPart(.path("M-26 7q26 6 52 0 2 8-26 10T-26 7Z"), fill: .accent),
            ArtPart(.path("M-24 2H24V8H-24Z"), fill: .accent),
            ArtPart(.path("M-23 2q0-20 23-20t23 20z"), fill: .light),
            ArtPart(.path("M0-14v9M-4-11h8"))
        ]
        case "mortarboard": return [
            ArtPart(.path("M-15 10q0-15 15-15t15 15q-15 5-30 0z"), fill: .accent),
            ArtPart(.path("M-29-6 0-15l29 9L0 4Z"), fill: .accent),
            ArtPart(.path("M23-8v13"), stroke: .light),
            ArtPart(.circle(23, 8, 2.8), fill: .light)
        ]
        case "crown": return [
            ArtPart(.path("M-23 8-26-20-13-8 0-25l13 17 13-12-3 28q-23 7-46 0z"), fill: .accent),
            ArtPart(.path("M-21 2q21 6 42 0"), stroke: .light, width: 3),
            ArtPart(.circle(0, -19, 2.6), fill: .light),
            ArtPart(.circle(-18, -14, 2.2), fill: .light),
            ArtPart(.circle(18, -14, 2.2), fill: .light)
        ]
        case "cowboy": return [
            ArtPart(.path("M-31 5q7-6 31-6t31 6q-7 8-31 8T-31 5Z"), fill: .accent),
            ArtPart(.path("M-17 5q1-21 9-22 4 4 8 4t8-4q8 1 9 22q-17 6-34 0Z"), fill: .accent)
        ]
        case "bonnet": return [
            ArtPart(.path("M-27 17q-6-35 27-35t27 35q-11-17-27-17t-27 17z"), fill: .accent),
            ArtPart(.path("M-25 17-26 28M25 17 26 28"), width: 3),
            ArtPart(.path("m0-22 5 5-5 5-5-5z"), fill: .light)
        ]
        case "antenna": return [
            ArtPart(.path("M-22 12q0-27 22-27t22 27q-22 8-44 0z"), fill: .accent),
            ArtPart(.path("M0-16v-12")),
            ArtPart(.circle(0, -32, 5), fill: .light)
        ]
        case "headband": return [
            ArtPart(.path("M-26 9q26 13 52 0l2 7q-28 14-56 0z"), fill: .accent),
            ArtPart(.path("m25 13 11 5-4 4-3 6-6-6z"), fill: .accent)
        ]
        case "pirate": return [
            ArtPart(.path("M-26 10q2-25 26-25t26 25q-26 8-52 0Z"), fill: .accent),
            ArtPart(.path("m22 3 14 6-10 7z"), fill: .accent),
            ArtPart(.circle(0, -6, 5), fill: .light),
            ArtPart(.path("m-7 1 14 5m-14 0 14-5"), stroke: .light)
        ]
        case "deerstalker": return [
            ArtPart(.ellipse(0, 11, 28, 5), fill: .accent),
            ArtPart(.path("M-21 10q0-25 21-25t21 25q-21 6-42 0z"), fill: .accent),
            ArtPart(.path("M-27 5q-7 13 1 18 7-2 8-13zM27 5q7 13-1 18-7-2-8-13z"), fill: .accent)
        ]
        case "witch": return [
            ArtPart(.ellipse(0, 8, 29, 6), fill: .accent),
            ArtPart(.path("M-15 6Q-17-14-5-35 8-18 15 6Z"), fill: .accent),
            ArtPart(.path("M-7-3H7V5H-7Z"), fill: .light)
        ]
        case "top": return [
            ArtPart(.path("M-15-32H15V2H-15Z"), fill: .accent),
            ArtPart(.path("M-15-9h30"), stroke: .light, width: 6),
            ArtPart(.ellipse(0, 3, 25, 5), fill: .accent)
        ]
        case "mushroom": return [
            ArtPart(.path("M-28 11q0-34 28-34t28 34q-28 9-56 0z"), fill: .accent),
            ArtPart(.circle(-13, -7, 4.5), fill: .light, stroke: .none),
            ArtPart(.circle(6, -13, 5.5), fill: .light, stroke: .none),
            ArtPart(.circle(18, -1, 3.5), fill: .light, stroke: .none)
        ]
        case "chef": return [
            ArtPart(.path("M-17 0a12 12 0 0 1 1-21 13 13 0 0 1 16-10 13 13 0 0 1 16 10 12 12 0 0 1 1 21z"), fill: .light),
            ArtPart(.path("M-17 0H17V7q-17 8-34 0z"), fill: .accent)
        ]
        case "helmet": return [
            ArtPart(.path("M-24 15q0-31 24-31t24 31q-24 8-48 0z"), fill: .accent),
            ArtPart(.path("M-9-16q12-19 23-8-8 14-23 8z"), fill: .light),
            ArtPart(.path("M-19 4h38"), width: 4),
            ArtPart(.circle(-16, 12, 2), fill: .light),
            ArtPart(.circle(16, 12, 2), fill: .light)
        ]
        case "rainhat": return [
            ArtPart(.path("M-30 9q30 9 60 0-3 12-30 12T-30 9Z"), fill: .accent),
            ArtPart(.path("M-20 9q0-24 20-24t20 24q-20 6-40 0z"), fill: .accent)
        ]
        case "mohawk": return [
            ArtPart(.path("m-15 9 3-18 5 5 4-22 5 20 6-13 7 28q-15 6-30 0z"), fill: .accent)
        ]
        case "vampire": return [
            ArtPart(.path("M-24 14q0-29 24-29t24 29q-6-10-14-8L0 17-10 6q-8-2-14 8z"), fill: .accent),
            ArtPart(.path("M-14-11q9-6 19-2"), stroke: .light)
        ]
        case "halo": return [
            ArtPart(.ellipse(0, -15, 15, 5), width: 5.5),
            ArtPart(.ellipse(0, -15, 15, 5), stroke: .light, width: 2)
        ]
        case "beret": return [
            ArtPart(.path("M-24 5q-2-20 24-20t22 16q-2 8-23 8T-24 5Z"), fill: .accent),
            ArtPart(.path("m14-15 5-7"))
        ]
        case "fringe": return [
            ArtPart(.path("M-25 7q-3-32 25-32 27 0 27 26-8-14-21-12l8 22q-10-16-24-18-9 0-15 14z"), fill: .accent)
        ]
        case "backcap": return [
            ArtPart(.path("M18 4q21 0 18 8-8 5-18-2z"), fill: .accent),
            ArtPart(.path("M-22 9q0-26 22-26t22 26q-22 7-44 0z"), fill: .accent),
            ArtPart(.path("M-14 7h28"), stroke: .light, width: 4)
        ]
        case "beanie": return [
            ArtPart(.path("M-22 6q0-25 22-25t22 25z"), fill: .accent),
            ArtPart(.path("M-24 5H24V12q-24 8-48 0z"), fill: .accent),
            ArtPart(.path("M-21 9q21 6 42 0"), stroke: .light),
            ArtPart(.circle(0, -22, 5), fill: .light)
        ]
        case "headset": return [
            ArtPart(.path("M-27 12q0-29 27-29t27 29"), width: 5),
            ArtPart(.rect(-32, 6, 12, 21, 6), fill: .accent),
            ArtPart(.rect(20, 6, 12, 21, 6), fill: .accent),
            ArtPart(.path("M-27 25q-5 14 8 19")),
            ArtPart(.circle(-16, 45, 3.5), fill: .accent)
        ]
        case "shako": return [
            ArtPart(.path("M-14-24H14V4H-14Z"), fill: .accent),
            ArtPart(.path("M-9-13h18"), stroke: .light, width: 5),
            ArtPart(.ellipse(0, 5, 19, 4.5), fill: .accent),
            ArtPart(.path("M0-24v-6"), width: 3),
            ArtPart(.circle(0, -34, 5), fill: .light)
        ]
        default: return []
        }
    }
    /// x 0 at the face centre, y 0 at the eye line.
    static func face(_ id: String) -> [ArtPart] {
        switch id {
        case "sunglasses": return [
            ArtPart(.path("M-20 1H-4q0 11-8 11t-8-11z"), fill: .accent),
            ArtPart(.path("M20 1H4q0 11 8 11t8-11z"), fill: .accent),
            ArtPart(.path("M-4 3h8M-20 2-27 0M20 2 27 0"))
        ]
        case "nerdglasses": return [
            ArtPart(.circle(-12.5, 3.5, 7.5), fill: .light, fillOpacity: 0.45),
            ArtPart(.circle(12.5, 3.5, 7.5), fill: .light, fillOpacity: 0.45),
            ArtPart(.path("M-5 3h10M-20 2-26 4M20 3l6-2")),
            ArtPart(.path("M0 0v7"), width: 4)
        ]
        case "readers": return [
            ArtPart(.ellipse(-12, 4, 9, 6.5), fill: .hex(0xe4ecc0), fillOpacity: 0.55),
            ArtPart(.ellipse(12, 4, 9, 6.5), fill: .hex(0xe4ecc0), fillOpacity: 0.55),
            ArtPart(.path("M-3 4h6M-21 2-27 0M21 2 27 0"))
        ]
        case "book": return [
            ArtPart(.path("M-23 21q11-4 22 4 11-8 22-4v18q-11-4-22 4-11-8-22-4z"), fill: .light),
            ArtPart(.path("M-1 25v18M-18 26h11M-18 32h11M4 26h11M4 32h11"), width: 1.6)
        ]
        default: return []
        }
    }
    /// x 0 sixteen points right of the body, y 0 on the ground.
    static func prop(_ id: String) -> [ArtPart] {
        switch id {
        case "cane": return [
            ArtPart(.path("M3 0v-30q0-10 9-10t8 9"), width: 5)
        ]
        case "record": return [
            ArtPart(.circle(8, -16, 15), fill: .accent),
            ArtPart(.circle(8, -16, 5.5), fill: .light),
            ArtPart(.circle(8, -16, 1.8), stroke: .none)
        ]
        case "scroll": return [
            ArtPart(.path("M0-40H20V-4H0Z"), fill: .light),
            ArtPart(.path("M3-33h14M3-25h14M3-17h11"), width: 1.8),
            ArtPart(.rect(-4, -44, 28, 6, 3), fill: .accent),
            ArtPart(.rect(-4, -6, 28, 6, 3), fill: .accent)
        ]
        case "rake": return [
            ArtPart(.path("M5 0v-36M-7-36H19M-7-45v9M-1-45v9M5-45v9M11-45v9M19-45v9"))
        ]
        case "bowl": return [
            ArtPart(.path("M-9-15H25q-3 15-17 15T-9-15Z"), fill: .accent),
            ArtPart(.path("M-11-15H27"), width: 3),
            ArtPart(.path("M2-22q-5-5 0-9M14-22q-5-5 0-9"))
        ]
        case "anchor": return [
            ArtPart(.path("M8-40V-5M-2-31h20M-7-17q15 23 30 0M-7-17v9M23-17v9")),
            ArtPart(.circle(8, -44, 4.5))
        ]
        case "book": return [
            ArtPart(.path("M-8-24q10-4 17 3 7-7 17-3v22q-10-4-17 3-7-7-17-3z"), fill: .light),
            ArtPart(.path("M9-21v22M-4-18h8M-4-12h8M14-18h8M14-12h8"), width: 1.6)
        ]
        case "mug": return [
            ArtPart(.path("M-2-26H18V0H-2Z"), fill: .light),
            ArtPart(.path("M18-21q14-2 4 12h-4")),
            ArtPart(.path("M3-32q-5-5 0-9M12-32q-5-5 0-9"))
        ]
        case "planet": return [
            ArtPart(.circle(9, -24, 13), fill: .light),
            ArtPart(.ellipse(9, -24, 21, 6), rotation: -22)
        ]
        case "flower": return [
            ArtPart(.path("M9 0v-26M9-13 1-20")),
            ArtPart(.circle(9, -41, 7.5), fill: .accent),
            ArtPart(.circle(1, -33, 7.5), fill: .accent),
            ArtPart(.circle(17, -33, 7.5), fill: .accent),
            ArtPart(.circle(9, -25, 7.5), fill: .accent),
            ArtPart(.circle(9, -33, 6), fill: .light)
        ]
        case "lens": return [
            ArtPart(.circle(14, -33, 13), fill: .light, fillOpacity: 0.55),
            ArtPart(.path("M5-23 0-3"), width: 5)
        ]
        case "phone": return [
            ArtPart(.rect(0, -36, 21, 36, 3.5), fill: .accent),
            ArtPart(.rect(3.5, -31.5, 14, 24, 0), fill: .light),
            ArtPart(.circle(10.5, -4, 1.6), fill: .light)
        ]
        case "coin": return [
            ArtPart(.circle(10, -16, 15), fill: .light),
            ArtPart(.path("M10-28v24M17-25H7q-7 0-7 5.5t10 3.5q10 0 10 5.5T13-6H4"))
        ]
        case "shield": return [
            ArtPart(.path("M-6-40 9-45l15 5v18q-2 14-15 21-13-7-15-21z"), fill: .light),
            ArtPart(.path("M9-44V-2M-5-29h28"))
        ]
        case "umbrella": return [
            ArtPart(.path("M-13-30q8-24 21-24t21 24q-5 6-10.5 0-5 6-10.5 0-5 6-10.5 0-5 6-10.5 0z"), fill: .accent),
            ArtPart(.path("M8-54v-5M8-30v25q0 5 6 3")),
            ArtPart(.path("M-2-33q5-19 10-19M18-33q-5-19-10-19"), stroke: .light)
        ]
        case "wand": return [
            ArtPart(.path("M0-3 15-32"), width: 5),
            ArtPart(.path("m19-50 2.8 8.4h8.8l-7.1 5.2 2.7 8.4-7.2-5.2-7.2 5.2 2.7-8.4-7.1-5.2h8.8z"), fill: .light)
        ]
        case "palette": return [
            ArtPart(.path("M-6-27q3-21 22-17 17 4 13 20-3 15-16 12l-1-9q-19 3-18-6z"), fill: .light),
            ArtPart(.circle(3, -33, 3), fill: .accent, stroke: .none),
            ArtPart(.circle(16, -35, 3), fill: .accent, stroke: .none),
            ArtPart(.circle(23, -24, 3), fill: .accent, stroke: .none),
            ArtPart(.path("M0 0 13-21"))
        ]
        case "scepter": return [
            ArtPart(.path("M9 0v-36"), width: 5),
            ArtPart(.path("m-1-46 10-12 10 12-10 12z"), fill: .light)
        ]
        case "clock": return [
            ArtPart(.circle(10, -18, 16), fill: .light),
            ArtPart(.path("M10-29v11l8 5M3-37h14"))
        ]
        case "infinity": return [
            ArtPart(.path("M10-26C-16-52-19 2 10-26 39-52 36 2 10-26Z"), width: 6)
        ]
        case "journal": return [
            ArtPart(.rect(-2, -34, 24, 34, 2.5), fill: .accent),
            ArtPart(.path("M10-12 3.5-19q-3.5-4.5 1-6.5 3.5-1.5 5.5 2 2-3.5 5.5-2 4.5 2 1 6.5z"), fill: .light, stroke: .none)
        ]
        case "ball": return [
            ArtPart(.circle(10, -15, 15), fill: .accent),
            ArtPart(.path("M-5-15h30M10-30v30M-2-26q12 11 0 22M22-26q-12 11 0 22"), stroke: .light)
        ]
        case "skateboard": return [
            ArtPart(.path("M-8-14q-4 0-4-4t4-4h34q4 0 4 4t-4 4z"), fill: .accent),
            ArtPart(.path("M-6-20q6-4 12-2M-2-14v4M24-14v4")),
            ArtPart(.circle(-2, -5, 5), fill: .light),
            ArtPart(.circle(24, -5, 5), fill: .light)
        ]
        case "controller": return [
            ArtPart(.path("M-7-34q0-9 9-9h16q9 0 9 9l2 12q-3 8-9 2l-4-5H0l-4 5q-6 6-9-2z"), fill: .accent),
            ArtPart(.path("M-1-31h6M2-34v6"), stroke: .light),
            ArtPart(.circle(17, -32, 2.2), fill: .light),
            ArtPart(.circle(22, -27, 2.2), fill: .light)
        ]
        case "masks": return [
            ArtPart(.path("M-7-34q14-6 15 9 0 15-8 15t-7-24z"), fill: .light),
            ArtPart(.path("M-4-25h3M2-25h1M-4-16q5 4 8 0"), width: 1.8),
            ArtPart(.path("M13-34q14-6 15 9 0 15-8 15t-7-24z"), fill: .accent),
            ArtPart(.path("M16-25h3M22-25h1M16-13q5-4 8 0"), stroke: .light, width: 1.8)
        ]
        case "trumpet": return [
            ArtPart(.path("M-3-25h17"), width: 4),
            ArtPart(.path("M14-35 30-41v32l-16-6z"), fill: .accent),
            ArtPart(.path("M1-25v-7M8-25v-7")),
            ArtPart(.circle(-4, -25, 3.5))
        ]
        default: return []
        }
    }
    /// Vibe items keyed "vibe.slot" where slot is face, held or hand.
    static func worn(_ id: String) -> [ArtPart] {
        switch id {
        case "shades.face": return [
            ArtPart(.path("M-20 1H-4q0 11-8 11t-8-11z"), fill: .accent),
            ArtPart(.path("M20 1H4q0 11 8 11t8-11z"), fill: .accent),
            ArtPart(.path("M-4 3h8M-20 2-27 0M20 2 27 0"))
        ]
        case "lounge.face": return [
            ArtPart(.path("M-20 1H-4q0 11-8 11t-8-11z"), fill: .accent),
            ArtPart(.path("M20 1H4q0 11 8 11t8-11z"), fill: .accent),
            ArtPart(.path("M-4 3h8M-20 2-27 0M20 2 27 0"))
        ]
        case "book.held": return [
            ArtPart(.path("M-23 21q11-4 22 4 11-8 22-4v18q-11-4-22 4-11-8-22-4z"), fill: .light),
            ArtPart(.path("M-1 25v18M-18 26h11M-18 32h11M4 26h11M4 32h11"), width: 1.6)
        ]
        case "fire.hand": return [
            ArtPart(.path("M7-2-17-14"), stroke: .hex(0x7a5a3a)),
            ArtPart(.rect(-22, -19, 8, 8, 0), fill: .hex(0xfffde9), width: 1.5)
        ]
        default: return []
        }
    }
    /// Scenery beside a content pickle, in body coordinates shifted by (h - 91) vertically.
    static func scene(_ id: String) -> [ArtPart] {
        switch id {
        case "lounge": return [
            ArtPart(.circle(-26, 2, 9), fill: .hex(0xe6c95a), stroke: .hex(0xc9a53a)),
            ArtPart(.path("M-26-14V-10M-26 12V16M-42 2H-38M-14 2H-10M-37-9 -34-6M-18 10 -15 13M-37 13 -34 10M-18-6 -15-9"), stroke: .hex(0xc9a53a)),
            ArtPart(.path("M-16 100H84"), stroke: .hex(0xd9a066), width: 7),
            ArtPart(.path("M-12 100H80"), stroke: .hex(0xe6ecc5), width: 2, dash: 6),
            ArtPart(.rect(70, 80, 12, 18, 0), fill: .hex(0xdce7ac)),
            ArtPart(.path("M76 80V66")),
            ArtPart(.path("M64 66H88L76 58Z"), fill: .hex(0xc96a6a))
        ]
        case "fire": return [
            ArtPart(.path("M-38 100 -12 92M-38 92 -12 100"), stroke: .hex(0x7a5a3a), width: 5),
            ArtPart(.path("M-25 90Q-40 76-27 58Q-24 68-19 66Q-14 74-25 90Z"), fill: .hex(0xe0893a), stroke: .none, flicker: true),
            ArtPart(.path("M-25 88Q-32 78-26 68Q-23 74-20 72Q-18 80-25 88Z"), fill: .hex(0xf1c85c), stroke: .none, flicker: true)
        ]
        default: return []
        }
    }
}
