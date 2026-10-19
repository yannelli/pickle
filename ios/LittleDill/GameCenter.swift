import GameKit
import UIKit

/// Signs in to Game Center and posts personal bests. Leaderboards are created by ios/scripts/game-center.mjs.
@MainActor final class GameCenter: ObservableObject {
    static let shared = GameCenter()
    enum Board: String, CaseIterable {
        case arena = "ld.arena.mass", daily = "ld.daily"
        case hunt = "ld.arcade.hunt", memory = "ld.arcade.memory", brineCatch = "ld.arcade.catch"
        case hop = "ld.arcade.hop", chop = "ld.arcade.chop", toss = "ld.arcade.toss"
        static func arcade(_ game: String) -> Board? { Board(rawValue: "ld.arcade.\(game)") }
    }
    @Published private(set) var signedIn = false
    private var started = false

    /// `bests` are posted after sign-in so scores earned before Game Center was enabled still count.
    func authenticate(bests: @escaping () -> [Board: Int]) {
        guard !started else { return }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") { return }
        #endif
        started = true
        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, _ in
            Task { @MainActor in
                guard let self else { return }
                if let controller { Self.topController()?.present(controller, animated: true); return }
                self.signedIn = GKLocalPlayer.local.isAuthenticated
                if self.signedIn { for (board, score) in bests() { self.submit(score, to: board) } }
            }
        }
    }

    func submit(_ score: Int, to board: Board) {
        guard signedIn, score > 0 else { return }
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [board.rawValue]) { _ in }
    }

    func showLeaderboards() {
        guard signedIn else { return }
        GKAccessPoint.shared.trigger(state: .leaderboards) {}
    }

    private static func topController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let next = top?.presentedViewController { top = next }
        return top
    }
}
