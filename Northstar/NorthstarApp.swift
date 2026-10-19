import SwiftUI

@main
struct NorthstarApp: App {
    /// Settings → Appearance: Automatic (follows the phone), Day or Night.
    @AppStorage(SettingsKeys.appearance) private var appearance = Appearance.automatic
    /// The star opening plays once each time the app starts (not when it comes back from the background).
    @State private var introDone = StarIntroView.clip == nil

    var body: some Scene {

        WindowGroup {
            ZStack {
                if introDone {
                    // ContentView sets the window's look (Night on the home screen, the chosen look elsewhere).
                    ContentView()
                        .transition(.opacity)
                } else {
                    StarIntroView {
                        withAnimation(.easeInOut(duration: 0.6)) { introDone = true }
                    }
                    .transition(.opacity)
                }
            }
        }
    }
}
