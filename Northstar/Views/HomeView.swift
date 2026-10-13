import SwiftUI

struct HomeView: View {
    @State private var messageText: String = ""
    @State private var showStarMenu = false // Controls the new tool pop-up
    
    var body: some View {
        ZStack {
            // Your signature deep navy background
            Color(red: 0.05, green: 0.06, blue: 0.12)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Header
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                    Text("Northstar")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                .padding(.top, 16)
                .padding(.bottom, 24)
                
                // Chat Canvas
                ScrollView {
                    VStack(spacing: 24) {
                        // AI Bubble
                        HStack {
                            Text("Type Sitemap to create the\nwebsite structure.")
                                .padding()
                                .background(Color.white.opacity(0.15))
                                .foregroundColor(.white)
                                .cornerRadius(20)
                            Spacer()
                        }
                        
                        // User Bubble
                        HStack {
                            Spacer()
                            Text("Site map")
                                .padding()
                                .background(Color.white.opacity(0.25))
                                .foregroundColor(.white)
                                .cornerRadius(20)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Bottom Interaction Area
                ZStack(alignment: .bottomTrailing) {
                    
                    // The main Frosted Input Pill
                    HStack(spacing: 12) {
                        // 1. Star Settings Button
                        Button(action: {
                            showStarMenu.toggle() // Triggers the menu below
                        }) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                        
                        // 2. Text Field
                        TextField("Ask Northstar...", text: $messageText)
                            .foregroundColor(.white)
                        
                        // 3. Microphone
                        Button(action: {
                            // Voice dictation action
                        }) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.gray)
                        }
                        
                        // 4. Send Arrow
                        Button(action: {
                            // Send message action
                        }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(messageText.isEmpty ? .gray : .white)
                        }
                        .disabled(messageText.isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(30)
                    
                    // Floating Camera/Scanner Button (Overlapping the pill)
                    Button(action: {
                        // Triggers the camera/computer vision
                    }) {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color(red: 0.4, green: 0.4, blue: 0.5).opacity(0.9))
                            .clipShape(Circle())
                    }
                    // This specific offset pulls it down to perfectly overlap the pill
                    .offset(x: 0, y: -45)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        // The interactive Star Menu drawer
        .sheet(isPresented: $showStarMenu) {
            VStack(spacing: 24) {
                Text("Art Direction Tiers")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.top, 30)
                
                Button("Junior Designer") { showStarMenu = false }
                    .foregroundColor(.white)
                Button("Senior Art Director") { showStarMenu = false }
                    .foregroundColor(.white)
                Button("Creative Director") { showStarMenu = false }
                    .foregroundColor(.white)
                    
                Divider().background(Color.gray).padding(.horizontal, 40)
                
                Button("Upload File") { showStarMenu = false }
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(red: 0.05, green: 0.06, blue: 0.12).ignoresSafeArea())
            // This restricts the menu to the bottom 40% of the screen
            .presentationDetents([.fraction(0.4)])
        }
    }
}

#Preview {
    HomeView()
}
