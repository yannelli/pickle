import SwiftUI

struct FriendsView: View {
    @EnvironmentObject private var store: DillStore
    let arena: (ArenaLaunch) -> Void
    @State private var code = ""
    var body: some View {
        VStack(spacing:24) {
            PageHeading(eyebrow:"Friends",title:"Play with\nyour people.",detail:"Meet up online in a private Brine Royale crew room.")
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
                Text("Create a private Brine Royale room and share its code. Friends can join from iPhone or the web.").font(.subheadline).foregroundStyle(DillTheme.cream.opacity(0.8))
                Button {arena(ArenaLaunch(room:ArenaLaunch.newRoom()))} label: {Label("Create a crew room",systemImage:"plus.circle")}.buttonStyle(DillButton(light:true)).accessibilityIdentifier("createArenaRoom")
            }.padding(23).background(DillTheme.ink,in:RoundedRectangle(cornerRadius:28))
            SoftCard {
                VStack(alignment:.leading,spacing:14) {
                    Text("Got an invite?").font(DillTheme.display(25))
                    TextField("6-letter room code",text:$code).font(.system(.title3,design:.monospaced)).textInputAutocapitalization(.characters).autocorrectionDisabled().submitLabel(.go)
                        .padding(15).background(DillTheme.sage,in:RoundedRectangle(cornerRadius:16)).accessibilityIdentifier("arenaRoomCode")
                        .onChange(of:code) {_,value in code = String(value.uppercased().filter {$0.isASCII && ($0.isLetter || $0.isNumber)}.prefix(6))}
                        .onSubmit {if ArenaLaunch.validRoom(code) {arena(ArenaLaunch(room:code))}}
                    Button {arena(ArenaLaunch(room:code))} label: {Text("Join crew room")}.buttonStyle(DillButton()).disabled(!ArenaLaunch.validRoom(code)).opacity(ArenaLaunch.validRoom(code) ? 1 : 0.5).accessibilityIdentifier("joinArenaRoom")
                }
            }
            VStack(alignment:.leading,spacing:14) {
                Text("Meet my pickle.").font(DillTheme.display(26))
                Text("Share a picture card of your pickle with friends.").font(.subheadline).foregroundStyle(DillTheme.muted)
                ShareCardButton(pet:store.pet,title:"Share your pickle")
            }
        }
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
            Text("Earn 1 coin per 1,000 mass collected, up to 1,000 coins daily. Resets at 00:00 UTC.").font(.system(size:11,weight:.medium)).fixedSize(horizontal:false,vertical:true)
            Button(action:play) {HStack {Text("Join Brine Royale"); Image(systemName:"arrow.up.right")}}.buttonStyle(DillButton()).accessibilityIdentifier("joinArena")
            HStack(spacing:5) {Image(systemName:"person.2.fill"); Text("Up to 64 players. A whole garden to grow.")}.font(.system(size:10,weight:.medium,design:.rounded))
        }.padding(23).background(DillTheme.lime,in:RoundedRectangle(cornerRadius:28))
    }
}
