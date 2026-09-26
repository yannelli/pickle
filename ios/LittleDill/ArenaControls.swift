import SwiftUI

struct ArenaStickInput {
    let offset: CGSize
    let direction: CGVector
    let atEdge: Bool

    static func resolve(delta: CGSize, reach: CGFloat) -> Self {
        let length = hypot(delta.width, delta.height)
        guard length > 0 else { return Self(offset: .zero, direction: .zero, atEdge: false) }
        let amount = min(1, length / reach)
        let speed = pow(max(0, (amount - 0.12) / 0.88), 1.35)
        let x = delta.width / length, y = delta.height / length
        return Self(offset: CGSize(width: x * amount * reach, height: y * amount * reach),
                    direction: CGVector(dx: x * speed, dy: y * speed), atEdge: amount >= 0.95)
    }
}

struct ArenaControls: View {
    let me: ArenaPlayer
    let compact: Bool
    let swapped: Bool
    @Binding var stick: CGSize
    let steer: (CGVector) -> Void
    let split: () -> Void
    let dash: () -> Void
    let swap: () -> Void
    let feedback: (ArenaFeedbackCue) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragging = false
    @State private var atEdge = false

    private var diameter: CGFloat { compact ? 88 : 104 }
    private var reach: CGFloat { compact ? 28 : 34 }

    var body: some View {
        VStack(spacing: compact ? 2 : 6) {
            HStack(alignment: .bottom, spacing: 12) {
                if swapped { actions; Spacer(minLength: 0); joystick }
                else { joystick; Spacer(minLength: 0); actions }
            }
            HStack(spacing: 8) {
                Text(me.regroupHint)
                    .font(.system(size: compact ? 10 : 11, weight: .medium, design: .rounded))
                    .lineLimit(2).minimumScaleFactor(0.8)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(DillTheme.cream.opacity(0.85), in: Capsule())
                    .accessibilityIdentifier("arenaRegroup")
                Spacer(minLength: 0)
                Button { release(); swap(); feedback(.stick) } label: {
                    Label("Swap", systemImage: "arrow.left.arrow.right")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 12).frame(minHeight: 44)
                        .background(DillTheme.cream.opacity(0.9), in: Capsule())
                }
                .accessibilityLabel("Swap arena controls")
                .accessibilityValue(swapped ? "Joystick on right" : "Joystick on left")
                .accessibilityIdentifier("arenaSwapControls")
            }
        }
        .padding(.horizontal, 20).padding(.bottom, compact ? 2 : 8)
        .onDisappear { release() }
    }

    private var joystick: some View {
        ZStack {
            Circle().fill(DillTheme.cream.opacity(0.8))
                .overlay(Circle().stroke(DillTheme.ink.opacity(dragging ? 0.35 : 0.15), lineWidth: dragging ? 2 : 1))
            Image(systemName: "plus").font(.system(size: 35, weight: .ultraLight))
                .foregroundStyle(DillTheme.ink.opacity(0.2))
            Path { path in
                path.move(to: CGPoint(x: diameter / 2, y: diameter / 2))
                path.addLine(to: CGPoint(x: diameter / 2 + stick.width, y: diameter / 2 + stick.height))
            }.stroke(DillTheme.ink.opacity(0.25), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            Circle().fill(DillTheme.ink).frame(width: 46, height: 46)
                .overlay(Image(systemName: "leaf.fill").foregroundStyle(DillTheme.lime))
                .shadow(color: DillTheme.ink.opacity(dragging ? 0.25 : 0.1), radius: dragging ? 6 : 2, y: 2)
                .offset(stick)
                .animation(reduceMotion || dragging ? nil : .spring(response: 0.2, dampingFraction: 0.8), value: stick)
        }
        .frame(width: diameter, height: diameter).contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
            if !dragging { dragging = true; feedback(.stick) }
            let input = ArenaStickInput.resolve(delta: CGSize(width: value.location.x - diameter / 2,
                                                              height: value.location.y - diameter / 2), reach: reach)
            stick = input.offset; steer(input.direction)
            if input.atEdge && !atEdge { feedback(.edge) }
            atEdge = input.atEdge
        }.onEnded { _ in release() })
        .accessibilityElement(children: .ignore).accessibilityLabel("Steer your pickle")
        .accessibilityValue(swapped ? "Right thumb" : "Left thumb")
        .accessibilityAction(named: Text("Move up")) { steer(CGVector(dx: 0, dy: -1)) }
        .accessibilityAction(named: Text("Move down")) { steer(CGVector(dx: 0, dy: 1)) }
        .accessibilityAction(named: Text("Move left")) { steer(CGVector(dx: -1, dy: 0)) }
        .accessibilityAction(named: Text("Move right")) { steer(CGVector(dx: 1, dy: 0)) }
        .accessibilityAction(named: Text("Stop moving")) { release() }
        .accessibilityIdentifier("arenaJoystick")
    }

    private var actions: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 5) {
                action(symbol: "arrow.triangle.branch", title: "SPLIT", cooldown: me.splitCooldown ?? 0,
                       duration: 1, enabled: me.canSplit, light: true, perform: split)
                    .accessibilityLabel("Split your pickle").accessibilityValue(me.splitHint)
                    .accessibilityIdentifier("arenaSplit")
                Text(me.splitHint).frame(width: 80, height: 22)
            }
            VStack(spacing: 5) {
                action(symbol: "bolt.fill", title: "DASH", cooldown: me.cooldown, duration: 4,
                       enabled: me.cooldown <= 0 && me.mass >= 35, light: false, perform: dash)
                    .accessibilityLabel("Dash").accessibilityValue(me.cooldown > 0 ? "Ready in \(Int(ceil(me.cooldown))) seconds" : "Costs 5 mass")
                    .accessibilityIdentifier("arenaDash")
                Text(me.mass < 35 ? "Grow to 35" : "Costs 5 mass").frame(width: 76, height: 22)
            }
        }
        .font(.system(size: 8, weight: .medium)).lineLimit(2).multilineTextAlignment(.center)
        .foregroundStyle(DillTheme.muted)
    }

    private func action(symbol: String, title: String, cooldown: Double, duration: Double,
                        enabled: Bool, light: Bool, perform: @escaping () -> Void) -> some View {
        Button { feedback(.stick); perform() } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 24, weight: .semibold))
                Text(cooldown > 0 ? "\(Int(ceil(cooldown)))s" : title)
                    .font(.system(size: 10, weight: .black, design: .rounded)).monospacedDigit()
            }
            .frame(width: compact ? 66 : 72, height: compact ? 66 : 72)
            .foregroundStyle(light ? DillTheme.ink : DillTheme.lime)
            .background(light ? DillTheme.lime : DillTheme.ink, in: Circle())
            .overlay(Circle().stroke(DillTheme.cream.opacity(0.6), lineWidth: 3))
            .overlay {
                if cooldown > 0 {
                    Circle().trim(from: 0, to: min(1, max(0, 1 - cooldown / duration)))
                        .stroke(light ? DillTheme.ink : DillTheme.lime, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90)).padding(2)
                }
            }
        }
        .buttonStyle(ArenaActionPress()).disabled(!enabled).opacity(enabled || cooldown > 0 ? 1 : 0.5)
    }

    private func release() { dragging = false; atEdge = false; stick = .zero; steer(.zero) }
}

private struct ArenaActionPress: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
