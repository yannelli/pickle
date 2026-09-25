import SwiftUI

@main
struct LittleDillApp: App {
    @StateObject private var store: DillStore
    init() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ui-testing") {
            let defaults = UserDefaults(suiteName: "little-dill.ui-tests")!
            if arguments.contains("--reset") { defaults.removePersistentDomain(forName: "little-dill.ui-tests") }
            DebugClock.fastHatch = arguments.contains("--fast-hatch")
            _store = StateObject(wrappedValue: DillStore(defaults: defaults, clock: { DebugClock.now }))
        } else { _store = StateObject(wrappedValue: DillStore()) }
        #else
        _store = StateObject(wrappedValue: DillStore())
        #endif
    }
    var body: some Scene {
        WindowGroup { RootView().environmentObject(store).tint(DillTheme.ink).preferredColorScheme(.light) }
    }
}

#if DEBUG
/// UI tests pass `--fast-hatch` so brining jumps the store clock past the one-minute hatch.
enum DebugClock {
    static var fastHatch = false
    private static var offset: TimeInterval = 0
    static var now: Date { Date().addingTimeInterval(offset) }
    static func skipHatch() { if fastHatch { offset += Double(PetLife.HATCH_MS) / 1000 + 1 } }
}
#endif

enum DillTab: String, CaseIterable { case nest = "Nest", play = "Play", friends = "Friends", closet = "Closet"
    var symbol: String {
        switch self { case .nest: return "house.fill"; case .play: return "gamecontroller.fill"; case .friends: return "person.2.fill"; case .closet: return "tshirt.fill" }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: DillStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: DillTab = .nest
    @State private var settings = false
    @State private var challenge: GameLaunch?
    @State private var pendingChallenge: DailyChallenge?
    @State private var arena: ArenaLaunch?
    @State private var pendingArena: ArenaLaunch?
    var body: some View {
        ZStack {
            DillTheme.cream.ignoresSafeArea()
            if store.pet.adopted {
                VStack(spacing: 0) {
                    HStack {
                        Text("little dill.").font(DillTheme.display(27)).tracking(-1.5)
                        Spacer()
                        CoinPill(amount: store.pet.coins)
                        Button { settings = true } label: { Image(systemName: "slider.horizontal.3").font(.system(size: 18)).frame(width:44,height:44) }.accessibilityLabel("Settings")
                    }.padding(.horizontal,24).padding(.top,8).padding(.bottom,10)
                    ScrollViewReader { scroll in
                    ScrollView {
                        VStack(spacing: 24) {
                            switch tab {
                            case .nest: NestView(play: { openDaily() }, closet: { tab = .closet }, arena:{arena = ArenaLaunch()}, revealCare:{withAnimation(.easeInOut(duration:0.3)) {scroll.scrollTo("careStage",anchor:.top)}})
                            case .play: PlayView(launch: { challenge = $0 }, arena:{arena = ArenaLaunch()})
                            case .friends: FriendsView(arena:{arena = $0})
                            case .closet: ClosetView()
                            }
                        }.padding(.horizontal,24).padding(.top,12).padding(.bottom,28).frame(maxWidth:640).frame(maxWidth:.infinity)
                    }.scrollIndicators(.hidden).clipped()
                    }
                    HStack(spacing:4) {
                        ForEach(DillTab.allCases,id:\.self) { item in
                            Button { store.feedback(); tab = item } label: {
                                VStack(spacing:5) { Image(systemName:item.symbol).font(.system(size:19)); Text(item.rawValue).font(.system(size:10,weight:.semibold,design:.rounded)) }
                                    .frame(maxWidth:.infinity).frame(minHeight:54).foregroundStyle(tab == item ? DillTheme.ink : DillTheme.muted)
                                    .background(tab == item ? DillTheme.sage : .clear,in:RoundedRectangle(cornerRadius:19))
                            }.accessibilityIdentifier("tab.\(item.rawValue)").accessibilityAddTraits(tab == item ? .isSelected : [])
                        }
                    }.padding(7).frame(maxWidth:500).background(DillTheme.cream.opacity(0.98),in:RoundedRectangle(cornerRadius:26))
                        .overlay(RoundedRectangle(cornerRadius:26).stroke(DillTheme.line,lineWidth:1)).padding(.horizontal,24).padding(.bottom,8)
                        .frame(maxWidth:.infinity).background(DillTheme.cream.ignoresSafeArea(edges:.bottom))
                }
            } else { NurseryView() }
        }
        .foregroundStyle(DillTheme.ink)
        .sheet(isPresented:$settings) { SettingsView().environmentObject(store) }
        .fullScreenCover(item:$challenge) { launch in GameView(launch:launch).environmentObject(store) }
        .fullScreenCover(item:$arena) {launch in ArenaView(launch:launch).id(launch.id).environmentObject(store)}
        .onChange(of:scenePhase) { _,phase in if phase == .active { store.tick() } else { store.save(); DillAudio.shared.stop() } }
        .task(id:store.pet.life.phase) {
            // Web TICK_MS: every 3 s for a living pickle, every second while it brines or waits for a name.
            while !Task.isCancelled {
                try? await Task.sleep(for:.seconds(store.pet.life.phase == .living ? 3 : 1))
                if !Task.isCancelled { store.tick() }
            }
        }
        .onOpenURL { url in
            guard !url.isFileURL else { return }
            if let launch = ArenaLaunch.from(url) {
                if store.pet.adopted {arena = launch} else {pendingArena = launch}
                return
            }
            guard let daily = DailyChallenge.from(url) else { store.notice = "That challenge link isn’t valid."; return }
            if store.pet.adopted { challenge = .solo(daily) } else { pendingChallenge = daily }
        }
        .dillBackupOpening()
        .onChange(of:store.pet.adopted) { _,adopted in
            if adopted, let launch = pendingArena {arena = launch; pendingArena = nil}
            if adopted, let daily = pendingChallenge { challenge = .solo(daily); pendingChallenge = nil }
        }
        .alert("A little heads-up",isPresented:Binding(get:{store.notice != nil},set:{if !$0 {store.notice = nil}})) { Button("Got it") { store.notice = nil } } message: { Text(store.notice ?? "") }
    }
    private func openDaily() { challenge = .solo(DailyChallenge(day:DailyChallenge.today())) }
}
