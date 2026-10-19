import SwiftUI

/// Life events derived from the pet rules, the stored first-time moments, streak stickers and the 32-slot elder album.
struct ScrapbookView: View {
    @EnvironmentObject private var store: DillStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        let now = PetLife.ms(Date())
        let page = PetLife.scrapbook(store.pet.life, now: now, streak: store.pet.streak)
        let favorite = PetLife.favorite(store.pet.life.variety)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.pet.name).font(DillTheme.display(30)).tracking(-1)
                        Label("\(store.pet.streak)-day visit streak", systemImage: "flame.fill").font(.system(size: 12, weight: .semibold))
                            .accessibilityIdentifier("scrapbook.streak")
                        Text("Loves \(PetLife.FOOD_NAMES[favorite.food] ?? favorite.food) and \(PetLife.GAME_NAMES[favorite.game] ?? favorite.game).")
                            .font(.caption).foregroundStyle(DillTheme.muted)
                    }
                    stickers(page.stickers)
                    moments(page.moments)
                    album(page)
                }.padding(24).frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
            }
            .background(DillTheme.cream.ignoresSafeArea())
            .navigationTitle("Scrapbook").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .foregroundStyle(DillTheme.ink)
        .accessibilityIdentifier("scrapbook")
    }

    private func heading(_ text: String) -> some View {
        Text(text.uppercased()).font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.4).foregroundStyle(DillTheme.muted)
    }

    private func stickers(_ stickers: [ScrapbookPage.Sticker]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            heading("Streak stickers")
            HStack(spacing: 10) {
                ForEach(stickers, id: \.days) { sticker in
                    VStack(spacing: 4) {
                        Image(systemName: sticker.earned ? "star.circle.fill" : "lock.circle").font(.system(size: 26))
                        Text("\(sticker.days) days").font(.system(size: 10, weight: .semibold, design: .rounded))
                    }.frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(sticker.earned ? DillTheme.peach.opacity(0.6) : .clear, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(DillTheme.line, lineWidth: 1))
                        .foregroundStyle(sticker.earned ? DillTheme.ink : DillTheme.muted)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(sticker.days)-day streak sticker, \(sticker.earned ? "earned" : "locked")")
                }
            }
        }
    }

    private func moments(_ moments: [ScrapbookMoment]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            heading("Life so far")
            if moments.isEmpty { Text("The first page is waiting for a hatchling.").font(.caption).foregroundStyle(DillTheme.muted) }
            ForEach(moments, id: \.id) { moment in
                HStack(spacing: 10) {
                    Image(systemName: "circle.fill").font(.system(size: 6))
                    Text(PetLife.MOMENTS[moment.id] ?? moment.id).font(.system(size: 13, weight: .semibold, design: .rounded))
                    Spacer(minLength: 6)
                    Text(PetLife.date(moment.at).formatted(date: .abbreviated, time: .omitted)).font(.system(size: 11)).foregroundStyle(DillTheme.muted)
                }.padding(.vertical, 4).accessibilityElement(children: .combine)
            }
        }.accessibilityIdentifier("scrapbook.moments")
    }

    private func album(_ page: ScrapbookPage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            heading("Elder album · \(page.unlocked)/32")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 7)], spacing: 7) {
                ForEach(Array(page.album.enumerated()), id: \.element.id) { index, slot in
                    let form = ElderLook.all[index]
                    VStack(alignment: .leading, spacing: 5) {
                        Text(slot.unlocked ? form.name : "Locked").font(.system(size: 11, weight: .bold))
                        Text(slot.unlocked ? PetLife.date(slot.at).formatted(date: .abbreviated, time: .omitted) : "Day \(slot.day)")
                            .font(.system(size: 10)).foregroundStyle(DillTheme.muted)
                    }.padding(11).frame(maxWidth: .infinity, alignment: .leading)
                        .background(slot.unlocked ? Color(hex: 0xE7ECD9) : .clear, in: RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(DillTheme.line, lineWidth: 1))
                        .foregroundStyle(slot.unlocked ? DillTheme.ink : DillTheme.muted)
                        .accessibilityElement(children: .combine)
                }
            }
        }.accessibilityIdentifier("scrapbook.album")
    }
}
