import SwiftUI

@main
struct NorthstarApp: App {
    /// Settings → Appearance: Automatic (follows the phone), Day or Night.
    @AppStorage(SettingsKeys.appearance) private var appearance = Appearance.automatic

    var body: some Scene {

        WindowGroup {

            ContentView()
                // Set the look on the app's windows, so switching in Settings takes effect
                // right away (and Automatic goes back to following the phone).
                .onAppear { appearance.apply() }
                .onChange(of: appearance) { appearance.apply() }
        }
    }
}
