import SwiftUI

enum Screen: Hashable { case choose, game(Game.Mode) }

struct ContentView: View {
    /// One game per ordered device, each keeping its own progress; `current` is the one being played.
    @State private var games = Catalog.devices.map { Game(device: $0) }
    @State private var current = 0
    @State private var path: [Screen] = []
    /// Face ID and the payment chime play before the order confirmation is shown.
    @State private var verified = false
    /// Set by Done, so that closing the summary sheet knows whether to start over.
    @State private var endsSession = false

    var body: some View {
        if verified {
            content
                .transition(.opacity)
        } else {
            FaceIDIntroView {
                withAnimation(.smooth) { verified = true }
            }
        }
    }

    private var content: some View {
        @Bindable var game = games[current]
        return NavigationStack(path: $path) {
            OrderView { path.append(.choose) }
                .navigationDestination(for: Screen.self) { screen in
                    switch screen {
                    case .choose: ChooseGameView(current: $current)
                    case .game(let mode): GameView().onAppear { game.play(mode) }
                    }
                }
        }
        .sheet(isPresented: $game.showsSummary, onDismiss: {
            // Done ends the session; Close only hides the summary and leaves the games as they were.
            guard endsSession else { return }
            endsSession = false
            games = Catalog.devices.map { Game(device: $0) }
            current = 0
            path = []
        }) {
            SummaryView(games: games, onClose: { game.showsSummary = false }) {
                endsSession = true
                game.showsSummary = false
            }
        }
        .environment(game)
    }
}

#Preview {
    ContentView()
}
