import SwiftUI
import Combine

struct GameLaunch: Identifiable {
    enum Mode { case solo, party }
    let id = UUID()
    let challenge: DailyChallenge
    let mode: Mode
    let players: [String]
    static func solo(_ challenge:DailyChallenge) -> GameLaunch { GameLaunch(challenge:challenge,mode:.solo,players:[]) }
}

struct PlayView: View {
    @EnvironmentObject private var store: DillStore
    let launch: (GameLaunch) -> Void
    let arena: () -> Void
    @State private var party = false
    var body: some View {
        let daily = DailyChallenge(day:DailyChallenge.today())
        VStack(spacing:24) {
            PageHeading(eyebrow:"A little friendly competition",title:"Let’s make\na big dill of it.",detail:"Easy to learn. Almost impossible to tap just once.")
            RoyaleCard(play:arena)
            if let best = store.pet.arenaBest {
                HStack {Label("Your biggest dill",systemImage:"trophy.fill").font(.subheadline); Spacer(); Text("\(best) mass").font(.system(.headline,design:.rounded))}.padding(18).background(DillTheme.sage,in:RoundedRectangle(cornerRadius:20))
            }
            VStack(alignment:.leading,spacing:20) {
                HStack { Eyebrow(text:"Daily crunch / \(daily.number)"); Spacer(); Image(systemName:"sun.max.fill") }
                HStack(alignment:.center) {
                    VStack(alignment:.leading,spacing:10) {
                        Text("Three taps.\nAll the glory.").font(DillTheme.display(32)).tracking(-1)
                        Text("Stop the seed in the sweet spot.\nGet as close as you can, three times.").font(.system(size:13)).foregroundStyle(DillTheme.muted)
                    }
                    Spacer(minLength:0)
                    PickleCharacter(brine:store.pet.brine,outfit:.shades).frame(width:110,height:130).rotationEffect(.degrees(9))
                }
                HStack {
                    Label("\(store.pet.scores.first(where:{$0.day == daily.day})?.score ?? 0) best",systemImage:"trophy").font(.caption.bold())
                    Spacer()
                    Text(store.pet.rewardedDays.contains(daily.day) ? "Replay for a new best" : "+25 coins on completion").font(.system(size:10,weight:.medium))
                }
                Button { launch(.solo(daily)) } label: { HStack { Text("Play today’s challenge"); Image(systemName:"arrow.right") } }.buttonStyle(DillButton()).accessibilityIdentifier("playDaily")
            }.padding(22).background(DillTheme.lime,in:RoundedRectangle(cornerRadius:28))
            Button { party = true } label: {
                SoftCard {
                    HStack(spacing:16) {
                        Image(systemName:"iphone.gen3.radiowaves.left.and.right").font(.system(size:27)).frame(width:48,height:56).background(DillTheme.peach.opacity(0.6),in:RoundedRectangle(cornerRadius:16))
                        VStack(alignment:.leading,spacing:6) { Text("Pass the pickle.").font(DillTheme.display(23)); Text("2–4 friends. One phone. Zero chill.").font(.caption).foregroundStyle(DillTheme.muted) }
                        Spacer(minLength:0); Image(systemName:"arrow.up.right")
                    }
                }
            }.accessibilityIdentifier("passAndPlay")
            VStack(alignment:.leading,spacing:14) {
                HStack { Text("Your little victories").font(DillTheme.display(23)); Spacer(); Image(systemName:"sparkles") }
                if store.pet.scores.isEmpty {
                    Text("Your first score is the start of something crunchy.").font(.subheadline).foregroundStyle(DillTheme.muted).padding(.vertical,14)
                } else {
                    ForEach(store.pet.scores.prefix(7)) { score in
                        HStack { VStack(alignment:.leading,spacing:5) { Text(score.day == daily.day ? "Today’s crunch" : score.day).font(.subheadline.bold()); Text("Personal best").font(.caption).foregroundStyle(DillTheme.muted) }; Spacer(); Text("\(score.score)").font(.system(size:24,weight:.bold,design:.rounded)); Text("/ 300").font(.caption).foregroundStyle(DillTheme.muted) }.padding(.vertical,8)
                    }
                }
            }
            Text("Same course for everyone. A fresh challenge at midnight UTC.").font(.caption).foregroundStyle(DillTheme.muted).multilineTextAlignment(.center)
        }.sheet(isPresented:$party) { PartySetup { names in party = false; launch(GameLaunch(challenge:daily,mode:.party,players:names)) } }
    }
}

