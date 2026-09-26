import SwiftUI

/// The pet arcade: the three web games plus Pickle hop, Cuke chop and Jar toss. Rules live in the Arcade*.swift files.
struct ArcadeSheet: View {
    @EnvironmentObject private var store: DillStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var engine: (any ArcadePlay)?
    @State private var gained: Int?
    @State private var notice: String?
    @State private var lastFrame: Date?

    private static let noteSounds: [DillSound] = [.pop, .dash, .respawn]
    private static let heart = Color(hex: 0xC8553D)

    private var paused: Bool { scenePhase != .active }
    private var running: Bool {
        guard let game = engine else { return false }
        return !game.isFinished
    }
    private var canPlay: Bool { store.pet.adopted && !store.pet.life.dead && !store.pet.life.sleeping }
    private var menuStatus: String? {
        if !store.pet.adopted { return "hatch your pickle first. then it’s game time." }
        if store.pet.life.dead { return "every ending is a new beginning" }
        if store.pet.life.sleeping { return "shh… your pickle is napping. wake them to play." }
        if store.pet.energy < 6 { return "a little nap first! games need 6 energy." }
        return nil
    }

    var body: some View {
        ZStack {
            DillTheme.cream.ignoresSafeArea()
            GeometryReader { viewport in
                ScrollView {
                    FillHeight(minHeight: viewport.size.height) {
                        VStack(spacing: 22) {
                            header
                            content
                        }
                        .padding(24)
                        .frame(maxWidth: 580)
                        .frame(maxWidth: .infinity)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .foregroundStyle(DillTheme.ink)
        .background(clock)
        .statusBarHidden(engine != nil)
        .persistentSystemOverlays(engine != nil ? .hidden : .automatic)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { lastFrame = nil }
        }
        .onChange(of: store.pet.life.dead) { _, dead in
            if dead { abandon() }
        }
        .onDisappear { abandon() }
    }

    private var clock: some View {
        TimelineView(.animation(minimumInterval: nil, paused: paused || !running)) { context in
            Color.clear.onChange(of: context.date) { _, date in tick(date) }
        }
        .accessibilityHidden(true)
    }

    private var header: some View {
        HStack {
            if engine?.isFinished != true {
                Button { abandon(); dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .semibold))
                        .frame(width: 44, height: 44).background(DillTheme.sage, in: Circle())
                }
                .accessibilityLabel(engine == nil ? "Back" : "Leave game")
                .accessibilityIdentifier("arcade.close")
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
            Spacer()
            Eyebrow(text: engine == nil ? "The dill arcade" : "6 energy per game")
            Spacer()
            Label("\(Int(store.pet.energy.rounded()))", systemImage: "bolt.fill")
                .font(.system(size: 12, weight: .bold, design: .rounded)).monospacedDigit()
                .frame(minWidth: 44)
                .accessibilityLabel("\(Int(store.pet.energy.rounded())) energy")
        }
    }

    @ViewBuilder private var content: some View {
        if let game = engine {
            playing(game)
        } else {
            menu
        }
    }

    // MARK: Menu

    private var menu: some View {
        VStack(spacing: 20) {
            PageHeading(eyebrow: "Pick your kind of pickle play", title: "The dill\narcade.", detail: "6 energy per game · 10–34 happy ♥ for every finished round.")
            VStack(spacing: 12) {
                ForEach(ArcadeGame.allCases) { game in gameCard(game) }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("arcade.menu")
            if let text = notice ?? menuStatus {
                Text(text).font(.system(size: 13, weight: .medium, design: .rounded)).multilineTextAlignment(.center)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(DillTheme.peach.opacity(0.55), in: Capsule())
            }
        }
    }

    private func gameCard(_ game: ArcadeGame) -> some View {
        Button { start(game) } label: {
            HStack(spacing: 16) {
                Text(game.glyph).font(.system(size: 28, weight: .bold))
                    .frame(width: 56, height: 56)
                    .background(DillTheme.lime, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                VStack(alignment: .leading, spacing: 5) {
                    Text(game.title).font(DillTheme.display(22))
                    Text(game.tagline).font(.caption).foregroundStyle(DillTheme.muted)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 3) {
                    Eyebrow(text: "Best")
                    Text("\(best(game))").font(.system(size: 20, weight: .bold, design: .rounded)).monospacedDigit()
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(DillTheme.line, lineWidth: 1))
        }
        .buttonStyle(ArcadePress())
        .disabled(!canPlay)
        .opacity(canPlay ? 1 : 0.55)
        .accessibilityLabel("\(game.title), \(game.tagline). Best \(best(game))")
        .accessibilityIdentifier("arcade.game.\(game.rawValue)")
    }

    // MARK: Game

    private func playing(_ game: any ArcadePlay) -> some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Text(game.game.title).font(DillTheme.display(38)).tracking(-1)
                Text(game.meta(best: best(game.game)))
                    .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.5)
                    .foregroundStyle(DillTheme.muted)
            }
            .fixedSize(horizontal: false, vertical: true)
            if !game.isFinished {
                Text(game.message).font(.system(size: 13, weight: .medium, design: .rounded)).multilineTextAlignment(.center)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(DillTheme.sage, in: Capsule())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.updatesFrequently)
            }
            if game.game.isClassic {
                board(game)
                if game.isFinished { result(game) }
            } else {
                ZStack {
                    board(game)
                    if game.isFinished { result(game).padding(16) }
                }
            }
        }
    }

