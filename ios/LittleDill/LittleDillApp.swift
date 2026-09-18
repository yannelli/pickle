import SwiftUI

@main
struct LittleDillApp: App {
    @StateObject private var store: DillStore
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let defaults = UserDefaults(suiteName: "little-dill.ui-tests")!
            if ProcessInfo.processInfo.arguments.contains("--reset") { defaults.removePersistentDomain(forName: "little-dill.ui-tests") }
            _store = StateObject(wrappedValue: DillStore(defaults: defaults))
        } else { _store = StateObject(wrappedValue: DillStore()) }
        #else
        _store = StateObject(wrappedValue: DillStore())
        #endif
    }
    var body: some Scene {
        WindowGroup { RootView().environmentObject(store).tint(DillTheme.ink).preferredColorScheme(.light) }
    }
}

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
            } else { WelcomeView() }
        }
        .foregroundStyle(DillTheme.ink)
        .sheet(isPresented:$settings) { SettingsView().environmentObject(store) }
        .fullScreenCover(item:$challenge) { launch in GameView(launch:launch).environmentObject(store) }
        .fullScreenCover(item:$arena) {launch in ArenaView(launch:launch).id(launch.id).environmentObject(store)}
        .onChange(of:scenePhase) { _,phase in if phase == .active { store.refresh() } else { store.save(); DillAudio.shared.stop() } }
        .onOpenURL { url in
            if let launch = ArenaLaunch.from(url) {
                if store.pet.adopted {arena = launch} else {pendingArena = launch}
                return
            }
            guard let daily = DailyChallenge.from(url) else { store.notice = "That challenge link isn’t valid."; return }
            if store.pet.adopted { challenge = .solo(daily) } else { pendingChallenge = daily }
        }
        .onChange(of:store.pet.adopted) { _,adopted in
            if adopted, let launch = pendingArena {arena = launch; pendingArena = nil}
            if adopted, let daily = pendingChallenge { challenge = .solo(daily); pendingChallenge = nil }
        }
        .alert("A little heads-up",isPresented:Binding(get:{store.notice != nil},set:{if !$0 {store.notice = nil}})) { Button("Got it") { store.notice = nil } } message: { Text(store.notice ?? "") }
    }
    private func openDaily() { challenge = .solo(DailyChallenge(day:DailyChallenge.today())) }
}

struct WelcomeView: View {
    @EnvironmentObject private var store: DillStore
    @State private var name = "Dilly"
    @State private var brine: Brine = .classic
    @FocusState private var editing: Bool
    var body: some View {
        ScrollView {
            VStack(spacing:26) {
                HStack { Text("little dill.").font(DillTheme.display(29)).tracking(-1); Spacer(); Eyebrow(text:"A tiny companion") }
                VStack(spacing:8) {
                    Text("Life’s better\nwith a little dill.").font(DillTheme.display(44)).tracking(-2).multilineTextAlignment(.center)
                    Text("Raise a cutie. Challenge your people.\nMake a very big dill out of the little things.").font(.subheadline).foregroundStyle(DillTheme.muted).multilineTextAlignment(.center)
                }
                ZStack {
                    Circle().fill(DillTheme.sage).frame(width:215,height:215)
                    PickleCharacter(brine:brine,outfit:.sprout,happy:true).frame(width:245,height:245)
                    Text("100% friend-shaped").font(.system(size:11,weight:.semibold,design:.rounded)).padding(.horizontal,15).padding(.vertical,10).background(DillTheme.peach,in:Capsule()).rotationEffect(.degrees(-8)).offset(x:-70,y:100)
                }.frame(height:250)
                VStack(alignment:.leading,spacing:12) {
                    Eyebrow(text:"01 / Pick your personality")
                    HStack(spacing:8) {
                        ForEach(Brine.allCases) { option in
                            Button { brine = option; store.feedback() } label: {
                                VStack(spacing:6) { Circle().fill(option.color).frame(width:18,height:18); Text(option.title).font(.system(size:13,weight:.semibold,design:.rounded)) }
                                    .frame(maxWidth:.infinity).padding(.vertical,14)
                                    .background(brine == option ? DillTheme.sage : .white.opacity(0.6),in:RoundedRectangle(cornerRadius:18))
                                    .overlay(RoundedRectangle(cornerRadius:18).stroke(brine == option ? DillTheme.ink : DillTheme.line,lineWidth:brine == option ? 2 : 1))
                            }.accessibilityAddTraits(brine == option ? .isSelected : [])
                        }
                    }
                    Text(brine.subtitle).font(.caption).foregroundStyle(DillTheme.muted)
                    Eyebrow(text:"02 / Give your pickle a name").padding(.top,8)
                    TextField("Your pickle’s name",text:$name).font(.system(.title3,design:.rounded,weight:.semibold)).padding(16).background(.white.opacity(0.7),in:RoundedRectangle(cornerRadius:18))
                        .focused($editing).submitLabel(.done).onSubmit { editing = false }.onChange(of:name) { _,value in name = String(value.prefix(18)) }.accessibilityIdentifier("petName")
                }
                Button { editing = false; store.adopt(name:name,brine:brine); store.feedback(.medium) } label: { HStack { Text("Meet your little dill"); Image(systemName:"arrow.right") } }.buttonStyle(DillButton()).accessibilityIdentifier("adopt")
                Text("No account. No pressure. Just a little joy.").font(.caption).foregroundStyle(DillTheme.muted)
            }.padding(26).frame(maxWidth:540).frame(maxWidth:.infinity)
        }.scrollIndicators(.hidden).scrollDismissesKeyboard(.interactively)
    }
}