struct PartySetup: View {
    @Environment(\.dismiss) private var dismiss
    @State private var count = 2
    @State private var names = ["Player 1","Player 2","Player 3","Player 4"]
    let start: ([String]) -> Void
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing:25) {
                    PageHeading(eyebrow:"Gather your favorite humans",title:"Pass the pickle.",detail:"Everyone gets the same three-round course. Take turns, then crown the crunch champion.")
                    Picker("Players",selection:$count) { ForEach(2...4,id:\.self) { Text("\($0) players").tag($0) } }.pickerStyle(.segmented)
                    ForEach(0..<count,id:\.self) { index in
                        HStack { Text("0\(index + 1)").font(.system(.headline,design:.monospaced)).foregroundStyle(DillTheme.muted); TextField("Player \(index + 1)",text:$names[index]).textInputAutocapitalization(.words).onChange(of:names[index]) { _,v in names[index] = String(v.prefix(18)) }.accessibilityIdentifier("playerName.\(index)") }.padding(18).background(.white,in:RoundedRectangle(cornerRadius:18))
                    }
                    Button { start((0..<count).map { names[$0].trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? "Player \($0+1)" : names[$0].trimmingCharacters(in:.whitespacesAndNewlines) }) } label: { Text("Let the crunch begin") }.buttonStyle(DillButton()).accessibilityIdentifier("startParty")
                }.padding(24).frame(maxWidth:580).frame(maxWidth:.infinity)
            }.background(DillTheme.cream).navigationTitle("Game night").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.topBarTrailing) { Button("Cancel") { dismiss() } } }
        }.tint(DillTheme.ink)
    }
}

