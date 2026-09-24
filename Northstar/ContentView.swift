import SwiftUI

struct ContentView: View {
    @State private var promptText: String = ""
    @State private var isPulsing = false
    @State private var isThinking = false // Tracks if AI is processing
    @State private var spinDegree = 0.0   // Controls the spinning animation
    
    var body: some View {
        ZStack {
            // 1. Atmosphere: Slate Blue Background
            Color(red: 0.08, green: 0.12, blue: 0.25)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // 2. Focal Point: Glowing North Star
                Image(systemName: "sparkle")
                    .font(.system(size: 70, weight: .ultraLight))
                    // Turns blue when thinking, white when resting
                    .foregroundColor(isThinking ? .cyan : .white)
                    .shadow(color: isThinking ? .cyan.opacity(0.8) : .white.opacity(0.8), radius: isThinking ? 25 : 15, x: 0, y: 0)
                    .shadow(color: isThinking ? .cyan.opacity(0.4) : .white.opacity(0.4), radius: isThinking ? 50 : 30, x: 0, y: 0)
                    // Grows slightly larger when thinking
                    .scaleEffect(isThinking ? 1.25 : (isPulsing ? 1.15 : 0.85))
                    // Spins when the spinDegree variable increases
                    .rotationEffect(.degrees(spinDegree))
                    .padding(.bottom, 30)
                
                // 3. Identity Text
                Text(isThinking ? "Thinking..." : "Northstar")
                    .font(.system(size: 34, weight: .light))
                    .foregroundColor(.white)
                    .tracking(3)
                    .padding(.bottom, 10)
                
                // Manifesto (Fades out when thinking)
                VStack(spacing: 4) {
                    Text("ONE BLANK DESTINATION.")
                    Text("AN INTELLIGENT PATH FORWARD.")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .tracking(2)
                .opacity(isThinking ? 0 : 1)
                
                Spacer()
                
                // 4. Entry Point: Glass-morphic Text Field
                HStack {
                    Image(systemName: "mic")
                        .foregroundColor(.white.opacity(0.7))
                    
                    TextField("Where to?", text: $promptText)
                        .foregroundColor(.white)
                        .accentColor(.white)
                        .disabled(isThinking) // Locks keyboard while thinking
                        .onSubmit {
                            startThinking() // Triggers the animation when you hit Return
                        }
                    
                    // Shows a loading spinner instead of arrow while thinking
                    if isThinking {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                    } else {
                        Image(systemName: "location.fill")
                            .foregroundColor(promptText.isEmpty ? .white.opacity(0.5) : .white)
                            .onTapGesture {
                                startThinking() // Also triggers if you tap the arrow
                            }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
                .opacity(isThinking ? 0.6 : 1.0)
            }
        }
        // Smoothly animates all color/opacity changes taking 0.8 seconds
        .animation(.easeInOut(duration: 0.8), value: isThinking)
        // Starts the gentle breathing pulse when the app opens
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
        // Listens for the thinking state to change, and spins the star
        .onChange(of: isThinking) { thinking in
            if thinking {
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    spinDegree = 360.0
                }
            } else {
                withAnimation(.easeOut(duration: 0.5)) {
                    spinDegree = 0.0
                }
            }
        }
    }
    
    // The logic that runs when you submit a question
    func startThinking() {
        guard !promptText.isEmpty else { return } // Stops if text box is empty
        
        isThinking = true
        promptText = ""
        
        // Fakes a 4-second delay to prove the animation works
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            isThinking = false
        }
    }
}

#Preview {
    ContentView()
}
