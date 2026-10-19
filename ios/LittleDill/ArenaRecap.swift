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

/// The life's goals with progress; compact phones get one summary row.
struct ArenaGoalsHUD: View {
    let goals: [ArenaGoal]
    let compact: Bool
    static let doneColor = Color(hex:0x5C873E)
    var body: some View {
        if !goals.isEmpty {
            Group {
                if compact {
                    HStack(spacing:3) {
                        ForEach(Array(goals.enumerated()),id:\.offset) {_,goal in mark(goal)}
                        Text("\(goals.filter(\.done).count)/\(goals.count) goals")
                    }
                } else {
                    VStack(alignment:.leading,spacing:3) {
                        ForEach(Array(goals.enumerated()),id:\.offset) {_,goal in
                            HStack(spacing:4) {
                                mark(goal)
                                Text(goal.label).lineLimit(1).minimumScaleFactor(0.7).strikethrough(goal.done)
                                Spacer(minLength:4)
                                Text(goal.progressText).monospacedDigit().foregroundStyle(DillTheme.muted)
                            }
                        }
                    }.frame(maxWidth:180,alignment:.leading)
                }
            }.font(.system(size:10,weight:.semibold))
                .accessibilityElement(children:.ignore)
                .accessibilityLabel("Goals: " + goals.map {"\($0.label), \($0.done ? "done" : $0.progressText)"}.joined(separator:"; "))
                .accessibilityIdentifier("arenaGoals")
        }
    }
    private func mark(_ goal:ArenaGoal) -> some View {
        Image(systemName:goal.done ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(goal.done ? Self.doneColor : DillTheme.muted)
    }
}
