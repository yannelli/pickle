import SwiftUI

struct NestView: View {
    @EnvironmentObject private var store: DillStore
    let play: () -> Void
    let closet: () -> Void
    let arena: () -> Void
    var revealCare: () -> Void = {}
    @StateObject private var stage = PetStage()
    @State private var performance: CarePerformance?
    @State private var reactionTask: Task<Void,Never>?
    @State private var arcade = false
    @State private var joyBeforeArcade = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var life: WebPet { store.pet.life }
    private var snacking: Bool { store.snackBites != nil }
    private var nowMs: Int64 { PetLife.ms(Date()) }
    private var canPlay: Bool { store.pet.adopted && !life.dead && !life.sleeping && life.energy >= 6 && !snacking }

    var body: some View {
        VStack(spacing:22) {
            header
            VStack(spacing:12) {
                NestMeters(life:life)
                PetGarden(pet:store.pet,bites:store.snackBites,stage:stage,performance:performance,message:message,
                          hint:NestText.hint(life,bites:store.snackBites),onTap:tapPickle,onHold:startSnack,restart:restart)
                careButtons
                Button { pet(performing:true) } label: {
                    Text("Pet +8 ♥").font(.system(size:12,weight:.semibold,design:.rounded)).padding(.horizontal,16).frame(minHeight:40)
                        .background(.white.opacity(0.6),in:Capsule()).overlay(Capsule().stroke(DillTheme.line,lineWidth:1))
                }.disabled(!store.pet.adopted || life.dead || life.sleeping || snacking).accessibilityIdentifier("care.pet")
            }.id("careStage")
            HStack { Text("\(store.pet.dailyCare.count)/4 little acts of love today").font(.caption); Spacer(); Text("+5 coins each").font(.system(size:10,weight:.semibold)).foregroundStyle(DillTheme.muted) }
            PetProfileCard(life:life)
            ElderClub(life:life)
            RoyaleCard(play:arena)
            dailyCard
            HStack { Image(systemName:"tshirt"); Text("A new look, a whole new dill.").font(.caption); Spacer(); Button("Dress up",action:closet).font(.caption.bold()) }.foregroundStyle(DillTheme.muted)
        }
        .sheet(isPresented:$arcade,onDismiss:arcadeClosed) { ArcadeSheet().environmentObject(store) }
        .onAppear {
            if let line = store.speech, PetLife.ms(Date()) - life.bornAt < 15_000 { stage.say(line,for:6) }
        }
        .onChange(of:store.speech) { _,line in
            // Store lines that arrive on their own (growing up, a bite timing out) still reach the message line.
            if let line, Date().timeIntervalSince(stage.lastSaid) > 0.3 { stage.say(line,for:5) }
        }
        .task { await idleLoop() }
        .onDisappear {
            reactionTask?.cancel(); performance = nil; DillAudio.shared.stop()
            if snacking { store.cancelBite() }
        }
    }

    private var header: some View {
        VStack(alignment:.leading,spacing:10) {
            HStack(spacing:8) {
                Eyebrow(text:NestText.stageLabel(life,now:nowMs) + " · " + NestText.age(life,now:nowMs)).accessibilityIdentifier("nestStage")
                Spacer(minLength:4)
                Label("\(store.pet.streak) day\(store.pet.streak == 1 ? "" : "s")",systemImage:"flame.fill")
                    .font(.system(size:11,weight:.semibold)).padding(.horizontal,10).padding(.vertical,7)
                    .background(DillTheme.peach.opacity(0.6),in:Capsule()).accessibilityLabel("\(store.pet.streak) day visit streak")
            }
            Text(store.pet.name).font(DillTheme.display(33)).tracking(-1.4).lineLimit(2).minimumScaleFactor(0.6)
        }.frame(maxWidth:.infinity,alignment:.leading)
    }