    @ViewBuilder private func board(_ game: any ArcadePlay) -> some View {
        if let classic = game as? ArcadeEngine {
            switch classic.game {
            case .hunt: jars(classic)
            case .memory: pads(classic)
            default: lanes(classic)
            }
        } else if let run = game as? HopRun {
            HopBoard(run: run, look: ArcadeArt.look(store.pet), reduceMotion: reduceMotion) { apply(HopRun.self) { $0.hop() } }
                .frame(minHeight: 360, maxHeight: .infinity)
        } else if let run = game as? ChopRun {
            ChopBoard(run: run, look: ArcadeArt.look(store.pet),
                      swipe: { from, to in apply(ChopRun.self) { $0.swipe(from: from, to: to) } },
                      lift: { apply(ChopRun.self) { $0.endSwipe() } })
                .frame(minHeight: 360, maxHeight: .infinity)
        } else if let run = game as? TossRun {
            TossBoard(run: run, look: ArcadeArt.look(store.pet), reduceMotion: reduceMotion,
                      aim: { pull in apply(TossRun.self) { $0.aim(pull) } },
                      release: { apply(TossRun.self) { $0.release() } })
                .frame(minHeight: 360, maxHeight: .infinity)
        }
    }

    private func jarAnimation(_ game: ArcadeEngine) -> Animation? {
        if reduceMotion || game.shuffleDuration <= 0 { return nil }
        return .spring(duration: game.shuffleDuration, bounce: 0.25)
    }

    private func jars(_ game: ArcadeEngine) -> some View {
        GeometryReader { proxy in
            let step = proxy.size.width / 3
            let unit = min(2.2, max(0.8, min(step / 100, (proxy.size.height - 40) / 115)))
            let tall = min(1.6, max(1, (proxy.size.height * 0.6 - 24 * unit) / (76 * unit)))
            ZStack(alignment: .topLeading) {
                ForEach(0..<3, id: \.self) { jar in
                    jarButton(game, jar: jar, size: CGSize(width: step, height: proxy.size.height), unit: unit, tall: tall)
                        .offset(x: CGFloat(game.slot(ofJar: jar)) * step)
                }
            }
        }
        .frame(minHeight: 150, maxHeight: 600)
        .background(DillTheme.sage.opacity(0.6), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .animation(jarAnimation(game), value: game.order)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: game.revealed)
    }

    private func jarButton(_ game: ArcadeEngine, jar: Int, size: CGSize, unit: CGFloat, tall: CGFloat) -> some View {
        let slot = game.slot(ofJar: jar)
        let shown = game.revealed.contains(jar)
        let hasHeart = jar == game.winner
        let value: String = shown ? (hasHeart ? "heart" : "empty") : ""
        return Button { choose(jar) } label: {
            VStack(spacing: 8 * unit) {
                ArcadeJar(hasHeart: hasHeart, shown: shown, picked: game.picked == jar, heart: Self.heart, unit: unit, tall: tall)
                Text("\(slot + 1)").font(.system(size: 11 * min(unit, 1.5), weight: .bold, design: .monospaced))
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
        }
        .buttonStyle(ArcadePress())
        .disabled(game.phase != .choose || paused)
        .accessibilityLabel("Jar \(slot + 1)")
        .accessibilityValue(value)
        .accessibilityIdentifier("arcade.jar.\(slot)")
    }

    private func pads(_ game: ArcadeEngine) -> some View {
        GeometryReader { proxy in
            let side = min((proxy.size.width - 24) / 3, proxy.size.height)
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { pad in padButton(game, pad: pad, unit: min(2.2, max(1, side / 75))) }
            }
        }
        .frame(minHeight: 140, maxHeight: 560)
    }

