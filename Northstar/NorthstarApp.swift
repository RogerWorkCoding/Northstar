import SwiftUI

@main
struct NorthstarApp: App {

    var body: some Scene {

        WindowGroup {

            // TEMPORARY: evaluating NorthstarVisionScreen as the launch experience.
            // The original launch path (ContentView) is preserved below, untouched,
            // in the #else branch — DEBUG-only builds show the vision screen, any
            // Release build still launches ContentView as before.
            // To revert: delete this #if/#else/#endif and keep only the ContentView() line.
            #if DEBUG
            NorthstarVisionScreen()
                .preferredColorScheme(.dark)
            #else
            ContentView()
                .preferredColorScheme(.dark)
            #endif
        }
    }
}