struct NestView: View {
    @EnvironmentObject private var store: DillStore
    let play: () -> Void
    let closet: () -> Void
    let arena: () -> Void
    @State private var message = "emotionally attached? same."
    var revealCare: () -> Void = {}
    @State private var performance: CarePerformance?
    @State private var reactionTask: Task<Void,Never>?
    var body: some View {
        VStack(spacing:22) {
            VStack(alignment:.leading,spacing:12) {
                HStack {
                    Eyebrow(text:"A little love, every day")
                    Spacer(minLength:4)
                    Label("\(store.pet.streak) day\(store.pet.streak == 1 ? "" : "s")",systemImage:"flame.fill")
                        .font(.system(size:11,weight:.semibold)).padding(.horizontal,10).padding(.vertical,7)
                        .background(DillTheme.peach.opacity(0.6),in:Capsule()).accessibilityLabel("\(store.pet.streak) day visit streak")
                }
                Text("Small pickle.\nBig main character.").font(DillTheme.display(33)).tracking(-1.4)
            }.frame(maxWidth:.infinity,alignment:.leading)
            VStack(spacing:12) {
                PetGarden(pet:store.pet,message:message,performance:performance,onPet:{ care(.pet) })
            HStack(spacing:10) {
                ForEach(Care.allCases) { action in
                    Button { care(action) } label: {
                        VStack(spacing:9) {
                            Image(systemName:action.symbol).font(.system(size:21,weight:.medium)).frame(height:25)
                            Text(action.title).font(.system(size:12,weight:.semibold,design:.rounded))
                        }.frame(maxWidth:.infinity).padding(.vertical,15).background(.white.opacity(0.75),in:RoundedRectangle(cornerRadius:21))
                            .overlay(alignment:.topTrailing) { if store.pet.dailyCare.contains(action.rawValue) { Image(systemName:"checkmark.circle.fill").font(.system(size:12)).foregroundStyle(DillTheme.muted).padding(6) } }
                    }.accessibilityIdentifier("care.\(action.rawValue)")
                }
            }
            }.id("careStage")
            HStack(spacing:12) {
                meter("Full tummy",value:store.pet.food,symbol:"carrot.fill",color:Color(hex:0xDBA976))
                meter("Good vibes",value:store.pet.joy,symbol:"heart.fill",color:Color(hex:0xD7A5A0))
                meter("Squeaky",value:store.pet.clean,symbol:"drop.fill",color:Color(hex:0x8DAEA4))
                meter("Energy",value:store.pet.energy,symbol:"bolt.fill",color:Color(hex:0xA7B86B))
            }
            HStack { Text("\(store.pet.dailyCare.count)/4 little acts of love today").font(.caption); Spacer(); Text("+5 coins each").font(.system(size:10,weight:.semibold)).foregroundStyle(DillTheme.muted) }
            RoyaleCard(play:arena)
            Button(action:play) {
                HStack(spacing:15) {
                    VStack(alignment:.leading,spacing:9) {
                        Text("TODAY’S TINY CHALLENGE").font(.system(size:9,weight:.bold,design:.monospaced)).tracking(1.4).foregroundStyle(DillTheme.lime)
                        Text("The daily crunch.").font(DillTheme.display(26)).tracking(-0.6)
                        Text("Three taps. One score. Bragging rights.").font(.system(size:12)).foregroundStyle(DillTheme.cream.opacity(0.75))
                    }
                    Spacer(minLength:0)
                    Image(systemName:"arrow.up.right").font(.system(size:19,weight:.semibold)).frame(width:44,height:44).foregroundStyle(DillTheme.ink).background(DillTheme.lime,in:Circle())
                }.padding(22).frame(maxWidth:.infinity,alignment:.leading).foregroundStyle(DillTheme.cream).background(DillTheme.ink,in:RoundedRectangle(cornerRadius:26))
            }.accessibilityIdentifier("dailyChallenge")
            HStack { Image(systemName:"tshirt"); Text("A new look, a whole new dill.").font(.caption); Spacer(); Button("Dress up",action:closet).font(.caption.bold()) }.foregroundStyle(DillTheme.muted)
        }.onDisappear { reactionTask?.cancel(); performance = nil; DillAudio.shared.stop() }
    }
    private func meter(_ title: String,value:Double,symbol:String,color:Color) -> some View {
        VStack(alignment:.leading,spacing:8) {
            HStack(spacing:4) { Image(systemName:symbol).font(.system(size:10)); Text("\(Int(value.rounded()))").font(.system(size:11,weight:.semibold,design:.rounded)) }
            GeometryReader { geometry in Capsule().fill(DillTheme.line); Capsule().fill(color).frame(width:geometry.size.width * value / 100) }.frame(height:5)
            Text(title).font(.system(size:9,weight:.medium)).foregroundStyle(DillTheme.muted).lineLimit(1).minimumScaleFactor(0.7)
        }.frame(maxWidth:.infinity).accessibilityElement(children:.ignore).accessibilityLabel("\(title), \(Int(value.rounded())) percent")
    }
    private func care(_ action: Care) {
        let reward = store.care(action)
        store.feedback()
        message = action.message + (reward > 0 ? " +5 ✦" : "")
        let next = CarePerformance(action:action)
        performance = next
        store.sound(DillSound(rawValue:action.rawValue)!)
        revealCare()
        reactionTask?.cancel()
        reactionTask = Task {
            try? await Task.sleep(for:.seconds(next.duration))
            guard !Task.isCancelled else {return}
            withAnimation(.easeOut(duration:0.2)) {performance = nil}
        }
    }
}
