import SwiftUI

/// The web `.pet-profile` card: name, kind, quip, care and growth outlooks.
struct PetProfileCard: View {
    let life: WebPet
    var body: some View {
        let now = PetLife.ms(Date())
        SoftCard {
            VStack(spacing:7) {
                Text(life.name).font(.system(size:17,weight:.bold,design:.rounded)).multilineTextAlignment(.center)
                Text(NestText.kind(life,now:now)).font(.caption).foregroundStyle(DillTheme.muted).multilineTextAlignment(.center)
                Text(NestText.quip(life,now:now)).font(.system(size:17,design:.serif).italic()).multilineTextAlignment(.center).padding(.vertical,3)
                Text(NestText.careOutlook(life,now:now)).font(.caption).foregroundStyle(DillTheme.muted).multilineTextAlignment(.center)
                Text(NestText.growthOutlook(life,now:now)).font(.caption).foregroundStyle(DillTheme.muted).multilineTextAlignment(.center)
            }.frame(maxWidth:.infinity)
        }.accessibilityElement(children:.combine).accessibilityIdentifier("petProfile")
    }
}

/// The web `.elder-club` details list of all 32 elder looks.
struct ElderClub: View {
    let life: WebPet
    @State private var open = false
    var body: some View {
        let unlocked = NestText.eldersUnlocked(life,now:PetLife.ms(Date()))
        SoftCard(color:Color(hex:0xEEF0DF)) {
            DisclosureGroup(isExpanded:$open) {
                LazyVGrid(columns:[GridItem(.adaptive(minimum:140),spacing:7)],spacing:7) {
                    ForEach(Array(ElderLook.all.enumerated()),id:\.element.id) { index,form in
                        ElderCard(form:form,index:index,found:index < unlocked)
                    }
                }.padding(.top,14)
            } label: {
                Text("The elder club · \(unlocked)/32 discovered").font(.system(size:13,weight:.bold,design:.rounded)).foregroundStyle(DillTheme.ink)
            }.tint(DillTheme.ink).accessibilityIdentifier("elderClub")
        }
    }
}

private struct ElderCard: View {
    let form: ElderLook
    let index: Int
    let found: Bool
    var body: some View {
        HStack(alignment:.top,spacing:8) {
            if found {
                PickleCharacter(outfit:.original,variety:PickleVariety.all[index % PickleVariety.all.count],stage:.elder,elder:form)
                    .frame(width:40,height:40)
            }
            VStack(alignment:.leading,spacing:5) {
                Text((found ? "✦ " : "") + form.name).font(.system(size:11,weight:.bold))
                Text(found ? form.quip : "Day \(14 + index * 3)").font(.system(size:10)).foregroundStyle(DillTheme.muted).fixedSize(horizontal:false,vertical:true)
            }
            Spacer(minLength:0)
        }.padding(11).frame(maxWidth:.infinity,alignment:.leading)
            .background(found ? Color(hex:0xE7ECD9) : .clear,in:RoundedRectangle(cornerRadius:9))
            .overlay(RoundedRectangle(cornerRadius:9).stroke(DillTheme.line,lineWidth:1))
            .foregroundStyle(found ? DillTheme.ink : DillTheme.muted)
            .accessibilityElement(children:.combine)
    }
}
