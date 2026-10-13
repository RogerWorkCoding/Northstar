import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            // 1. Your new AI Chat Canvas (Loads First)
            HomeView()
                .tabItem {
                    Image(systemName: "sparkles")
                    Text("Northstar")
                }

            // 2. Your Projects Database
            ProjectsView()
                .tabItem {
                    Image(systemName: "folder.fill")
                    Text("Projects")
                }
            
            // 3. Your Rules/Memory Database
            DecisionsView()
                .tabItem {
                    Image(systemName: "text.book.closed.fill")
                    Text("Rules")
                }
        }
        .tint(.white)
        .preferredColorScheme(.dark)
    }
}
