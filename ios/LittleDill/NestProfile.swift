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
