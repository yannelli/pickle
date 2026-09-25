import SwiftUI

struct FriendsView: View {
    @EnvironmentObject private var store: DillStore
    let arena: (ArenaLaunch) -> Void
    @State private var code = ""
    @State private var party = false
    @State private var game: GameLaunch?
    var body: some View {
        VStack(spacing:24) {
            PageHeading(eyebrow:"Good things come in jars",title:"Your people.\nYour pickle chaos.",detail:"Across the couch or across the world. There’s always room for a little rivalry.")
            ZStack {
                RoundedRectangle(cornerRadius:28).fill(DillTheme.sage)
                HStack(spacing:-35) {
                    PickleCharacter(brine:.classic,outfit:.sprout,happy:true).rotationEffect(.degrees(-12))
                    PickleCharacter(brine:.spicy,outfit:.bow,happy:true).rotationEffect(.degrees(12))
                }.frame(height:185).padding(.horizontal,25)
                Text("a couple of big dills").font(.system(size:12,weight:.medium,design:.rounded)).padding(.horizontal,17).padding(.vertical,10).background(DillTheme.peach,in:Capsule()).rotationEffect(.degrees(-6)).offset(y:83)
            }.frame(height:220)
            VStack(alignment:.leading,spacing:18) {
                HStack {Label("ONLINE WITH YOUR CREW",systemImage:"globe").font(.system(size:10,weight:.bold,design:.monospaced)).tracking(1); Spacer(); Image(systemName:"person.2.fill")}.foregroundStyle(DillTheme.lime)
                Text("Same garden.\nDifferent zip codes.").font(DillTheme.display(29)).foregroundStyle(DillTheme.cream)
                Text("Create a private arena and share its room code. Your friends can join from iPhone or the web.").font(.subheadline).foregroundStyle(DillTheme.cream.opacity(0.8))
                Button {arena(ArenaLaunch(room:ArenaLaunch.newRoom()))} label: {Label("Make a crew room",systemImage:"plus.circle")}.buttonStyle(DillButton(light:true)).accessibilityIdentifier("createArenaRoom")
            }.padding(23).background(DillTheme.ink,in:RoundedRectangle(cornerRadius:28))
            SoftCard {
                VStack(alignment:.leading,spacing:14) {
                    Text("Got an invite?").font(DillTheme.display(25))
                    TextField("6-letter room code",text:$code).font(.system(.title3,design:.monospaced)).textInputAutocapitalization(.characters).autocorrectionDisabled().submitLabel(.go)
                        .padding(15).background(DillTheme.sage,in:RoundedRectangle(cornerRadius:16)).accessibilityIdentifier("arenaRoomCode")
                        .onChange(of:code) {_,value in code = String(value.uppercased().filter {$0.isASCII && ($0.isLetter || $0.isNumber)}.prefix(6))}
                        .onSubmit {if ArenaLaunch.validRoom(code) {arena(ArenaLaunch(room:code))}}
                    Button {arena(ArenaLaunch(room:code))} label: {Text("Join their garden")}.buttonStyle(DillButton()).disabled(!ArenaLaunch.validRoom(code)).opacity(ArenaLaunch.validRoom(code) ? 1 : 0.5).accessibilityIdentifier("joinArenaRoom")
                }
            }
            Button {party = true} label: {
                SoftCard {HStack(spacing:15) {Image(systemName:"person.3.fill").font(.title2); VStack(alignment:.leading,spacing:6) {Text("Pass & play").font(DillTheme.display(23)); Text("One phone. 2–4 friends. Offline fun.").font(.caption).foregroundStyle(DillTheme.muted)}; Spacer(); Image(systemName:"arrow.up.right")}}
            }
            VStack(alignment:.leading,spacing:14) {
                Text("Meet my little dill.").font(DillTheme.display(26))
                Text("Your pickle was born to be in the group chat.").font(.subheadline).foregroundStyle(DillTheme.muted)
                ShareCardButton(pet:store.pet,title:"Share your pickle")
            }
        }.sheet(isPresented:$party) {PartySetup {names in party = false; game = GameLaunch(challenge:DailyChallenge(day:DailyChallenge.today()),mode:.party,players:names)}}
            .fullScreenCover(item:$game) {GameView(launch:$0).environmentObject(store)}
    }
}

struct RoyaleCard: View {
    let play: () -> Void
    var body: some View {
        VStack(alignment:.leading,spacing:18) {
            HStack {
                Label("LIVE MULTIPLAYER",systemImage:"globe").font(.system(size:10,weight:.bold,design:.monospaced)).tracking(1.3)
                Spacer()
            }
            HStack(spacing:0) {
                VStack(alignment:.leading,spacing:9) {
                    Text("Brine\nRoyale.").font(DillTheme.display(43)).tracking(-1.8)
                    Text("Start little. Grow big.\nTry not to become a snack.").font(.subheadline).foregroundStyle(DillTheme.ink.opacity(0.8))
                }
                Spacer(minLength:0)
                ZStack {
                    PickleCharacter(brine:.spicy,outfit:.original).frame(width:62,height:62).rotationEffect(.degrees(-15)).offset(x:-36,y:58)
                    PickleCharacter(brine:.classic,outfit:.crown,happy:true).frame(width:125,height:160).rotationEffect(.degrees(10))
                }.frame(width:130,height:180)
            }
            Button(action:play) {HStack {Text("Jump into the garden"); Image(systemName:"arrow.up.right")}}.buttonStyle(DillButton()).accessibilityIdentifier("joinArena")
            HStack(spacing:5) {Image(systemName:"person.2.fill"); Text("Up to 64 players. A whole garden to grow.")}.font(.system(size:10,weight:.medium,design:.rounded))
        }.padding(23).background(DillTheme.lime,in:RoundedRectangle(cornerRadius:28))
    }
}
