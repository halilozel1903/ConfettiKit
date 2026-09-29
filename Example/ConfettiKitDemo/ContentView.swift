import SwiftUI

enum DemoTab: Hashable {
    case celebrate
    case presets
}

struct ContentView: View {
    let scene: ScreenshotScene?

    @State private var tab: DemoTab

    init(scene: ScreenshotScene? = nil) {
        self.scene = scene
        _tab = State(initialValue: scene == .presets ? .presets : .celebrate)
    }

    var body: some View {
        TabView(selection: $tab) {
            CelebrateView(isFrozen: scene != nil)
                .tabItem { Label("Celebrate", systemImage: "party.popper") }
                .tag(DemoTab.celebrate)

            PresetsView(isFrozen: scene != nil)
                .tabItem { Label("Presets", systemImage: "square.grid.2x2") }
                .tag(DemoTab.presets)
        }
    }
}

#Preview {
    ContentView()
}
