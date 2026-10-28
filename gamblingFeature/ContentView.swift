import SwiftUI

enum Screen: Hashable { case choose, game(Game.Mode) }

struct ContentView: View {
    @State private var game = Game()
    @State private var path: [Screen] = []

    var body: some View {
        NavigationStack(path: $path) {
            OrderView { path.append(.choose) }
                .navigationDestination(for: Screen.self) { screen in
                    switch screen {
                    case .choose: ChooseGameView()
                    case .game(let mode): GameView().onAppear { game.play(mode) }
                    }
                }
        }
        .sheet(isPresented: $game.showsSummary, onDismiss: {
            // The summary can only be closed with Done, which ends the session.
            game = Game()
            path = []
        }) {
            SummaryView { game.showsSummary = false }
        }
        .environment(game)
    }
}

#Preview {
    ContentView()
}