    private var careButtons: some View {
        HStack(spacing:10) {
            careButton(snacking ? "NEVER" : "Feed",symbol:snacking ? "hand.raised.fill" : Care.feed.symbol,id:"care.feed",done:store.pet.dailyCare.contains("feed"),
                       label:snacking ? "Spare your pickle" : "Feed brine") { snacking ? cancelSnack() : care(.feed) }
                .disabled(!store.pet.adopted || life.dead)
            careButton(snacking ? "NOPE" : "Play",symbol:snacking ? "xmark" : "gamecontroller.fill",id:"care.play",done:false,
                       label:snacking ? "Spare your pickle" : "Open the dill arcade") { snacking ? cancelSnack() : openArcade() }
                .disabled(!snacking && !canPlay)
            careButton(snacking ? "CHOMP" : "Clean",symbol:snacking ? "mouth.fill" : "sparkles",id:"care.wash",done:store.pet.dailyCare.contains("wash"),
                       label:snacking ? ((store.snackBites ?? 0) > 0 ? "Take another bite" : "Take a bite") : "Clean your pickle") { snacking ? chomp() : care(.wash) }
                .disabled(!store.pet.adopted || life.dead)
            careButton(life.sleeping ? "Wake" : "Nap",symbol:life.sleeping ? "sun.max.fill" : Care.nap.symbol,id:"care.nap",done:store.pet.dailyCare.contains("nap"),
                       label:life.sleeping ? "Wake your pickle" : "Nap") { toggleSleep() }
                .disabled(!store.pet.adopted || life.dead || snacking)
        }
    }

    private func careButton(_ title: String,symbol: String,id: String,done: Bool,label: String,action: @escaping () -> Void) -> some View {
        Button(action:action) {
            VStack(spacing:9) {
                Image(systemName:symbol).font(.system(size:21,weight:.medium)).frame(height:25)
                Text(title).font(.system(size:12,weight:.semibold,design:.rounded))
            }.frame(maxWidth:.infinity).padding(.vertical,15)
                .background(snacking ? DillTheme.peach.opacity(0.55) : .white.opacity(0.75),in:RoundedRectangle(cornerRadius:21))
                .overlay(alignment:.topTrailing) { if done && !snacking { Image(systemName:"checkmark.circle.fill").font(.system(size:12)).foregroundStyle(DillTheme.muted).padding(6) } }
        }.accessibilityLabel(label).accessibilityIdentifier(id)
    }

    private var dailyCard: some View {
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
    }

    private var message: String {
        if life.dead { return NestText.defaultMessage(life,now:nowMs) }
        if snacking { return store.speech ?? "" }
        return stage.line ?? NestText.defaultMessage(life,now:nowMs)
    }

    private func line(_ result: CareResult) -> String { result.message + (result.coins > 0 ? " +\(result.coins) ✦" : "") }

    private func care(_ action: Care) {
        let before = life.fullness
        let result = store.care(action)
        stage.say(line(result))
        guard result.applied else { stage.play(.wiggle); store.feedback(.rigid); return }
        store.feedback()
        stage.happyUntil = Date().addingTimeInterval(5)
        if action == .feed { stage.pop("+\(Int((life.fullness - before).rounded())) food") } else { stage.pop("✧ squeaky clean ✧") }
        perform(action)
    }

    private func pet(performing: Bool) {
        let before = life.happiness
        let result = store.care(.pet)
        stage.say(line(result))
        guard result.applied else { store.feedback(.soft); return }
        let added = Int((life.happiness - before).rounded())
        stage.happyUntil = Date().addingTimeInterval(5)
        stage.pop(added > 0 ? "+\(added) happy ♥" : "♥ so loved ♥",hearts:true)
        store.feedback()
        if performing { perform(.pet) } else { stage.play(.hop); store.sound(.pet) }
    }

    private func tapPickle() {
        if snacking { cancelSnack(); return }
        guard store.pet.adopted, !life.dead else { return }
        if life.sleeping { toggleSleep(); return }
        pet(performing:false)
    }