struct GameView: View {
    enum Stage { case ready, playing, roundResult, handoff, finished }
    let launch: GameLaunch
    var completion: ((Int) -> Void)?
    @EnvironmentObject private var store: DillStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stage: Stage = .ready
    @State private var round = 0
    @State private var player = 0
    @State private var points: [Int] = []
    @State private var totals: [Int] = []
    @State private var elapsed = 0.0
    @State private var carried = 0.0
    @State private var started = 0.0
    @State private var cursor = 0.0
    @State private var paused = false
    @State private var quit = false
    @State private var reward = 0
    @State private var enteredTarget = false
    private let clock = Timer.publish(every:1 / 60,on:.main,in:.common).autoconnect()
    private var playerName: String { launch.players.isEmpty ? store.pet.name : launch.players[player] }
    private var target: Double { launch.challenge.target(round:round) }
    var body: some View {
        ZStack {
            DillTheme.cream.ignoresSafeArea()
            ScrollView {
                VStack(spacing:26) {
                    HStack {
                        Button { if stage == .finished { dismiss() } else { pause(); quit = true } } label: { Image(systemName:"xmark").font(.system(size:15,weight:.semibold)).frame(width:44,height:44).background(DillTheme.sage,in:Circle()) }.accessibilityLabel("Leave game")
                        Spacer(); Eyebrow(text:launch.mode == .party ? "Pass the pickle" : "Daily crunch / \(launch.challenge.number)"); Spacer(); Image(systemName:"sparkle").frame(width:44)
                    }
                    if stage == .finished { results }
                    else if stage == .handoff { handoff }
                    else { course }
                }.padding(24).frame(maxWidth:580).frame(maxWidth:.infinity)
            }.scrollIndicators(.hidden)
        }.foregroundStyle(DillTheme.ink).interactiveDismissDisabled(stage != .finished)
            .onReceive(clock) { _ in tick() }
            .onChange(of:scenePhase) { _,phase in if phase != .active { pause() } }
            .confirmationDialog("Leave this game?",isPresented:$quit,titleVisibility:.visible) {
                Button("Leave game",role:.destructive) { dismiss() }
                Button("Keep playing",role:.cancel) {}
            } message: { Text("This unfinished run won’t be saved.") }
    }
    private var course: some View {
        VStack(spacing:24) {
            VStack(spacing:9) {
                Eyebrow(text:"\(playerName)’s turn · Round \(round+1) of 3")
                Text(stage == .roundResult ? verdict : "Find your\nsweet spot.").font(DillTheme.display(43)).tracking(-1.5).multilineTextAlignment(.center)
                Text(stage == .roundResult ? "\(points.last ?? 0) points. Every little crunch counts." : "Tap CRUNCH when the seed meets the stripe.").font(.subheadline).foregroundStyle(DillTheme.muted).multilineTextAlignment(.center)
            }
            ZStack {
                Circle().fill(DillTheme.sage).frame(width:205,height:205)
                PickleCharacter(brine:store.pet.brine,outfit:store.pet.outfit,happy:stage == .roundResult).frame(width:220,height:220)
                if stage == .roundResult { Text("+\(points.last ?? 0)").font(.system(size:28,weight:.black,design:.rounded)).padding(15).background(DillTheme.lime,in:Capsule()).rotationEffect(.degrees(-10)).offset(x:78,y:70) }
            }.frame(height:230)
            VStack(spacing:15) {
                HStack { Eyebrow(text:"The sweet spot"); Spacer(); Text(stage == .playing ? String(format:"%.1fs",max(0,6-elapsed)) : "Aim for \(Int(target * 100))%").font(.system(size:11,weight:.medium,design:.monospaced)).foregroundStyle(DillTheme.muted) }
                GeometryReader { geometry in
                    let width = max(1,geometry.size.width - 28)
                    ZStack(alignment:.leading) {
                        RoundedRectangle(cornerRadius:25).fill(DillTheme.sage)
                        RoundedRectangle(cornerRadius:14).fill(DillTheme.ink).frame(width:32,height:66).offset(x:14 + width * target - 16)
                        Rectangle().fill(DillTheme.lime).frame(width:2,height:50).offset(x:14 + width * target - 1)
                        Capsule().fill(DillTheme.lime).frame(width:22,height:38).overlay(Capsule().stroke(DillTheme.ink,lineWidth:2)).rotationEffect(.degrees(-15)).offset(x:3 + width * cursor)
                    }
                }.frame(height:66).accessibilityElement(children:.ignore).accessibilityLabel("Seed position \(Int(cursor * 100)) percent. Target \(Int(target * 100)) percent.")
                HStack(spacing:8) {
                    ForEach(0..<3,id:\.self) { index in
                        HStack(spacing:6) { Text("0\(index+1)").foregroundStyle(DillTheme.muted); Text(index < points.count ? "\(points[index])" : "—").bold() }.font(.system(size:12,design:.monospaced)).frame(maxWidth:.infinity).padding(12).background(.white.opacity(0.7),in:RoundedRectangle(cornerRadius:12))
                    }
                }
            }
            if stage == .ready {
                Button { begin() } label: { Label("I’m ready",systemImage:"play.fill") }.buttonStyle(DillButton()).accessibilityIdentifier("gameReady")
                Text("You have 6 seconds per round. Closer = crunchier.").font(.caption).foregroundStyle(DillTheme.muted)
            } else if stage == .playing {
                Button { if paused { resume() } else { stopRound() } } label: {
                    Text(paused ? "Resume round" : "CRUNCH!").font(.system(size:23,weight:.black,design:.rounded)).tracking(2)
                }.buttonStyle(DillButton(light:!paused)).accessibilityIdentifier(paused ? "gameResume" : "gameCrunch")
                Text(paused ? "All good. Your round is paused." : "Feel the little tap when you enter the sweet spot.").font(.caption).foregroundStyle(DillTheme.muted)
            } else {
                Button { advance() } label: { HStack { Text(round == 2 ? "See how you did" : "Next crunch"); Image(systemName:"arrow.right") } }.buttonStyle(DillButton()).accessibilityIdentifier("gameNext")
            }
        }
    }
    private var verdict: String {
        switch points.last ?? 0 { case 95...100:return "Absolutely\ncrunchworthy."; case 75...94:return "That’s a\npretty big dill."; case 40...74:return "A little crunch.\nA lot of heart."; default:return "Still a\nsweet pickle." }
    }
    private var handoff: some View {
        VStack(spacing:25) {
            PickleCharacter(brine:store.pet.brine,outfit:.party,happy:true).frame(width:240,height:240)
            Eyebrow(text:"Next up")
            Text("Pass it to\n\(playerName).").font(DillTheme.display(42)).multilineTextAlignment(.center)
            Text("Same course. Fresh pair of thumbs.\nNo peeking at the final scores yet.").font(.subheadline).foregroundStyle(DillTheme.muted).multilineTextAlignment(.center)
            Button { stage = .ready } label: { Text("I’m \(playerName). Let’s go.") }.buttonStyle(DillButton()).accessibilityIdentifier("gameHandoff")
        }.padding(.top,30)
    }
    private var results: some View {
        VStack(spacing:24) {
            Eyebrow(text:launch.mode == .party ? "The crunch council has spoken" : "One tiny victory, secured")
            Text(launch.mode == .party ? "A round of\napplause, please." : "Kind of\na big dill.").font(DillTheme.display(46)).tracking(-1.5).multilineTextAlignment(.center)
            PickleCharacter(brine:store.pet.brine,outfit:.crown,happy:true).frame(width:210,height:210)
            if launch.mode == .party {
                ForEach(Array(totals.indices.sorted { totals[$0] == totals[$1] ? $0 < $1 : totals[$0] > totals[$1] }),id:\.self) { index in
                    HStack {
                        Image(systemName:totals[index] == totals.max() ? "crown.fill" : "sparkle")
                        Text(launch.players[index]).font(.headline)
                        Spacer(); Text("\(totals[index])").font(.system(size:25,weight:.bold,design:.rounded))
                    }.padding(18).background(totals[index] == totals.max() ? DillTheme.lime : DillTheme.sage,in:RoundedRectangle(cornerRadius:18))
                }
                Text(totals.filter { $0 == totals.max() }.count > 1 ? "A tie! There’s room for more than one big dill." : "Winner gets the glory. Everyone gets the good vibes.").font(.caption).foregroundStyle(DillTheme.muted).multilineTextAlignment(.center)
            } else {
                HStack(alignment:.firstTextBaseline) { Text("\(totals.first ?? 0)").font(.system(size:76,weight:.black,design:.rounded)); Text("/ 300").font(.title3).foregroundStyle(DillTheme.muted) }.accessibilityIdentifier("finalScore")
                Text(reward > 0 ? "+\(reward) coins · Your pickle is proud of you." : "Saved to your daily best. Your pickle is proud of you.").font(.subheadline).foregroundStyle(DillTheme.muted).multilineTextAlignment(.center)
                ShareCardButton(pet:store.pet,score:totals.first ?? 0,day:launch.challenge.day)
            }
            Button { dismiss() } label: { Text("Back to my little dill") }.buttonStyle(DillButton()).accessibilityIdentifier("gameDone")
        }
    }
    private func begin() { elapsed = 0; carried = 0; started = ProcessInfo.processInfo.systemUptime; cursor = 0; paused = false; enteredTarget = false; stage = .playing; store.feedback() }
    private func tick() {
        guard stage == .playing, !paused, scenePhase == .active, !quit else { return }
        elapsed = carried + max(0,ProcessInfo.processInfo.systemUptime - started)
        cursor = DailyChallenge.position(elapsed:elapsed,round:round)
        let inTarget = abs(cursor - target) < 0.045
        if inTarget && !enteredTarget { store.feedback(.soft) }
        enteredTarget = inTarget
        if elapsed >= 6 { stopRound(timedOut:true) }
    }
    private func stopRound(timedOut:Bool = false) {
        guard stage == .playing, !paused else { return }
        let actual = carried + max(0,ProcessInfo.processInfo.systemUptime - started)
        cursor = DailyChallenge.position(elapsed:actual,round:round)
        points.append(timedOut || actual >= 6 ? 0 : DailyChallenge.points(position:cursor,target:target))
        stage = .roundResult; store.feedback(.medium); store.sound(.crunch)
    }
    private func advance() {
        guard stage == .roundResult else { return }
        if round < 2 { round += 1; stage = .ready; cursor = 0 }
        else {
            let total = points.reduce(0,+)
            totals.append(total)
            if launch.mode == .party && player + 1 < launch.players.count {
                player += 1; points = []; round = 0; cursor = 0; stage = .handoff
            } else {
                if launch.mode == .solo { reward = store.record(score:total,day:launch.challenge.day) }
                completion?(total); stage = .finished; store.sound(.win)
            }
        }
    }
    private func pause() {
        guard stage == .playing, !paused else { return }
        carried += max(0,ProcessInfo.processInfo.systemUptime - started); paused = true
    }
    private func resume() { started = ProcessInfo.processInfo.systemUptime; paused = false }
}
