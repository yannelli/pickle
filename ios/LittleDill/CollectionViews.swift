import SwiftUI

private enum ClosetFilter: String, CaseIterable {
    case all = "All", owned = "Owned", affordable = "Affordable"
}

struct ClosetView: View {
    @EnvironmentObject private var store: DillStore
    @State private var selected: Outfit?
    @State private var note: String?
    @State private var filter = ClosetFilter.all
    private struct OutfitSection { let title: String; let detail: String; let outfits: [Outfit] }
    private static let premiumCost = 500
    private var sections: [OutfitSection] {
        let owned = visibleOutfits.filter { store.pet.unlocked.contains($0) }
        let locked = visibleOutfits.filter { !store.pet.unlocked.contains($0) }.sorted { $0.cost < $1.cost }
        let coin = locked.filter { $0.cost < Self.premiumCost }, premium = locked.filter { $0.cost >= Self.premiumCost }
        return [
            OutfitSection(title:"Owned",detail:"Tap to wear",outfits:owned),
            OutfitSection(title:"Coin outfits",detail:Self.priceRange(coin),outfits:coin),
            OutfitSection(title:"Premium",detail:Self.priceRange(premium),outfits:premium),
        ].filter { !$0.outfits.isEmpty }
    }
    private static func priceRange(_ outfits: [Outfit]) -> String {
        let low = outfits.first?.cost ?? 0, high = outfits.last?.cost ?? 0
        return low == high ? "\(low.formatted()) coins" : "\(low.formatted()) to \(high.formatted()) coins"
    }
    private var visibleOutfits: [Outfit] {
        switch filter {
        case .all: Outfit.allCases
        case .owned: Outfit.allCases.filter { store.pet.unlocked.contains($0) }
        case .affordable: Outfit.allCases.filter { !store.pet.unlocked.contains($0) && $0.cost <= store.pet.coins }
        }
    }
    var body: some View {
        VStack(spacing:24) {
            PageHeading(eyebrow:"Closet",title:"Dress up\nyour pickle.",detail:"Earn coins through daily care, the daily crunch, and Brine Royale.")
            HStack(spacing:16) {
                PickleCharacter(pet:store.pet).frame(width:100,height:100)
                VStack(alignment:.leading,spacing:8) { Eyebrow(text:"Currently serving"); Text(store.pet.outfit.title).font(DillTheme.display(24)); Text("\(store.pet.unlocked.count) of \(Outfit.allCases.count) looks collected").font(.caption).foregroundStyle(DillTheme.muted) }
                Spacer()
            }.padding(16).background(DillTheme.sage,in:RoundedRectangle(cornerRadius:26))
            Picker("Show looks",selection:$filter) {
                ForEach(ClosetFilter.allCases,id:\.self) { option in Text(option.rawValue).tag(option) }
            }.pickerStyle(.segmented)
            ForEach(sections,id:\.title) { section in
                VStack(alignment:.leading,spacing:12) {
                    HStack(alignment:.firstTextBaseline) {
                        Text(section.title).font(DillTheme.display(22))
                        Spacer()
                        Text(section.detail).font(.caption).foregroundStyle(DillTheme.muted)
                    }.accessibilityElement(children:.combine).accessibilityAddTraits(.isHeader)
                    LazyVGrid(columns:[GridItem(.adaptive(minimum:140),spacing:14)],spacing:14) {
                        ForEach(section.outfits) { outfit in
                            outfitCard(outfit)
                        }
                    }
                }
            }
            if visibleOutfits.isEmpty { Text("Keep caring for your pickle to earn the next look.").font(.subheadline).foregroundStyle(DillTheme.muted) }
            Text("Outfits are bought with coins you earn by playing.").font(.caption).foregroundStyle(DillTheme.muted)
        }
        .alert("\(selected?.title ?? "New look")",isPresented:Binding(get:{selected != nil},set:{if !$0 { selected = nil }})) {
            if let outfit = selected, store.pet.coins >= outfit.cost {
                Button("Unlock for \(outfit.cost) coins") { _ = store.equip(outfit); store.feedback(.medium); selected = nil }
            }
            Button("Keep browsing",role:.cancel) { selected = nil }
        } message: {
            if let outfit = selected { Text(store.pet.coins >= outfit.cost ? "Make it yours forever for \(outfit.cost) coins?" : "You need \(outfit.cost - store.pet.coins) more coins. Care for your pickle and complete today’s challenge to earn them.") }
        }
    }
    private func outfitCard(_ outfit: Outfit) -> some View {
        let owned = store.pet.unlocked.contains(outfit)
        let equipped = store.pet.outfit == outfit
        return Button { if owned { _ = store.equip(outfit); store.feedback() } else { selected = outfit } } label: {
            VStack(alignment:.leading,spacing:8) {
                PickleCharacter(pet:store.pet,outfit:outfit).frame(height:140).frame(maxWidth:.infinity)
                Text(outfit.title).font(.system(size:14,weight:.bold,design:.rounded))
                HStack {
                    Text(equipped ? "Wearing it" : owned ? "Wear this" : "\(outfit.cost) coins").font(.system(size:11,weight:.medium))
                    Spacer()
                    Image(systemName:equipped ? "checkmark.circle.fill" : owned ? "arrow.up.right" : "plus.circle").font(.system(size:14))
                }.foregroundStyle(DillTheme.muted)
            }.padding(16).background(equipped ? DillTheme.sage : .white.opacity(0.65),in:RoundedRectangle(cornerRadius:24))
                .overlay(RoundedRectangle(cornerRadius:24).stroke(equipped ? DillTheme.ink.opacity(0.35) : DillTheme.line,lineWidth:1))
        }.accessibilityLabel("\(outfit.title), \(equipped ? "wearing" : owned ? "owned" : "\(outfit.cost) coins")").accessibilityIdentifier("outfit.\(outfit.rawValue)")
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: DillStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var nameError: String?
    @State private var confirmReset = false
    @AppStorage(ArenaControls.swappedKey,store:ArenaResume.defaults) private var arenaControlsSwapped = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Your pickle") {
                    if store.pet.adopted {
                        LabeledContent("Pickle name") {
                            TextField("Pickle name",text:$name).multilineTextAlignment(.trailing).accessibilityIdentifier("settings.name")
                                .onChange(of:name) { _,v in
                                    if v.count > 24 { name = String(v.prefix(24)) }
                                    nameError = nil
                                }
                        }
                        Button("Save name") { saveName() }.disabled(name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                        if let nameError { Text(nameError).font(.footnote).foregroundStyle(.red).accessibilityIdentifier("settings.nameError") }
                    }
                    LabeledContent("Brine",value:store.pet.brine.title)
                    if store.pet.adopted { LabeledContent("Adopted",value:store.pet.birthday.formatted(date:.abbreviated,time:.omitted)) }
                }
                BackupSection()
                Section {
                    Toggle("Haptic feedback",isOn:Binding(get:{store.pet.haptics},set:{store.setHaptics($0)}))
                    Toggle("Sound effects",isOn:Binding(get:{store.pet.sounds},set:{store.setSounds($0)})).accessibilityIdentifier("soundEffects")
                } header: { Text("Sound and haptics") } footer: { Text("Sounds respect Silent Mode and mix with your music.") }
                Section {
                    Toggle("Joystick on the right",isOn:$arenaControlsSwapped).accessibilityIdentifier("arenaControlsSwapped")
                } header: { Text("Brine Royale") } footer: { Text("Split and dash move to your left thumb.") }
                Section {
                    NavigationLink("How Little Dill works") { HowItWorksView() }.accessibilityIdentifier("settings.howItWorks")
                }
                Section {
                    Link("Privacy policy",destination:URL(string:"https://littledill.app/privacy")!)
                    Link("Privacy choices",destination:URL(string:"https://littledill.app/privacy-choices")!)
                    Link("Terms of use",destination:URL(string:"https://littledill.app/terms")!)
                    Link("Contact support",destination:URL(string:"mailto:ryanyannelli@gmail.com?subject=Little%20Dill")!)
                }
                Section { Button("Start over with a new pickle",role:.destructive) { confirmReset = true } } footer: { Text("This erases this app’s pet, coins, outfits, and scores on this device.") }
                Section { Text("Little Dill \(Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "")").font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.topBarTrailing) { Button("Done") { dismiss() } } }
        }.onAppear { name = store.pet.name }
            .confirmationDialog("Say goodbye to \(store.pet.name)?",isPresented:$confirmReset,titleVisibility:.visible) {
                Button("Erase progress and start over",role:.destructive) { store.reset(); dismiss() }
            } message: { Text("Your pet, coins, outfits, and scores will be permanently removed from this device.") }
    }
    @MainActor private func saveName() {
        if store.rename(name) { dismiss() } else { nameError = "Give your pickle a name with 1–24 characters." }
    }
}

