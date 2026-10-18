import SwiftUI
import Supabase

// 💬 Feedback (Settings): testers tell Northstar Labs what works and what doesn't.
// Always anonymous: no name, email or account is attached, and the screen says so before sending.

@MainActor
enum FeedbackService {
    private nonisolated struct Request: Encodable, Sendable {
        let message: String
        let rating: Int?
        let kind: String
        let app_version: String
    }
    private nonisolated struct Reply: Decodable, Sendable { let ok: Bool?; let error: String? }

    /// nil when it worked, otherwise a friendly message.
    static func send(message: String, rating: Int?, kind: String) async -> String? {
        let info = Bundle.main.infoDictionary
        let version = "\(info?["CFBundleShortVersionString"] as? String ?? "1.0") (\(info?["CFBundleVersion"] as? String ?? "1"))"
        do {
            let reply: Reply = try await SupabaseManager.shared.client.functions.invoke(
                "northstar-feedback",
                options: FunctionInvokeOptions(body: Request(message: message, rating: rating, kind: kind, app_version: version))
            )
            return reply.ok == true ? nil : (reply.error ?? "Couldn't send right now. Please try again.")
        } catch let FunctionsError.httpError(_, data) {
            return (try? JSONDecoder().decode(Reply.self, from: data))?.error ?? "Couldn't send right now. Please try again."
        } catch {
            return "Couldn't send right now. Please try again."
        }
    }
}

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kind = "general"
    @State private var rating = 0
    @State private var message = ""
    @State private var sending = false
    @State private var sent = false
    @State private var problem: String?
    @FocusState private var typing: Bool

    private var clean: String { message.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                if sent {
                    Section {
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(NorthstarChatStyle.savedGreen)
                            Text("Thank you!").font(.title3.weight(.semibold))
                            Text("Your feedback was sent anonymously. It helps make Northstar better for everyone.")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                } else {
                    Section {
                        Picker("Type", selection: $kind) {
                            Text("General").tag("general")
                            Text("Idea").tag("idea")
                            Text("Problem").tag("problem")
                        }
                        .pickerStyle(.segmented)

                        HStack {
                            Text("Rating")
                            Spacer()
                            ForEach(1...5, id: \.self) { n in
                                Button {
                                    rating = rating == n ? 0 : n
                                } label: {
                                    Image(systemName: n <= rating ? "star.fill" : "star")
                                        .font(.title3)
                                        .foregroundStyle(n <= rating ? NorthstarChatStyle.starGold : .secondary)
                                        .frame(minWidth: 36, minHeight: 44)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(n) star\(n == 1 ? "" : "s")")
                            }
                        }
                    } footer: {
                        Text("Rating is optional.")
                    }

                    Section {
                        TextField(placeholder, text: $message, axis: .vertical)
                            .lineLimit(5...12)
                            .focused($typing)
                    } header: {
                        Text("Your feedback")
                    } footer: {
                        Label("Anonymous. Your name, email and account are never attached.", systemImage: "eye.slash")
                    }

                    if let problem {
                        Section { Text(problem).foregroundStyle(NorthstarChatStyle.warning) }
                    }

                    Section {
                        Button {
                            send()
                        } label: {
                            HStack {
                                Spacer()
                                if sending { ProgressView() } else { Text("Send anonymously").font(.headline) }
                                Spacer()
                            }
                            .frame(minHeight: 44)
                        }
                        .disabled(clean.isEmpty || sending)
                    }
                }
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(sent ? "Done" : "Cancel") { dismiss() }
                }
            }
        }
        .onAppear { typing = true }
    }

    private var placeholder: String {
        switch kind {
        case "idea": return "What would make Northstar better?"
        case "problem": return "What went wrong? What were you trying to do?"
        default: return "What's working? What isn't?"
        }
    }

    private func send() {
        sending = true
        problem = nil
        Task {
            problem = await FeedbackService.send(message: clean, rating: rating == 0 ? nil : rating, kind: kind)
            sending = false
            if problem == nil { withAnimation { sent = true } }
        }
    }
}

#Preview { FeedbackView() }
