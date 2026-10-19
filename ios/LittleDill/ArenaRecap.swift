import SwiftUI

/// End-of-life stats from the server's `run` and the life's goals.
struct ArenaRunRecap: Equatable {
    let peakMass: Int
    let kills: Int
    let seconds: Int
    let rank: Int
    let goalsDone: Int
    let goalCount: Int
    init(peakMass:Int,kills:Int,seconds:Int,rank:Int,goalsDone:Int,goalCount:Int) {
        self.peakMass = peakMass; self.kills = kills; self.seconds = seconds; self.rank = rank
        self.goalsDone = goalsDone; self.goalCount = goalCount
    }
    init?(player:ArenaPlayer?) {
        guard let player, let run = player.run else {return nil}
        self.init(peakMass:Int(run.peakMass),kills:run.kills,seconds:Int(run.secondsAlive),rank:run.bestRank,
                  goalsDone:player.goals.filter(\.done).count,goalCount:player.goals.count)
    }
    var timeText: String { seconds >= 60 ? "\(seconds / 60):" + String(format:"%02d",seconds % 60) : "\(seconds)s" }
    var rankText: String { rank > 0 ? "#\(rank)" : "–" }
    var goalsText: String? { goalCount > 0 ? "\(goalsDone)/\(goalCount)" : nil }
    var summary: String {
        var parts = ["Best rank \(rankText)","\(kills) crunched","\(timeText) alive"]
        if let goalsText {parts.append("\(goalsText) goals")}
        return parts.joined(separator:" · ")
    }
}

struct ArenaRecapStats: View {
    let recap: ArenaRunRecap
    var body: some View {
        VStack(spacing:12) {
            HStack(spacing:18) {
                stat("\(recap.peakMass)","Peak mass")
                stat(recap.rankText,"Best rank")
                stat("\(recap.kills)","Crunched")
            }
            HStack(spacing:18) {
                stat(recap.timeText,"Time alive")
                if let goals = recap.goalsText {stat(goals,"Goals done")}
            }
        }.accessibilityElement(children:.combine)
    }
    private func stat(_ value:String,_ title:String) -> some View {
        VStack(spacing:2) {
            Text(value).font(.system(size:24,weight:.bold,design:.rounded)).lineLimit(1).minimumScaleFactor(0.5)
            Eyebrow(text:title)
        }.frame(minWidth:72)
    }
}

/// Shown after an explicit leave; Done closes the arena.
struct ArenaRecapCard: View {
    let recap: ArenaRunRecap
    let pet: PetState
    let room: String?
    let done: () -> Void
    var body: some View {
        VStack(spacing:18) {
            Eyebrow(text:"Run recap")
            Text("That was\na good brine.").font(DillTheme.display(34)).tracking(-1).multilineTextAlignment(.center)
            ArenaRecapStats(recap:recap)
            ShareCardButton(pet:pet,score:recap.peakMass,title:"Share your run",arenaScore:true,arenaRoom:room,recap:recap)
            Button(action:done) {Text("Done")}.buttonStyle(DillButton()).accessibilityIdentifier("arenaRecapDone")
        }.padding(26).frame(maxWidth:350).background(DillTheme.cream,in:RoundedRectangle(cornerRadius:30)).padding(24)
    }
}

/// A completed-goal pill shown under the score bar.
struct ArenaGoalToast: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size:12,weight:.bold,design:.rounded)).lineLimit(1).minimumScaleFactor(0.7)
            .padding(.horizontal,14).padding(.vertical,7)
            .background(DillTheme.cream.opacity(0.95),in:Capsule())
            .overlay(Capsule().stroke(Color(hex:0x5C873E).opacity(0.5),lineWidth:1))
            .accessibilityIdentifier("arenaGoalToast")
    }
}