struct HowItWorksView: View {
    var body: some View {
        Form {
            Section("Play with your people") {
                Text("Pass & play works on one phone. Brine Royale connects up to 64 players across iPhone and the web. Collect food, grow, absorb smaller pickles, and split or dash to chase. Your pieces regroup after a little time. Create a crew room to invite friends.")
                Text("Challenge links open the same daily course on a friend’s installed app. Scorecards can be saved or shared anywhere. Brine Royale room links join your friends in the same online room.")
            }
            Section("Privacy") {
                Text("Your pet and personal bests stay on this device. When you are signed in to Game Center, your best scores also go to Apple’s leaderboards. Online arenas share your chosen pickle name, appearance, movements, and live scores with players in the same room. The server processes your IP address to limit connections. Arena sessions are temporary. No accounts, ads, analytics, or purchases. Sharing uses the apps you choose.")
            }
            Section("Daily resets") {
                Text("Daily challenges reset at midnight UTC. Visit streaks and care rewards follow your local calendar. Native progress is separate from the browser game.")
            }
            Section("Accessibility") {
                Text("Little Dill follows your text-size and Reduce Motion settings. Your pickle stays here while you are away.")
            }
        }.font(.footnote).navigationTitle("How Little Dill works").navigationBarTitleDisplayMode(.inline)
    }
}

