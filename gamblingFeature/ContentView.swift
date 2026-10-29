import SwiftUI

enum Screen: Hashable { case choose, game(Game.Mode) }

struct ContentView: View {
    /// One game per ordered device, each keeping its own progress; `current` is the one being played.
    @State private var games = Catalog.devices.map { Game(device: $0) }
    @State private var current = 0
    @State private var path: [Screen] = []

    var body: some View {
        @Bindable var game = games[current]
        NavigationStack(path: $path) {
            OrderView { path.append(.choose) }
                .navigationDestination(for: Screen.self) { screen in
                    switch screen {
                    case .choose: ChooseGameView(current: $current)
                    case .game(let mode): GameView().onAppear { game.play(mode) }
                    }
                }
        }
        .sheet(isPresented: $game.showsSummary, onDismiss: {
            // The summary can only be closed with Done, which ends the session.
            games = Catalog.devices.map { Game(device: $0) }
            current = 0
            path = []
        }) {
            SummaryView(games: games) { game.showsSummary = false }
        }
        .environment(game)
    }
}

#Preview {
    ContentView()
}
