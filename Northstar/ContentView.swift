import SwiftUI

struct ContentView: View {
    @State private var promptText: String = ""
    @State private var isPulsing = false
    @State private var isThinking = false
    @State private var spinDegree = 0.0
    
    // New variables to control the glass response window
    @State private var showResponse = false
    @State private var aiResponse = ""
    
    var body: some View {
        ZStack {
            // Atmosphere
            Color(red: 0.08, green: 0.12, blue: 0.25)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Focal Point: Glowing North Star
                Image(systemName: "sparkle")
                    .font(.system(size: showResponse ? 50 : 70, weight: .ultraLight)) // Shrinks slightly when reading
                    .foregroundColor(isThinking ? .cyan : .white)
                    .shadow(color: isThinking ? .cyan.opacity(0.8) : .white.opacity(0.8), radius: isThinking ? 25 : 15, x: 0, y: 0)
                    .shadow(color: isThinking ? .cyan.opacity(0.4) : .white.opacity(0.4), radius: isThinking ? 50 : 30, x: 0, y: 0)
                    .scaleEffect(isThinking ? 1.25 : (isPulsing ? 1.15 : 0.85))
                    .rotationEffect(.degrees(spinDegree))
                    .padding(.bottom, showResponse ? 15 : 30)
                
                // Swaps between the Title/Manifesto and the Glass Response Window
                if !showResponse {
                    Text(isThinking ? "Thinking..." : "Northstar")
                        .font(.system(size: 34, weight: .light))
                        .foregroundColor(.white)
                        .tracking(3)
                        .padding(.bottom, 10)
                    
                    VStack(spacing: 4) {
                        Text("ONE BLANK DESTINATION.")
                        Text("AN INTELLIGENT PATH FORWARD.")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(2)
                    .opacity(isThinking ? 0 : 1)
                } else {
                    // The Glass Response Window
                    ScrollView {
                        Text(aiResponse)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white)
                            .lineSpacing(8)
                            .padding(20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 250)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 30)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                Spacer()
                
                // Entry Point: Text Field
                HStack {
                    Image(systemName: "mic")
                        .foregroundColor(.white.opacity(0.7))
                    
                    TextField("Where to?", text: $promptText)
                        .foregroundColor(.white)
                        .accentColor(.white)
                        .disabled(isThinking)
                        .onSubmit {
                            startThinking()
                        }
                    
                    if isThinking {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                    } else {
                        Image(systemName: "location.fill")
                            .foregroundColor(promptText.isEmpty ? .white.opacity(0.5) : .white)
                            .onTapGesture {
                                startThinking()
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
        .animation(.easeInOut(duration: 0.8), value: isThinking)
        .animation(.easeInOut(duration: 0.8), value: showResponse)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
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
    
    func startThinking() {
        guard !promptText.isEmpty else { return }
        
        isThinking = true
        showResponse = false // Hides any previous response
        promptText = ""
        
        // Fakes the delay, then shows the glass window
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            isThinking = false
            aiResponse = "I am Northstar. I am ready to help you navigate your path forward. This window will display my actual insights once we connect the AI brain."
            showResponse = true
        }
    }
}

#Preview {
    ContentView()
}
