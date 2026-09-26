import SwiftUI

struct ArcadeCircuitCard: View {
    let circuit: ArcadeCircuit
    let canPlay: Bool
    let play: (ArcadeGame) -> Void

    private var pick: ArcadeGame {
        circuit.nextGame ?? ArcadeCircuit.games.min {
            ArcadeCircuit.points(game: $0, score: circuit.scores[$0.rawValue] ?? 0) <
            ArcadeCircuit.points(game: $1, score: circuit.scores[$1.rawValue] ?? 0)
        }!
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Eyebrow(text: "Only on iOS · \(circuit.day)")
                    Text("The daily circuit")
                        .font(DillTheme.display(28))
                    Text("The same three challenges for everyone today. Beat your best.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(DillTheme.muted)
                }
                Spacer(minLength: 8)
                Text("\(circuit.total)/300")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            HStack(spacing: 8) {
                ForEach(ArcadeCircuit.games) { game in
                    let finished = circuit.scores[game.rawValue] != nil
                    HStack(spacing: 5) {
                        Image(systemName: finished ? "checkmark.circle.fill" : "circle")
                        Text(game.title)
                    }
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(finished ? DillTheme.ink : DillTheme.muted)
                    .accessibilityIdentifier("arcade.circuit.\(game.rawValue)")
                }
            }
            if let medal = circuit.medal {
                Text("\(medal) circuit · all three complete")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            Button { play(pick) } label: {
                Label(circuit.completed ? "Improve score" : circuit.scores.isEmpty ? "Play the circuit" : "Continue circuit",
                      systemImage: "arrow.right")
            }
            .buttonStyle(DillButton())
            .disabled(!canPlay)
            .accessibilityIdentifier("arcade.circuit.play")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DillTheme.lime.opacity(0.5), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(DillTheme.ink.opacity(0.14)))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("arcade.circuit")
    }
}