struct Scorecard: View {
    let pet: PetState
    let score: Int?
    let day: String
    var arenaScore = false
    var recap: ArenaRunRecap? = nil
    var body: some View {
        VStack(spacing:20) {
            HStack { Text("little dill.").font(DillTheme.display(29)).tracking(-1); Spacer() }
            Rectangle().fill(DillTheme.ink.opacity(0.15)).frame(height:1)
            Eyebrow(text:score == nil ? "My pickle" : recap != nil ? "Brine Royale · Run recap" : arenaScore ? "Brine Royale · Personal best" : "The daily crunch · \(day)")
            Text(score == nil ? "Meet \(pet.name)." : "Kind of a big dill.").font(DillTheme.display(37)).tracking(-1).multilineTextAlignment(.center)
            PickleCharacter(pet:pet,happy:true).frame(width:210,height:210)
            if let score {
                HStack(alignment:.firstTextBaseline,spacing:4) { Text("\(score)").font(.system(size:76,weight:.black,design:.rounded)).lineLimit(1).minimumScaleFactor(0.3); Text(arenaScore ? "mass" : "/ 300").font(.title3).foregroundStyle(DillTheme.muted).fixedSize() }
                Text(arenaScore ? "\(pet.name) grew into a very big dill. Beat that." : "\(pet.name) brought the crunch. Your turn.").font(.system(size:14,weight:.medium,design:.rounded)).multilineTextAlignment(.center)
                if let recap { Text(recap.summary).font(.system(size:12,weight:.semibold,design:.rounded)).multilineTextAlignment(.center) }
            } else { Text("Adopted \(pet.birthday.formatted(date:.abbreviated,time:.omitted))").font(.system(size:15,weight:.medium,design:.rounded)) }
            Text("LITTLEDILL.APP").font(.system(size:10,weight:.bold,design:.monospaced)).tracking(2)
        }.padding(30).frame(width:360).foregroundStyle(DillTheme.ink).background(DillTheme.lime)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context:Context) -> UIActivityViewController { UIActivityViewController(activityItems:items,applicationActivities:nil) }
    func updateUIViewController(_ uiViewController:UIActivityViewController,context:Context) {}
}

struct ShareCardButton: View {
    let pet: PetState
    var score: Int?
    var day = DailyChallenge.today()
    var title = "Share your scorecard"
    var arenaScore = false
    var arenaRoom: String?
    var recap: ArenaRunRecap? = nil
    private struct SharePayload: Identifiable { let id = UUID(); let image: UIImage }
    @State private var payload: SharePayload?
    @State private var failure = false
    var body: some View {
        Button {
            let renderer = ImageRenderer(content:Scorecard(pet:pet,score:score,day:day,arenaScore:arenaScore,recap:recap))
            renderer.scale = 3
            if let image = renderer.uiImage { payload = SharePayload(image:image) } else { failure = true }
        } label: { Label(title,systemImage:"square.and.arrow.up").frame(maxWidth:.infinity) }
            .buttonStyle(DillButton(light:true))
            .sheet(item:$payload) { payload in
                    ShareSheet(items:[payload.image,shareText])
                        .presentationDetents([.medium,.large])
            }
            .alert("Couldn’t make the scorecard",isPresented:$failure) { Button("OK",role:.cancel) {} } message: { Text("Please try sharing again.") }
    }
    private var shareText: String {
        if arenaScore, let score {return "\(pet.name) grew to \(score.formatted()) mass in Brine Royale. Can you beat my pickle? \(ArenaLaunch.shareURL(room:arenaRoom).absoluteString) · https://littledill.app"}
        return (score.map {"\(pet.name) scored \($0)/300 in Little Dill. Can you beat it? Open the same course: \(DailyChallenge(day:day).url.absoluteString)"} ?? "Meet \(pet.name), my Little Dill. A pickle that grows up with you.") + " · https://littledill.app"
    }
}
