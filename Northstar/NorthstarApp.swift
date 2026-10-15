import SwiftUI

@main
struct NorthstarApp: App {
    /// Settings → Appearance: Automatic (follows the phone), Day or Night.
    @AppStorage(SettingsKeys.appearance) private var appearance = Appearance.automatic

    var body: some Scene {

        WindowGroup {

            ContentView()
                .preferredColorScheme(appearance.colorScheme)
        }
    }
}