    private func padButton(_ game: ArcadeEngine, pad: Int, unit: CGFloat) -> some View {
        let lit = game.litNote == pad
        let names = ["circle", "diamond", "star"]
        return Button { note(pad) } label: {
            VStack(spacing: 6 * unit) {
                Text(MemoryRules.shapes[pad]).font(.system(size: 34 * unit, weight: .bold))
                Text("\(pad + 1)").font(.system(size: 11 * min(unit, 1.5), weight: .bold, design: .monospaced))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(lit ? DillTheme.cream : DillTheme.ink)
            .background(lit ? DillTheme.ink : DillTheme.lime.opacity(0.6), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(DillTheme.ink.opacity(0.25), lineWidth: 1))
            .offset(y: lit ? 3 : 0)
        }
        .buttonStyle(ArcadePress())
        .disabled(game.phase != .respond || paused)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: lit)
        .accessibilityLabel("Play note \(pad + 1), \(names[pad])")
        .accessibilityIdentifier("arcade.pad.\(pad)")
    }

    private func lanes(_ game: ArcadeEngine) -> some View {
        let enabled = game.acceptsInput && !paused
        return VStack(spacing: 12) {
            GeometryReader { proxy in
                let laneWidth = proxy.size.width / 3
                let unit = min(1.8, max(1, min(laneWidth / 90, proxy.size.height / 230)))
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { lane in laneButton(game, lane: lane, enabled: enabled) }
                    }
                    if let drop = game.drop, let progress = game.dropProgress {
                        dropView(drop, progress: progress, laneWidth: laneWidth, height: proxy.size.height, unit: unit)
                    }
                    basket(game, laneWidth: laneWidth, height: proxy.size.height, unit: unit)
                }
            }
            .frame(minHeight: 230, maxHeight: 640)
            .background(DillTheme.sage, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            HStack(spacing: 12) {
                Button { shift(-1) } label: { Label("Left", systemImage: "arrow.left") }
                    .accessibilityLabel("Move basket left one lane")
                Button { shift(1) } label: { Label("Right", systemImage: "arrow.right") }
                    .accessibilityLabel("Move basket right one lane")
            }
            .buttonStyle(DillButton(light: true))
            .disabled(!enabled)
        }
    }

    private func laneButton(_ game: ArcadeEngine, lane: Int, enabled: Bool) -> some View {
        let selected = game.basket == lane
        let names = ["Move basket left", "Move basket center", "Move basket right"]
        return Button { move(lane) } label: {
            Rectangle().fill(selected ? DillTheme.lime.opacity(0.45) : Color.clear)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(ArcadePress(pressScale: 1))
        .overlay(alignment: .trailing) {
            if lane < 2 { Rectangle().fill(DillTheme.ink.opacity(0.12)).frame(width: 1) }
        }
        .disabled(!enabled)
        .accessibilityLabel(names[lane])
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("arcade.lane.\(lane)")
    }

    private func dropView(_ drop: CatchDrop, progress: Double, laneWidth: CGFloat, height: CGFloat, unit: CGFloat) -> some View {
        let fall = max(0, height - 100 * unit)
        let travel: CGFloat = reduceMotion ? 0 : CGFloat(progress) * fall
        return Text(drop.salt ? "×" : "♥")
            .font(.system(size: 36 * unit, weight: .black, design: .rounded))
            .foregroundStyle(drop.salt ? DillTheme.ink : Self.heart)
            .frame(width: laneWidth, height: 44 * unit)
            .offset(x: CGFloat(drop.lane) * laneWidth, y: 10 * unit + travel)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func basket(_ game: ArcadeEngine, laneWidth: CGFloat, height: CGFloat, unit: CGFloat) -> some View {
        Image(systemName: "basket.fill")
            .font(.system(size: 36 * unit, weight: .bold))
            .frame(width: laneWidth, height: 48 * unit)
            .offset(x: CGFloat(game.basket) * laneWidth, y: height - 60 * unit)
            .animation(reduceMotion ? nil : .spring(duration: 0.22, bounce: 0.3), value: game.basket)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func result(_ game: any ArcadePlay) -> some View {
        let text = (game.finishMessage ?? "") + " +\(gained ?? 0) happy ♥"
        return VStack(spacing: 16) {
            Text(text).font(DillTheme.display(26)).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("arcade.result")
            Text("Best \(best(game.game))").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(DillTheme.muted)
            Button { start(game.game) } label: { Label("Play again", systemImage: "arrow.clockwise") }
                .buttonStyle(DillButton())
                .accessibilityIdentifier("arcade.again")
            HStack(spacing: 12) {
                Button { showMenu() } label: { Text("Games") }
                    .buttonStyle(DillButton(light: true))
                    .accessibilityIdentifier("arcade.games")
                Button { abandon(); dismiss() } label: { Text("Back") }
                    .buttonStyle(DillButton(light: true))
                    .accessibilityIdentifier("arcade.close")
            }
        }
        .padding(22)
        .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(DillTheme.line, lineWidth: 1))
    }

    // MARK: Actions

    private func best(_ game: ArcadeGame) -> Int { store.pet.arcadeRecords[game.rawValue] ?? 0 }

    private func start(_ game: ArcadeGame) {
        abandon()
        notice = nil
        guard store.startArcade() else {
            notice = menuStatus ?? "a little nap first! games need 6 energy."
            store.feedback(.rigid)
            return
        }
        lastFrame = nil
        engine = game.play(reduceMotion: reduceMotion)
        store.sound(.respawn)
        store.feedback(.medium)
    }

    private func showMenu() {
        abandon()
        notice = nil
    }

    /// Leaves the current game. An unfinished game ends without the completion reward.
    private func abandon() {
        guard let game = engine else { return }
        engine = nil
        gained = nil
        lastFrame = nil
        if !game.isFinished {
            store.finishArcade(game: game.game.rawValue, score: game.score, completed: false)
        }
    }

    private func tick(_ date: Date) {
        guard !paused, var game = engine, !game.isFinished else { lastFrame = nil; return }
        guard store.arcadeActive else { abandon(); return }
        var step = 0.0
        if let previous = lastFrame { step = min(0.1, max(0, date.timeIntervalSince(previous))) }
        lastFrame = date
        let cues = game.advance(by: step)
        engine = game
        play(cues)
    }

    private func choose(_ jar: Int) { apply(ArcadeEngine.self) { $0.chooseJar(jar) } }
    private func note(_ pad: Int) { apply(ArcadeEngine.self) { $0.chooseNote(pad) } }
    private func move(_ lane: Int) { apply(ArcadeEngine.self) { $0.moveBasket(lane) } }
    private func shift(_ delta: Int) {
        apply(ArcadeEngine.self) { game in
            let lane = game.basket + delta
            return game.moveBasket(lane)
        }
    }

    private func apply<Game: ArcadePlay>(_ kind: Game.Type, _ action: (inout Game) -> [ArcadeCue]) {
        guard !paused, var game = engine as? Game, !game.isFinished else { return }
        let cues = action(&game)
        engine = game
        play(cues)
    }

    private func play(_ cues: [ArcadeCue]) {
        for cue in cues {
            switch cue {
            case .shuffle: store.sound(.dash)
            case .good: store.sound(.crunch); store.feedback(.medium)
            case .miss: store.sound(.pop); store.feedback(.rigid)
            case .select: store.feedback(.light)
            case let .note(pad): store.sound(Self.noteSounds[pad]); store.feedback(.light)
            case .hop: store.sound(.hop); store.feedback(.light)
            case .ding: store.sound(.ding)
            case .chop: store.sound(.chop); store.feedback(.light)
            case .bonk: store.sound(.boing); store.feedback(.heavy)
            case .fling: store.sound(.dash); store.feedback(.medium)
            case .splash: store.sound(.splash); store.feedback(.medium)
            case .clank: store.sound(.clank); store.feedback(.rigid)
            case .finished: complete()
            }
        }
    }

    private func complete() {
        guard let game = engine, gained == nil else { return }
        gained = store.finishArcade(game: game.game.rawValue, score: game.score, completed: true)
        store.sound(game.score > 0 ? .win : .pet)
        store.feedback(game.score > 0 ? .medium : .soft)
    }
}

private struct ArcadePress: ButtonStyle {
    var pressScale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressScale : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct ArcadeJar: View {
    let hasHeart: Bool
    let shown: Bool
    let picked: Bool
    let heart: Color
    var unit: CGFloat = 1
    var tall: CGFloat = 1
    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 12 * unit, style: .continuous)
                .fill(DillTheme.lime.opacity(0.55))
                .overlay(RoundedRectangle(cornerRadius: 12 * unit, style: .continuous).stroke(DillTheme.ink, lineWidth: 3 * unit))
                .frame(width: 64 * unit, height: 76 * unit * tall)
                .padding(.top, 8 * unit)
            Capsule().fill(Color.white.opacity(0.6)).frame(width: 5 * unit, height: 34 * unit * tall).offset(x: -20 * unit, y: 22 * unit)
            Capsule().fill(DillTheme.ink).frame(width: 74 * unit, height: 13 * unit)
            Text(hasHeart ? "♥" : "·")
                .font(.system(size: 32 * unit, weight: .black, design: .rounded))
                .foregroundStyle(hasHeart ? heart : DillTheme.ink)
                .padding(.top, (38 * tall - 8) * unit)
                .opacity(shown ? 1 : 0)
                .scaleEffect(shown ? 1 : 0.4)
        }
        .padding(8 * unit)
        .overlay(
            RoundedRectangle(cornerRadius: 18 * unit, style: .continuous)
                .stroke(DillTheme.ink, style: StrokeStyle(lineWidth: 2 * unit, dash: [5 * unit, 4 * unit]))
                .opacity(picked ? 1 : 0)
        )
        .accessibilityHidden(true)
    }
}
