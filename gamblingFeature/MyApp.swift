import SwiftUI

@main struct MyApp: App {
    #if DEBUG
    init() { Game.selfCheck() }
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
