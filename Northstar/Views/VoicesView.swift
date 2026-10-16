import SwiftUI

// 🔊 Voices (star menu): choose Northstar's voice and turn reading aloud on or off.
// Premium voices (ElevenLabs) first when they're set up, then the free phone voices, then speed.
// The voice only changes the sound; it's always the same Northstar.

struct VoicesView: View {
    @AppStorage(SettingsKeys.speakReplies) private var speakReplies = false
    @AppStorage(SettingsKeys.voice) private var voiceChoice = NorthstarVoiceChoice.calmUS
    @AppStorage(SettingsKeys.voiceSpeed) private var voiceSpeed = NorthstarVoiceSpeed.normal
    @AppStorage(SettingsKeys.premiumVoice) private var premiumVoice = ""
    @State private var premiumVoices: [PremiumVoice] = []
    @State private var loaded = false

    var body: some View {
        Form {
            Section {
                Toggle("Read replies aloud", isOn: $speakReplies)
                    .onChange(of: speakReplies) {
                        if speakReplies { sampleChosen() } else { NorthstarVoice.shared.stop() }
                    }
            } footer: {
                Text("When on, Northstar reads each reply aloud. You can also tap Listen on any reply.")
            }

            if !premiumVoices.isEmpty {
                Section {
                    ForEach(premiumVoices) { voice in
                        row(title: voice.name,
                            note: nil,
                            picked: premiumVoice == voice.id,
                            pick: { premiumVoice = voice.id; NorthstarVoice.shared.samplePremium(voice) },
                            play: { NorthstarVoice.shared.samplePremium(voice) })
                    }
                } header: {
                    Text("Premium voices")
                } footer: {
                    Text("The most natural sound. Needs the internet.")
                }
            } else if !loaded {
                Section("Premium voices") {
                    HStack { ProgressView(); Text("Loading…").foregroundStyle(.secondary) }
                }
            }

            Section {
                ForEach(NorthstarVoiceChoice.allCases) { choice in
                    row(title: choice.label,
                        note: choice.qualityNote.isEmpty ? nil : choice.qualityNote,
                        picked: premiumVoice.isEmpty && voiceChoice == choice,
                        pick: { voiceChoice = choice; premiumVoice = ""; NorthstarVoice.shared.sample(choice) },
                        play: { NorthstarVoice.shared.sample(choice) })
                }
            } header: {
                Text("Phone voices")
            } footer: {
                Text("Free, private and work offline. For a richer sound, download a Premium voice in iPhone Settings › Accessibility › Spoken Content › Voices › English.")
            }

            Section {
                Picker("Speed", selection: $voiceSpeed) {
                    ForEach(NorthstarVoiceSpeed.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: voiceSpeed) { if premiumVoice.isEmpty { NorthstarVoice.shared.sample(voiceChoice) } }
            } header: {
                Text("Speed")
            } footer: {
                Text("Speed applies to the phone voices.")
            }
        }
        .navigationTitle("Voices")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            premiumVoices = await NorthstarVoice.premiumVoices()
            loaded = true
        }
        .onDisappear { NorthstarVoice.shared.stop() }
    }

    private func sampleChosen() {
        if let voice = premiumVoices.first(where: { $0.id == premiumVoice }) {
            NorthstarVoice.shared.samplePremium(voice)
        } else {
            NorthstarVoice.shared.sample(voiceChoice)
        }
    }

    private func row(title: String, note: String?, picked: Bool, pick: @escaping () -> Void, play: @escaping () -> Void) -> some View {
        HStack {
            Button(action: pick) {
                HStack {
                    Image(systemName: picked ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(picked ? Color.accentColor : .secondary)
                    Text(title)
                    if let note {
                        Text(note).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(picked ? "\(title), chosen" : title)
            Button(action: play) {
                Image(systemName: "play.circle")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Hear \(title)")
        }
    }
}

#Preview {
    NavigationStack { VoicesView() }
}