    private func toggleSleep() {
        guard !snacking else { return }
        let result = store.toggleSleep()
        guard result.applied else { return }
        stage.say(line(result)); stage.happyUntil = .distantPast
        store.feedback(.medium)
        if life.sleeping { stage.play(.yawn); perform(.nap) }
        else { stopPerformance(); stage.play(.wake); store.sound(.pop) }
    }

    private func openArcade() {
        guard canPlay else { return }
        joyBeforeArcade = life.happiness
        store.feedback(); store.sound(.pop); arcade = true
    }

    private func arcadeClosed() {
        guard life.happiness > joyBeforeArcade, !life.dead else { return }
        stage.happyUntil = Date().addingTimeInterval(5); stage.play(.hop)
    }

    private func startSnack() {
        guard !snacking, store.startBite() else { return }
        stopPerformance()
        stage.say(store.speech ?? "",for:9); stage.play(.wiggle); stage.happyUntil = .distantPast
        store.sound(.pop); store.feedback(.heavy)
    }

    private func cancelSnack() {
        store.cancelBite()
        stage.say(store.speech ?? "",for:5); stage.play(.shimmy)
        store.sound(.pop); store.feedback()
    }

    private func chomp() {
        let bite = store.bite()
        guard bite >= 0 else { return }
        stage.say(store.speech ?? "",for:6)
        store.sound(.crunch); store.feedback(.heavy)
        if bite < 2 { stage.play(.bitten); stage.pop(bite == 0 ? "CRONCH" : "CRUNCH") } else { stage.pop("burp.") }
    }

    private func restart() {
        stopPerformance(); stage.reset()
        store.restart(); store.sound(.respawn); store.feedback(.medium)
    }

    private func perform(_ action: Care) {
        let next = CarePerformance(action:action)
        performance = next
        store.sound(DillSound(rawValue:action.rawValue)!)
        revealCare()
        reactionTask?.cancel()
        reactionTask = Task { @MainActor in
            try? await Task.sleep(for:.seconds(next.duration))
            guard !Task.isCancelled else {return}
            performance = nil
        }
    }

    private func stopPerformance() {
        reactionTask?.cancel()
        if performance != nil { performance = nil; DillAudio.shared.stop() }
    }

    @MainActor private func idleLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for:.seconds(Double.random(in:2.8...7)))
            let mood = stage.mood(life,snacking:snacking,now:Date())
            stage.idleTick(mood:mood,busy:performance != nil,reduceMotion:reduceMotion)
        }
    }
}

