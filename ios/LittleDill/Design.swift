import SwiftUI

extension Color {
    init(hex: UInt32) { self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1) }
}
enum DillTheme {
    static let cream = Color(hex: 0xF8F6ED)
    static let ink = Color(hex: 0x263E31)
    static let muted = Color(hex: 0x6A7868)
    static let lime = Color(hex: 0xD4EB85)
    static let sage = Color(hex: 0xE7ECD9)
    static let peach = Color(hex: 0xF1C9B4)
    static let line = Color(hex: 0xDDE1D2)
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .serif) }
}
struct DillButton: ButtonStyle {
    var light = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(.headline, design: .rounded)).frame(maxWidth: .infinity).padding(.vertical, 18)
            .foregroundStyle(light ? DillTheme.ink : DillTheme.cream)
            .background(light ? DillTheme.lime : DillTheme.ink, in: RoundedRectangle(cornerRadius: 22))
            .scaleEffect(configuration.isPressed ? 0.97 : 1).opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
struct Eyebrow: View {
    let text: String
    var body: some View { Text(text.uppercased()).font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(2).foregroundStyle(DillTheme.muted) }
}
struct CoinPill: View {
    let amount: Int
    var body: some View {
        HStack(spacing: 5) { Image(systemName: "sparkle"); Text("\(amount)").monospacedDigit() }
            .font(.system(size: 13, weight: .bold, design: .rounded)).padding(.horizontal, 12).padding(.vertical, 9)
            .background(.white.opacity(0.7), in: Capsule()).overlay(Capsule().stroke(DillTheme.line, lineWidth: 1))
            .accessibilityLabel("\(amount) crunch coins")
    }
}
struct PageHeading: View {
    let eyebrow: String
    let title: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Eyebrow(text: eyebrow)
            Text(title).font(DillTheme.display(38)).tracking(-1.5).fixedSize(horizontal: false, vertical: true)
            Text(detail).font(.subheadline).foregroundStyle(DillTheme.muted).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct SoftCard<Content: View>: View {
    var color: Color = .white.opacity(0.65)
    @ViewBuilder var content: Content
    var body: some View { content.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(color, in: RoundedRectangle(cornerRadius: 26)).overlay(RoundedRectangle(cornerRadius: 26).stroke(DillTheme.line.opacity(0.6), lineWidth: 1)) }
}