/// The pickle's room: message line, the animated scene, and the web screen hint.
struct PetGarden: View {
    let pet: PetState
    let bites: Int?
    @ObservedObject var stage: PetStage
    let performance: CarePerformance?
    let message: String
    let hint: String
    let onTap: () -> Void
    let onHold: () -> Void
    let restart: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var dark: Bool { pet.life.sleeping && !pet.life.dead }
    private var roomColor: Color {
        if dark { return Color(hex:0x344F50) }
        if pet.life.dead { return Color(hex:0xDDE1D2) }
        return performance?.action == .wash ? Color(hex:0xDCEDE5) : Color(hex:0xE9EEDC)
    }
    var body: some View {
        VStack(spacing:0) {
            HStack {
                Label(performance?.caption ?? (dark ? "SHHH. DREAMING" : "YOUR HAPPY PLACE"),systemImage:performance?.action.symbol ?? (dark ? "moon.zzz.fill" : "sun.max"))
                    .font(.system(size:9,weight:.bold,design:.monospaced)).tracking(1.5)
                Spacer()
                Image(systemName:"sparkle")
            }.padding(.horizontal,20).padding(.top,18).padding(.bottom,10)
                .foregroundStyle(dark ? DillTheme.cream : DillTheme.ink)
            Text(message).font(.system(size:12,weight:.medium,design:.rounded)).multilineTextAlignment(.center).padding(.horizontal,16).padding(.vertical,10)
                .foregroundStyle(DillTheme.ink).background(DillTheme.cream.opacity(0.92),in:Capsule()).padding(.horizontal,16)
                .contentTransition(.opacity).animation(.easeInOut(duration:0.25),value:message).accessibilityIdentifier("petMessage")
            ZStack(alignment:.top) {
                TimelineView(.animation(minimumInterval:reduceMotion ? 0.1 : nil)) { timeline in
                    CareScene(pet:pet,bites:bites,stage:stage,performance:performance,now:timeline.date,reduceMotion:reduceMotion)
                }
                .contentShape(Rectangle())
                .gesture(LongPressGesture(minimumDuration:0.8).onEnded { _ in onHold() }.exclusively(before:TapGesture().onEnded { onTap() }))
                .accessibilityElement(children:.contain)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { onTap() }
                .accessibilityAction(named:"Eat the pickle") { onHold() }
                if pet.life.dead {
                    Button(action:restart) {
                        Text("Plant a new pickle ↻").font(.system(size:12,weight:.bold,design:.rounded)).padding(.horizontal,16).frame(minHeight:40)
                            .background(DillTheme.cream,in:Capsule()).overlay(Capsule().stroke(DillTheme.ink,lineWidth:1.5))
                    }.foregroundStyle(DillTheme.ink).padding(.top,4).accessibilityIdentifier("restart")
                }
            }
            HStack(spacing:6) { Circle().frame(width:5,height:5); Text(hint).font(.system(size:11,weight:.medium,design:.rounded)) }
                .padding(.bottom,18).foregroundStyle(dark ? DillTheme.cream : DillTheme.ink).accessibilityIdentifier("petHint")
        }.background(roomColor,in:RoundedRectangle(cornerRadius:32)).animation(.easeInOut(duration:0.6),value:dark)
    }
}

struct NestMeters: View {
    let life: WebPet
    var body: some View {
        HStack(spacing:12) {
            meter("Food",value:life.fullness,symbol:"carrot.fill",color:Color(hex:0xDBA976))
            meter("Happy",value:life.happiness,symbol:"heart.fill",color:Color(hex:0xD7A5A0))
            meter("Energy",value:life.energy,symbol:"bolt.fill",color:Color(hex:0xA7B86B))
            meter("Clean",value:life.hygiene,symbol:"drop.fill",color:Color(hex:0x8DAEA4))
        }
    }
    private func meter(_ title: String,value: Double,symbol: String,color: Color) -> some View {
        let shown = Int(value.rounded())
        let low = shown < 25
        return VStack(alignment:.leading,spacing:7) {
            HStack(spacing:3) {
                Image(systemName:low ? "exclamationmark.circle.fill" : symbol).font(.system(size:10))
                Text("\(shown)").font(.system(size:11,weight:.semibold,design:.rounded)).monospacedDigit()
            }.foregroundStyle(low ? Color(hex:0xB2573A) : DillTheme.ink)
            GeometryReader { geometry in
                ZStack(alignment:.leading) {
                    Capsule().fill(DillTheme.line)
                    Capsule().fill(low ? Color(hex:0xD9825F) : color).frame(width:geometry.size.width * value / 100)
                }
            }.frame(height:6).animation(.easeOut(duration:0.3),value:value)
            Text(title.uppercased()).font(.system(size:9,weight:.bold,design:.monospaced)).tracking(0.6)
                .foregroundStyle(low ? Color(hex:0xB2573A) : DillTheme.muted).underline(low).lineLimit(1).minimumScaleFactor(0.7)
        }.frame(maxWidth:.infinity).accessibilityElement(children:.ignore)
            .accessibilityLabel("\(title), \(shown) percent\(low ? ", low" : "")").accessibilityIdentifier("meter.\(title.lowercased())")
    }
}
